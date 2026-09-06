-- TZ business rules: secure profile bootstrap and transactional delivery

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, full_name, email, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name', ''),
    lower(new.email),
    case
      when lower(new.email) in (
        'pharwazxyusuf@gmail.com',
        'mytemzbusiness@gmail.com',
        'omolaratemilade567@gmail.com'
      ) then 'admin'::public.user_role
      else 'agent'::public.user_role
    end
  )
  on conflict (id) do update
    set email = excluded.email;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute function public.handle_new_user();

-- Agents may update their own delivery/payment information only through this RPC.
-- This prevents a client from directly moving stock or changing its assignment.
create or replace function public.agent_update_order(
  p_order_id uuid,
  p_status public.delivery_status default null,
  p_scheduled_delivery_date date default null,
  p_amount_charged numeric default null,
  p_amount_remitted numeric default null,
  p_extra_charge numeric default null,
  p_extra_charge_reason text default null,
  p_payment_method public.payment_method default null
)
returns public.orders
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders;
  v_old_status public.delivery_status;
  v_new_status public.delivery_status;
begin
  select * into v_order
  from public.orders
  where id = p_order_id
    and assigned_agent_id = auth.uid()
  for update;

  if not found then
    raise exception 'Order not found or not assigned to this agent';
  end if;

  v_old_status := v_order.status;
  v_new_status := coalesce(p_status, v_order.status);

  -- Final states cannot be reopened by an agent.
  if v_old_status in ('Delivered','Cancelled') and v_new_status <> v_old_status then
    raise exception 'Final orders cannot be reopened';
  end if;

  -- Delivered is transactional: verify custody, deduct each line item once, then update order.
  if v_new_status = 'Delivered' and v_old_status <> 'Delivered' then
    if p_payment_method is null then
      raise exception 'Payment method is required for delivery';
    end if;

    if exists (
      select 1
      from public.order_items oi
      left join public.agent_stock ast
        on ast.agent_id = v_order.assigned_agent_id
       and ast.product_id = oi.product_id
      where oi.order_id = v_order.id
        and coalesce(ast.quantity, 0) < oi.quantity
    ) then
      raise exception 'Insufficient agent stock for this delivery';
    end if;

    update public.agent_stock ast
    set quantity = ast.quantity - oi.quantity,
        updated_at = now()
    from public.order_items oi
    where ast.agent_id = v_order.assigned_agent_id
      and ast.product_id = oi.product_id
      and oi.order_id = v_order.id;
  end if;

  update public.orders
  set status = v_new_status,
      scheduled_delivery_date = case
        when v_new_status = 'Customer Chose Another Day' then p_scheduled_delivery_date
        else scheduled_delivery_date
      end,
      amount_charged = coalesce(p_amount_charged, amount_charged),
      amount_remitted = coalesce(p_amount_remitted, amount_remitted),
      extra_charge = coalesce(p_extra_charge, extra_charge),
      extra_charge_reason = coalesce(p_extra_charge_reason, extra_charge_reason),
      payment_method = coalesce(p_payment_method, payment_method),
      acceptance_updated_at = case when v_old_status = 'Awaiting Agent Acceptance' and v_new_status in ('Accepted','Cancelled') then now() else acceptance_updated_at end,
      last_agent_update_at = now()
  where id = v_order.id
  returning * into v_order;

  insert into public.order_status_history(order_id,status,changed_by)
  values (v_order.id,v_order.status,auth.uid());

  return v_order;
end;
$$;

revoke all on function public.agent_update_order(uuid,public.delivery_status,date,numeric,numeric,numeric,text,public.payment_method) from public;
grant execute on function public.agent_update_order(uuid,public.delivery_status,date,numeric,numeric,numeric,text,public.payment_method) to authenticated;

-- Receipt generation is only allowed after successful delivery.
create or replace function public.generate_receipt(p_order_id uuid)
returns public.receipts
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders;
  v_receipt public.receipts;
  v_num text;
begin
  select * into v_order from public.orders where id = p_order_id;
  if not found then raise exception 'Order not found'; end if;
  if not (public.is_admin() or v_order.assigned_agent_id = auth.uid()) then
    raise exception 'Not authorized';
  end if;
  if v_order.status <> 'Delivered' then
    raise exception 'Receipt can only be generated for delivered orders';
  end if;
  if v_order.payment_method is null then
    raise exception 'Payment method is required before generating receipt';
  end if;

  select * into v_receipt from public.receipts where order_id = p_order_id;
  if found then return v_receipt; end if;

  v_num := 'R-' || replace(v_order.order_number, 'TZ-', '');
  insert into public.receipts(order_id, receipt_number)
  values (p_order_id, v_num)
  returning * into v_receipt;

  update public.orders set receipt_generated = true where id = p_order_id;
  return v_receipt;
end;
$$;

grant execute on function public.generate_receipt(uuid) to authenticated;

-- Seed the initial catalogue. Prices remain editable only by admins through RLS.
insert into public.products (name, selling_price, central_stock)
values
  ('Motion Sensor Light', 18000, 120),
  ('Electronic Posture Corrector', 22000, 75),
  ('Anti-Snoring Device', 12000, 90),
  ('Creative 3D Visualization Lamp', 20000, 60)
on conflict (name) do nothing;
