# Recipe feature

`RecipesScreen` replaces the shell's placeholder with My Recipes, Community,
Saved and Catalog lists. Community supports cuisine/meal filters; lists have
30-row pagination, empty/error/retry states and pull-to-refresh. Detail screens
show ingredients, ordered steps, photos, declared allergens and preference-based
warnings. Only owners see edit/delete controls; database RLS enforces ownership.

The editor loads its options from the database, validates quantities and required
fields, requires explicit allergens/None confirmation, and saves private or
published recipes. Photos reuse the team's photo picker interface, with camera
and library options and 5 MB JPEG/PNG/WebP validation. Recipe persistence and
photo upload are separate operations: after an upload failure, the saved ID is
retained so retrying cannot create another recipe.

Riverpod providers depend on the overridable `RecipeDataSource` interface.
`lib/recipes/recipe_repository.dart` retains the existing Supabase implementation
and compatibility location. No recipe widget accesses Supabase directly.

Widget checks: `flutter test test/features/recipes/recipes_screen_test.dart`.
They exercise owner-only actions and required-field validation with a fake data
source. The full Flutter suite now passes (53 tests), static analysis reports no
issues, and a debug code/assets bundle compiles with Flutter 3.47.8. SQL/RLS tests
also pass. See `docs/BUILD_VERIFICATION.md`; no native iPhone/device run is claimed.

Not deployed: the database migrations/storage/functions still need development
deployment. Bootstrap, dependency and merge-conflict repairs are verified locally;
the existing merge remains uncommitted.
Recommendations and the account deletion UI remain integration work with their
owners. Real Storage, camera permissions and two-account behavior require hosted
and device testing. Replacing/removing an existing photo currently supports
replacement; deleting a recipe cleans its photo through the backend queue.
