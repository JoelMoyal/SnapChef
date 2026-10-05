# SnapChef 📸🍳

Snap a photo of the ingredients you have on hand and get recipe suggestions you can actually make. SnapChef is a cross-platform **Flutter** app (iOS + Android).

> **Status:** early scaffold. The AI/vision layer is currently stubbed — the app runs end-to-end with mock data while the real recognition + recipe engine is wired up.

---

## ✨ What it does (planned)

1. **Snap** a photo of your ingredients (or pick one from your gallery).
2. SnapChef **detects** the ingredients (stubbed for now).
3. You get a list of **recipe suggestions** you can cook with what you have.

## 🛠 Tech stack

| Area | Choice |
|------|--------|
| Framework | Flutter (stable channel) |
| Language | Dart (`sdk: ^3.13.3`) |
| Platforms | iOS, Android |
| AI/vision | Stubbed (mock service) — real engine TBD |

## 🚀 Getting started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (stable channel)
- Xcode (for iOS) and/or Android Studio + SDK (for Android)
- Run `flutter doctor` and resolve any issues before building.

### Setup

```bash
git clone https://github.com/JoelMoyal/SnapChef.git
cd SnapChef
flutter pub get
```

### Run

```bash
flutter run                 # runs on a connected device / simulator
flutter run -d ios          # force iOS
flutter run -d android      # force Android
```

### Common commands

```bash
flutter analyze             # static analysis (must be clean)
dart format .               # format code
flutter test                # run tests
flutter build apk           # Android release build
flutter build ios           # iOS release build
```

## 📁 Project structure

```
lib/            # Dart application code
test/           # Widget & unit tests
android/        # Android host project
ios/            # iOS host project
.github/        # CI, issue/PR templates, CODEOWNERS, Dependabot
```

## 🤝 Contributing

Please read [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. In short: branch off `main`, keep `flutter analyze` clean, format with `dart format`, and open a PR — CI will run analyze + tests automatically.

## 📄 License

[MIT](LICENSE) © Joel Moyal
