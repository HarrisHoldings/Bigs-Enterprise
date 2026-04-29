-- Row Level Security for inventory + menu catalog.
-- Writes remain denied for anon/authenticated unless additional policies are added;
-- service_role / dashboard bypass RLS for admin operations.

--------------------------------------------------------------------------------
-- Inventory & vendors (staff-only reads — costs and supplier data)
--------------------------------------------------------------------------------

alter table public.units_of_measure enable row level security;

create policy "units_of_measure_select_authenticated"
  on public.units_of_measure
  for select
  to authenticated
  using (true);

alter table public.vendors enable row level security;

create policy "vendors_select_authenticated"
  on public.vendors
  for select
  to authenticated
  using (true);

alter table public.inventory_categories enable row level security;

create policy "inventory_categories_select_authenticated"
  on public.inventory_categories
  for select
  to authenticated
  using (true);

alter table public.ingredients enable row level security;

create policy "ingredients_select_authenticated"
  on public.ingredients
  for select
  to authenticated
  using (true);

--------------------------------------------------------------------------------
-- Menu catalog (anonymous + signed-in clients — POS / online menu)
--------------------------------------------------------------------------------

alter table public.menu_categories enable row level security;

create policy "menu_categories_select_public"
  on public.menu_categories
  for select
  to anon, authenticated
  using (true);

alter table public.pizza_sizes enable row level security;

create policy "pizza_sizes_select_public"
  on public.pizza_sizes
  for select
  to anon, authenticated
  using (true);

alter table public.crust_types enable row level security;

create policy "crust_types_select_public"
  on public.crust_types
  for select
  to anon, authenticated
  using (true);

alter table public.toppings enable row level security;

create policy "toppings_select_public"
  on public.toppings
  for select
  to anon, authenticated
  using (true);

alter table public.menu_items enable row level security;

create policy "menu_items_select_public"
  on public.menu_items
  for select
  to anon, authenticated
  using (true);
