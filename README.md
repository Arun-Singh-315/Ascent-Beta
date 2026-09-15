# Ascent - Job Prep Companion App

> **Your personal job-search operating system.**  
> A calm, local-first, empathetic mobile application designed to turn job preparation and interview hunting into a structured, stress-free engineering practice.

---

## 📖 Complete V1 Specifications & Design System Handoff

For external developers, contributors, and team members building new **V1** features, refer to the master specification:

👉 **[ASCENT_V1_SPECIFICATION_HANDOFF.md](./ASCENT_V1_SPECIFICATION_HANDOFF.md)**

This document details:
- **Design Tokens & Theme:** Full hex color codes (Light & Dark modes), font scale (`Plus Jakarta Sans`, `Inter`, `JetBrains Mono`), corner radii, and elevation.
- **Component Catalog:** Standard widgets (`AscentCard`, `AscentButton`, `MainScaffold`, `AscentDrawer`, `EmptyState`, `SkeletonShimmer`, `UndoSnackbar`).
- **Complete Screen Directory:** UX flows, states, and interactive specifications for all 15+ screens.
- **Database Schema & Drift DAOs:** 12 tables, relations, and Riverpod stream providers.
- **On-Device Intelligence:** `InsightEngine` and `SeriesEngine` velocity math.
- **Developer Guardrails:** Non-negotiable rules to ensure new v1 features do not regress or alter default aesthetics or data integrity.

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

# 2. Run code generation (Drift & Riverpod)
dart run build_runner build --delete-conflicting-outputs

# 3. Analyze codebase
flutter analyze

# 4. Run on connected device
flutter run
```

