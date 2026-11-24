# Database and demo integration review

Reviewed November 23, 2026. No live database DDL, grants, functions, or data were
changed. Local edits are not deployed. The working tree already contained an
unfinished merge before this review. Its conflict has since been resolved locally;
no merge commit or push was made.

Local follow-up: the temporary browser database tester has been removed. The
Flutter Recipes placeholder has now been replaced with list/filter/detail,
create/edit/private/publish, bookmark, photo and owner-delete UI, wired through
overridable Riverpod providers. After local bootstrap repairs and installing the
pinned Flutter SDK, static analysis is clean, all 53 Flutter tests pass, and the
debug code/assets bundle compiles. SQL tests pass too; see `BUILD_VERIFICATION.md`.
This supersedes the local UI status in the branch snapshot/remaining-work list
below; those sections describe what was found in the fetched branches. Deployment,
account deletion UI and recommendation
integration remain outstanding. No live database changes were made.

## Live Supabase audit

Project: `wlopsesyhmfcuwxoesja`, matching both the original and feature-based app.
The SQL Editor executed only the read-only query in `supabase/audit_profiles.sql`.

| Role | SELECT | INSERT | UPDATE | DELETE |
| --- | --- | --- | --- | --- |
| anon | No | No | No | No |
| authenticated | Yes | Yes | Yes | No |
| service_role | Yes | Yes | Yes | Yes |

Public schema usage is granted for these roles. Profile RLS is enabled.
`snapchef_read_own`, `snapchef_insert_own`, and `snapchef_update_own` apply to
authenticated users. Their predicates/checks enforce `auth.uid() = id`.
`snapchef_profile_updated` stamps updates and `snapchef_auth_user_created`
creates the initial profile from signup metadata. Columns match `setup.sql`,
including `updated_at`. These are Hetal's existing objects, not recipe objects.

The earlier dashboard "API DISABLED" badge did not establish that authenticated
profile access was broken. The actual database grants permit the application's
profile operations. This audit verifies database grants/policies; it is not an
end-to-end REST login test or a check of every project API configuration setting.
No permission repair is indicated by these results.

The recipe migration now only checks the required profile schema, RLS and grants.
It does not add a second set of policies, alter the profile schema, recreate its
table, or replace its functions/triggers. The test harness applies the actual
team setup first and checks the profile contract remains unchanged afterward.

## Remote branch review

`git fetch origin --prune` completed before this review. Branches are snapshots,
not independent deliverables to merge one after another.

| Branch / commit | Implemented in source | Integration status |
| --- | --- | --- |
| `origin/main` / `1845e3d` | Riverpod feature architecture, auth/preferences, image picker, scan states, editable ingredient list, Gemini function and tests | Main already includes auth-flow and ingredient-capture work |
| `origin/feat/auth-flow` / `e1db99b` | Feature-based account flow, profile preferences and reset | Already merged into main |
| `origin/feat/ingredient-capture` / `3e0a6cc` | Camera/gallery wrapper, permission/failure handling, ingredient confirmation, detection integration | Already merged into main |
| `origin/ci/pin-flutter-version` / `2f1033d` | Flutter version pin in CI | Already merged into main; use team version 3.47.8 for reproducibility |
| `origin/hetal` / `637d3e3` | Main merged with legacy account UI, branding assets, and profile SQL setup | Contains integration defects described below |
| local `newt-database` / `11cac62` plus current edits | Recipe persistence/privacy, bookmarks, catalog seed, recommendation SQL, photo lifecycle and keep/discard deletion endpoint | Not wired to the new feature screens; not deployed |

The fetched refs did not include `origin/newt-database`. The previous push was
blocked; don't assume teammates can see the local database commit yet.
Dependency-bot branches are version updates, not additional recipe features.
Branch review verifies source availability, not deployment or device execution.

## Merge / demo blockers found at audit time (now repaired locally)

The working tree was already merging `637d3e3` (Hetal) into `newt-database`.
`README.md` is unmerged; many incoming feature files are staged. This review
neither aborts that merge nor commits/stages the pre-existing incoming changes.

The incoming Hetal source has concrete build problems, beyond the README conflict:

1. `lib/main.dart` contains both legacy and feature-based entrypoints, imports
   after declarations, and an unclosed legacy auth-gate class. Keep one coherent
   bootstrap; the feature-based `origin/main:lib/main.dart` is the recommended
   starting point. Keep Hetal's reusable UI/assets rather than discarding them.
2. `pubspec.yaml` declares `supabase_flutter` twice (2.10.0 and 2.18.3 ranges).
   Keep one dependency compatible with the feature branch and its lockfile.
3. The Flutter/Dart SDK is not on this machine's PATH. Full Flutter analysis,
   widget tests and a live demo were not run during this review.

These defects were initially left untouched during the read-only audit. At the
user's subsequent request, the entrypoint/dependencies/smoke test were repaired,
the README conflict resolved, and compilation/tests verified. The historical
findings above explain the repairs; they are no longer outstanding build blockers.

## What Newton still needs to integrate

1. Finish the feature-shell merge and establish a passing Flutter baseline.
2. Introduce a recipe repository interface and Riverpod provider under
   `lib/src/features/recipes/`, adapting `lib/recipes/recipe_repository.dart` to
   the team architecture rather than exposing Supabase directly to widgets.
3. Replace `RecipesScreen`'s placeholder with editor, My Recipes (private and
   published), community list/filter/detail, saved bookmarks and allergen warnings.
4. Wire recipe image upload/download and deletion confirmation to that UI.
5. Coordinate with Joel: `RecommendationsScreen` is a placeholder. The SQL RPC
   supplies recipe/matched/missing results; his controller should refresh on
   confirmed-ingredient and preference changes and label missing ingredients.
6. Coordinate with Hetal: add the explicit keep/discard deletion confirmation and
   call the trusted deletion endpoint. Her current account screen has no deletion
   flow. Keep profile creation/login/password recovery in her workstream.
7. Review/deploy recipe migrations, seed, storage policies and Edge Functions in
   development; validate with two real users before applying to shared production.
   A local test pass does not verify hosted Storage/Auth behavior.

Shared option lists need alignment: recipes include German cuisine, while the
current `FoodPreferences.cuisineOptions` omits it. Avoid divergent lists as forms
are integrated. Ingredient matching is exact after trim/lowercase, not synonym
recognition. The historical implementation plan still mentions Firebase; actual
code is using Supabase. Do not introduce Firebase as part of this integration.

## Recommended demo path

Use Flutter, not a separate Expo rewrite. Expo Go runs React Native; this repo
contains a Flutter app with no Expo package/app configuration. A separate Expo
prototype would not demonstrate this code or its tested ownership rules.

After resolving the above merge/build issues and installing the team Flutter SDK:

```powershell
flutter --version
flutter pub get
flutter analyze
flutter test
flutter devices
# Android emulator or USB-connected Android device, without live recognition:
flutter run --dart-define=STUB_DETECTION=true
```

For a browser demo, first add the missing web host on an integration branch
(`flutter create --platforms=web .`, review generated changes), then:

```powershell
flutter run -d chrome --dart-define=STUB_DETECTION=true
```

`STUB_DETECTION` fakes recognition only. It does not fake authentication,
preferences, recipes, or provision any hosted database tables. For development,
override `SUPABASE_URL` and `SUPABASE_PUBLISHABLE_KEY` using the existing build
configuration. Use only a publishable key in the app, never service credentials.

Suggested demo sequence once screens are connected: sign in as A, create private
recipe, publish a second recipe, sign in as B, verify only the published recipe
appears, save it, filter/open details, and test manual ingredients/recommendations.
Use Android for final camera/permission checks; a browser demo alone is insufficient.

References: [Expo tools](https://docs.expo.dev/develop/tools/),
[Flutter web setup](https://docs.flutter.dev/platform-integration/web/setup).
