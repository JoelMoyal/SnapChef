# Contributing to SnapChef

Thanks for helping build SnapChef! This guide covers how to get set up and the workflow we follow so everyone can push smoothly.

## Getting set up

1. Install the [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel).
2. Clone the repo and fetch dependencies:
   ```bash
   git clone https://github.com/JoelMoyal/SnapChef.git
   cd SnapChef
   flutter pub get
   ```
3. Run `flutter doctor` and resolve any reported issues.

## Branching & workflow

- `main` is the default branch and should always build and pass CI.
- Create a feature branch off `main`:
  ```bash
  git checkout -b feat/<short-description>
  ```
- Suggested branch prefixes: `feat/`, `fix/`, `chore/`, `docs/`, `refactor/`, `test/`.
- Keep commits focused. Use clear, imperative commit messages (e.g. `Add ingredient capture screen`).

## Before you open a PR

Run these locally — CI runs the same checks and will block merge if they fail:

```bash
dart format --set-exit-if-changed .   # formatting
flutter analyze                        # static analysis (must be clean)
flutter test                           # tests must pass
```

## Pull requests

1. Push your branch and open a PR against `main`.
2. Fill out the PR template.
3. Make sure CI is green.
4. Request a review (see [CODEOWNERS](.github/CODEOWNERS)).
5. Squash or keep a tidy history on merge.

## Code style

- Follow the lints in [`analysis_options.yaml`](analysis_options.yaml) (Flutter's recommended set).
- Format with `dart format .` — no unformatted code in PRs.
- Prefer small widgets and clear names over cleverness.

## Reporting bugs / requesting features

Open an issue using the appropriate template under **Issues → New issue**.

Happy cooking! 🍳
