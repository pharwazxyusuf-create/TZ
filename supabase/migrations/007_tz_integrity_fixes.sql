-- TZ integrity fixes discovered during full pre-release audit.

-- 1) Make order numbers concurrency-safe. The previous max()+1 approach could
-- generate duplicate TZ numbers when two orders arrived simultaneously.
create sequence if not exists public.tz_order_number_seq;

select setval(
  'public.tz_order_number_seq',
  greatest(
    coalesce((select max(nullif(regexp_replace(order_number, '[^0-9]', '', 'g'), '')::bigint) from public.orders), 0),
    coalesce((select last_value from public.tz_order_number_seq), 1)
  ),
  true
);

create or replace function public.tz_next_order_number()
returns text language sql security definer set search_path = public as $$
  select 'TZ-' || lpad(nextval('public.tz_order_number_seq')::text, 6, '0');
$$;

-- 2) Never assign an order to a removed/unavailable/unapproved agent.
create or replace function public.tz_assign_order(p_order uuid, p_agent uuid)
returns void language plpgsql security definer set search_path = public as $$
declare agent_name text;
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  select full_name into agent_name
  from public.profiles
  where id=p_agent
    and role='agent'
    and available=true
    and coalesce(agent_approval_status,'approved')='approved';
  if agent_name is null then raise exception 'Agent is not approved or available'; end if;

  update public.orders
  set assigned_agent_id=p_agent,
      status='Awaiting Agent Acceptance',
      acceptance_updated_at=now(),
      last_agent_update_at=now()
  where id=p_order;
  if not found then raise exception 'Order not found'; end if;

  insert into public.order_status_history(order_id,status,changed_by,note)
  values(p_order,'Awaiting Agent Acceptance',auth.uid(),'Assigned to '||agent_name);
  perform public.tz_notify(p_agent,'New order assigned','You have a new TZ order awaiting your acceptance.','assignment',p_order);
end; $$;

-- 3) Delivery should only deduct agent stock. Receipt generation remains a
-- separate admin action after delivery/payment confirmation, as specified.
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

    -- Validate all lines before changing stock so insufficient stock fails
    -- atomically without leaving partial deductions.
    if exists (
      select 1
      from public.order_items i
      left join public.agent_stock s
        on s.product_id=i.product_id and s.agent_id=auth.uid()
      where i.order_id=p_order and coalesce(s.quantity,0) < i.quantity
    ) then
      raise exception 'Insufficient agent stock for delivered order';
    end if;

    update public.orders
    set status='Delivered',
        scheduled_delivery_date=null,
        amount_charged=p_amount_charged,
        amount_remitted=coalesce(p_amount_remitted,0),
        extra_charge=coalesce(p_extra_charge,0),
        extra_charge_reason=p_extra_reason,
        payment_method=p_payment_method,
        last_agent_update_at=now()
    where id=p_order;

    update public.agent_stock s
    set quantity=s.quantity-i.quantity,
        updated_at=now()
    from public.order_items i
    where i.order_id=p_order
      and i.product_id=s.product_id
      and s.agent_id=auth.uid();

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

  insert into public.order_status_history(order_id,status,changed_by)
  values(p_order,p_status,auth.uid());
end; $$;
