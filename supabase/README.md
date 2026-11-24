# SnapChef recipe backend

This extends Hetal's Supabase authentication project. No credentials, migrations,
or functions have been applied to the hosted project by this branch.

## Apply and deploy

1. Review `audit_profiles.sql` against the shared project. The November 23 audit
   confirmed Hetal's owner-only profile policies and authenticated SELECT/INSERT/
   UPDATE grants. No live grants or data were changed. Export/back up the existing
   schema/data and test in development first. Do not reset the shared database.
   On a fresh development database only, run the accounts owner's reviewed
   `setup.sql` first. It is the source of truth for profiles and signup triggers;
   do not rerun it on the shared project merely to install recipe tables.
2. Apply `migrations/202611170001_recipes.sql`, then
   `migrations/202611170002_recommendations.sql` in SQL Editor, or use the team's
   Supabase CLI migration workflow after reconciling remote migration history.
   Each migration is transactional and runs once. The first verifies the profile
   contract and fails before changing anything if setup is incompatible. It never
   creates/alters the profile table, changes its grants/policies, or replaces any
   signup/timestamp trigger. The existing three owner policies remain authoritative.
3. Optionally run `seed.sql` as administrator to add three original catalog recipes.
4. Deploy `delete-account` and `cleanup-recipe-photos` with the Supabase CLI.
   `config.toml` disables gateway JWT verification because the handlers perform
   their own authentication. Deletion verifies the caller through Auth getUser;
   cleanup requires a separate `RECIPE_CLEANUP_SECRET` set as a function secret.
   Supabase supplies `SUPABASE_URL` and `SUPABASE_SERVICE_ROLE_KEY` server-side.
   Never copy the service key or cleanup secret into Flutter.
5. Schedule a trusted POST to `cleanup-recipe-photos` every few minutes with
   `Authorization: Bearer <RECIPE_CLEANUP_SECRET>`. A batch handles 100 objects;
   monitor the queue and invoke more often if necessary. Do not put secrets in git.
6. Repeat the two-user checks below against development Supabase, including real
   Storage uploads and deployed function requests, before production deployment.

## Model and behavior

One recipe row contains ordered JSON ingredient objects (`name`, positive numeric
`quantity`, supported `unit`) and an ordered string array of steps. Whole-row
saves are atomic; no partially saved ingredient/step collections. This simple
model avoids multi-request transactions for a small app. Normalize child tables
later if ingredient analytics or shared ingredient metadata requires it.

- `recipes`: an owned private/published community recipe, or administrator-managed
  published catalog recipe. Recipes require complete fields even when private;
  incomplete editing drafts stay in the UI. `allergens_declared=true` plus an
  empty allergen array explicitly means None. Dietary tags are author-declared.
- `recipe_options`: shared authoritative meal/cuisine/allergen/unit/dietary lists.
  Recipe forms should load these using `options()`; existing preferences UI still
  has hardcoded lists and should be migrated to this source during UI integration.
- `saved_recipes`: private bookmarks of published recipes. Updates follow the
  original. Unpublishing hides it from saved results; republishing restores it.
  Deleting the original cascades bookmark deletion. Bookmarks are not copies.
- Public means readable to signed-in users. Only authors can change their own
  community recipes. Clients cannot change ownership, source, or timestamps.
- `author_first_name` is a public display name supplied by the author, not a
  verified identity. Private profile records are never joined into community data.
- Photos live at `<recipe-id>/photo` in a private 5 MB bucket. Upload JPEG/PNG/WebP
  bytes with the correct MIME type. Authenticated downloads enforce current
  visibility; do not replace them with public URLs or cached signed URLs. UI must
  clear any locally displayed private data/photos on logout/account changes.
- Deletion queues the fixed photo path even if upload succeeded but linking failed.
  The service worker removes objects through Storage's API, then acknowledges the
  queue. Failed cleanup is retried; do not delete Storage metadata using SQL.

## Flutter integration

Instantiate `RecipeRepository(backend)` using the existing client from
`lib/backend.dart`. The feature shell now includes a Riverpod-wired recipe editor,
My Recipes, community/filter/detail, catalog and bookmarks under
`lib/src/features/recipes/`. The provider is overridable for widget tests.
The account-deletion confirmation flow still needs integration with accounts.
The bootstrap/dependency conflicts have now been repaired and local analysis,
53 Flutter tests and debug bundle compilation pass (see `docs/BUILD_VERIFICATION.md`).
Hosted migrations/functions and real device integration remain unverified and
are still not deployed by these local code changes.

- `create` / `update`: submit a `RecipeDraft`; changing `published` publishes or
  unpublishes the same recipe. Read the returned row for its database-generated ID.
- `mine`, `community`, `catalog`, `saved`: pages of 30, with optional offset.
  Community excludes the viewer's own recipes; My Recipes includes both visibilities.
  Saved results contain `saved_at` and nested `recipes` data.
- `get`, `delete`, `save`, `unsave`: detail, owner deletion, bookmark operations.
  UI must confirm deletion before calling `delete`.
- `uploadPhoto` / `downloadPhoto`: storage helpers; display bytes using Image.memory.
- `recommend`: passes the confirmed ingredient list. Results contain `recipe`,
  `matched_count`, `missing_count`. Reinvoke when inputs/preferences change.
- `deleteAccount(keepPublished: ...)`: call only after explicit confirmation and
  choice. It invokes the trusted endpoint then clears the local session.

Recommendations include published catalog/community recipes, not private recipes.
They require at least one matching ingredient and apply saved meal/cuisine choices,
allergen exclusions and dietary tags. Rank by missing count ascending, matched
count descending, then recipe ID. Ingredient names match after trim/lowercase;
duplicates count once. Synonyms, singular/plural, quantities and substitutions
are not inferred. `other_allergens` is treated as comma-separated exact ingredient
names. These filters are not a medical allergen guarantee; the existing warning
still applies. Community browsing should warn on allergen overlap rather than
hide recipes (the repository returns their declared allergens).

## Account deletion contract

POST to `delete-account` with `{ "confirmation": "DELETE", "keepPublished": true }`
or `false`. The endpoint derives identity from the validated token, never a body ID.
The service-only SQL operation runs atomically:

- Keep: anonymize published contributions to `Former member`, retaining their
  recipe photos; delete owned private recipes, profile, bookmarks and Auth user.
- Discard: delete all owned recipes, profile, bookmarks and Auth user.
- Both: deleted recipe photos are queued for asynchronous removal.

Recipe-bucket object ownership fields are cleared in the same deletion transaction
before deleting Auth, including for retained photos. Recipe-based Storage policies
continue to control access. This avoids the legacy Storage owner foreign-key
restriction; file deletion still goes through the Storage API worker.

Coordinate with Hetal: her deletion UI must use this endpoint instead of directly
deleting the Auth user. Unrelated future tables/buckets need explicit deletion
handling. Do not put identifying details in recipe content/photos if retaining
them anonymously; anonymization removes the owner link/display name only.
Auth tokens already issued may remain valid until expiry; RLS prevents those
tokens from writing to the deleted user's recipes/profile via ownership/FKs,
but public signed-in reads can persist until expiry. This is Supabase token
behavior, not immediate global JWT revocation.

## Verification

Install the temporary embedded PostgreSQL test engine from the repository root:

```powershell
npm install --prefix tmp/database-check --no-save --package-lock=false @electric-sql/pglite@0.5.16
node supabase/tests/database.test.mjs
```

The harness stubs Supabase-owned Auth/Storage tables and roles, applies the real
team `setup.sql`, then executes the recipe migrations and PostgreSQL policies.
It compares profile data, columns, constraints, grants, policies, triggers and
trigger functions before/after, and checks a missing setup fails without creating
recipe tables. It also checks two-user isolation,
owner-only writes, bookmark visibility, photo isolation, validation, recommendation
ranking/preferences, anonymous rejection, and both deletion choices. It cannot
verify Supabase HTTP gateways, Auth internals or real Storage object removal.

Deployment checks: user A creates private and published recipes and uploads photos;
user B can read/save only the published recipe, cannot edit/delete either, and
cannot read A's bookmarks/profile/private photos. Unpublish and verify B loses
recipe/photo access. Delete accounts with each choice, run cleanup, and verify
Auth login fails and only the explicitly retained published content survives.

## Requirements coverage

US5 FR01-05: recipe validation, fixed options, declared allergens, optional photo.
FR06-10: publish, owner list, ownership enforcement, community list/filter/detail.
FR11: allergen metadata supplied for UI warnings. FR12: unpublished recipes and
private bookmarks. US1: profile persistence and filtering. US4: recommendation
query/data contract. US2: associated-data deletion integration only; account
creation/login remain with the existing implementation. UI permission prompts,
field error presentation and confirmation dialogs are outside this data layer.

Implementation references: [Supabase RLS](https://supabase.com/docs/guides/database/postgres/row-level-security),
[database function security](https://supabase.com/docs/guides/database/functions),
[Storage access control](https://supabase.com/docs/guides/storage/security/access-control).
