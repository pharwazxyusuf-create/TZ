-- Admin can promote an existing agent account to administrator and revoke admin from another admin.
create or replace function public.tz_set_admin_role(p_user uuid, p_make_admin boolean)
returns void language plpgsql security definer set search_path=public as $$
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  if p_user=auth.uid() and not p_make_admin then raise exception 'You cannot remove your own administrator access'; end if;
  if p_make_admin then
    update public.profiles set role='admin',available=true,agent_approval_status='approved',updated_at=now() where id=p_user;
  else
    update public.profiles set role='agent',available=false,agent_approval_status='approved',updated_at=now() where id=p_user;
  end if;
  if not found then raise exception 'User profile not found'; end if;
  insert into public.audit_logs(actor_id,action,entity_type,entity_id,details)
  values(auth.uid(),case when p_make_admin then 'promote_admin' else 'demote_admin' end,'profile',p_user,jsonb_build_object('admin',p_make_admin));
end; $$;
