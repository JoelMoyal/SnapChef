// Local PostgreSQL verification. PGlite stubs only Supabase-owned auth/storage
// objects; the production migrations and PostgreSQL RLS run unchanged.
import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import { PGlite } from "../../tmp/database-check/node_modules/@electric-sql/pglite/dist/index.js";

const db = new PGlite();
const a = "11111111-1111-4111-8111-111111111111";
const b = "22222222-2222-4222-8222-222222222222";
await db.exec(`
  create role anon; create role authenticated; create role service_role bypassrls;
  create schema auth; create schema storage;
  create table auth.users(id uuid primary key);
  create function auth.uid() returns uuid language sql stable as
    $$ select nullif(current_setting('request.jwt.claim.sub', true), '')::uuid $$;
  create table storage.buckets(id text primary key, name text, public boolean,
    file_size_limit bigint, allowed_mime_types text[]);
  create table storage.objects(id uuid default gen_random_uuid(), bucket_id text, name text,
    owner uuid default auth.uid() references auth.users(id), owner_id text);
  alter table storage.objects enable row level security;
  grant usage on schema public, auth, storage to anon, authenticated, service_role;
  grant execute on function auth.uid() to authenticated;
  grant all on storage.objects to authenticated;
  insert into auth.users values ('${a}'), ('${b}');
`);
for (
  const name of ["202611170001_recipes.sql", "202611170002_recommendations.sql"]
) {
  await db.exec(
    await readFile(new URL(`../migrations/${name}`, import.meta.url), "utf8"),
  );
}
const asUser = async (id) => {
  await db.exec(
    `reset role; set role authenticated; set request.jwt.claim.sub = '${id}';`,
  );
};
const count = async (sql) => (await db.query(sql)).rows.length;
const fails = async (sql) => assert.rejects(() => db.exec(sql));
const insert = async (
  title,
  visibility,
  ingredients = '[{"name":"tomato","quantity":2,"unit":"piece"}]',
) => {
  const { rows } = await db.query(
    `insert into public.recipes
    (owner_id,title,meal_type,cuisine,ingredients,steps,allergens_declared,visibility)
    values (auth.uid(),$1,'Dinner','Italian',$2::jsonb,'["Cook"]',true,$3) returning id`,
    [title, ingredients, visibility],
  );
  return rows[0].id;
};
await asUser(a);
await db.exec(
  `insert into public.snapchef_profiles(id,full_name) values (auth.uid(),'User A')`,
);
const privateId = await insert("Private A", "private");
const publicId = await insert("Published A", "published");
const missingId = await insert(
  "Missing ingredient",
  "published",
  '[{"name":"tomato","quantity":1,"unit":"piece"},{"name":"onion","quantity":1,"unit":"piece"}]',
);
await db.exec(
  `insert into storage.objects(bucket_id,name) values ('recipe-photos','${privateId}/photo');
  update public.recipes set photo_path='${privateId}/photo' where id='${privateId}';`,
);
assert.equal(await count("select * from storage.objects"), 1);
await asUser(b);
assert.equal(await count("select * from public.snapchef_profiles"), 0);
assert.equal(await count("select * from public.recipes"), 2);
assert.equal(await count("select * from storage.objects"), 0);
assert.equal(
  await count(
    `update public.recipes set title='Stolen' where id='${publicId}' returning id`,
  ),
  0,
);
assert.equal(
  await count(`delete from public.recipes where id='${publicId}' returning id`),
  0,
);
await fails(
  `insert into public.saved_recipes(recipe_id) values ('${privateId}')`,
);
await db.exec(
  `insert into public.saved_recipes(recipe_id) values ('${publicId}')`,
);
await fails(`update public.recipes set owner_id='${b}' where id='${publicId}'`);
await fails(`select public.delete_snapchef_account('${a}',false)`);
const results = (await db.query(
  `select * from public.recommend_recipes(array[' Tomato ','tomato'])`,
)).rows;
assert.equal(results.length, 2);
assert.equal(results[0].recipe.id, publicId);
assert.equal(results[0].matched_count, 1);
assert.equal(results[1].missing_count, 1);
await db.exec(
  `insert into public.snapchef_profiles(id, allergens) values (auth.uid(),array['Milk'])`,
);
await asUser(a);
assert.equal(await count("select * from public.saved_recipes"), 0);
await db.exec(
  `update public.recipes set allergens=array['Milk'] where id='${publicId}'`,
);
await asUser(b);
assert.equal(
  await count(`select * from public.recommend_recipes(array['tomato'])`),
  1,
);
await asUser(a);
await db.exec(
  `update public.recipes set visibility='private' where id='${publicId}'`,
);
await asUser(b);
assert.equal(
  await count(
    "select * from public.saved_recipes s join public.recipes r on r.id=s.recipe_id",
  ),
  0,
);
await fails(
  `insert into storage.objects(bucket_id,name) values ('recipe-photos','${privateId}/photo')`,
);
await asUser(a);
await fails(
  `update public.recipes set ingredients='[]' where id='${privateId}'`,
);
await fails(
  `update public.recipes set allergens_declared=false where id='${privateId}'`,
);
await fails(`update public.recipes set steps='[""]' where id='${privateId}'`);
await fails(
  `update public.recipes set cuisine='Invalid' where id='${privateId}'`,
);
await fails(
  `update public.recipes set ingredients='[{"name":"x","quantity":0,"unit":"g"}]' where id='${privateId}'`,
);
await db.exec(`reset role; select public.delete_snapchef_account('${a}',true)`);
assert.equal(await count(`select * from auth.users where id='${a}'`), 0);
assert.equal(
  await count(`select * from public.recipes where id='${privateId}'`),
  0,
);
assert.equal(
  await count(
    `select * from public.recipe_photo_cleanup where path='${privateId}/photo'`,
  ),
  1,
);
const retained =
  (await db.query(`select * from public.recipes where id='${missingId}'`))
    .rows[0];
assert.equal(retained.owner_id, null);
assert.equal(retained.author_first_name, "Former member");
await asUser(b);
const discardId = await insert("Discard B", "published");
await db.exec(
  `reset role; select public.delete_snapchef_account('${b}',false)`,
);
assert.equal(
  await count(`select * from public.recipes where id='${discardId}'`),
  0,
);
await db.exec(`set role anon`);
await fails("select * from public.recipes");
await fails(`select * from public.recommend_recipes(array['tomato'])`);
await db.exec("reset role");
const seed = await readFile(new URL("../seed.sql", import.meta.url), "utf8");
await db.exec(seed);
await db.exec(seed);
assert.equal(
  await count("select * from public.recipes where source='catalog'"),
  3,
);
await db.close();
console.log(
  "PASS: migrations, recipe validation, two-user RLS, bookmarks, photos, ranking, filters, keep/discard deletion, anonymous denial.",
);
