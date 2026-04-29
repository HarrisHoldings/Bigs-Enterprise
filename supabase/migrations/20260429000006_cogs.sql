-- ============================================================
-- LITTLE BIGS POS — COGS (Cost of Goods Sold)
-- Theoretical recipe costs from ingredient usage × cost_per_oz
-- Depends on: ingredients, menu_items (core + menu migrations)
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
-- ROW LEVEL SECURITY (kitchen / management — not public catalog)
--------------------------------------------------------------------------------

alter table public.recipes enable row level security;

create policy "recipes_select_authenticated"
  on public.recipes for select to authenticated using (true);

alter table public.recipe_lines enable row level security;

create policy "recipe_lines_select_authenticated"
  on public.recipe_lines for select to authenticated using (true);
