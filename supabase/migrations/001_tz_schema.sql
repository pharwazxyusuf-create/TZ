-- TZ / Temz Store production schema
create extension if not exists pgcrypto;

create type public.user_role as enum ('admin','agent');
create type public.delivery_status as enum ('New Order','Awaiting Agent Acceptance','Accepted','Out for Delivery','Customer Not Available','Unable to Meet Up','Customer Chose Another Day','Delivered','Cancelled');
create type public.payment_method as enum ('Cash','Bank Transfer');

create table public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  email text not null,
  phone text,
  role public.user_role not null default 'agent',
  state text,
  available boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.products (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  selling_price numeric(12,2) not null default 0 check (selling_price >= 0),
  central_stock integer not null default 0 check (central_stock >= 0),
  active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.agent_stock (
  agent_id uuid not null references public.profiles(id) on delete cascade,
  product_id uuid not null references public.products(id) on delete cascade,
  quantity integer not null default 0 check (quantity >= 0),
  updated_at timestamptz not null default now(),
  primary key (agent_id, product_id)
);

create table public.orders (
  id uuid primary key default gen_random_uuid(),
  order_number text not null unique,
  created_at timestamptz not null default now(),
  customer_name text not null,
  customer_phone text not null,
  customer_email text,
  state text not null,
  city text not null,
  delivery_address text not null,
  assigned_agent_id uuid references public.profiles(id),
  status public.delivery_status not null default 'New Order',
  scheduled_delivery_date date,
  total_amount numeric(12,2) not null default 0,
  amount_charged numeric(12,2),
  amount_remitted numeric(12,2) default 0,
  extra_charge numeric(12,2) default 0,
  extra_charge_reason text,
  payment_method public.payment_method,
  receipt_generated boolean not null default false,
  acceptance_updated_at timestamptz,
  last_agent_update_at timestamptz,
  created_from text default 'app'
);

create table public.order_items (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null references public.orders(id) on delete cascade,
  product_id uuid not null references public.products(id),
  quantity integer not null check (quantity > 0),
  unit_price numeric(12,2) not null check (unit_price >= 0),
  line_total numeric(12,2) generated always as (quantity * unit_price) stored
);

create table public.order_status_history (
  id bigint generated always as identity primary key,
  order_id uuid not null references public.orders(id) on delete cascade,
  status public.delivery_status not null,
  changed_by uuid references public.profiles(id),
  changed_at timestamptz not null default now(),
  note text
);

create table public.receipts (
  id uuid primary key default gen_random_uuid(),
  order_id uuid not null unique references public.orders(id) on delete cascade,
  receipt_number text not null unique,
  generated_at timestamptz not null default now()
);

create table public.device_tokens (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references public.profiles(id) on delete cascade,
  token text not null unique,
  platform text not null,
  active boolean not null default true,
  updated_at timestamptz not null default now()
);

create table public.audit_logs (
  id bigint generated always as identity primary key,
  actor_id uuid references public.profiles(id),
  action text not null,
  entity_type text,
  entity_id uuid,
  details jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now()
);

create index orders_status_idx on public.orders(status);
create index orders_agent_idx on public.orders(assigned_agent_id);
create index orders_phone_idx on public.orders(customer_phone);
create index orders_created_idx on public.orders(created_at desc);
create index order_items_order_idx on public.order_items(order_id);

create or replace function public.current_role() returns public.user_role
language sql stable security definer set search_path = public as $$
  select role from public.profiles where id = auth.uid();
$$;

create or replace function public.is_admin() returns boolean
language sql stable security definer set search_path = public as $$
  select coalesce(public.current_role() = 'admin', false);
$$;

alter table public.profiles enable row level security;
alter table public.products enable row level security;
alter table public.agent_stock enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.order_status_history enable row level security;
alter table public.receipts enable row level security;
alter table public.device_tokens enable row level security;
alter table public.audit_logs enable row level security;

create policy profiles_admin_all on public.profiles for all using (public.is_admin()) with check (public.is_admin());
create policy profiles_self_read on public.profiles for select using (id = auth.uid());

create policy products_authenticated_read on public.products for select using (auth.uid() is not null);
create policy products_admin_write on public.products for all using (public.is_admin()) with check (public.is_admin());

create policy agent_stock_admin_all on public.agent_stock for all using (public.is_admin()) with check (public.is_admin());
create policy agent_stock_self_read on public.agent_stock for select using (agent_id = auth.uid());

create policy orders_admin_all on public.orders for all using (public.is_admin()) with check (public.is_admin());
create policy orders_agent_read_assigned on public.orders for select using (assigned_agent_id = auth.uid());
create policy orders_agent_update_assigned on public.orders for update using (assigned_agent_id = auth.uid()) with check (assigned_agent_id = auth.uid());

create policy order_items_admin_all on public.order_items for all using (public.is_admin()) with check (public.is_admin());
create policy order_items_agent_read_assigned on public.order_items for select using (exists (select 1 from public.orders o where o.id = order_id and o.assigned_agent_id = auth.uid()));

create policy history_admin_all on public.order_status_history for all using (public.is_admin()) with check (public.is_admin());
create policy history_agent_read_assigned on public.order_status_history for select using (exists (select 1 from public.orders o where o.id = order_id and o.assigned_agent_id = auth.uid()));

create policy receipts_admin_all on public.receipts for all using (public.is_admin()) with check (public.is_admin());
create policy receipts_agent_assigned_read on public.receipts for select using (exists (select 1 from public.orders o where o.id = order_id and o.assigned_agent_id = auth.uid()));

create policy tokens_self_manage on public.device_tokens for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy audit_admin_read on public.audit_logs for select using (public.is_admin());

-- Successful delivery stock deduction must be server-side/transactional in the production Edge Function.
-- Do not expose a client-side stock decrement RPC.
