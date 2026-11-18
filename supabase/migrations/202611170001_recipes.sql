-- Apply to a reviewed Supabase project. Does not replace existing auth tables.
begin;

create table if not exists public.snapchef_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  dietary_preferences text[] not null default '{}',
  meal_types text[] not null default '{}',
  cuisines text[] not null default '{}',
  allergens text[] not null default '{}',
  other_allergens text not null default ''
);
-- Existing installations may have only the initial profile columns.
alter table public.snapchef_profiles
  add column if not exists meal_types text[] not null default '{}',
  add column if not exists cuisines text[] not null default '{}',
  add column if not exists allergens text[] not null default '{}',
  add column if not exists other_allergens text not null default '';
alter table public.snapchef_profiles enable row level security;
create policy snapchef_profile_read on public.snapchef_profiles for select to authenticated using (id = (select auth.uid()));
create policy snapchef_profile_insert on public.snapchef_profiles for insert to authenticated with check (id = (select auth.uid()));
create policy snapchef_profile_update on public.snapchef_profiles for update to authenticated using (id = (select auth.uid())) with check (id = (select auth.uid()));
grant select, insert, update on public.snapchef_profiles to authenticated;

create table public.recipe_options (
  kind text not null check (kind in ('meal', 'cuisine', 'allergen', 'unit', 'dietary')),
  value text not null,
  primary key (kind, value)
);
insert into public.recipe_options(kind, value)
select 'meal', unnest(array['Breakfast','Lunch','Dinner','Snack','Dessert']) union all
select 'cuisine', unnest(array['Indian','Italian','Mexican','Chinese','Thai','Japanese','Korean','Mediterranean','Middle Eastern','American','German']) union all
select 'allergen', unnest(array['Milk','Eggs','Peanuts','Tree nuts','Wheat','Soy','Fish','Shellfish','Sesame']) union all
select 'dietary', unnest(array['Vegetarian','Vegan','Gluten-free','Dairy-free']) union all
select 'unit', unnest(array['g','kg','ml','l','cup','tbsp','tsp','piece']);
alter table public.recipe_options enable row level security;
create policy recipe_options_read on public.recipe_options for select to authenticated using (true);
grant select on public.recipe_options to authenticated;

-- Ordered JSON arrays keep each recipe save atomic. Each ingredient is
-- {name, quantity, unit}; steps are strings. The trigger validates their shape.
create table public.recipes (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid references auth.users(id) on delete set null,
  source text not null default 'community' check (source in ('community','catalog')),
  visibility text not null default 'private' check (visibility in ('private','published')),
  author_first_name text not null default 'Community member',
  title text not null check (length(trim(title)) between 1 and 160),
  meal_type text not null,
  cuisine text not null,
  ingredients jsonb not null,
  steps jsonb not null,
  allergens text[] not null default '{}',
  allergens_declared boolean not null default false,
  dietary_tags text[] not null default '{}',
  photo_path text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  published_at timestamptz,
  check (owner_id is not null or visibility = 'published'),
  check (source <> 'catalog' or (owner_id is null and visibility = 'published'))
);
create index recipes_owner on public.recipes(owner_id, created_at desc);
create index recipes_community on public.recipes(published_at desc, id) where visibility = 'published';
create index recipes_filters on public.recipes(meal_type, cuisine) where visibility = 'published';

create function public.validate_recipe() returns trigger
language plpgsql set search_path = '' as $$
declare item jsonb; tag text; pair record;
begin
  new.title := trim(new.title);
  if jsonb_typeof(new.ingredients) <> 'array' or jsonb_array_length(new.ingredients) = 0
    or jsonb_typeof(new.steps) <> 'array' or jsonb_array_length(new.steps) = 0 then
    raise exception 'At least one ingredient and preparation step are required.';
  end if;
  for item in select * from jsonb_array_elements(new.ingredients) loop
    if jsonb_typeof(item) <> 'object' or coalesce(jsonb_typeof(item->'name'), '') <> 'string'
      or length(trim(item->>'name')) not between 1 and 120
      or coalesce(jsonb_typeof(item->'quantity'), '') <> 'number'
      or not exists (select 1 from public.recipe_options where kind = 'unit' and value = item->>'unit') then
      raise exception 'Each ingredient needs a name, positive numeric quantity and supported unit.';
    end if;
    if (item->>'quantity')::numeric <= 0 then raise exception 'Quantity must be positive.'; end if;
  end loop;
  for item in select * from jsonb_array_elements(new.steps) loop
    if jsonb_typeof(item) <> 'string' or length(trim(item #>> '{}')) = 0 then
      raise exception 'Preparation steps must be nonempty strings.';
    end if;
  end loop;
  for pair in select * from (values ('meal', array[new.meal_type]),
    ('cuisine', array[new.cuisine]), ('allergen', new.allergens), ('dietary', new.dietary_tags)) as p(kind, tags) loop
    foreach tag in array pair.tags loop
      if not exists (select 1 from public.recipe_options where kind = pair.kind and value = tag) then
        raise exception 'Unsupported % option: %', pair.kind, tag;
      end if;
    end loop;
  end loop;
  if not new.allergens_declared then raise exception 'Declare allergens or explicitly select None.'; end if;
  if new.photo_path is not null and new.photo_path <> new.id::text || '/photo' then
    raise exception 'Invalid photo path.';
  end if;
  if tg_op = 'UPDATE' then
    new.created_at := old.created_at;
    if new.id <> old.id then raise exception 'Recipe ID cannot change.'; end if;
  end if;
  new.updated_at := now();
  if new.visibility = 'published' then new.published_at := coalesce(new.published_at, now());
  else new.published_at := null; end if;
  return new;
end;
$$;
revoke all on function public.validate_recipe() from public, anon, authenticated;
create trigger validate_recipe before insert or update on public.recipes for each row execute function public.validate_recipe();

alter table public.recipes enable row level security;
create policy recipe_read on public.recipes for select to authenticated
  using (visibility = 'published' or owner_id = (select auth.uid()));
create policy recipe_create on public.recipes for insert to authenticated
  with check (owner_id = (select auth.uid()) and source = 'community');
create policy recipe_edit on public.recipes for update to authenticated
  using (owner_id = (select auth.uid())) with check (owner_id = (select auth.uid()) and source = 'community');
create policy recipe_delete on public.recipes for delete to authenticated using (owner_id = (select auth.uid()));
-- Column grants prevent authors changing provenance, ownership or timestamps.
revoke all on public.recipes from anon, authenticated;
grant select, delete on public.recipes to authenticated;
grant insert (owner_id, title, meal_type, cuisine, ingredients, steps, allergens,
  allergens_declared, dietary_tags, visibility, author_first_name) on public.recipes to authenticated;
grant update (title, meal_type, cuisine, ingredients, steps, allergens,
  allergens_declared, dietary_tags, visibility, author_first_name, photo_path) on public.recipes to authenticated;

create table public.saved_recipes (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  recipe_id uuid not null references public.recipes(id) on delete cascade,
  saved_at timestamptz not null default now(),
  primary key (user_id, recipe_id)
);
alter table public.saved_recipes enable row level security;
create policy bookmarks_read on public.saved_recipes for select to authenticated using (user_id = (select auth.uid()));
create policy bookmarks_add on public.saved_recipes for insert to authenticated with check (
  user_id = (select auth.uid()) and exists (select 1 from public.recipes r where r.id = recipe_id and r.visibility = 'published'));
create policy bookmarks_remove on public.saved_recipes for delete to authenticated using (user_id = (select auth.uid()));
grant select, insert, delete on public.saved_recipes to authenticated;

-- Photos are private bucket objects, even for published recipes. Always use
-- authenticated downloads; signed URLs would remain valid after unpublishing.
insert into storage.buckets(id, name, public, file_size_limit, allowed_mime_types)
values ('recipe-photos', 'recipe-photos', false, 5242880, array['image/jpeg','image/png','image/webp']);
create policy recipe_photo_read on storage.objects for select to authenticated using (
  bucket_id = 'recipe-photos' and exists (select 1 from public.recipes r where name = r.photo_path
    or (name = r.id::text || '/photo' and r.owner_id = (select auth.uid()))));
create policy recipe_photo_insert on storage.objects for insert to authenticated with check (
  bucket_id = 'recipe-photos' and exists (select 1 from public.recipes r where name = r.id::text || '/photo' and r.owner_id = (select auth.uid())));
create policy recipe_photo_update on storage.objects for update to authenticated using (
  bucket_id = 'recipe-photos' and exists (select 1 from public.recipes r where name = r.id::text || '/photo' and r.owner_id = (select auth.uid()))) with check (
  bucket_id = 'recipe-photos' and exists (select 1 from public.recipes r where name = r.id::text || '/photo' and r.owner_id = (select auth.uid())));
create policy recipe_photo_delete on storage.objects for delete to authenticated using (
  bucket_id = 'recipe-photos' and exists (select 1 from public.recipes r where name = r.id::text || '/photo' and r.owner_id = (select auth.uid())));

-- Durable queue: database deletions commit independently of object storage.
create table public.recipe_photo_cleanup (
  path text primary key,
  queued_at timestamptz not null default now()
);
alter table public.recipe_photo_cleanup enable row level security;
revoke all on public.recipe_photo_cleanup from anon, authenticated;
create function public.queue_recipe_photo_cleanup() returns trigger
language plpgsql security definer set search_path = '' as $$
begin
  insert into public.recipe_photo_cleanup(path) values (old.id::text || '/photo') on conflict do nothing;
  return old;
end;
$$;
revoke all on function public.queue_recipe_photo_cleanup() from public, anon, authenticated;
create trigger queue_recipe_photo_cleanup after delete on public.recipes for each row execute function public.queue_recipe_photo_cleanup();

-- Only trusted backend code may call this. Deletes auth and recipe data in
-- one transaction; published contributions can survive anonymously.
create function public.delete_snapchef_account(p_user_id uuid, p_keep_published boolean) returns void
language plpgsql security definer set search_path = '' as $$
begin
  if p_user_id is null or p_keep_published is null then raise exception 'Explicit deletion choice required.'; end if;
  -- Reassign recipe-bucket object ownership before deleting Auth. Legacy
  -- Storage schemas reference auth.users through owner. File bytes are never
  -- deleted via SQL: discarded photos are removed by the queued Storage worker.
  -- Our object policies use recipe ownership, not these Storage owner fields.
  update storage.objects set owner = null, owner_id = null
    where bucket_id = 'recipe-photos'
      and (owner = p_user_id or owner_id = p_user_id::text);
  if p_keep_published then
    update public.recipes set owner_id = null, author_first_name = 'Former member'
      where owner_id = p_user_id and visibility = 'published';
  end if;
  delete from public.recipes where owner_id = p_user_id;
  delete from public.saved_recipes where user_id = p_user_id;
  delete from public.snapchef_profiles where id = p_user_id;
  delete from auth.users where id = p_user_id;
end;
$$;
revoke all on function public.delete_snapchef_account(uuid, boolean) from public, anon, authenticated;
grant execute on function public.delete_snapchef_account(uuid, boolean) to service_role;
grant all on public.recipe_photo_cleanup to service_role;
commit;
