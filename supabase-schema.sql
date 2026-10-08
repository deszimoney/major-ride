create table if not exists public.users (
  id text primary key,
  name text not null,
  email text not null unique,
  password text,
  provider text not null default 'email',
  role text not null default 'user',
  created_at timestamptz not null default now()
);

create table if not exists public.products (
  id text primary key,
  name text not null,
  category text not null,
  description text not null,
  price numeric(10,2) not null,
  image text,
  created_at timestamptz not null default now()
);

create table if not exists public.orders (
  id text primary key,
  user_id text not null,
  user_name text not null,
  user_email text not null,
  items jsonb not null,
  subtotal numeric(10,2) not null,
  service_fee numeric(10,2) not null,
  total numeric(10,2) not null,
  payment_status text not null default 'completed',
  payment_provider text not null default 'paystack',
  payment_reference text unique,
  paid_at timestamptz not null default now(),
  delivery_method text not null default 'delivery',
  delivery_location text,
  delivery_confirmed boolean not null default false,
  delivered_at timestamptz
);

alter table public.orders add column if not exists payment_provider text not null default 'paystack';
alter table public.orders add column if not exists payment_reference text unique;
alter table public.orders add column if not exists delivery_location text;

alter table public.users enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;

-- Users Table Policies
drop policy if exists "public users can read" on public.users;
create policy "public users can read" on public.users for select using (true);

drop policy if exists "public users can insert" on public.users;
create policy "public users can insert" on public.users for insert with check (true);

drop policy if exists "public users can update" on public.users;
create policy "public users can update" on public.users for update using (true) with check (true);

-- Products Table Policies
drop policy if exists "public products can read" on public.products;
create policy "public products can read" on public.products for select using (true);

drop policy if exists "public products can insert" on public.products;
create policy "public products can insert" on public.products for insert with check (true);

drop policy if exists "public products can update" on public.products;
create policy "public products can update" on public.products for update using (true) with check (true);

drop policy if exists "public products can delete" on public.products;
create policy "public products can delete" on public.products for delete using (true);

-- Orders Table Policies
drop policy if exists "public orders can read" on public.orders;
create policy "public orders can read" on public.orders for select using (true);

drop policy if exists "public orders can insert" on public.orders;
create policy "public orders can insert" on public.orders for insert with check (true);

drop policy if exists "public orders can update" on public.orders;
create policy "public orders can update" on public.orders for update using (true) with check (true);

-- Seed Data
insert into public.users (id, name, email, password, provider, role)
values (
  'admin-001',
  'Owner',
  'admin@mayorrideco.com',
  'admin123',
  'email',
  'admin'
)
on conflict (email) do update set
  name = excluded.name,
  password = excluded.password,
  provider = excluded.provider,
  role = excluded.role;

insert into public.products (id, name, category, description, price, image)
values
  (
    'prod-001',
    'Shark Evo Helmet',
    'Helmets',
    'High-impact protection with a lightweight shell and premium comfort fit.',
    299.99,
    'https://unsplash.com'
  ),
  (
    'prod-002',
    'Alpinestars Gloves',
    'Gloves',
    'Rugged grip and dexterity for daily rides and track-ready performance.',
    89.99,
    'https://unsplash.com'
  ),
  (
    'prod-003',
    'Racing Boots',
    'Boots',
    'Supportive ankle protection with durable construction and all-day comfort.',
    199.99,
    'https://unsplash.com'
  )
on conflict (id) do nothing;
