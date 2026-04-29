-- ============================================================
-- LITTLE BIGS POS — PRICING SCHEMA
-- Tiered topping charges by pizza size + optional crust upcharges
-- Depends on: pizza_sizes, crust_types (menu catalog migration)
-- ============================================================

--------------------------------------------------------------------------------
-- TOPPING PRICE TIERS (per category × pizza size)
--------------------------------------------------------------------------------

create table public.topping_prices (
  id uuid primary key default gen_random_uuid(),
  pizza_size_id uuid not null references public.pizza_sizes (id) on delete cascade,
  topping_category text not null check (topping_category in (
                  'standard', 'premium', 'specialty', 'extra')),
  price_each decimal(10, 2) not null,
  unique (pizza_size_id, topping_category)
);

comment on table public.topping_prices is
  'Add-on price per full topping portion for BYO pizzas; categories mirror public.toppings.category';

insert into public.topping_prices (pizza_size_id, topping_category, price_each)
select ps.id, v.cat, v.price
from public.pizza_sizes ps
cross join (
  values
    ('standard',  1.00::decimal),
    ('premium',   1.75::decimal),
    ('specialty', 2.25::decimal),
    ('extra',     1.50::decimal)
) as v(cat, price)
where ps.slug = '8-inch';

insert into public.topping_prices (pizza_size_id, topping_category, price_each)
select ps.id, v.cat, v.price
from public.pizza_sizes ps
cross join (
  values
    ('standard',  1.35::decimal),
    ('premium',   2.25::decimal),
    ('specialty', 2.95::decimal),
    ('extra',     2.00::decimal)
) as v(cat, price)
where ps.slug = '12-inch';

insert into public.topping_prices (pizza_size_id, topping_category, price_each)
select ps.id, v.cat, v.price
from public.pizza_sizes ps
cross join (
  values
    ('standard',  1.65::decimal),
    ('premium',   2.75::decimal),
    ('specialty', 3.50::decimal),
    ('extra',     2.35::decimal)
) as v(cat, price)
where ps.slug = '16-inch';

insert into public.topping_prices (pizza_size_id, topping_category, price_each)
select ps.id, v.cat, v.price
from public.pizza_sizes ps
cross join (
  values
    ('standard',  1.95::decimal),
    ('premium',   3.25::decimal),
    ('specialty', 4.15::decimal),
    ('extra',     2.75::decimal)
) as v(cat, price)
where ps.slug = '20-inch';

--------------------------------------------------------------------------------
-- CRUST UPCHARGE MATRIX (per pizza size × crust type)
--------------------------------------------------------------------------------

create table public.crust_price_adjustments (
  id uuid primary key default gen_random_uuid(),
  pizza_size_id uuid not null references public.pizza_sizes (id) on delete cascade,
  crust_type_id uuid not null references public.crust_types (id) on delete cascade,
  extra_charge decimal(10, 2) not null default 0,
  unique (pizza_size_id, crust_type_id)
);

comment on table public.crust_price_adjustments is
  'Flat dollar add-on for crust choice on a BYO pizza (defaults zero until configured)';

insert into public.crust_price_adjustments (pizza_size_id, crust_type_id, extra_charge)
select ps.id, ct.id, 0::decimal
from public.pizza_sizes ps
cross join public.crust_types ct;

--------------------------------------------------------------------------------
-- ROW LEVEL SECURITY (catalog pricing readable publicly at POS / web)
--------------------------------------------------------------------------------

alter table public.topping_prices enable row level security;

create policy "topping_prices_select_public"
  on public.topping_prices
  for select
  to anon, authenticated
  using (true);

alter table public.crust_price_adjustments enable row level security;

create policy "crust_price_adjustments_select_public"
  on public.crust_price_adjustments
  for select
  to anon, authenticated
  using (true);
