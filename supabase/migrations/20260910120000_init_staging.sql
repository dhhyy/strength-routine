-- Staging foundation: auth-linked profile + opaque JSON mirrors of local files.
-- App sync UI comes later; schema is ready for RLS-safe upserts.

create extension if not exists "pgcrypto";

create table if not exists public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.training_snapshots (
  user_id uuid primary key references auth.users (id) on delete cascade,
  schema_hint text,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.working_max_snapshots (
  user_id uuid primary key references auth.users (id) on delete cascade,
  payload jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_set_updated_at on public.profiles;
create trigger profiles_set_updated_at
  before update on public.profiles
  for each row execute function public.set_updated_at();

drop trigger if exists training_snapshots_set_updated_at on public.training_snapshots;
create trigger training_snapshots_set_updated_at
  before update on public.training_snapshots
  for each row execute function public.set_updated_at();

drop trigger if exists working_max_snapshots_set_updated_at on public.working_max_snapshots;
create trigger working_max_snapshots_set_updated_at
  before update on public.working_max_snapshots
  for each row execute function public.set_updated_at();

-- Auto-create profile row on signup.
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'full_name', new.email))
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.training_snapshots enable row level security;
alter table public.working_max_snapshots enable row level security;

drop policy if exists "profiles_select_own" on public.profiles;
create policy "profiles_select_own"
  on public.profiles for select
  using (auth.uid() = id);

drop policy if exists "profiles_update_own" on public.profiles;
create policy "profiles_update_own"
  on public.profiles for update
  using (auth.uid() = id)
  with check (auth.uid() = id);

drop policy if exists "training_snapshots_select_own" on public.training_snapshots;
create policy "training_snapshots_select_own"
  on public.training_snapshots for select
  using (auth.uid() = user_id);

drop policy if exists "training_snapshots_upsert_own" on public.training_snapshots;
create policy "training_snapshots_upsert_own"
  on public.training_snapshots for insert
  with check (auth.uid() = user_id);

drop policy if exists "training_snapshots_update_own" on public.training_snapshots;
create policy "training_snapshots_update_own"
  on public.training_snapshots for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

drop policy if exists "working_max_select_own" on public.working_max_snapshots;
create policy "working_max_select_own"
  on public.working_max_snapshots for select
  using (auth.uid() = user_id);

drop policy if exists "working_max_insert_own" on public.working_max_snapshots;
create policy "working_max_insert_own"
  on public.working_max_snapshots for insert
  with check (auth.uid() = user_id);

drop policy if exists "working_max_update_own" on public.working_max_snapshots;
create policy "working_max_update_own"
  on public.working_max_snapshots for update
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
