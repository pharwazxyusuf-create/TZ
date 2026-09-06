-- Agent management: admin can deactivate/reactivate agents without deleting order history.
create or replace function public.tz_set_agent_active(p_agent uuid, p_active boolean)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  if not exists (select 1 from public.profiles where id=p_agent and role='agent') then raise exception 'Agent not found'; end if;
  update public.profiles set available=p_active, updated_at=now() where id=p_agent and role='agent';
  insert into public.audit_logs(actor_id, action, entity_type, entity_id, details)
  values(auth.uid(), case when p_active then 'agent_reactivated' else 'agent_deactivated' end, 'profile', p_agent, jsonb_build_object('active',p_active));
end;
$$;

grant execute on function public.tz_set_agent_active(uuid, boolean) to authenticated;

-- An inactive agent must not be able to use TZ even if an old Auth session remains.
