-- Agent onboarding state.
-- Existing agents remain active; newly invited agents must finish password setup.
alter table public.profiles
  add column if not exists password_set boolean not null default true;

create or replace function public.tz_complete_agent_setup()
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  update public.profiles
  set password_set = true,
      updated_at = now()
  where id = auth.uid()
    and role = 'agent';

  if not found then
    raise exception 'Agent profile not found';
  end if;
end;
$$;

grant execute on function public.tz_complete_agent_setup() to authenticated;
