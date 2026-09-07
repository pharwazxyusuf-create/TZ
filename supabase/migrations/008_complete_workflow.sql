-- TZ final workflow hardening.
-- Concurrency-safe order numbers; first generated order is TZ-000001.
create sequence if not exists public.tz_order_number_seq;
select setval('public.tz_order_number_seq', coalesce((select max(nullif(regexp_replace(order_number,'[^0-9]','','g'),'')::bigint) from public.orders),0), true);
create or replace function public.tz_next_order_number()
returns text language sql security definer set search_path=public as $$
  select 'TZ-' || lpad(nextval('public.tz_order_number_seq')::text,6,'0');
$$;

create or replace function public.tz_agent_reject_order(p_order uuid)
returns void language plpgsql security definer set search_path = public as $$
declare o public.orders%rowtype;
begin
  select * into o from public.orders where id=p_order for update;
  if o.id is null then raise exception 'Order not found'; end if;
  if o.assigned_agent_id <> auth.uid() then raise exception 'Order is not assigned to you'; end if;
  if o.status <> 'Awaiting Agent Acceptance' then raise exception 'Order is not awaiting acceptance'; end if;
  update public.orders set assigned_agent_id=null,status='New Order',acceptance_updated_at=now(),last_agent_update_at=now() where id=p_order;
  insert into public.order_status_history(order_id,status,changed_by,note) values(p_order,'New Order',auth.uid(),'Agent rejected assignment; order returned for reassignment');
  insert into public.notifications(user_id,title,body,type,order_id)
    select id,'Agent rejected order',o.order_number || ' was rejected and is ready for reassignment.','agent_rejection',p_order from public.profiles where role='admin';
end; $$;

create or replace function public.tz_set_agent_stock(p_agent uuid, p_product uuid, p_quantity integer)
returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  if p_quantity < 0 then raise exception 'Quantity cannot be negative'; end if;
  if not exists(select 1 from public.profiles where id=p_agent and role='agent') then raise exception 'Agent not found'; end if;
  if not exists(select 1 from public.products where id=p_product) then raise exception 'Product not found'; end if;
  insert into public.agent_stock(agent_id,product_id,quantity,updated_at) values(p_agent,p_product,p_quantity,now())
  on conflict(agent_id,product_id) do update set quantity=excluded.quantity,updated_at=now();
end; $$;

create or replace function public.tz_run_agent_reminders()
returns integer language plpgsql security definer set search_path = public as $$
declare r record; c integer := 0;
begin
  for r in select id,assigned_agent_id,order_number from public.orders where assigned_agent_id is not null and status not in ('Delivered','Cancelled') and last_agent_update_at < now()-interval '3 hours' loop
    insert into public.notifications(user_id,title,body,type,order_id) values(r.assigned_agent_id,'TZ order reminder',r.order_number || ' needs a delivery status update.','reminder',r.id);
    update public.orders set last_agent_update_at=now() where id=r.id;
    c := c+1;
  end loop;
  return c;
end; $$;

drop policy if exists orders_agent_update_assigned on public.orders;
