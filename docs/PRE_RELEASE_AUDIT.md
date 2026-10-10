# Ascent — Pre-Release Product & Quality Audit

**Version:** 1.0.2+3  
**Date:** October 2026  
**Auditor:** Principal Software Architect & Pre-Release Quality Auditor  
**Status:** In Progress (Feature Branch: `feature/pre-release-audit-and-standardization`)

---

## 1. Executive Summary

Ascent is a comprehensive, on-device job-search operating system and life companion built with Flutter, Riverpod, and Drift SQLite. It combines deep productivity (tasks, timed study focus, course syllabus player, DSA problem logging, job application pipeline, resume vault) with life mindfulness (guided Chai breaks, hydration, medicine compliance, walking GPS tracker, self-talk Thought Wall, and an on-device AI assistant).

The application boasts exceptional core stability (all 223 automated unit and widget tests passing out of the box), responsive local-first SQLite persistence, and rich atmospheric aesthetics. However, as it approaches its first public release, the codebase exhibits critical architectural bifurcations and inconsistencies:

1. **Two Co-existing Design Architectures:**
   - Modern "Redesigned" screens (Home, Reminders, Money, Thought Wall, Chai Break, Walk, Focus) leverage `AscentScaffold`, `AscentGlass`, `AscentCard`, and `AscentAtmosphereBackground`.
   - Secondary screens (Pipeline, Card Detail, Interview Prep, Resume Vault, DSA Problem Tracker, Consistency Tracker, Analytics, Series Report, Kindle Book Reader) still use vanilla `Scaffold`, raw Material `AppBar`, basic `Card`, and manual back navigation buttons, creating a noticeable visual and tactile disparity.
2. **Typography System Duplication:**
   - Two typography scale systems run concurrently in `lib/app/theme/text_styles.dart`: (a) Plus Jakarta Sans + Inter + JetBrains Mono, and (b) Bricolage Grotesque + DM Sans.
3. **Component Re-invention & Missing Abstractions:**
   - Over 40 calls to `showModalBottomSheet` each re-implement custom drag handles, border radii, padding, and background colors.
   - 15+ calls to `showDialog` re-implement custom `AlertDialog` widgets with ad-hoc button styling.
   - 70+ calls to `showSnackBar` lack standardized presentation or theming.
   - Text inputs (`TextField`) vary from zero-border custom pill containers to standard Material `InputDecoration` to hardcoded border outlines.
4. **Hardcoded Color Constants in Features:**
   - 23 feature files contain hardcoded `Color(0x...)` values rather than resolving semantic tokens through `AscentColorsX` or `AscentGlassX`. This creates contrast risks in Day (Light) Mode.
5. **Redundant Controls & Dead Code:**
   - **Thought Wall:** Features a bottom chat composer with reflection prompt shortcut, PLUS an AppBar button opening the exact same prompt sheet.
   - **Dead AI Code:** `JarvisCopilotCard`, `JarvisOmnibar`, and `RiyaFloatingGateway` sit unreferenced in `lib/shared/widgets/` and `lib/features/home/widgets/`.
   - **Unused Dependencies:** `motor: ^1.1.0`, `heroine: ^0.7.2`, and `flutter_confetti: ^0.9.2` are declared in `pubspec.yaml` with zero project imports.
   - **Dead Repository Layer:** 5 repository pass-through classes in `lib/core/repository/local/` are bypassed in favor of direct Drift DAOs across all screens and tests.
6. **State Duplication & Dual Sources of Truth:**
   - Daily streaks are tracked by both `studyStreakProvider` and `ConsistencyDao` (`currentStreakStreamProvider`), causing visual discrepancies between Home and Consistency Tracker screens.
7. **Momentum Feature Scope:**
   - The current 30-day Momentum protocol is planned for total retirement and replacement with a polished Coming Soon screen.

---

## 2. Consistency Matrix

| Component / Pattern | Where It Appears | Current Implementations | Inconsistency or Defect | Proposed Standard | Priority |
|---|---|---|---|---|---|
| **Page Scaffolding & Atmosphere** | Application-wide (25 screens) | `AscentScaffold` in 14 screens; standard `Scaffold` + `AppBar` in 11 screens | Visual & behavioral inconsistency: secondary screens lack atmospheric backdrop, liquid glass app bars, and unified back pill buttons | Migrate all subpages and screens to `AscentScaffold` | **P0 (Blocker)** |
| **Typography Scale** | App-wide | `text_styles.dart` defines two conflicting font scales: Jakarta/Inter vs Bricolage/DM Sans | Visual inconsistency: inconsistent font weights, line heights, and hierarchy across screens | Consolidate into a single authoritative design system type scale | **P0 (Blocker)** |
| **Modal Bottom Sheets** | 40+ call sites across features | Inline `showModalBottomSheet` with custom decorations, manual drag handles, conflicting radii (20px vs 24px) | Duplicated implementation; inconsistent drag handle and background transparency | Centralize into `AscentBottomSheet.show(...)` with standardized drag handle, sheet radius (24px), and padding | **P1 (High)** |
| **Dialogs & Confirmations** | 15+ call sites across features | Raw `showDialog` + `AlertDialog` with custom button styles, shapes, and colors | Behavioral & visual inconsistency; danger dialogs look different from session completion dialogs | Standardize via `AscentDialog.confirm(...)` and `AscentDialog.alert(...)` using `AscentButton` variants | **P1 (High)** |
| **Text Inputs & Form Fields** | 40+ call sites across feature sheets & screens | Raw `TextField` with custom decoration: some borderless pills, some `InputDecoration`, some `OutlineInputBorder` | Visual inconsistency; missing unified focus state, label hierarchy, and error presentation | Centralize into `AscentTextField` supporting standard, search, pill, and numeric modes | **P1 (High)** |
| **Snackbars & Notifications** | 70+ call sites | Inline `ScaffoldMessenger.of(context).showSnackBar` with manual durations and backgrounds | Inconsistent floating behavior, colors, and dismiss timing | Standardize into `AscentSnackBar.show(...)` with success, error, info, and undo presets | **P1 (High)** |
| **Surface Cards & Glass** | App-wide | `AscentCard` (radius 16, no blur), `GlassSurface` (radius 24, 22px blur), raw `Container` decorations | Duplicated card abstractions; arbitrary corner radii (8, 10, 12, 14, 16, 20, 24px) | Consolidate `AscentCard` with explicit variants: `.glass`, `.solid`, `.outlined`, `.elevated` | **P1 (High)** |
| **Hardcoded Color Constants** | 23 feature files | `Color(0x...)` constants scattered across widgets | Theme switching defect: dark hex colors appear on light backgrounds, breaking Day Mode contrast | Replace all raw hex literals with `context.glass` or `context.*` semantic tokens | **P1 (High)** |
| **Thought Wall Input Redundancy** | `lib/features/thought_wall/` | Bottom chat composer with prompt icon PLUS top AppBar action button opening same `DropThoughtSheet` | Unnecessary UI: duplicate entry points for adding thoughts | Remove redundant AppBar button; keep the bottom composer as the single source of truth | **P1 (High)** |
| **Unreferenced AI Bot Widgets** | `lib/shared/widgets/`, `lib/features/home/` | `JarvisCopilotCard`, `JarvisOmnibar`, `RiyaFloatingGateway` | Dead code: defined but unimported and unreferenced in active screens | Purge dead AI widgets; preserve centralized `/ai-assistant` screen and HomeHeader gateway | **P1 (High)** |
| **Streak Source of Truth** | Home, Header, Consistency Tracker | `studyStreakProvider` vs `consistencyDaoProvider.watchCurrentStreak()` | Functional inconsistency: streak counts can drift between Home and Consistency Tracker | Unify into single authoritative streak calculation engine | **P1 (High)** |
| **Momentum Feature Retirement** | Tab 3, Home Hub, Core services | Full 30-day challenge generator, models, DAOs, screens, onboarding | Explicit user request to retire current Momentum and replace with Coming Soon placeholder | Retire feature code, install `MomentumComingSoonScreen`, clean Home cell and notification methods | **P0 (Blocker)** |
| **Unused Dependencies** | `pubspec.yaml` | `motor`, `heroine`, `flutter_confetti` | Unnecessary dependencies: zero references across entire codebase | Remove from `pubspec.yaml` to reduce bundle overhead and supply-chain complexity | **P2 (Medium)** |
| **Unused Repository Layer** | `lib/core/repository/local/` | 5 repository classes | Incomplete abstraction: 100% bypassed by all features and tests in favor of direct DAOs | Purge unused repository pass-through files | **P2 (Medium)** |

---

## 3. Visual & Theming Audit

### 3.1 Light vs. Dark Mode Contrast
- **Dark Mode (Night):** High contrast, deep obsidian base (`#0D1016` / `#0F1216`), glowing atmospheric ambient nodes (coral/clay `#D6785C` and slate `#5C72BE`), clear typography contrast with `#ECEAF2`.
- **Light Mode (Day):** Clean off-white base (`#F4F3F8` / `#F8F9FA`), terracotta clay (`#A4523A`), slate blue (`#4A68B0`), deep ink text (`#1B1E2B`).
- **Defects Identified:**
  - 23 feature files hardcode dark-mode specific colors (`Color(0xFF1E222D)`, `Color(0xFF151A28)`) inside containers, chips, and borders. When switched to Light Mode, these widgets render dark patches with unreadable text.
  - Secondary screens using standard Material `AppBar` have flat backgrounds that do not match the subtle ambient gradients of the Home and Focus screens.

### 3.2 Glassmorphism & Surface Contrast Policy
- **Liquid Glass Philosophy:** Glass is reserved for interactive cards, floating app bars, bottom navigation, and modal sheets. Primary content (long text, form inputs) must sit on high-contrast surfaces (`context.bgSurface` or `g.fill`) with clear borders (`g.edge`).
- **BackdropFilter Policy:** Continuous background blur (`BackdropFilter(sigma: 22)`) must only be used on static or floating overlays with `RepaintBoundary` wrappers to prevent 60fps frame drops on budget Android devices.

---

## 4. Engineering Quality & Baseline Verification

- **Automated Tests:** 223 passed, 0 failed.
- **Static Analysis:**
  - 2 warnings: unused element `_quickPrompts` in `ai_assistant_screen.dart`, unused import `hydration_popup_dialog.dart` in `hydration_screen.dart`.
  - 1 info: `prefer_final_fields` in `thought_wall_screen.dart`.
- **Git Branch:** Verified on dedicated feature branch `feature/pre-release-audit-and-standardization`.
