-- profiles.account_role: admin | vendor | employee | user (all rows reference auth.users via id).
-- Self-service sign-up may only insert account_role = user. Changes use service role or DB owner (SQL editor).

alter table public.profiles
  add column account_role text not null default 'user'
  constraint profiles_account_role_check
    check (account_role in ('admin', 'vendor', 'employee', 'user'));

create index if not exists profiles_account_role_idx on public.profiles (account_role);

drop policy if exists "profiles_insert_own" on public.profiles;

create policy "profiles_insert_own"
  on public.profiles
  for insert
  to authenticated
  with check (
    id = auth.uid()
    and account_role = 'user'
  );

drop policy if exists "profiles_update_own" on public.profiles;

create policy "profiles_update_own"
  on public.profiles
  for update
  to authenticated
  using (id = auth.uid())
  with check (id = auth.uid());

create or replace function public.profiles_guard_account_role_change()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
declare
  jwt_role text;
begin
  if tg_op <> 'UPDATE' then
    return new;
  end if;
  if new.account_role is not distinct from old.account_role then
    return new;
  end if;

  -- Allow privileged DB users and service_role (covers Supabase's new opaque
  -- sb_secret_ key format where PostgREST sets current_user = 'service_role').
  if current_user in ('postgres', 'supabase_admin', 'service_role') then
    return new;
  end if;

  -- Legacy JWT-based service role key carries role claim in the token.
  jwt_role := coalesce(auth.jwt() ->> 'role', '');
  if jwt_role = 'service_role' then
    return new;
  end if;

  raise exception
    'account_role may only be changed with the service role or as a database maintainer';
end;
$$;

drop trigger if exists profiles_account_role_guard on public.profiles;
create trigger profiles_account_role_guard
  before update on public.profiles
  for each row
  execute function public.profiles_guard_account_role_change();
