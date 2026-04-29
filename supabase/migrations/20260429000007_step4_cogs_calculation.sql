-- ============================================================
-- LITTLE BIGS POS — STEP 4
-- COGS Calculation
-- recipe_slots, portion_specs, scale_events, cogs_variance
-- ============================================================

--------------------------------------------------------------------------------
-- HOUSE SAUCE RECIPE
--------------------------------------------------------------------------------

create table public.sauce_recipes (
  id uuid primary key default gen_random_uuid(),
  name text not null unique,
  slug text not null unique,
  batch_yield_oz numeric(10, 2) not null,
  batch_cost decimal(10, 4),
  cost_per_oz decimal(10, 6),
  storage_temp text default 'refrigerated',
  notes text,
  is_active boolean default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create trigger sauce_recipes_set_updated_at
  before update on public.sauce_recipes
  for each row
  execute function public.set_updated_at();

insert into public.sauce_recipes (
  name, slug, batch_yield_oz, batch_cost, cost_per_oz, notes
) values (
  'Little Bigs House Pizza Sauce',
  'house-pizza-sauce',
  398.00,
  23.058,
  0.057939,
  '3-can blend — SuperDLC + Full Red + 7/11. 12L bucket per batch.'
);

create table public.sauce_recipe_ingredients (
  id uuid primary key default gen_random_uuid(),
  sauce_id uuid not null references public.sauce_recipes (id) on delete cascade,
  ingredient_id uuid not null references public.ingredients (id),
  quantity_oz numeric(10, 4) not null,
  unit_id uuid references public.units_of_measure (id),
  cost decimal(10, 6),
  notes text,
  created_at timestamptz not null default timezone('utc', now())
);

-- Requires matching vendor_sku on ingredients (seed SKUs from procurement).
-- Duplicate SKU rows omitted — negligible salt folded into batch elsewhere.
insert into public.sauce_recipe_ingredients (
  sauce_id, ingredient_id, quantity_oz, cost, notes
)
select
  sr.id,
  i.id,
  ing.qty_oz,
  round(ing.qty_oz * i.cost_per_oz, 6),
  ing.notes
from public.sauce_recipes sr
cross join (
  values
    ('56022'::text,  104.00::numeric, '7/11 Ground Tomato — 1 #10 can'::text),
    ('17870'::text,  104.00::numeric, 'SuperDLC Pizza Sauce — 1 #10 can'::text),
    ('27743'::text,  104.00::numeric, 'Full Red Sauce w/Basil — 1 #10 can'::text),
    ('268806'::text,  16.00::numeric, 'Sugar — 16oz / 4 cups'::text),
    ('263561'::text,   1.00::numeric, 'Garlic Powder — 1oz'::text),
    ('229433'::text,   1.00::numeric, 'Olive Oil — 1oz'::text)
) as ing(sku, qty_oz, notes)
join public.ingredients i on i.vendor_sku = ing.sku
where sr.slug = 'house-pizza-sauce';

--------------------------------------------------------------------------------
-- PIZZA RECIPE SLOTS
--------------------------------------------------------------------------------

create table public.pizza_recipe_slots (
  id uuid primary key default gen_random_uuid(),
  size_id uuid not null references public.pizza_sizes (id) on delete cascade,
  slot_type text not null check (slot_type in (
                  'sauce', 'cheese', 'topping', 'dough', 'box', 'oil')),
  ingredient_id uuid references public.ingredients (id),
  sauce_recipe_id uuid references public.sauce_recipes (id),
  quantity_oz numeric(10, 4) not null,
  portioning text not null check (portioning in (
                  'cup', 'pre_bagged', 'weighed_live', 'set_weight', 'fixed')),
  cup_color text,
  cup_count integer default 1,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  constraint slot_source check (
    ingredient_id is not null or sauce_recipe_id is not null
  )
);

insert into public.pizza_recipe_slots (
  size_id, slot_type, sauce_recipe_id,
  quantity_oz, portioning, notes
)
select
  ps.id,
  'sauce',
  sr.id,
  case ps.slug
    when '8-inch'  then 1.5::numeric
    when '12-inch' then 2.0::numeric
    when '16-inch' then 4.0::numeric
    when '20-inch' then 8.0::numeric
  end,
  'fixed',
  'House pizza sauce — ' || ps.name
from public.pizza_sizes ps
cross join public.sauce_recipes sr
where sr.slug = 'house-pizza-sauce';

insert into public.pizza_recipe_slots (
  size_id, slot_type, ingredient_id,
  quantity_oz, portioning, cup_color, cup_count, notes
)
select
  ps.id,
  'cheese',
  i.id,
  case ps.slug
    when '8-inch'  then 2.0::numeric
    when '12-inch' then 4.0::numeric
    when '16-inch' then 8.0::numeric
    when '20-inch' then 10.0::numeric
  end,
  'cup',
  case ps.slug
    when '8-inch'  then 'red'::text
    when '12-inch' then 'green'::text
    when '16-inch' then 'blue'::text
    when '20-inch' then 'grey'::text
  end,
  case ps.slug
    when '8-inch'  then 1
    when '12-inch' then 1
    when '16-inch' then 2
    when '20-inch' then 2
  end,
  'Bacio mozzarella — ' || ps.name
from public.pizza_sizes ps
cross join public.ingredients i
where i.vendor_sku = '337784';

--------------------------------------------------------------------------------
-- PORTION SPECS
--------------------------------------------------------------------------------

create table public.portion_specs (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.ingredients (id) on delete cascade,
  application text not null check (application in (
                  'pizza', 'sub', 'wedgie', 'salad',
                  'pasta', 'side', 'nachos')),
  size_context text not null,
  quantity_oz numeric(10, 4) not null,
  portioning text not null check (portioning in (
                  'pre_bagged', 'weighed_live',
                  'set_weight', 'cup', 'fixed')),
  cost decimal(10, 6),
  notes text,
  created_at timestamptz not null default timezone('utc', now())
);

insert into public.portion_specs (
  ingredient_id, application, size_context,
  quantity_oz, portioning, cost, notes
)
select
  i.id,
  p.application,
  p.size_context,
  p.quantity_oz,
  'pre_bagged',
  round(p.quantity_oz * i.cost_per_oz, 6),
  'Pre-bagged — ' || p.size_context
from public.ingredients i
cross join (
  values
    ('pizza'::text,   '8-inch'::text,    2.0::numeric),
    ('pizza'::text,   '12-inch'::text,   4.0::numeric),
    ('pizza'::text,   '16-inch'::text,   6.0::numeric),
    ('pizza'::text,   '20-inch'::text,  10.0::numeric),
    ('sub'::text,     '8-inch'::text,    4.0::numeric),
    ('sub'::text,     '12-inch'::text,   6.0::numeric),
    ('wedgie'::text,  '12-inch'::text,   4.0::numeric),
    ('wedgie'::text,  '16-inch'::text,   6.0::numeric)
) as p(application, size_context, quantity_oz)
where i.vendor_sku = '186495';

insert into public.portion_specs (
  ingredient_id, application, size_context,
  quantity_oz, portioning, cost, notes
)
select
  i.id,
  p.application,
  p.size_context,
  p.quantity_oz,
  'pre_bagged',
  round(p.quantity_oz * i.cost_per_oz, 6),
  'Pre-bagged — ' || p.size_context
from public.ingredients i
cross join (
  values
    ('pizza'::text, '8-inch'::text,   2.0::numeric),
    ('pizza'::text, '12-inch'::text,  5.0::numeric),
    ('pizza'::text, '16-inch'::text,  7.0::numeric),
    ('pizza'::text, '20-inch'::text, 12.0::numeric),
    ('sub'::text,   '8-inch'::text,   2.0::numeric),
    ('sub'::text,   '12-inch'::text,  5.0::numeric),
    ('salad'::text, 'small'::text,    5.0::numeric),
    ('salad'::text, 'large'::text,    7.0::numeric),
    ('pasta'::text, 'regular'::text,  5.0::numeric)
) as p(application, size_context, quantity_oz)
where i.vendor_sku = '600752';

insert into public.portion_specs (
  ingredient_id, application, size_context,
  quantity_oz, portioning, cost, notes
)
select
  i.id,
  p.application,
  p.size_context,
  p.quantity_oz,
  'pre_bagged',
  round(p.quantity_oz * i.cost_per_oz, 6),
  'Pre-bagged — ' || p.size_context
from public.ingredients i
cross join (
  values
    ('pizza'::text, '12-inch'::text,  4.0::numeric),
    ('pizza'::text, '16-inch'::text,  6.0::numeric),
    ('pizza'::text, '20-inch'::text, 10.0::numeric),
    ('salad'::text, 'taco'::text,     6.0::numeric),
    ('nachos'::text,'loaded'::text,   6.0::numeric),
    ('side'::text,  'extra-lg'::text, 6.0::numeric),
    ('side'::text,  'extra-sm'::text, 4.0::numeric)
) as p(application, size_context, quantity_oz)
where i.vendor_sku = '329695';

--------------------------------------------------------------------------------
-- SCALE EVENTS
--------------------------------------------------------------------------------

create table public.scale_events (
  id uuid primary key default gen_random_uuid(),
  scale_id text not null,
  station text not null check (station in (
                   'freezer', 'make_table', 'prep', 'receiving', 'fryer')),
  ingredient_id uuid references public.ingredients (id),
  menu_item_id uuid references public.menu_items (id),
  order_item_id uuid,
  tare_weight_oz numeric(10, 4) default 0,
  gross_weight_oz numeric(10, 4) not null,
  net_weight_oz numeric(10, 4)
                   generated always as
                   (gross_weight_oz - tare_weight_oz) stored,
  target_weight_oz numeric(10, 4),
  variance_oz numeric(10, 4)
                   generated always as
                   ((gross_weight_oz - tare_weight_oz) - target_weight_oz) stored,
  cost_per_oz decimal(10, 6),
  event_cost decimal(10, 6),
  triggered_by text default 'order',
  employee_id uuid references public.profiles (id),
  weighed_at timestamptz not null default timezone('utc', now())
);

--------------------------------------------------------------------------------
-- COGS VARIANCE LOG
--------------------------------------------------------------------------------

create table public.cogs_variance_log (
  id uuid primary key default gen_random_uuid(),
  order_item_id uuid,
  ingredient_id uuid references public.ingredients (id),
  menu_item_id uuid references public.menu_items (id),
  theoretical_oz numeric(10, 4),
  actual_oz numeric(10, 4),
  variance_oz numeric(10, 4)
                    generated always as
                    (actual_oz - theoretical_oz) stored,
  theoretical_cost decimal(10, 6),
  actual_cost decimal(10, 6),
  variance_cost decimal(10, 6)
                    generated always as
                    (actual_cost - theoretical_cost) stored,
  gl_account text default '5000',
  logged_at timestamptz not null default timezone('utc', now())
);

--------------------------------------------------------------------------------
-- ITEM COGS DAILY
--------------------------------------------------------------------------------

create table public.item_cogs_daily (
  id uuid primary key default gen_random_uuid(),
  report_date date not null default ((timezone('utc', now()))::date),
  menu_item_id uuid references public.menu_items (id),
  size_context text,
  units_sold integer default 0,
  theoretical_cogs decimal(10, 4) default 0,
  actual_cogs decimal(10, 4) default 0,
  variance_cogs decimal(10, 4)
                    generated always as
                    (actual_cogs - theoretical_cogs) stored,
  revenue decimal(10, 4) default 0,
  food_cost_pct numeric(8, 4)
                    generated always as
                    (case when revenue > 0
                     then (actual_cogs / revenue) * 100
                     else 0 end) stored,
  gl_account text default '5000',
  created_at timestamptz not null default timezone('utc', now()),
  unique (report_date, menu_item_id, size_context)
);

--------------------------------------------------------------------------------
-- FOOD COST HISTORY
--------------------------------------------------------------------------------

create table public.food_cost_pct_history (
  id uuid primary key default gen_random_uuid(),
  period_date date not null,
  period_type text not null check (period_type in (
                 'daily', 'weekly', 'monthly')),
  total_revenue decimal(12, 2) default 0,
  total_cogs decimal(12, 2) default 0,
  food_cost_pct numeric(8, 4)
                 generated always as
                 (case when total_revenue > 0
                  then (total_cogs / total_revenue) * 100
                  else 0 end) stored,
  gl_account text default '5000',
  created_at timestamptz not null default timezone('utc', now()),
  unique (period_date, period_type)
);

--------------------------------------------------------------------------------
-- CALCULATE PIZZA COGS FUNCTION
--------------------------------------------------------------------------------

create or replace function public.calculate_pizza_cogs(
  p_size_slug text,
  p_topping_ids uuid[] default array[]::uuid[]
)
returns table (
  component text,
  ingredient_name text,
  quantity_oz numeric,
  cost_per_oz numeric,
  total_cost numeric
)
language plpgsql
stable
security invoker
set search_path = ''
as $$
begin
  return query
  select
    'sauce'::text,
    sr.name::text,
    prs.quantity_oz,
    sr.cost_per_oz::numeric,
    round(prs.quantity_oz * sr.cost_per_oz, 6)::numeric
  from public.pizza_recipe_slots prs
  join public.pizza_sizes ps on ps.id = prs.size_id
  join public.sauce_recipes sr on sr.id = prs.sauce_recipe_id
  where ps.slug = p_size_slug
  and prs.slot_type = 'sauce';

  return query
  select
    'cheese'::text,
    i.name::text,
    prs.quantity_oz,
    i.cost_per_oz::numeric,
    round(prs.quantity_oz * i.cost_per_oz, 6)::numeric
  from public.pizza_recipe_slots prs
  join public.pizza_sizes ps on ps.id = prs.size_id
  join public.ingredients i on i.id = prs.ingredient_id
  where ps.slug = p_size_slug
  and prs.slot_type = 'cheese';

  return query
  select
    'box'::text,
    i.name::text,
    1.0::numeric,
    i.cost_per_oz::numeric,
    i.cost_per_oz::numeric
  from public.pizza_sizes ps
  join public.ingredients i on i.vendor_sku = ps.box_sku
  where ps.slug = p_size_slug;

  if coalesce(array_length(p_topping_ids, 1), 0) > 0 then
    return query
    select
      'topping'::text,
      i.name::text,
      ps.topping_oz,
      i.cost_per_oz::numeric,
      round(ps.topping_oz * i.cost_per_oz, 6)::numeric
    from public.pizza_sizes ps
    join public.toppings t on t.id = any (p_topping_ids)
    join public.ingredients i on i.id = t.ingredient_id
    where ps.slug = p_size_slug
    and i.id is not null;
  end if;
end;
$$;

--------------------------------------------------------------------------------
-- THEORETICAL VS ACTUAL VIEW
--------------------------------------------------------------------------------

create view public.theoretical_vs_actual
with (security_invoker = true) as
select
  icd.report_date,
  mi.name as item_name,
  icd.size_context,
  icd.units_sold,
  round(icd.theoretical_cogs, 2) as theoretical_cogs,
  round(icd.actual_cogs, 2) as actual_cogs,
  round(icd.variance_cogs, 2) as variance_cogs,
  round(icd.food_cost_pct, 2) as food_cost_pct,
  round(icd.revenue, 2) as revenue,
  case
    when icd.variance_cogs > (icd.theoretical_cogs * 0.10)
      then 'critical'::text
    when icd.variance_cogs > (icd.theoretical_cogs * 0.05)
      then 'warning'::text
    else 'normal'::text
  end as variance_status
from public.item_cogs_daily icd
join public.menu_items mi on mi.id = icd.menu_item_id;

grant select on public.theoretical_vs_actual to authenticated;

grant execute on function public.calculate_pizza_cogs(text, uuid[]) to authenticated;

--------------------------------------------------------------------------------
-- ROW LEVEL SECURITY
--------------------------------------------------------------------------------

alter table public.sauce_recipes enable row level security;
alter table public.sauce_recipe_ingredients enable row level security;
alter table public.pizza_recipe_slots enable row level security;
alter table public.portion_specs enable row level security;
alter table public.scale_events enable row level security;
alter table public.cogs_variance_log enable row level security;
alter table public.item_cogs_daily enable row level security;
alter table public.food_cost_pct_history enable row level security;

create policy "sauce_recipes_select_authenticated"
  on public.sauce_recipes for select to authenticated using (true);

create policy "sauce_recipe_ingredients_select_authenticated"
  on public.sauce_recipe_ingredients for select to authenticated using (true);

create policy "pizza_recipe_slots_select_authenticated"
  on public.pizza_recipe_slots for select to authenticated using (true);

create policy "portion_specs_select_authenticated"
  on public.portion_specs for select to authenticated using (true);

create policy "scale_events_select_authenticated"
  on public.scale_events for select to authenticated using (true);

create policy "cogs_variance_log_select_authenticated"
  on public.cogs_variance_log for select to authenticated using (true);

create policy "item_cogs_daily_select_authenticated"
  on public.item_cogs_daily for select to authenticated using (true);

create policy "food_cost_pct_history_select_authenticated"
  on public.food_cost_pct_history for select to authenticated using (true);
