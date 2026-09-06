-- TZ production workflow layer
-- Run after 001_tz_schema.sql

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  title text not null,
  body text not null,
  type text not null default 'info',
  order_id uuid references public.orders(id) on delete cascade,
  read_at timestamptz,
  created_at timestamptz not null default now()
);
create index if not exists notifications_user_idx on public.notifications(user_id, created_at desc);
alter table public.notifications enable row level security;
create policy notifications_self_read on public.notifications for select using (user_id = auth.uid());
create policy notifications_self_update on public.notifications for update using (user_id = auth.uid()) with check (user_id = auth.uid());

create or replace function public.tz_next_order_number()
returns text language plpgsql security definer set search_path = public as $$
declare n bigint;
begin
  select coalesce(max(nullif(regexp_replace(order_number, '[^0-9]', '', 'g'), '')::bigint), 0) + 1 into n from public.orders;
  return 'TZ-' || lpad(n::text, 6, '0');
end; $$;

create or replace function public.tz_profile_bootstrap()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(id, full_name, email, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''), lower(new.email), 'agent')
  on conflict (id) do update set email = excluded.email;
  return new;
end; $$;
drop trigger if exists on_auth_user_created_tz on auth.users;
create trigger on_auth_user_created_tz after insert on auth.users
for each row execute function public.tz_profile_bootstrap();

create or replace function public.tz_notify(p_user uuid, p_title text, p_body text, p_type text, p_order uuid default null)
returns void language sql security definer set search_path = public as $$
  insert into public.notifications(user_id,title,body,type,order_id)
  values(p_user,p_title,p_body,p_type,p_order);
$$;

create or replace function public.tz_assign_order(p_order uuid, p_agent uuid)
returns void language plpgsql security definer set search_path = public as $$
declare agent_name text;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  select full_name into agent_name from public.profiles where id=p_agent and role='agent';
  if agent_name is null then raise exception 'Agent not found'; end if;
  update public.orders set assigned_agent_id=p_agent, status='Awaiting Agent Acceptance', acceptance_updated_at=now(), last_agent_update_at=now() where id=p_order;
  insert into public.order_status_history(order_id,status,changed_by,note) values(p_order,'Awaiting Agent Acceptance',auth.uid(),'Assigned to '||agent_name);
  perform public.tz_notify(p_agent,'New order assigned','You have a new TZ order awaiting your acceptance.','assignment',p_order);
end; $$;

create or replace function public.tz_agent_update_order(
  p_order uuid,
  p_status public.delivery_status,
  p_scheduled_date date default null,
  p_amount_charged numeric default null,
  p_amount_remitted numeric default null,
  p_extra_charge numeric default 0,
  p_extra_reason text default null,
  p_payment_method public.payment_method default null
) returns void language plpgsql security definer set search_path = public as $$
declare current public.orders%rowtype;
begin
  select * into current from public.orders where id=p_order for update;
  if current.id is null then raise exception 'Order not found'; end if;
  if current.assigned_agent_id <> auth.uid() then raise exception 'Order is not assigned to you'; end if;
  if current.status in ('Delivered','Cancelled') then raise exception 'Completed order cannot be changed'; end if;

  if p_status='Delivered' then
    if p_amount_charged is null or p_amount_charged < 0 then raise exception 'Amount charged is required'; end if;
    if p_payment_method is null then raise exception 'Payment method is required'; end if;
    if coalesce(p_extra_charge,0) > 0 and nullif(trim(coalesce(p_extra_reason,'')),'') is null then raise exception 'Extra charge reason is required'; end if;
    if coalesce(p_amount_remitted,0) < 0 then raise exception 'Invalid remitted amount'; end if;
    update public.orders set status='Delivered', scheduled_delivery_date=null, amount_charged=p_amount_charged, amount_remitted=coalesce(p_amount_remitted,0), extra_charge=coalesce(p_extra_charge,0), extra_charge_reason=p_extra_reason, payment_method=p_payment_method, last_agent_update_at=now() where id=p_order;

    -- Deduct every delivered line item from the assigned agent atomically.
    update public.agent_stock s set quantity=s.quantity-i.quantity, updated_at=now()
    from public.order_items i where i.order_id=p_order and i.product_id=s.product_id and s.agent_id=auth.uid() and s.quantity >= i.quantity;
    if exists (select 1 from public.order_items i left join public.agent_stock s on s.product_id=i.product_id and s.agent_id=auth.uid() where i.order_id=p_order and coalesce(s.quantity,0) < i.quantity) then
      raise exception 'Insufficient agent stock for delivered order';
    end if;
    insert into public.receipts(order_id,receipt_number) values(p_order,'RCP-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))) on conflict (order_id) do nothing;
    update public.orders set receipt_generated=true where id=p_order;
  elsif p_status='Customer Chose Another Day' then
    if p_scheduled_date is null or p_scheduled_date <= current_date then raise exception 'Choose a future delivery date'; end if;
    update public.orders set status=p_status, scheduled_delivery_date=p_scheduled_date, last_agent_update_at=now() where id=p_order;
  elsif p_status='Accepted' then
    update public.orders set status=p_status, acceptance_updated_at=now(), last_agent_update_at=now() where id=p_order;
  elsif p_status in ('Out for Delivery','Customer Not Available','Unable to Meet Up','Cancelled') then
    update public.orders set status=p_status, last_agent_update_at=now() where id=p_order;
  else
    raise exception 'Unsupported agent status';
  end if;
  insert into public.order_status_history(order_id,status,changed_by) values(p_order,p_status,auth.uid());
end; $$;

-- Admin can still update orders through the existing admin policy.
-- Agents must use the transactional RPC above; remove broad direct UPDATE access.
drop policy if exists orders_agent_update_assigned on public.orders;

create or replace function public.tz_generate_receipt(p_order uuid)
returns uuid language plpgsql security definer set search_path = public as $$
declare r uuid;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  if not exists(select 1 from public.orders where id=p_order and status='Delivered') then raise exception 'Receipt requires a delivered order'; end if;
  insert into public.receipts(order_id,receipt_number) values(p_order,'RCP-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,10))) on conflict(order_id) do nothing returning id into r;
  update public.orders set receipt_generated=true where id=p_order;
  select id into r from public.receipts where order_id=p_order;
  return r;
end; $$;

-- Initial product catalog. Prices remain admin-editable in the app.
insert into public.products(name,selling_price,central_stock) values
('Motion Sensor Light',18000,120),
('Electronic Posture Corrector',22000,75),
('Anti-Snoring Device',12000,90),
('Creative 3D Visualization Lamp',20000,60)
on conflict(name) do nothing;
