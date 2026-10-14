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
  `StubIngredientRepository`.
- `application/ingredient_providers.dart` — providers exposing the repo and the
  detected ingredients.
- `presentation/ingredients_screen.dart` — a `ConsumerWidget` that watches the
  provider and renders loading / error / data states.

## Rules of thumb

- UI depends on **interfaces**, never on a concrete data source. Swap the stub
  for Firebase later without touching screens.
- Shared types go in `core/`; feature-specific types stay in the feature.
- Keep providers small and testable; override them in tests with fakes.
