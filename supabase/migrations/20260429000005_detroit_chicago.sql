-- ============================================================
-- LITTLE BIGS POS — DETROIT & CHICAGO
-- Chicago sizes, recipe slots, Detroit/Chicago topping $
-- Depends on: 00003 (detroit_sizes), 00004 (sauce_recipes, menu)
-- ============================================================

--------------------------------------------------------------------------------
-- CHICAGO DEEP-DISH SIZES
--------------------------------------------------------------------------------

create table if not exists public.chicago_sizes (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  dimensions text not null,
  base_price decimal(10, 2) not null,
  sort_order integer default 0,
  is_active boolean default true,
  created_at timestamptz not null default timezone('utc', now())
);

insert into public.chicago_sizes (name, slug, dimensions, base_price, sort_order) values
  ('Personal', 'chicago-personal', '10-inch deep pan', 22.00, 1),
  ('Large',    'chicago-lg',       '12-inch deep pan', 24.00, 2),
  ('Party',    'chicago-party',    '14-inch deep pan', 26.00, 3);

comment on table public.chicago_sizes is
  'Chicago deep-dish price tiers; recipe lines live in public.chicago_recipe_slots.';

--------------------------------------------------------------------------------
-- DETROIT RECIPE SLOTS
--------------------------------------------------------------------------------

create table if not exists public.detroit_recipe_slots (
  id uuid primary key default gen_random_uuid(),
  detroit_size_id uuid not null references public.detroit_sizes (id) on delete cascade,
  slot_type text not null check (slot_type in (
                  'sauce', 'cheese', 'topping', 'dough')),
  ingredient_id uuid references public.ingredients (id),
  sauce_recipe_id uuid references public.sauce_recipes (id),
  quantity_oz numeric(10, 4) not null,
  half_qty_oz numeric(10, 4),
  portioning text not null check (portioning in (
                  'cup', 'pre_bagged', 'weighed_live', 'fixed')),
  cup_color text,
  cup_count integer default 1,
  notes text,
  created_at timestamptz not null default timezone('utc', now())
);

-- Small  2× Green = 8oz | Large 2× Blue = 12oz | XL 2× Grey = 20oz

insert into public.detroit_recipe_slots (
  detroit_size_id, slot_type, ingredient_id,
  quantity_oz, portioning, cup_color, cup_count, notes
)
select
  ds.id,
  'cheese',
  i.id,
  case ds.slug
    when 'detroit-sm' then 8.0
    when 'detroit-lg' then 12.0
    when 'detroit-xl' then 20.0
  end,
  'cup',
  case ds.slug
    when 'detroit-sm' then 'green'::text
    when 'detroit-lg' then 'blue'::text
    when 'detroit-xl' then 'grey'::text
  end,
  2,
  'Bacio mozzarella 2 cups — ' || ds.name
from public.detroit_sizes ds
cross join public.ingredients i
where i.vendor_sku = '337784';

-- Topping oz by size (full/half cups)

insert into public.detroit_recipe_slots (
  detroit_size_id, slot_type,
  quantity_oz, half_qty_oz, portioning,
  cup_color, cup_count, notes
)
select
  ds.id,
  'topping',
  case ds.slug
    when 'detroit-sm' then 2.0::numeric
    when 'detroit-lg' then 4.0
    when 'detroit-xl' then 6.0
  end,
  case ds.slug
    when 'detroit-sm' then 1.5
    when 'detroit-lg' then 2.0
    when 'detroit-xl' then 3.0
  end,
  'cup',
  case ds.slug
    when 'detroit-sm' then 'red'::text
    when 'detroit-lg' then 'green'::text
    when 'detroit-xl' then 'black'::text
  end,
  2,
  'Standard topping — ' || ds.name
from public.detroit_sizes ds;

insert into public.detroit_recipe_slots (
  detroit_size_id, slot_type, sauce_recipe_id,
  quantity_oz, portioning, notes
)
select
  ds.id,
  'sauce',
  sr.id,
  case ds.slug
    when 'detroit-sm' then 3.0::numeric
    when 'detroit-lg' then 5.0
    when 'detroit-xl' then 8.0
  end,
  'fixed',
  'House pizza sauce — ' || ds.name
from public.detroit_sizes ds
cross join public.sauce_recipes sr
where sr.slug = 'house-pizza-sauce';

--------------------------------------------------------------------------------
-- DETROIT TOPPING PRICING (align to 20" round)
--------------------------------------------------------------------------------

create table if not exists public.detroit_topping_pricing (
  id uuid primary key default gen_random_uuid(),
  detroit_size_id uuid not null references public.detroit_sizes (id) on delete cascade,
  whole_price decimal(10, 2) not null default 1.99,
  half_price decimal(10, 2) not null default 1.99,
  created_at timestamptz not null default timezone('utc', now()),
  unique (detroit_size_id)
);

insert into public.detroit_topping_pricing (detroit_size_id, whole_price, half_price)
select id, 1.99, 1.99
from public.detroit_sizes;

--------------------------------------------------------------------------------
-- CHICAGO RECIPE SLOTS
--------------------------------------------------------------------------------

create table if not exists public.chicago_recipe_slots (
  id uuid primary key default gen_random_uuid(),
  menu_item_id uuid not null references public.menu_items (id) on delete cascade,
  slot_type text not null check (slot_type in (
                  'sauce', 'cheese', 'topping', 'dough', 'protein', 'side')),
  ingredient_id uuid references public.ingredients (id),
  sauce_recipe_id uuid references public.sauce_recipes (id),
  quantity_oz numeric(10, 4) not null,
  half_qty_oz numeric(10, 4),
  portioning text not null check (portioning in (
                  'cup', 'pre_bagged', 'weighed_live', 'fixed')),
  cup_color text,
  cup_count integer default 1,
  notes text,
  created_at timestamptz not null default timezone('utc', now())
);

insert into public.chicago_recipe_slots (
  menu_item_id, slot_type, ingredient_id,
  quantity_oz, portioning, cup_color, cup_count, notes
)
select
  mi.id,
  'cheese',
  i.id,
  15.0,
  'cup',
  'grey',
  3,
  '3 Grey cups = 15oz mozzarella — ' || mi.name
from public.menu_items mi
cross join public.ingredients i
where mi.category_id = (
  select id from public.menu_categories where slug = 'chicago'
)
and i.vendor_sku = '337784';

insert into public.chicago_recipe_slots (
  menu_item_id, slot_type,
  quantity_oz, half_qty_oz, portioning,
  cup_color, cup_count, notes
)
select
  mi.id,
  'topping',
  8.0,
  4.0,
  'cup',
  'blue',
  1,
  'Chicago topping — ' || mi.name
from public.menu_items mi
where mi.category_id = (
  select id from public.menu_categories where slug = 'chicago'
)
and mi.slug != 'the-city';

insert into public.chicago_recipe_slots (
  menu_item_id, slot_type, sauce_recipe_id,
  quantity_oz, portioning, notes
)
select
  mi.id,
  'sauce',
  sr.id,
  6.0,
  'fixed',
  'House pizza sauce — ' || mi.name
from public.menu_items mi
cross join public.sauce_recipes sr
where mi.category_id = (
  select id from public.menu_categories where slug = 'chicago'
)
and sr.slug = 'house-pizza-sauce';

insert into public.chicago_recipe_slots (
  menu_item_id, slot_type, ingredient_id,
  quantity_oz, portioning, notes
)
select mi.id, 'protein', i.id, 12.0, 'pre_bagged',
  'Grilled Chicken 12oz pre-bagged'
from public.menu_items mi
cross join public.ingredients i
where mi.slug = 'memphis-deep-dish'
and i.vendor_sku = '600752';

insert into public.chicago_recipe_slots (
  menu_item_id, slot_type, ingredient_id,
  quantity_oz, portioning, notes
)
select mi.id, 'protein', i.id, 12.0, 'weighed_live',
  'Grilled Chicken 12oz OR Crispy Chicken — scale weight TBD'
from public.menu_items mi
cross join public.ingredients i
where mi.slug = 'big-buff'
and i.vendor_sku = '600752';

insert into public.chicago_recipe_slots (
  menu_item_id, slot_type, ingredient_id,
  quantity_oz, portioning, notes
)
select mi.id, 'side', i.id, 4.0, 'fixed',
  'Blue Cheese 4oz — included with Big Buff'
from public.menu_items mi
cross join public.ingredients i
where mi.slug = 'big-buff'
and i.vendor_sku = '34977';

insert into public.chicago_recipe_slots (
  menu_item_id, slot_type, ingredient_id,
  quantity_oz, portioning, notes
)
select mi.id, 'side', i.id, 4.0, 'fixed',
  'Ranch 4oz — included with Big Buff'
from public.menu_items mi
cross join public.ingredients i
where mi.slug = 'big-buff'
and i.vendor_sku = '35399';

--------------------------------------------------------------------------------
-- THE CITY TOPPING PRICING
--------------------------------------------------------------------------------

create table if not exists public.city_topping_pricing (
  id uuid primary key default gen_random_uuid(),
  topping_id uuid not null references public.toppings (id) on delete cascade,
  price decimal(10, 2) not null,
  price_type text not null check (price_type in ('meat_cheese', 'veggie')),
  created_at timestamptz not null default timezone('utc', now()),
  unique (topping_id)
);

insert into public.city_topping_pricing (topping_id, price, price_type)
select id, 2.60, 'meat_cheese'::text
from public.toppings
where slug in (
  'pepperoni', 'sausage', 'ham', 'bacon', 'salami',
  'ground-beef', 'steak', 'grilled-chicken',
  'crispy-chicken', 'x-mozzarella', 'x-provolone'
);

insert into public.city_topping_pricing (topping_id, price, price_type)
select id, 2.30, 'veggie'::text
from public.toppings
where slug in (
  'green-peppers', 'sweet-peppers', 'banana-peppers',
  'black-olives', 'mushrooms', 'onions', 'tomatoes',
  'lettuce', 'pineapple', 'pickles', 'jalapenos',
  'ricotta', 'spring-mix', 'x-sauce'
);

--------------------------------------------------------------------------------
-- ROW LEVEL SECURITY
--------------------------------------------------------------------------------

alter table public.chicago_sizes enable row level security;

create policy "chicago_sizes_select_public"
  on public.chicago_sizes
  for select
  to anon, authenticated
  using (true);

alter table public.detroit_recipe_slots enable row level security;

create policy "detroit_recipe_slots_select_authenticated"
  on public.detroit_recipe_slots for select to authenticated using (true);

alter table public.chicago_recipe_slots enable row level security;

create policy "chicago_recipe_slots_select_authenticated"
  on public.chicago_recipe_slots for select to authenticated using (true);

alter table public.detroit_topping_pricing enable row level security;

create policy "detroit_topping_pricing_select_public"
  on public.detroit_topping_pricing
  for select
  to anon, authenticated
  using (true);

alter table public.city_topping_pricing enable row level security;

create policy "city_topping_pricing_select_public"
  on public.city_topping_pricing
  for select
  to anon, authenticated
  using (true);
