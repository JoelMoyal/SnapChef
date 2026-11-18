begin;
-- Invoker privileges preserve RLS, so private recipes never enter results.
-- Quantities do not affect matching. Names match after trimming/lowercasing.
create function public.recommend_recipes(p_ingredients text[], p_limit integer default 30)
returns table(recipe jsonb, matched_count integer, missing_count integer)
language sql stable security invoker set search_path = '' as $$
  with input as (
    select distinct lower(trim(x)) as name from unnest(p_ingredients) x where trim(x) <> ''
  ), prefs as (
    select p.* from public.snapchef_profiles p where p.id = (select auth.uid())
  ), candidates as (
    select r.* from public.recipes r left join prefs p on true
    where r.visibility = 'published'
      and (coalesce(cardinality(p.meal_types), 0) = 0 or r.meal_type = any(p.meal_types))
      and (coalesce(cardinality(p.cuisines), 0) = 0 or r.cuisine = any(p.cuisines))
      and not r.allergens && coalesce(p.allergens, '{}')
      and r.dietary_tags @> coalesce(p.dietary_preferences, '{}')
      and not exists (
        select 1 from jsonb_array_elements(r.ingredients) i,
          regexp_split_to_table(coalesce(p.other_allergens, ''), ',') excluded
        where trim(excluded) <> '' and lower(trim(i->>'name')) = lower(trim(excluded))
      )
  ), scored as (
    select c.id,
      count(distinct lower(trim(i->>'name'))) filter (where input.name is not null)::integer matched,
      count(distinct lower(trim(i->>'name'))) filter (where input.name is null)::integer missing
    from candidates c cross join lateral jsonb_array_elements(c.ingredients) i
    left join input on input.name = lower(trim(i->>'name')) group by c.id
  )
  select to_jsonb(c), s.matched, s.missing from candidates c join scored s using(id)
    where s.matched > 0 order by s.missing, s.matched desc, c.id
    limit greatest(1, least(coalesce(p_limit, 30), 100));
$$;
revoke all on function public.recommend_recipes(text[], integer) from public, anon;
grant execute on function public.recommend_recipes(text[], integer) to authenticated;
commit;
