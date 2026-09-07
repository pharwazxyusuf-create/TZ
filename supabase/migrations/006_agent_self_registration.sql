-- Agent self-registration + admin approval workflow
alter table public.profiles
  add column if not exists agent_approval_status text not null default 'approved';

alter table public.profiles
  drop constraint if exists profiles_agent_approval_status_check;

alter table public.profiles
  add constraint profiles_agent_approval_status_check
  check (agent_approval_status in ('pending','approved','rejected'));

-- New auth signups marked as agent registrations enter the pending queue.
-- The three permanent Temz Store admin emails always remain admins.
create or replace function public.tz_profile_bootstrap()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  is_admin_email boolean;
  is_agent_registration boolean;
  new_role public.user_role;
  new_approval text;
  new_available boolean;
begin
  is_admin_email := lower(new.email) in (
    'pharwazxyusuf@gmail.com',
    'mytemzbusiness@gmail.com',
    'omolaratemilade567@gmail.com'
  );
  is_agent_registration := coalesce(new.raw_user_meta_data->>'registration_type','') = 'agent';

  if is_admin_email then
    new_role := 'admin'::public.user_role;
    new_approval := 'approved';
    new_available := true;
  else
    new_role := 'agent'::public.user_role;
    new_approval := case when is_agent_registration then 'pending' else 'approved' end;
    new_available := case when is_agent_registration then false else true end;
  end if;

  insert into public.profiles(
    id, full_name, email, role, phone, state, agent_approval_status, available
  )
  values (
    new.id,
    coalesce(new.raw_user_meta_data->>'full_name',''),
    lower(new.email),
    new_role,
    nullif(new.raw_user_meta_data->>'phone',''),
    nullif(new.raw_user_meta_data->>'state',''),
    new_approval,
    new_available
  )
  on conflict (id) do update set
    full_name = excluded.full_name,
    email = excluded.email,
    phone = excluded.phone,
    state = excluded.state,
    role = case when excluded.role = 'admin' then 'admin'::public.user_role else public.profiles.role end,
    agent_approval_status = case when excluded.role = 'admin' then 'approved' else public.profiles.agent_approval_status end,
    available = case when excluded.role = 'admin' then true else public.profiles.available end,
    updated_at = now();
  return new;
end; $$;

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
