# Ascent — Centralized Design System Rulebook

**Version:** 1.0  
**Authority:** Official Ascent Pre-Release Design Specification  
**Location:** `docs/DESIGN_SYSTEM.md`

---

## 1. Design Philosophy: Liquid Glass & Grounded Minimalism

Ascent is designed for sustained focus, deep work, and calm clarity. The visual language combines **Liquid Glass** (subtle, translucent surfaces over deep obsidian or clean matte off-white backgrounds) with **restrained editorial typography** and **crisp harmonic accents**.

### Non-Negotiable Rules
1. **Never hardcode hex colors** (`Color(0xFF...)`) in screen or widget code. All colors must resolve from semantic tokens via `context.glass` or `context.*` (`AscentColorsX`).
2. **Every screen must use `AscentScaffold`**. No screen may instantiate raw `Scaffold` or raw `AppBar` unless it is a full-screen media/camera capture view.
3. **No ad-hoc modal bottom sheets**. Every modal sheet must be presented using `AscentBottomSheet.show(...)`.
4. **No raw Alert dialogs**. Use `AscentDialog.confirm(...)` or `AscentDialog.info(...)`.
5. **No raw snackbars**. Use `AscentSnackBar.success(...)`, `AscentSnackBar.error(...)`, or `AscentSnackBar.info(...)`.
6. **Every interaction must trigger appropriate tactile feedback** (`HapticFeedback.lightImpact()` for selection/taps, `HapticFeedback.mediumImpact()` for primary saves, `HapticFeedback.heavyImpact()` for deletions).

---

## 2. Color System & Semantic Tokens

### 2.1 Theme Modes
- **Dark Mode (Night):** Deep obsidian graphite (`#0D1016` base, `#181C22` surface, `#222832` elevated).
- **Light Mode (Day):** Crisp matte off-white (`#F4F3F8` base, `#FFFFFF` surface, `#F1F3F6` elevated).

### 2.2 Token Hierarchy & Semantic Roles

| Token | Dark Mode Value | Light Mode Value | Intended Usage |
|---|---|---|---|
| `context.bgBase` | `#0F1216` | `#F8F9FA` | Page scaffold background |
| `context.bgSurface` | `#181C22` | `#FFFFFF` | Solid cards, sheets, inputs |
| `context.bgSurfaceElevated` | `#222832` | `#F1F3F6` | Nested cards, chips, search pills |
| `context.glass.bg` | `#0D1016` | `#F4F3F8` | Liquid glass background |
| `context.glass.fill` | `rgba(255, 255, 255, 0.055)` | `rgba(255, 255, 255, 0.62)` | Frosted cards, app bars, containers |
| `context.glass.edge` | `rgba(255, 255, 255, 0.10)` | `rgba(27, 30, 43, 0.08)` | 1px border around glass containers |
| `context.glass.line` | `rgba(255, 255, 255, 0.09)` | `rgba(27, 30, 43, 0.09)` | Dividers, separators, cell borders |
| `context.accentPrimary` | `#63BA8B` (Sage) | `#38664D` (Forest Sage) | Primary CTA, active focus, completed states |
| `context.glass.clay` | `#E6A088` (Warm Clay) | `#A4523A` (Terracotta) | Brand anchor, Home header, primary chips |
| `context.glass.slate` | `#7E98D6` (Slate) | `#4A68B0` (Navy Slate) | Study, syllabus, academic indicators |
| `context.glass.amber` | `#ECA361` (Amber) | `#B06822` (Honey Amber) | Warnings, pending items, finance |
| `context.glass.coral` | `#E26D66` (Coral) | `#A63B34` (Rose Crimson) | Urgent alerts, destructive actions, Chai break |
| `context.textPrimary` / `g.ink` | `#ECEAF2` | `#1B1E2B` | Primary headings, titles, active text |
| `context.textSecondary` / `g.inkSecondary` | `#B4B7C6` | `#4A4E5F` | Subtitles, descriptions, card copy |
| `context.textMuted` / `g.inkMuted` | `#9094A4` | `#6A6E7E` | Captions, metadata, inactive icons |
| `context.divider` | `#262D37` | `#E5E8ED` | Hairline dividers |

---

## 3. Typography Scale & Font System

The Ascent typography system uses three purposeful font families:
- **Display & Headings:** `Plus Jakarta Sans` — bold, refined, modern geometric display.
- **Body & Labels:** `Inter` — exceptionally readable, balanced, clean neutral grotesque.
- **Numbers & Metrics:** `JetBrains Mono` — monospaced, precise, engineered for timers and stats.

### Standard Type Scale

| Style Name | Font Family | Size | Weight | Line Height | Usage |
|---|---|---|---|---|---|
| `AscentTextStyles.displayLarge` | Plus Jakarta Sans | 28px | Bold (700) | 1.2 | Hero statistics, modal sheet titles |
| `AscentTextStyles.displayMedium` | Plus Jakarta Sans | 22px | SemiBold (600) | 1.25 | Screen headers, major section titles |
| `AscentTextStyles.displaySmall` | Plus Jakarta Sans | 18px | SemiBold (600) | 1.3 | Card titles, dialog headings |
| `AscentTextStyles.headlineMedium`| Plus Jakarta Sans | 17px | SemiBold (600) | 1.3 | Sub-section headers |
| `AscentTextStyles.bodyLarge` | Inter | 16px | Regular (400) | 1.5 | Long-form reading, article copy |
| `AscentTextStyles.bodyMedium` | Inter | 14px | Regular (400) | 1.5 | Primary body text, input values |
| `AscentTextStyles.bodySmall` | Inter | 12px | Regular (400) | 1.4 | Descriptions, helper labels |
| `AscentTextStyles.labelLarge` | Inter | 16px | Medium (500) | 1.3 | Standard button labels |
| `AscentTextStyles.labelMedium` | Inter | 14px | Medium (500) | 1.3 | Compact button labels, tab titles |
| `AscentTextStyles.labelSmall` | Inter | 12px | Medium (500) | 1.3 | Chips, badges, metadata pills |
| `AscentTextStyles.caption` | Inter | 11px | Medium (500) | 1.4 | Uppercase date headers, tracking tags |
| `AscentTextStyles.statLarge` | JetBrains Mono | 28px | Medium (500) | 1.1 | Timers, hero money figures |
| `AscentTextStyles.statMedium` | JetBrains Mono | 22px | Medium (500) | 1.1 | Counters, progress figures |
| `AscentTextStyles.monoCode` | JetBrains Mono | 13px | Bold (700) | 1.2 | Live session durations, timestamps |

---

## 4. Spacing, Shapes & Elevation Scale

### 4.1 Spacing Scale
- **`xs` (4px):** Micro gaps between icon and text.
- **`sm` (8px):** Chip gaps, inter-control spacing.
- **`md` (12px):** Card row gaps, input field internal vertical padding.
- **`lg` (16px):** Standard card padding, standard screen edge margin.
- **`xl` (24px):** Major section spacing, modal bottom sheet padding.
- **`xxl` (32px):** Top-level dashboard level separations.

### 4.2 Corner Radii Scale
- **`Radius.sm` (8px):** Small badges, micro buttons, tag pills.
- **`Radius.md` (12px):** Buttons (`AscentButton`), text fields (`AscentTextField`).
- **`Radius.lg` (16px):** Standard cards (`AscentCard`), list items.
- **`Radius.xl` (20px):** Dialogs (`AscentDialog`), elevated containers.
- **`Radius.xxl` (24px):** Modal bottom sheets (`AscentBottomSheet`), `GlassSurface`.
- **`Radius.full` (999px):** Status chips, search pills, floating avatars.

### 4.3 Component Heights
- **Standard Button:** 44px
- **Compact Button:** 36px
- **Text Field:** 46px (single-line)
- **Bottom Navigation Bar:** 56px + safe area
- **App Bar:** 56px (`kToolbarHeight`)
- **Touch Target Minimum:** 44px × 44px

---

## 5. Standard Component Guidelines

### 5.1 Buttons (`AscentButton`)
- `AscentButton.primary`: Filled forest/sage green. Use for the single primary CTA on a screen or modal.
- `AscentButton.secondary`: Outlined with primary accent. Use for supporting actions.
- `AscentButton.outlined`: Subtle border with neutral ink text. Use for standard dismissal/cancel controls.
- `AscentButton.ghost`: Text-only button for inline actions.
- `AscentButton.icon`: Transparent rounded square with centered icon.
- `AscentButton.fab`: Floating action button with warm terracotta accent.
- `AscentButton.destructive`: Restrained rose crimson button for irreversible deletions.

### 5.2 Cards (`AscentCard`)
- Use `AscentCard` for all grouped content.
- Support variants:
  - `standard` (default): `g.fill`, 0.9px `g.edge` border, 8px diffuse shadow.
  - `glass`: translucent with subtle blur for floating widgets.
  - `elevated`: `context.bgSurfaceElevated` for nested cards.
  - `outlined`: transparent fill with distinct border for list cells.

### 5.3 Modal Bottom Sheets (`AscentBottomSheet`)
- Always launch using `AscentBottomSheet.show(context, title: ..., child: ...)`.
- Automatic features: 24px top radius, centered drag handle (38×4px), `context.bgSurface` background, automatic keyboard inset padding, safe-area compliance.

### 5.4 Dialogs (`AscentDialog`)
- Use `AscentDialog.confirm(context, title: ..., content: ..., onConfirm: ...)` for destructive or state-reset operations.
- Actions: Cancel button (`AscentButton.outlined`), Confirm button (`AscentButton.destructive` or `AscentButton.primary`).

### 5.5 Snackbars (`AscentSnackBar`)
- Floating position, 14px border radius, floating margin (`EdgeInsets.fromLTRB(20, 0, 20, 74)` above bottom navigation).
- Duration: 2.5 seconds standard, 4 seconds for undo actions.

---

## 6. How to Introduce New UI Without Design Drift

When authoring any new screen or feature:
1. Wrap the entire screen in `AscentScaffold(title: ..., body: ...)`.
2. Group content inside `AscentCard(...)`.
3. Use `AscentButton` for all tap interactions.
4. Use `AscentTextField` for all form inputs.
5. Launch secondary creation flows using `AscentBottomSheet.show(...)`.
6. Confirm deletions using `AscentDialog.confirm(...)`.
7. Never define custom `TextStyle(fontSize: ..., color: ...)` inline. Always use `AscentTextStyles.*.copyWith(color: context.textPrimary)`.
