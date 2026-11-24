# Local build verification — November 23, 2026

Verified with the team's pinned Flutter **3.47.8 / Dart 3.13.7**. The official
Windows SDK archive was checked against its release-manifest SHA-256 before use.
SDK and package cache are local in ignored `tmp/`; no global PATH change is needed.

Repairs: one feature-shell entrypoint with startup failure handling; one Supabase
dependency; corrected malformed/duplicate lockfile blocks; resolved README
conflict; restored a coherent smoke test; fixed lints and recipe-test scrolling.
The editor keeps its fields mounted while scrolling so validation covers the
entire recipe. Existing account UI/assets remain in the source tree.

Completed checks:

- `flutter pub get`: success, existing locked dependency versions retained.
- `dart format lib test`: source formatted with the pinned SDK.
- `flutter analyze --no-pub`: no issues.
- `flutter test --no-pub`: **53 passed**, including accounts, ingredients and recipes.
- `flutter build bundle --debug --no-pub --target-platform=android-arm64`: success.
  Produced `build/flutter_assets/kernel_blob.bin` and the asset bundle. This is
  Dart code/assets compilation, **not** an installable Android APK/AAB or iOS IPA.
- `node supabase/tests/database.test.mjs`: passed locally, including profile
  preservation and two-user recipe access rules.

Rerun from this workspace's PowerShell:

```powershell
./scripts/flutter.ps1 analyze --no-pub
./scripts/flutter.ps1 test --no-pub
./scripts/flutter.ps1 build bundle --debug --no-pub --target-platform=android-arm64
```

The helper uses the portable SDK and scopes its Git ownership exception and
package-cache environment to the invoked process. On another machine, install
Flutter 3.47.8 and use standard `flutter` commands; the ignored SDK isn't in git.
Format `lib test` rather than scanning the SDK inside `tmp/`.

No shared Supabase schema, data, grants, functions, secrets or storage were
modified. Tests use local/fake backends. The default build configuration still
points at the team's existing project; running the app and interacting with it
would use that project unless build-time configuration is overridden.

Remaining: deploy/test recipe backend changes in an agreed development environment;
integrate recommendation results and account-deletion UI; test real camera/photos
and hosted permissions; use Mac/Xcode signing for an installable iPhone build.
No iPhone build or device run was performed on Windows. The browser tester stays
removed. The existing merge conflict is resolved, but no merge commit or push was
made as part of these repairs.
