-- ============================================================
-- LITTLE BIGS POS — Migration 004: Deep Schema COGS
-- File: 20260429000004_deep_schema_cogs.sql
-- Full COGS layer: standalone recipes, pizza/sauce engine (slots, portions),
-- scale events, line variance + period variance ledger, item COGS daily,
-- food cost history, menu-item recipe_ingredients, ingredient batches,
-- menu_item_costing, pricing_alerts.
-- Depends on: 00001 core_tables, 00002 menu_catalog, 00003 pricing_schema
-- ============================================================

--------------------------------------------------------------------------------
-- RECIPES (optional link to menu item for plated/signature costing)
--------------------------------------------------------------------------------

create table public.recipes (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  menu_item_id uuid references public.menu_items (id) on delete set null,
  description text,
  servings_yield numeric(12, 4) not null default 1
    check (servings_yield > 0),
  notes text,
  is_active boolean default true,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create trigger recipes_set_updated_at
  before update on public.recipes
  for each row
  execute function public.set_updated_at();

create index recipes_menu_item_id_idx
  on public.recipes (menu_item_id)
  where menu_item_id is not null;

--------------------------------------------------------------------------------
-- RECIPE LINES (ingredient quantities per recipe)
--------------------------------------------------------------------------------

create table public.recipe_lines (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.recipes (id) on delete cascade,
  ingredient_id uuid not null references public.ingredients (id),
  qty_oz numeric(12, 4) not null check (qty_oz >= 0),
  sort_order integer default 0,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now())
);

create trigger recipe_lines_set_updated_at
  before update on public.recipe_lines
  for each row
  execute function public.set_updated_at();

create index recipe_lines_recipe_id_idx on public.recipe_lines (recipe_id);
create index recipe_lines_ingredient_id_idx on public.recipe_lines (ingredient_id);

--------------------------------------------------------------------------------
-- ROW LEVEL SECURITY (kitchen / management â€” not public catalog)
--------------------------------------------------------------------------------

alter table public.recipes enable row level security;

create policy "recipes_select_authenticated"
  on public.recipes for select to authenticated using (true);

alter table public.recipe_lines enable row level security;

create policy "recipe_lines_select_authenticated"
  on public.recipe_lines for select to authenticated using (true);


-- ============================================================
-- Deep Schema COGS — pizza / sauce / portions / scale / line variance
-- recipe_slots, portion_specs, scale_events, cogs_variance_log (line-level)
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
  '3-can blend â€” SuperDLC + Full Red + 7/11. 12L bucket per batch.'
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
-- Duplicate SKU rows omitted â€” negligible salt folded into batch elsewhere.
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
    ('56022'::text,  104.00::numeric, '7/11 Ground Tomato â€” 1 #10 can'::text),
    ('17870'::text,  104.00::numeric, 'SuperDLC Pizza Sauce â€” 1 #10 can'::text),
    ('27743'::text,  104.00::numeric, 'Full Red Sauce w/Basil â€” 1 #10 can'::text),
    ('268806'::text,  16.00::numeric, 'Sugar â€” 16oz / 4 cups'::text),
    ('263561'::text,   1.00::numeric, 'Garlic Powder â€” 1oz'::text),
    ('229433'::text,   1.00::numeric, 'Olive Oil â€” 1oz'::text)
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
  'House pizza sauce â€” ' || ps.name
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
  'Bacio mozzarella â€” ' || ps.name
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
  'Pre-bagged â€” ' || p.size_context
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
  'Pre-bagged â€” ' || p.size_context
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
  'Pre-bagged â€” ' || p.size_context
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
-- Deep Schema COGS — menu-item recipes, batches, period variance, costing, alerts
-- (invoice_line_item_id: optional uuid until procurement line items exist)
--------------------------------------------------------------------------------

create table public.recipe_ingredients (
  id uuid primary key default gen_random_uuid(),
  recipe_id uuid not null references public.menu_items (id) on delete cascade,
  ingredient_id uuid not null references public.ingredients (id) on delete restrict,
  quantity_oz decimal(10, 4) not null check (quantity_oz > 0),
  waste_factor decimal(5, 4) default 1.0000
    check (waste_factor >= 1.0000 and waste_factor <= 3.0000),
  yield_percent decimal(5, 2) default 100.00
    check (yield_percent > 0 and yield_percent <= 100),
  is_optional boolean default false,
  is_default boolean default true,
  substitution_group_id uuid,
  display_order integer default 0,
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  created_by uuid references auth.users (id),
  updated_by uuid references auth.users (id),
  unique (recipe_id, ingredient_id)
);

create index idx_recipe_ingredients_recipe on public.recipe_ingredients (recipe_id);
create index idx_recipe_ingredients_ingredient on public.recipe_ingredients (ingredient_id);
create index idx_recipe_ingredients_subgroup
  on public.recipe_ingredients (substitution_group_id)
  where substitution_group_id is not null;
create index idx_recipe_ingredients_optional
  on public.recipe_ingredients (recipe_id, is_optional);

comment on table public.recipe_ingredients is
  'Links menu items to ingredients with quantities, waste factors, and substitutions';
comment on column public.recipe_ingredients.quantity_oz is
  'Base quantity in ounces before waste factor';
comment on column public.recipe_ingredients.waste_factor is
  'Multiplier for waste (1.05 = 5% waste)';
comment on column public.recipe_ingredients.yield_percent is
  'Cooking yield % (e.g., raw chicken to cooked)';

create trigger recipe_ingredients_set_updated_at
  before update on public.recipe_ingredients
  for each row
  execute function public.set_updated_at();

create table public.ingredient_batches (
  id uuid primary key default gen_random_uuid(),
  ingredient_id uuid not null references public.ingredients (id) on delete restrict,
  batch_number text,
  invoice_line_item_id uuid,
  received_date date not null default current_date,
  cases_received integer not null check (cases_received > 0),
  count_per_case integer check (count_per_case is null or count_per_case > 0),
  total_pieces integer generated always as (
    case
      when count_per_case is not null then cases_received * count_per_case
      else null
    end
  ) stored,
  cost_per_case decimal(10, 2) not null check (cost_per_case > 0),
  cost_per_piece decimal(10, 4) generated always as (
    case
      when count_per_case is not null and count_per_case > 0
        then cost_per_case / count_per_case::decimal
      else null
    end
  ) stored,
  cost_per_oz decimal(10, 4) generated always as (
    case
      when count_per_case is null then cost_per_case / 16.0
      else null
    end
  ) stored,
  cases_remaining decimal(8, 2) not null default 0 check (cases_remaining >= 0),
  pieces_remaining integer,
  expiration_date date,
  status text default 'active' check (status in (
    'active', 'depleted', 'expired', 'recalled')),
  notes text,
  created_at timestamptz not null default timezone('utc', now()),
  updated_at timestamptz not null default timezone('utc', now()),
  created_by uuid references auth.users (id),
  constraint valid_pieces_remaining check (
    (count_per_case is null and pieces_remaining is null)
    or (
      count_per_case is not null
      and pieces_remaining is not null
      and pieces_remaining >= 0
    )
  )
);

comment on column public.ingredient_batches.invoice_line_item_id is
  'Optional link to procurement line item when invoice_line_items table exists';

create index idx_batches_ingredient on public.ingredient_batches (ingredient_id);
create index idx_batches_received_date on public.ingredient_batches (received_date);
create index idx_batches_expiration
  on public.ingredient_batches (expiration_date)
  where expiration_date is not null;
create index idx_batches_active on public.ingredient_batches (ingredient_id, status)
  where status = 'active'
    and (expiration_date is null or expiration_date >= current_date);
create index idx_batches_invoice
  on public.ingredient_batches (invoice_line_item_id)
  where invoice_line_item_id is not null;

comment on table public.ingredient_batches is
  'Batch tracking for variable-count items (wings) and FIFO inventory management';
comment on column public.ingredient_batches.count_per_case is
  'Actual count per case for variable items (null for weight-based)';
comment on column public.ingredient_batches.cost_per_piece is
  'Calculated cost per individual piece (wings, etc.)';

create trigger ingredient_batches_set_updated_at
  before update on public.ingredient_batches
  for each row
  execute function public.set_updated_at();

create or replace function public.update_batch_pieces_remaining()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  if new.count_per_case is null then
    return new;
  end if;
  if tg_op = 'INSERT' then
    new.pieces_remaining := floor((new.cases_remaining * new.count_per_case)::numeric)::integer;
  elsif
    new.cases_remaining is distinct from old.cases_remaining
    or new.count_per_case is distinct from old.count_per_case
  then
    new.pieces_remaining := floor((new.cases_remaining * new.count_per_case)::numeric)::integer;
  end if;
  return new;
end;
$$;

create trigger trigger_update_batch_pieces
  before insert or update of cases_remaining, count_per_case on public.ingredient_batches
  for each row
  execute function public.update_batch_pieces_remaining();

comment on trigger trigger_update_batch_pieces on public.ingredient_batches is
  'Keeps pieces_remaining in sync when cases_remaining or count_per_case changes';

create table public.cogs_period_variance_log (
  id uuid primary key default gen_random_uuid(),
  period_start date not null,
  period_end date not null check (period_end >= period_start),
  ingredient_id uuid not null references public.ingredients (id) on delete restrict,
  ingredient_name text not null,
  theoretical_usage_oz decimal(12, 4) not null check (theoretical_usage_oz >= 0),
  actual_usage_oz decimal(12, 4) not null check (actual_usage_oz >= 0),
  variance_oz decimal(12, 4) generated always as (
    actual_usage_oz - theoretical_usage_oz
  ) stored,
  variance_percent decimal(8, 4) generated always as (
    case
      when theoretical_usage_oz > 0
        then ((actual_usage_oz - theoretical_usage_oz) / theoretical_usage_oz) * 100
      else null
    end
  ) stored,
  average_cost_per_oz decimal(10, 4) not null check (average_cost_per_oz >= 0),
  variance_cost decimal(10, 2) generated always as (
    (actual_usage_oz - theoretical_usage_oz) * average_cost_per_oz
  ) stored,
  flag_level text generated always as (
    case
      when abs((actual_usage_oz - theoretical_usage_oz) / nullif(theoretical_usage_oz, 0) * 100)
        > 10
        then 'critical'
      when abs((actual_usage_oz - theoretical_usage_oz) / nullif(theoretical_usage_oz, 0) * 100)
        > 5
        then 'warning'
      else 'normal'
    end
  ) stored
    check (flag_level in ('normal', 'warning', 'critical')),
  suspected_cause text check (
    suspected_cause is null
    or suspected_cause in (
      'theft', 'waste', 'spoilage', 'recipe_error', 'measurement_error',
      'over_portioning', 'under_portioning'
    )
  ),
  investigated_at timestamptz,
  investigated_by uuid references auth.users (id),
  resolution_notes text,
  resolved_at timestamptz,
  resolved_by uuid references auth.users (id),
  created_at timestamptz not null default timezone('utc', now()),
  created_by uuid references auth.users (id)
);

create index idx_period_variance_ingredient
  on public.cogs_period_variance_log (ingredient_id);
create index idx_period_variance_period
  on public.cogs_period_variance_log (period_start, period_end);
create index idx_period_variance_flags
  on public.cogs_period_variance_log (flag_level)
  where flag_level in ('warning', 'critical');
create index idx_period_variance_unresolved
  on public.cogs_period_variance_log (ingredient_id, resolved_at)
  where resolved_at is null;

comment on table public.cogs_period_variance_log is
  'Period-level variance vs recipe usage (distinct from public.cogs_variance_log line items)';
comment on column public.cogs_period_variance_log.flag_level is
  'Auto: normal (<5%), warning (5-10%), critical (>10%)';

create table public.menu_item_costing (
  id uuid primary key default gen_random_uuid(),
  menu_item_id uuid not null references public.menu_items (id) on delete cascade,
  menu_item_name text not null,
  calculation_date timestamptz not null default timezone('utc', now()),
  calculation_type text not null check (calculation_type in (
    'standard', 'batch_weighted', 'fifo', 'manual')),
  theoretical_cogs decimal(10, 4) not null check (theoretical_cogs >= 0),
  current_batch_cogs decimal(10, 4) check (
    current_batch_cogs is null or current_batch_cogs >= 0
  ),
  labor_cost decimal(10, 4) default 0 check (labor_cost >= 0),
  packaging_cost decimal(10, 4) default 0 check (packaging_cost >= 0),
  total_cost decimal(10, 4) generated always as (
    coalesce(current_batch_cogs, theoretical_cogs)
    + coalesce(labor_cost, 0)
    + coalesce(packaging_cost, 0)
  ) stored,
  menu_price decimal(10, 2) not null check (menu_price > 0),
  food_cost_percent decimal(8, 4) generated always as (
    (coalesce(current_batch_cogs, theoretical_cogs) / nullif(menu_price, 0)) * 100
  ) stored,
  total_cost_percent decimal(8, 4) generated always as (
    (
      (coalesce(current_batch_cogs, theoretical_cogs) + coalesce(labor_cost, 0)
        + coalesce(packaging_cost, 0))
      / nullif(menu_price, 0)
    ) * 100
  ) stored,
  margin_dollars decimal(10, 2) generated always as (
    menu_price
    - (
      coalesce(current_batch_cogs, theoretical_cogs)
      + coalesce(labor_cost, 0)
      + coalesce(packaging_cost, 0)
    )
  ) stored,
  margin_percent decimal(8, 4) generated always as (
    (
      (
        menu_price
        - (
          coalesce(current_batch_cogs, theoretical_cogs)
          + coalesce(labor_cost, 0)
          + coalesce(packaging_cost, 0)
        )
      )
      / nullif(menu_price, 0)
    ) * 100
  ) stored,
  last_cost_change_date date,
  last_price_change_date date,
  cost_trend text check (
    cost_trend is null or cost_trend in ('stable', 'increasing', 'decreasing')
  ),
  is_current boolean default true,
  needs_review boolean default false,
  created_at timestamptz not null default timezone('utc', now()),
  created_by uuid references auth.users (id)
);

create unique index menu_item_costing_one_current_per_item_idx
  on public.menu_item_costing (menu_item_id)
  where is_current = true;

create index idx_costing_menu_item on public.menu_item_costing (menu_item_id);
create index idx_costing_current
  on public.menu_item_costing (menu_item_id, is_current)
  where is_current = true;
create index idx_costing_high_food_cost
  on public.menu_item_costing (food_cost_percent)
  where food_cost_percent > 35;
create index idx_costing_negative_margin
  on public.menu_item_costing (margin_dollars)
  where margin_dollars < 0;
create index idx_costing_needs_review
  on public.menu_item_costing (needs_review)
  where needs_review = true;

comment on table public.menu_item_costing is
  'COGS snapshots per menu item (food cost %, margins)';

create table public.pricing_alerts (
  id uuid primary key default gen_random_uuid(),
  menu_item_id uuid not null references public.menu_items (id) on delete cascade,
  menu_item_name text not null,
  menu_item_category text,
  alert_type text not null check (alert_type in (
    'high_food_cost', 'negative_margin', 'batch_variance', 'cost_spike',
    'price_below_threshold', 'ingredient_shortage'
  )),
  severity text not null default 'warning' check (severity in (
    'info', 'warning', 'critical')),
  current_food_cost_pct decimal(8, 4),
  current_margin decimal(10, 2),
  current_price decimal(10, 2),
  current_cogs decimal(10, 4),
  threshold_exceeded decimal(8, 4),
  suggested_action text not null,
  suggested_new_price decimal(10, 2),
  expected_new_food_cost_pct decimal(8, 4),
  expected_new_margin decimal(10, 2),
  daily_order_volume integer,
  estimated_daily_loss decimal(10, 2),
  estimated_monthly_loss decimal(10, 2) generated always as (
    estimated_daily_loss * 30
  ) stored,
  status text default 'open' check (status in (
    'open', 'acknowledged', 'resolved', 'dismissed', 'expired')),
  priority integer default 2 check (priority between 1 and 5),
  acknowledged_at timestamptz,
  acknowledged_by uuid references auth.users (id),
  resolved_at timestamptz,
  resolved_by uuid references auth.users (id),
  resolution_notes text,
  action_taken text check (
    action_taken is null
    or action_taken in (
      'price_increased', 'price_decreased', 'portion_reduced', 'recipe_changed',
      'vendor_changed', 'item_discontinued', 'no_action'
    )
  ),
  expires_at timestamptz default (timezone('utc', now()) + interval '30 days'),
  created_at timestamptz not null default timezone('utc', now()),
  created_by uuid references auth.users (id)
);

create index idx_alerts_menu_item on public.pricing_alerts (menu_item_id);
create index idx_alerts_status
  on public.pricing_alerts (status)
  where status in ('open', 'acknowledged');
create index idx_alerts_severity
  on public.pricing_alerts (severity, priority)
  where severity in ('warning', 'critical');
create index idx_alerts_type on public.pricing_alerts (alert_type, status);
create index idx_alerts_expiration
  on public.pricing_alerts (expires_at)
  where status = 'open';

comment on table public.pricing_alerts is
  'Automated pricing and food-cost alerts';

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
-- Deep Schema COGS — batch-weighted cost, recipe COGS, alert expiry
--------------------------------------------------------------------------------

create or replace function public.get_current_batch_cost(p_ingredient_id uuid)
returns decimal(10, 4)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_weighted_cost decimal(10, 4);
begin
  select
    sum(cost_per_piece * pieces_remaining) / nullif(sum(pieces_remaining), 0)
  into v_weighted_cost
  from public.ingredient_batches
  where ingredient_id = p_ingredient_id
    and status = 'active'
    and pieces_remaining > 0
    and count_per_case is not null
    and (expiration_date is null or expiration_date >= current_date);

  if v_weighted_cost is not null then
    return v_weighted_cost;
  end if;

  select
    sum(cost_per_oz * (cases_remaining * 16)) / nullif(sum(cases_remaining * 16), 0)
  into v_weighted_cost
  from public.ingredient_batches
  where ingredient_id = p_ingredient_id
    and status = 'active'
    and cases_remaining > 0
    and (expiration_date is null or expiration_date >= current_date);

  return coalesce(v_weighted_cost, 0);
end;
$$;

comment on function public.get_current_batch_cost(uuid) is
  'Weighted average cost across active batches (count- or weight-based)';

create or replace function public.calculate_recipe_cogs(p_recipe_id uuid)
returns decimal(10, 4)
language plpgsql
security definer
set search_path = public
as $$
declare
  v_total_cogs decimal(10, 4);
begin
  select coalesce(sum(
    ri.quantity_oz * ri.waste_factor * (i.cost_per_oz::decimal(10, 6))
  ), 0)
  into v_total_cogs
  from public.recipe_ingredients ri
  join public.ingredients i on i.id = ri.ingredient_id
  where ri.recipe_id = p_recipe_id
    and ri.is_optional = false;

  return v_total_cogs;
end;
$$;

comment on function public.calculate_recipe_cogs(uuid) is
  'Theoretical COGS from public.recipe_ingredients × ingredients.cost_per_oz';

create or replace function public.expire_old_pricing_alerts()
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_expired_count integer;
begin
  update public.pricing_alerts
  set status = 'expired'
  where status = 'open'
    and expires_at < timezone('utc', now());

  get diagnostics v_expired_count = row_count;
  return v_expired_count;
end;
$$;

comment on function public.expire_old_pricing_alerts() is
  'Mark open pricing alerts expired past expires_at (e.g. pg_cron)';

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

--------------------------------------------------------------------------------
-- Deep Schema COGS — live menu costs + pricing alert summary (views)
--------------------------------------------------------------------------------

create or replace view public.current_menu_costs
with (security_invoker = true) as
select
  mi.id,
  mi.name,
  mc.name as category,
  coalesce(mi.base_price, 0::decimal(10, 2)) as menu_price,
  public.calculate_recipe_cogs(mi.id) as theoretical_cogs,
  case
    when coalesce(mi.base_price, 0) > 0 then
      (public.calculate_recipe_cogs(mi.id) / mi.base_price) * 100
    else null
  end as food_cost_percent,
  coalesce(mi.base_price, 0) - public.calculate_recipe_cogs(mi.id) as margin_dollars,
  case
    when coalesce(mi.base_price, 0) > 0 then
      (
        (coalesce(mi.base_price, 0) - public.calculate_recipe_cogs(mi.id))
        / mi.base_price
      ) * 100
    else null
  end as margin_percent,
  case
    when (public.calculate_recipe_cogs(mi.id) / nullif(mi.base_price, 0)) * 100 > 40
      then 'critical'
    when (public.calculate_recipe_cogs(mi.id) / nullif(mi.base_price, 0)) * 100 > 35
      then 'warning'
    else 'healthy'
  end as cost_status,
  mi.is_active,
  mi.updated_at
from public.menu_items mi
left join public.menu_categories mc on mc.id = mi.category_id
where mi.is_active = true;

comment on view public.current_menu_costs is
  'Live costs from recipe_ingredients and menu base_price';

create or replace view public.high_food_cost_items
with (security_invoker = true) as
select
  c.*,
  case
    when c.food_cost_percent > 40 then 1
    when c.food_cost_percent > 35 then 2
    else 3
  end as priority
from public.current_menu_costs c
where c.food_cost_percent is not null
  and c.food_cost_percent > 35;

create or replace view public.active_pricing_alerts_summary
with (security_invoker = true) as
select
  alert_type,
  severity,
  count(*) as alert_count,
  sum(estimated_monthly_loss) as total_monthly_impact,
  min(created_at) as oldest_alert,
  max(created_at) as newest_alert
from public.pricing_alerts
where status in ('open', 'acknowledged')
group by alert_type, severity
order by
  case severity
    when 'critical' then 1
    when 'warning' then 2
    else 3
  end,
  count(*) desc;

comment on view public.active_pricing_alerts_summary is
  'Open/acknowledged pricing alerts by type and severity';

--------------------------------------------------------------------------------
-- GRANTS (views + functions)
--------------------------------------------------------------------------------

grant select on public.theoretical_vs_actual to authenticated;
grant select on public.current_menu_costs to authenticated;
grant select on public.high_food_cost_items to authenticated;
grant select on public.active_pricing_alerts_summary to authenticated;

revoke all on function public.get_current_batch_cost(uuid) from public;
revoke all on function public.calculate_recipe_cogs(uuid) from public;
revoke all on function public.expire_old_pricing_alerts() from public;

grant execute on function public.calculate_pizza_cogs(text, uuid[]) to authenticated;
grant execute on function public.get_current_batch_cost(uuid) to authenticated;
grant execute on function public.calculate_recipe_cogs(uuid) to authenticated;
grant execute on function public.expire_old_pricing_alerts() to authenticated;

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

alter table public.recipe_ingredients enable row level security;
alter table public.ingredient_batches enable row level security;
alter table public.cogs_period_variance_log enable row level security;
alter table public.menu_item_costing enable row level security;
alter table public.pricing_alerts enable row level security;

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

create policy "recipe_ingredients_select_authenticated"
  on public.recipe_ingredients for select to authenticated using (true);

create policy "ingredient_batches_select_authenticated"
  on public.ingredient_batches for select to authenticated using (true);

create policy "cogs_period_variance_select_authenticated"
  on public.cogs_period_variance_log for select to authenticated using (true);

create policy "menu_item_costing_select_authenticated"
  on public.menu_item_costing for select to authenticated using (true);

create policy "pricing_alerts_select_authenticated"
  on public.pricing_alerts for select to authenticated using (true);

