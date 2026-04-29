-- ============================================================
-- LITTLE BIGS POS — STEP 3
-- Pricing Schema
-- ============================================================

--------------------------------------------------------------------------------
-- TOPPING PRICES PER SIZE
-- Flat pricing — all toppings same price per size
--------------------------------------------------------------------------------

create table public.topping_size_pricing (
  id uuid primary key default gen_random_uuid(),
  size_id uuid not null references public.pizza_sizes (id) on delete cascade,
  whole_price decimal(10, 2) not null,
  half_price decimal(10, 2) not null,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  unique (size_id)
);

create trigger topping_size_pricing_set_updated_at
  before update on public.topping_size_pricing
  for each row
  execute function public.set_updated_at();

insert into public.topping_size_pricing (size_id, whole_price, half_price)
select ps.id, p.whole_price, p.half_price
from public.pizza_sizes ps
join (
  values
    ('8-inch'::text,  0.99::decimal, 0.99::decimal),
    ('12-inch'::text, 1.25::decimal, 1.25::decimal),
    ('16-inch'::text, 1.85::decimal, 1.85::decimal),
    ('20-inch'::text, 1.99::decimal, 1.99::decimal)
) as p(slug, whole_price, half_price)
  on ps.slug = p.slug;

--------------------------------------------------------------------------------
-- SIGNATURE PIZZA PRICING PER SIZE
--------------------------------------------------------------------------------

create table public.signature_pizza_pricing (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.menu_items (id) on delete cascade,
  size_id uuid not null references public.pizza_sizes (id) on delete cascade,
  price decimal(10, 2) not null,
  is_active boolean default true,
  created_at timestamptz not null default timezone('utc', now()),
  unique (item_id, size_id)
);

insert into public.signature_pizza_pricing (item_id, size_id, price)
select
  mi.id,
  ps.id,
  case ps.slug
    when '12-inch' then 14.00::decimal
    when '16-inch' then 21.00::decimal
    when '20-inch' then 24.00::decimal
  end
from public.menu_items mi
cross join public.pizza_sizes ps
where mi.category_id = (
  select id from public.menu_categories where slug = 'signature-pizzas'
)
and ps.slug in ('12-inch', '16-inch', '20-inch');

--------------------------------------------------------------------------------
-- DETROIT PIZZA SIZES
--------------------------------------------------------------------------------

create table public.detroit_sizes (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  dimensions text not null,
  base_price decimal(10, 2) not null,
  sort_order integer default 0,
  is_active boolean default true,
  created_at timestamptz not null default timezone('utc', now())
);

insert into public.detroit_sizes (name, slug, dimensions, base_price, sort_order) values
  ('Small',       'detroit-sm', '8x10',  12.75, 1),
  ('Large',       'detroit-lg', '10x14', 14.75, 2),
  ('Extra Large', 'detroit-xl', '12x17', 18.75, 3);

--------------------------------------------------------------------------------
-- SUB PRICING (two sizes per sub)
--------------------------------------------------------------------------------

create table public.sub_sizes (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  sort_order integer default 0,
  created_at timestamptz not null default timezone('utc', now())
);

insert into public.sub_sizes (name, slug, sort_order) values
  ('8 Inch',  '8-inch-sub',  1),
  ('12 Inch', '12-inch-sub', 2);

create table public.sub_pricing (
  id uuid primary key default gen_random_uuid(),
  item_id uuid not null references public.menu_items (id) on delete cascade,
  size_id uuid not null references public.sub_sizes (id) on delete cascade,
  price decimal(10, 2) not null,
  is_active boolean default true,
  created_at timestamptz not null default timezone('utc', now()),
  unique (item_id, size_id)
);

insert into public.sub_pricing (item_id, size_id, price)
select mi.id, ss.id, p.price
from public.menu_items mi
cross join public.sub_sizes ss
join (
  values
    ('bbq-chicken-sub'::text,     '8-inch-sub'::text,  7.50::decimal),
    ('bbq-chicken-sub'::text,     '12-inch-sub'::text, 10.50::decimal),
    ('blt-sub'::text,             '8-inch-sub'::text,  7.50::decimal),
    ('blt-sub'::text,             '12-inch-sub'::text, 10.50::decimal),
    ('buffalo-chicken-sub'::text, '8-inch-sub'::text,  7.55::decimal),
    ('buffalo-chicken-sub'::text, '12-inch-sub'::text, 10.50::decimal),
    ('chicken-parm-sub'::text,    '8-inch-sub'::text,  7.55::decimal),
    ('chicken-parm-sub'::text,    '12-inch-sub'::text, 10.50::decimal),
    ('ham-cheese-sub'::text,      '8-inch-sub'::text,  7.50::decimal),
    ('ham-cheese-sub'::text,      '12-inch-sub'::text, 10.00::decimal),
    ('italian-sausage-sub'::text, '8-inch-sub'::text,  8.25::decimal),
    ('italian-sausage-sub'::text, '12-inch-sub'::text, 10.50::decimal),
    ('meatball-sub'::text,        '8-inch-sub'::text,  7.55::decimal),
    ('meatball-sub'::text,        '12-inch-sub'::text, 10.50::decimal),
    ('pepperoni-sub'::text,       '8-inch-sub'::text,  7.50::decimal),
    ('pepperoni-sub'::text,       '12-inch-sub'::text, 10.00::decimal),
    ('spicy-italian-sub'::text,   '8-inch-sub'::text,  8.00::decimal),
    ('spicy-italian-sub'::text,   '12-inch-sub'::text, 10.00::decimal),
    ('steak-cheese-sub'::text,    '8-inch-sub'::text,  7.50::decimal),
    ('steak-cheese-sub'::text,    '12-inch-sub'::text, 10.50::decimal),
    ('tuna-sub'::text,            '8-inch-sub'::text,  7.50::decimal),
    ('tuna-sub'::text,            '12-inch-sub'::text, 10.00::decimal),
    ('veggie-sub'::text,          '8-inch-sub'::text,  7.00::decimal),
    ('veggie-sub'::text,          '12-inch-sub'::text, 9.50::decimal)
) as p(item_slug, size_slug, price)
  on mi.slug = p.item_slug
 and ss.slug = p.size_slug;

--------------------------------------------------------------------------------
-- TAX RATES
--------------------------------------------------------------------------------

create table public.tax_rates (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  rate numeric(6, 4) not null,
  state text,
  is_active boolean default true,
  created_at timestamptz not null default timezone('utc', now())
);

insert into public.tax_rates (name, rate, state) values
  ('West Virginia Sales Tax', 0.0600, 'WV');

--------------------------------------------------------------------------------
-- DISCOUNTS
--------------------------------------------------------------------------------

create table public.discounts (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  code text unique,
  discount_type text not null check (discount_type in (
                  'pct_off', 'fixed_off', 'free_item', 'bogo')),
  discount_value decimal(10, 2) not null,
  min_order_total decimal(10, 2) default 0,
  max_uses integer,
  uses_count integer default 0,
  starts_at timestamptz,
  expires_at timestamptz,
  is_active boolean default true,
  created_at timestamptz not null default timezone('utc', now())
);

--------------------------------------------------------------------------------
-- EXTRA BAG PRICING (Taco Meat add-ons)
--------------------------------------------------------------------------------

create table public.extra_bag_pricing (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text not null unique,
  item_id uuid references public.menu_items (id) on delete set null,
  size_oz numeric(4, 2) not null,
  price decimal(10, 2) not null,
  is_active boolean default true,
  created_at timestamptz not null default timezone('utc', now())
);

insert into public.extra_bag_pricing (name, slug, size_oz, price) values
  ('Extra Taco Meat Large', 'extra-taco-lg', 6.00, 1.99),
  ('Extra Taco Meat Small', 'extra-taco-sm', 4.00, 1.50);

--------------------------------------------------------------------------------
-- ROW LEVEL SECURITY
--------------------------------------------------------------------------------

alter table public.topping_size_pricing enable row level security;

create policy "topping_size_pricing_select_public"
  on public.topping_size_pricing for select to anon, authenticated using (true);

alter table public.signature_pizza_pricing enable row level security;

create policy "signature_pizza_pricing_select_public"
  on public.signature_pizza_pricing for select to anon, authenticated using (true);

alter table public.detroit_sizes enable row level security;

create policy "detroit_sizes_select_public"
  on public.detroit_sizes for select to anon, authenticated using (true);

alter table public.sub_sizes enable row level security;

create policy "sub_sizes_select_public"
  on public.sub_sizes for select to anon, authenticated using (true);

alter table public.sub_pricing enable row level security;

create policy "sub_pricing_select_public"
  on public.sub_pricing for select to anon, authenticated using (true);

alter table public.tax_rates enable row level security;

create policy "tax_rates_select_public"
  on public.tax_rates for select to anon, authenticated using (true);

alter table public.discounts enable row level security;

create policy "discounts_select_authenticated"
  on public.discounts for select to authenticated using (true);

alter table public.extra_bag_pricing enable row level security;

create policy "extra_bag_pricing_select_public"
  on public.extra_bag_pricing for select to anon, authenticated using (true);
