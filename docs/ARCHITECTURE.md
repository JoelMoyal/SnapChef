# Architecture & folder layout

SnapChef is organized **by feature** so the three workstreams can work in
parallel without stepping on each other. State management is **Riverpod**.

```
lib/
  main.dart                     # starts the app, wraps it in ProviderScope
  src/
    app.dart                    # MaterialApp + bottom-nav shell (one tab per feature)
    theme.dart                  # shared colors/typography
    core/                       # shared code used by every feature
      models/                   # shared data models (e.g. Ingredient)
      repositories/             # shared repository interfaces
    features/
      accounts/                 # Owner: Hetal — auth & preferences
      ingredients/              # Owner: Joël  — capture & recommendations
      recipes/                  # Owner: Newton — authoring & community
```

## The pattern (copy this per feature)

Each feature uses three layers:

- `data/` — repository **interface** + implementation (start with a stub).
- `application/` — Riverpod providers (state + wiring).
- `presentation/` — widgets/screens that `ref.watch(...)` the providers.

The `ingredients` feature is a worked example:

- `data/ingredient_repository.dart` — `IngredientRepository` interface +
  `StubIngredientRepository`; `supabase_ingredient_repository.dart` is the
  real implementation, and `photo_picker.dart` wraps the camera and photo
  library behind a `PhotoPicker` interface.
- `application/ingredient_providers.dart` — providers choosing those
  implementations; `ingredient_scan_controller.dart` — a `Notifier` holding
  the editable ingredient list and the state of the current scan.
- `presentation/ingredients_screen.dart` — a `ConsumerStatefulWidget` that
  watches the controller and renders each scan state: analyzing, found,
  nothing found, failed with retry, and permission denied.

## Ingredient recognition

Photos never go straight from the app to the vision model. The app sends a
resized photo to the `detect-ingredients` Supabase Edge Function
(`supabase/functions/detect-ingredients/`), which asks Google Gemini for the
ingredients and returns their names:

- The Gemini API key is an Edge Function secret, never in the app.
- Only signed-in users can call the function: the platform's JWT check (on by
  default; don't deploy with `--no-verify-jwt`) rejects other requests.
- Photos are not stored by the function or by Gemini (`store: false`).
- `gemini.ts` is the only provider-specific file. Swapping models or
  providers doesn't touch the app.

Deploying needs access to the team Supabase project and a key from
[Google AI Studio](https://aistudio.google.com/apikey):

```bash
supabase secrets set GEMINI_API_KEY=<key> --project-ref wlopsesyhmfcuwxoesja
supabase functions deploy detect-ingredients --project-ref wlopsesyhmfcuwxoesja --use-api
```

The model defaults to `gemini-3.5-flash-lite`; set a `GEMINI_MODEL` secret to
change it. Run the function's tests with
`deno test supabase/functions/detect-ingredients`. To try the app without the
function, run `flutter run --dart-define=STUB_DETECTION=true`, which returns
the same few ingredients for any photo.

## Rules of thumb

- UI depends on **interfaces**, never on a concrete data source. Swap the stub
  for Firebase later without touching screens.
- Shared types go in `core/`; feature-specific types stay in the feature.
- Keep providers small and testable; override them in tests with fakes.
