-- Agent self-registration + admin approval workflow
alter table public.profiles
  add column if not exists agent_approval_status text not null default 'approved';

alter table public.profiles
  drop constraint if exists profiles_agent_approval_status_check;

alter table public.profiles
  add constraint profiles_agent_approval_status_check
  check (agent_approval_status in ('pending','approved','rejected'));

-- New public signups marked as agent registrations enter the pending queue.
create or replace function public.tz_profile_bootstrap()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into public.profiles(
    id, full_name, email, role, phone, state, agent_approval_status, available
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name',''),
    lower(new.email),
    'agent',
    nullif(new.raw_user_meta_data->>'phone',''),
    nullif(new.raw_user_meta_data->>'state',''),
    case when coalesce(new.raw_user_meta_data->>'registration_type','') = 'agent' then 'pending' else 'approved' end,
    case when coalesce(new.raw_user_meta_data->>'registration_type','') = 'agent' then false else true end
  )
  on conflict (id) do update set
    full_name = excluded.full_name,
    email = excluded.email,
    phone = excluded.phone,
    state = excluded.state;
  return new;
end; $$;

-- Admin approves/rejects an agent. Rejection preserves the account/history.
create or replace function public.tz_set_agent_approval(
  p_agent uuid,
  p_status text
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  if p_status not in ('approved','rejected','pending') then raise exception 'Invalid approval status'; end if;
  if not exists(select 1 from public.profiles where id=p_agent and role='agent') then raise exception 'Agent not found'; end if;

  update public.profiles
  set agent_approval_status = p_status,
      available = (p_status = 'approved'),
      updated_at = now()
  where id = p_agent;

  insert into public.audit_logs(actor_id, action, entity_type, entity_id, details)
  values(auth.uid(), 'agent_approval_' || p_status, 'profile', p_agent, jsonb_build_object('status',p_status));
end; $$;

-- Keep existing removal/restore behavior, but never restore an unapproved agent.
create or replace function public.tz_set_agent_active(
  p_agent uuid,
  p_active boolean
) returns void language plpgsql security definer set search_path = public as $$
begin
  if not public.is_admin() then raise exception 'Admin access required'; end if;
  update public.profiles
  set available = case when p_active then (agent_approval_status = 'approved') else false end,
      updated_at = now()
  where id=p_agent and role='agent';
  if not found then raise exception 'Agent not found'; end if;
end; $$;
