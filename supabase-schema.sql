-- Secure schema for the Mayor Ride Co. static storefront.
-- Apply this in the Supabase SQL editor after backing up any important data.

create table if not exists public.users (
  id text primary key,
  name text not null,
  email text not null unique,
  provider text not null default 'email',
  role text not null default 'user',
  created_at timestamptz not null default now()
);

-- The old website stored passwords in plaintext. Supabase Auth owns credentials.
alter table public.users drop column if exists password;

create table if not exists public.products (
  id text primary key,
  name text not null,
  category text not null,
  description text not null,
  price numeric(10,2) not null check (price > 0),
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
  payment_status text not null default 'pending',
  payment_provider text not null default 'paystack',
  payment_reference text unique,
  payment_verified_at timestamptz,
  paid_at timestamptz,
  delivery_method text not null default 'delivery',
  delivery_location text,
  delivery_confirmed boolean not null default false,
  delivered_at timestamptz
);

alter table public.orders
  add column if not exists payment_verified_at timestamptz,
  add column if not exists delivery_location text;
alter table public.orders alter column payment_status set default 'pending';
alter table public.orders alter column paid_at drop default;

create or replace function public.is_store_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1
    from public.users
    where id = (select auth.uid())::text
      and role = 'admin'
  );
$$;

revoke all on function public.is_store_admin() from public, anon;
grant execute on function public.is_store_admin() to authenticated;

create or replace function public.create_user_profile()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.users (id, name, email, provider)
  values (
    new.id::text,
    coalesce(nullif(new.raw_user_meta_data ->> 'name', ''), split_part(new.email, '@', 1)),
    new.email,
    coalesce(new.raw_app_meta_data ->> 'provider', 'email')
  )
  on conflict (id) do update
    set name = excluded.name,
        email = excluded.email,
        provider = excluded.provider;
  return new;
end;
$$;

revoke all on function public.create_user_profile() from public, anon, authenticated;
drop trigger if exists on_auth_user_created_profile on auth.users;
create trigger on_auth_user_created_profile
  after insert on auth.users
  for each row execute function public.create_user_profile();

-- Backfill accounts created before the profile trigger was installed.
insert into public.users (id, name, email, provider)
select
  id::text,
  coalesce(nullif(raw_user_meta_data ->> 'name', ''), split_part(email, '@', 1)),
  email,
  coalesce(raw_app_meta_data ->> 'provider', 'email')
from auth.users
where email is not null
on conflict (id) do nothing;

-- Remove all earlier policies, including the permissive public write policies.
do $$
declare
  policy_record record;
begin
  for policy_record in
    select schemaname, tablename, policyname
    from pg_policies
    where schemaname = 'public'
      and tablename in ('users', 'products', 'orders')
  loop
    execute format(
      'drop policy %I on %I.%I',
      policy_record.policyname,
      policy_record.schemaname,
      policy_record.tablename
    );
  end loop;
end;
$$;

alter table public.users enable row level security;
alter table public.products enable row level security;
alter table public.orders enable row level security;

revoke all on public.users, public.products, public.orders from public, anon, authenticated;
grant select on public.users to authenticated;
grant select on public.products to anon, authenticated;
grant insert, update, delete on public.products to authenticated;
grant select on public.orders to authenticated;
grant update (delivery_confirmed, delivered_at) on public.orders to authenticated;

create policy users_read_self_or_admin
  on public.users for select to authenticated
  using (id = (select auth.uid())::text or (select public.is_store_admin()));

create policy products_public_read
  on public.products for select to anon, authenticated
  using (true);
create policy products_admin_insert
  on public.products for insert to authenticated
  with check ((select public.is_store_admin()));
create policy products_admin_update
  on public.products for update to authenticated
  using ((select public.is_store_admin()))
  with check ((select public.is_store_admin()));
create policy products_admin_delete
  on public.products for delete to authenticated
  using ((select public.is_store_admin()));

create policy orders_read_owner_or_admin
  on public.orders for select to authenticated
  using (user_id = (select auth.uid())::text or (select public.is_store_admin()));
create policy orders_admin_delivery_update
  on public.orders for update to authenticated
  using ((select public.is_store_admin()))
  with check ((select public.is_store_admin()));

-- Public starter inventory is safe to expose; no administrator or password is seeded here.
insert into public.products (id, name, category, description, price, image)
values
  ('prod-001', 'Shark Evo Helmet', 'Helmets',
   'High-impact protection with a lightweight shell and premium comfort fit.',
   299.99, 'https://images.unsplash.com/photo-1591637333184-19aa84b3e01f?auto=format&fit=crop&w=1200&q=80'),
  ('prod-002', 'Alpinestars Gloves', 'Gloves',
   'Rugged grip and dexterity for daily rides and track-ready performance.',
   89.99, 'https://images.unsplash.com/photo-1614165933026-0750fcd503e8?auto=format&fit=crop&w=1200&q=80'),
  ('prod-003', 'Racing Boots', 'Boots',
   'Supportive ankle protection with durable construction and all-day comfort.',
   199.99, 'https://images.unsplash.com/photo-1609630875171-b1321377ee65?auto=format&fit=crop&w=1200&q=80')
on conflict (id) do nothing;
