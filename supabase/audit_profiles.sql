-- Read-only inspection. Returns schema/security metadata, never profile rows.
-- Safe to run in the shared project's SQL Editor; do not apply migrations here.
begin read only;
select 'grants' as section, jsonb_agg(jsonb_build_object(
  'role',r,
  'select',has_table_privilege(r,'public.snapchef_profiles','SELECT'),
  'insert',has_table_privilege(r,'public.snapchef_profiles','INSERT'),
  'update',has_table_privilege(r,'public.snapchef_profiles','UPDATE'),
  'delete',has_table_privilege(r,'public.snapchef_profiles','DELETE'),
  'schema_usage',has_schema_privilege(r,'public','USAGE'))) as details
from unnest(array['anon','authenticated','service_role']) r
union all
select 'policies',jsonb_agg(to_jsonb(p)) from pg_policies p
where schemaname='public' and tablename='snapchef_profiles'
union all
select 'triggers',jsonb_agg(jsonb_build_object('schema',n.nspname,'table',c.relname,
  'definition',pg_get_triggerdef(t.oid),'function',pg_get_functiondef(t.tgfoid)))
from pg_trigger t join pg_class c on c.oid=t.tgrelid
join pg_namespace n on n.oid=c.relnamespace
where not t.tgisinternal and ((n.nspname='public' and c.relname='snapchef_profiles')
  or (n.nspname='auth' and c.relname='users'))
union all
select 'columns',jsonb_agg(jsonb_build_object('column',column_name,'type',udt_name,
  'default',column_default,'nullable',is_nullable)) from information_schema.columns
where table_schema='public' and table_name='snapchef_profiles'
union all
select 'rls',jsonb_agg(jsonb_build_object('table',relname,'enabled',relrowsecurity))
from pg_class where oid='public.snapchef_profiles'::regclass;
rollback;
