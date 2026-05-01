-- Core schema: profiles, organizations, memberships, and shared triggers.

--------------------------------------------------------------------------------
-- updated_at helper
--------------------------------------------------------------------------------

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.updated_at := timezone('utc', now());
  return new;
end;
$$;

--------------------------------------------------------------------------------
-- profiles (1:1 with auth.users)
-- Insert/update from the app after sign-in (e.g. ensureUserProfile), not triggers on auth.users.
--------------------------------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create trigger profiles_set_updated_at
  before update on public.profiles
  for each row
  execute function public.set_updated_at();

alter table public.profiles enable row level security;

create policy "profiles_select_own"
  on public.profiles
  for select
  to authenticated
  using (id = auth.uid());

create policy "profiles_insert_own"
  on public.profiles
  for insert
  to authenticated
  with check (id = auth.uid());

create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

--------------------------------------------------------------------------------
-- organizations & memberships
--------------------------------------------------------------------------------

create table public.organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create trigger organizations_set_updated_at
  before update on public.organizations
  for each row
  execute function public.set_updated_at();

create table public.organization_members (
  organization_id uuid not null references public.organizations (id) on delete cascade,
  user_id uuid not null references auth.users (id) on delete cascade,
  role text not null default 'member'
    check (role in ('owner', 'admin', 'member')),
  created_at timestamptz not null default timezone('utc', now()),
  primary key (organization_id, user_id)
);

create index organization_members_user_id_idx
  on public.organization_members (user_id);

alter table public.organizations enable row level security;
alter table public.organization_members enable row level security;

create policy "organizations_select_member"
  on public.organizations
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.organization_members m
      where m.organization_id = organizations.id
        and m.user_id = auth.uid()
    )
  );

create policy "organizations_update_owner_admin"
  on public.organizations
  for update
  to authenticated
  using (
    exists (
      select 1
      from public.organization_members m
      where m.organization_id = organizations.id
        and m.user_id = auth.uid()
        and m.role in ('owner', 'admin')
    )
  )
  with check (
    exists (
      select 1
      from public.organization_members m
      where m.organization_id = organizations.id
        and m.user_id = auth.uid()
        and m.role in ('owner', 'admin')
    )
  );

create policy "organization_members_select_same_org"
  on public.organization_members
  for select
  to authenticated
  using (
    exists (
      select 1
      from public.organization_members me
      where me.organization_id = organization_members.organization_id
        and me.user_id = auth.uid()
    )
  );

-- Inserts are not granted directly: use create_organization_with_owner() so users
-- cannot add themselves to arbitrary orgs.

--------------------------------------------------------------------------------
-- Create org + founding membership (atomic, trusted)
--------------------------------------------------------------------------------

create or replace function public.create_organization_with_owner(
  p_name text,
  p_slug text
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_org_id uuid;
  v_uid uuid;
begin
  v_uid := auth.uid();
  if v_uid is null then
    raise exception 'Not authenticated';
  end if;

  insert into public.organizations (name, slug)
  values (p_name, p_slug)
  returning id into v_org_id;

  insert into public.organization_members (organization_id, user_id, role)
  values (v_org_id, v_uid, 'owner');

  return v_org_id;
end;
$$;

revoke all on function public.create_organization_with_owner(text, text) from public;
grant execute on function public.create_organization_with_owner(text, text) to authenticated;

-- ============================================================
-- LITTLE BIGS POS — STEP 1
-- Core Data Tables
-- vendors, units_of_measure, inventory_categories, ingredients
-- ============================================================

create extension if not exists pgcrypto with schema extensions;

-- ============================================================
-- UNITS OF MEASURE
-- ============================================================

create table public.units_of_measure (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  abbreviation text not null unique,
  unit_type text not null check (unit_type in ('weight', 'volume', 'count')),
  created_at timestamptz default timezone('utc', now())
);

insert into public.units_of_measure (name, abbreviation, unit_type) values
  ('ounce', 'oz', 'weight'),
  ('pound', 'lb', 'weight'),
  ('fluid ounce', 'fl oz', 'volume'),
  ('gallon', 'gal', 'volume'),
  ('tablespoon', 'tbsp', 'volume'),
  ('teaspoon', 'tsp', 'volume'),
  ('each', 'ea', 'count'),
  ('case', 'cs', 'count'),
  ('bag', 'bag', 'count'),
  ('can', 'can', 'count'),
  ('roll', 'roll', 'count'),
  ('box', 'box', 'count');

-- ============================================================
-- VENDORS
-- ============================================================

create table public.vendors (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  customer_number text,
  rep_name text,
  rep_phone text,
  delivery_days text[],
  driver_name text,
  payment_terms text default 'NET 7 DAYS',
  phone text,
  is_active boolean default true,
  notes text,
  created_at timestamptz default timezone('utc', now()),
  updated_at timestamptz default timezone('utc', now())
);

create trigger vendors_set_updated_at
  before update on public.vendors
  for each row
  execute function public.set_updated_at();

insert into public.vendors (
  name,
  customer_number,
  rep_name,
  rep_phone,
  delivery_days,
  driver_name,
  payment_terms,
  phone
) values (
  'Performance Foodservice Maryland',
  '55090819',
  'Lou Lutz',
  '855-813-1332',
  array['Monday', 'Thursday'],
  'Robert Allen',
  'NET 7 DAYS',
  '800-755-4223'
);

-- ============================================================
-- INVENTORY CATEGORIES
-- ============================================================

create table public.inventory_categories (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  gl_account text not null default '5000',
  sort_order integer default 0,
  created_at timestamptz default timezone('utc', now())
);

insert into public.inventory_categories (name, gl_account, sort_order) values
  ('Meat & Proteins', '5030', 1),
  ('Poultry', '5030', 2),
  ('Cheese & Dairy', '5050', 3),
  ('Sauces & Condiments', '5010', 4),
  ('Dressings', '5040', 5),
  ('Produce - Fresh', '5040', 6),
  ('Produce - Canned', '5040', 7),
  ('Bread & Rolls', '5010', 8),
  ('Dry Goods & Pantry', '5010', 9),
  ('Oils & Fats', '5010', 10),
  ('Frozen Sides', '5020', 11),
  ('Beverages', '5010', 12),
  ('Packaging', '5060', 13),
  ('Cleaning & Supplies', '7000', 14);

-- ============================================================
-- INGREDIENTS
-- ============================================================

create table public.ingredients (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  vendor_id uuid references public.vendors (id),
  vendor_sku text,
  category_id uuid references public.inventory_categories (id),
  purchase_unit_id uuid references public.units_of_measure (id),
  purchase_pack_size text,
  purchase_unit_oz numeric(10, 4),
  case_cost numeric(10, 4),
  cost_per_oz numeric(10, 6),
  recipe_unit_id uuid references public.units_of_measure (id),
  on_hand_oz numeric(10, 2) default 0,
  storage_temp text check (storage_temp in ('dry', 'refrigerated', 'frozen')),
  gl_account text default '5000',
  is_active boolean default true,
  notes text,
  created_at timestamptz default timezone('utc', now()),
  updated_at timestamptz default timezone('utc', now())
);

create trigger ingredients_set_updated_at
  before update on public.ingredients
  for each row
  execute function public.set_updated_at();
