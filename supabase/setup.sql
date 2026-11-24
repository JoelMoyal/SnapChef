-- Run once in the Supabase SQL Editor. Safe to rerun for this schema.
begin;
create table if not exists public.snapchef_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '' check (char_length(full_name) <= 120),
  dietary_preferences text[] not null default '{}',
  cuisines text[] not null default '{}',
  allergens text[] not null default '{}',
  meal_types text[] not null default '{}',
  other_allergens text not null default '' check (char_length(other_allergens) <= 200),
  updated_at timestamptz not null default now()
);
alter table public.snapchef_profiles enable row level security;
revoke all on public.snapchef_profiles from anon;
revoke all on public.snapchef_profiles from authenticated;
grant select, insert, update on public.snapchef_profiles to authenticated;
drop policy if exists snapchef_read_own on public.snapchef_profiles;
create policy snapchef_read_own on public.snapchef_profiles for select to authenticated
  using ((select auth.uid()) = id);
drop policy if exists snapchef_insert_own on public.snapchef_profiles;
create policy snapchef_insert_own on public.snapchef_profiles for insert to authenticated
  with check ((select auth.uid()) = id);
drop policy if exists snapchef_update_own on public.snapchef_profiles;
create policy snapchef_update_own on public.snapchef_profiles for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create or replace function public.snapchef_stamp_profile()
returns trigger language plpgsql set search_path = '' as $$
begin
  new.updated_at = now();
  return new;
end;
$$;
drop trigger if exists snapchef_profile_updated on public.snapchef_profiles;
create trigger snapchef_profile_updated before update on public.snapchef_profiles
for each row execute function public.snapchef_stamp_profile();

-- Create the profile even when email confirmation delays the first session.
create or replace function public.snapchef_handle_new_user()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.snapchef_profiles (id, full_name, dietary_preferences)
  values (new.id, left(coalesce(new.raw_user_meta_data ->> 'full_name', ''), 120),
    case when jsonb_typeof(new.raw_user_meta_data -> 'dietary_preferences') = 'array'
      then array(select jsonb_array_elements_text(new.raw_user_meta_data -> 'dietary_preferences'))
      else '{}'::text[] end)
  on conflict (id) do nothing;
  return new;
end;
$$;
revoke all on function public.snapchef_handle_new_user() from public, anon, authenticated;
drop trigger if exists snapchef_auth_user_created on auth.users;
create trigger snapchef_auth_user_created after insert on auth.users
for each row execute function public.snapchef_handle_new_user();
commit;
