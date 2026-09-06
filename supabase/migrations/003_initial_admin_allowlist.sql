-- Initial Temz Store administrators.
-- When any of these emails are created in Supabase Auth, the profile is automatically promoted to admin.
create or replace function public.tz_profile_bootstrap()
returns trigger language plpgsql security definer set search_path = public as $$
declare r public.user_role;
begin
  r := case when lower(new.email) in (
    'pharwazxyusuf@gmail.com',
    'mytemzbusiness@gmail.com',
    'omolaratemilade567@gmail.com'
  ) then 'admin'::public.user_role else 'agent'::public.user_role end;
  insert into public.profiles(id, full_name, email, role)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name',''), lower(new.email), r)
  on conflict (id) do update set email=excluded.email, role=case when excluded.role='admin' then 'admin'::public.user_role else public.profiles.role end;
  return new;
end; $$;
