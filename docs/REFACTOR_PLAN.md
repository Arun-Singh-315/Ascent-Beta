# Ascent — Phased Refactor & Implementation Plan

**Target:** Production-Ready Pre-Release Standardization  
**Location:** `docs/REFACTOR_PLAN.md`

---

## Phase A: Baseline & Pre-Release Audit (Completed)
- [x] Comprehensive inspection of all screens, routes, providers, DAOs, and third-party packages.
- [x] Ran static analysis (`dart analyze`) and test suite (`flutter test`) — 223/223 tests passing.
- [x] Documented consistency matrix, component catalog, feature inventory, design rulebook, and architecture specification.
- [x] Established dedicated feature branch: `feature/pre-release-audit-and-standardization`.

---

## Phase B: Centralized Design System Foundation
**Objective:** Create authoritative design tokens and missing reusable UI components so that consistency becomes automatic.
- **Affected Files:**
  - `lib/app/theme/dimension_tokens.dart` (New: standard radii, spacing, heights)
  - `lib/app/theme/text_styles.dart` (Consolidate typography scale into single 3-font system)
  - `lib/app/theme/color_tokens.dart` (Verify semantic surface & border tokens)
  - `lib/shared/widgets/ascent_card.dart` (Add `.glass`, `.solid`, `.elevated`, `.outlined` variants)
  - `lib/shared/widgets/ascent_text_field.dart` (New: centralized text input widget)
  - `lib/shared/widgets/ascent_bottom_sheet.dart` (New: centralized modal bottom sheet helper)
  - `lib/shared/widgets/ascent_dialog.dart` (New: centralized confirmation & alert dialog helper)
  - `lib/shared/widgets/ascent_snack_bar.dart` (New: centralized floating snackbar utility)
- **Acceptance Criteria:**
  - All shared UI primitives exist, compile cleanly, and support both Day and Night modes.
  - Test cases added to verify component behavior in both themes.

---

## Phase C: Global UI Consistency & Redundant Control Cleanup
**Objective:** Migrate secondary screens to `AscentScaffold` and eliminate unnecessary UI.
- **Affected Files:**
  - `lib/features/thought_wall/thought_wall_screen.dart` (Remove redundant AppBar action; keep single bottom composer)
  - `lib/features/pipeline/pipeline_screen.dart` & `card_detail_screen.dart` (Migrate to `AscentScaffold`)
  - `lib/features/dsa/dsa_screen.dart` (Migrate to `AscentScaffold`)
  - `lib/features/interview_prep/interview_prep_screen.dart` (Migrate to `AscentScaffold`)
  - `lib/features/resume_vault/resume_vault_screen.dart` (Migrate to `AscentScaffold`)
  - `lib/features/consistency/consistency_screen.dart` (Migrate to `AscentScaffold`)
  - `lib/features/analytics/analytics_screen.dart` & `series_report_card_screen.dart` (Migrate to `AscentScaffold`)
  - `lib/features/book_reader/kindle_book_reader_screen.dart` (Migrate to `AscentScaffold`)
  - Purge dead AI bot widgets: delete `jarvis_copilot_card.dart`, `jarvis_omnibar.dart`, `riya_floating_gateway.dart`.
- **Acceptance Criteria:**
  - 100% of screens use `AscentScaffold` with consistent atmospheric backdrops and tactile back navigation.
  - Zero redundant input buttons on Thought Wall.
  - Unused bot code completely removed.

---

## Phase D: Complete Momentum Feature Retirement
**Objective:** Completely retire the obsolete Momentum implementation while preserving the Tab 3 navigation entry with a polished Coming Soon screen.
- **Affected Files:**
  - Remove `lib/features/momentum/momentum_screen.dart`
  - Remove `lib/features/momentum/momentum_onboarding_screen.dart`
  - Remove `lib/core/momentum/momentum_plan_generator.dart`
  - Remove `lib/core/momentum/momentum_service.dart`
  - Remove obsolete tests: `test/momentum_challenge_test.dart`, `test/momentum_executive_redesign_test.dart`, `test/momentum_ui_polish_test.dart`
  - Create `MomentumComingSoonScreen` in `lib/features/momentum/momentum_coming_soon_screen.dart` (or `momentum_screen.dart`)
  - Update `lib/features/home/widgets/quick_modules_nav_hub.dart`: Remove `_buildMomentumProgressCell`; rebalance Life & Health card with Medicine, Hydration, and Chai Break.
  - Update `lib/main.dart` and `lib/core/notifications/notification_service.dart`: Rename `scheduleDailyMomentumGuardianNudges` to `scheduleDailyStreakGuardianNudges`.
  - Update router: preserve `/momentum` routing to `MomentumComingSoonScreen`, remove obsolete onboarding subroutes.
- **Acceptance Criteria:**
  - Tapping Momentum Tab 3 displays a clean, premium Coming Soon screen.
  - No active Momentum timers, background tasks, or onboarding flows can be triggered.
  - Unrelated features (Walk, Chai Break, Focus, Medicine, Hydration) remain 100% operational.

---

## Phase E: Architecture Simplification & Dependency Cleanup
**Objective:** Clean up unused dependencies and dead repository wrappers.
- **Affected Files:**
  - `pubspec.yaml`: Remove `motor`, `heroine`, and `flutter_confetti`.
  - Delete `lib/core/repository/local/` (dead repository pass-through classes) and `lib/core/repository/repository_interface.dart`.
  - Update `lib/core/providers/database_provider.dart`: Clean up obsolete repository providers.
  - Unify streak calculations so Home and Consistency screens share the single source of truth.
- **Acceptance Criteria:**
  - `flutter pub get` completes cleanly without unused packages.
  - No dead repository code left in `lib/core/`.
  - Zero compilation warnings or lint errors.

---

## Phase F: Feature-Value Polish & Verification
**Objective:** Verify release readiness across performance, themes, and reliability.
- **Verification Steps:**
  - Format and analyze: `dart analyze` — must report 0 issues.
  - Execute automated tests: `flutter test` — all test suites must pass 100% green.
  - Verify day and night mode rendering across all major screens.
  - Produce final verification report (`Report 8`).
