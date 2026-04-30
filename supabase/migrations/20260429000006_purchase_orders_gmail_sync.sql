-- Purchase order receipts (vendor invoices) + Gmail push sync cursor

create table public.purchase_orders (
  id uuid primary key default gen_random_uuid(),
  vendor_id uuid not null references public.vendors (id) on delete restrict,
  invoice_number text not null,
  invoice_date text,
  status text not null default 'received',
  received_at timestamptz,
  subtotal numeric(12, 4),
  total numeric(12, 4),
  created_at timestamptz not null default timezone('utc', now()),
  unique (vendor_id, invoice_number)
);

create index purchase_orders_vendor_id_idx on public.purchase_orders (vendor_id);

alter table public.purchase_orders enable row level security;

create policy "purchase_orders_select_authenticated"
  on public.purchase_orders for select to authenticated using (true);

-- Stores last processed Gmail historyId for incremental history.list
create table public.gmail_sync_state (
  watch_email text primary key,
  last_history_id text not null,
  updated_at timestamptz not null default timezone('utc', now())
);

alter table public.gmail_sync_state enable row level security;
