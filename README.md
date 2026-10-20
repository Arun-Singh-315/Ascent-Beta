# Ascent - Job Prep Companion App

> **Your personal job-search operating system.**  
> A calm, local-first, empathetic mobile application designed to turn job preparation and interview hunting into a structured, stress-free engineering practice.

Next update planning: [Your Home, Connected Projects](docs/NEXT_UPDATE_PLAN.md) — Home customization first, followed by connections between existing tools.

---

## Documentation

See the [documentation index](docs/README.md) for current architecture, design conventions, components, feature entry points and historical release evidence.

The [Mind Space feedback plan](docs/MIND_SPACE_FEEDBACK_PLAN.md) covers the latest eleven feedback notes and proposed acceptance cases. It is a planning document; those changes have not been implemented yet.

---

## 🛠 Tech Stack

- **Framework:** Flutter (3.29+ / Dart 3.9+)
- **Architecture:** Feature-first layered architecture (UI -> Providers/State -> DAOs -> Database)
- **Local Database:** [Drift](https://drift.simonbinder.eu/) (SQLite with background isolates)
- **State Management:** [Riverpod 3](https://riverpod.dev/) (`flutter_riverpod`, code-generation ready)
- **Navigation:** [GoRouter](https://pub.dev/packages/go_router) with `StatefulShellRoute`
- **Charts & Visualizations:** [fl_chart](https://pub.dev/packages/fl_chart)
- **Local Notifications:** [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications)
- **Document Handling:** [file_picker](https://pub.dev/packages/file_picker) & [path_provider](https://pub.dev/packages/path_provider)

---

## 🚀 Running Locally

```bash
# 1. Fetch dependencies
flutter pub get

# 2. Run code generation (Drift)
dart run build_runner build --delete-conflicting-outputs

# 3. Analyze codebase
flutter analyze

# 4. Run on connected device
flutter run
```


### Device UI checks

Run `./scripts/test_device_qa.sh -d DEVICE_ID` for the daily welcome and existing navigation checks. The script builds the separate `com.arun.ascent.qa` package, uses in-memory records and preferences, and retains the test install for screenshots. It does not replace the normal debug or release app. Avoid running device integration tests against a personal workspace: Flutter's default test cleanup uninstalls the target app.
