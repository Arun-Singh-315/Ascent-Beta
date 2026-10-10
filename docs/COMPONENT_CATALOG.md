# Ascent — Reusable Component Catalog

**Version:** 1.0.2+3  
**Status:** Audit & Standardization Catalog

---

## 1. Master Component Catalog

| Component Name | File Path | Purpose | Supported Variants | Theme-Aware Properties | Status & Recommendation |
|---|---|---|---|---|---|
| **`AscentScaffold`** | `lib/shared/widgets/ascent_scaffold.dart` | Signature page scaffold with stationary atmospheric glow and frosted liquid glass app bar | Standard, full-screen, custom glows, custom leading/actions | Background (`g.bg`), glow nodes (`g.glow1`, `g.glow2`), glass app bar (`g.fill`, `g.edge`) | **Retain & Enforce:** Standardize across 100% of screens. Migrate remaining 11 vanilla `Scaffold` screens. |
| **`AscentAppBar`** | `lib/shared/widgets/ascent_scaffold.dart` | Frosted liquid glass header bar with circular tactile back button and subtitle | Standard, custom title widget, tab bar bottom | Translucent surface (`g.bg.withValues(alpha: 0.85)`), ink text (`g.ink`), edge border | **Retain:** Included in `AscentScaffold`. Standardize toolbar height and title typography. |
| **`AscentButton`** | `lib/shared/widgets/ascent_button.dart` | Unified button design covering all action archetypes | `primary`, `secondary`, `outlined`, `ghost`, `icon`, `fab`, `destructive` | Uses `context.accentPrimary`, `accentSecondary`, `stateDanger`, `g.fill`, `g.edge`, `context.isDark` | **Retain & Enforce:** High quality, comprehensive variant set. Replace all ad-hoc `ElevatedButton` and `TextButton` calls. |
| **`AscentCard`** | `lib/shared/widgets/ascent_card.dart` | Surface card with calm translucent fill, subtle 0.9px border, and tactile ink ripple | Default (radius 16, no blur), tappable with haptics, custom color | `g.fill`, `g.edge`, `g.shadow` | **Retain & Consolidate:** Add explicit variants (`.glass`, `.solid`, `.outlined`, `.elevated`). Consolidate with `GlassSurface`. |
| **`GlassSurface`** | `lib/shared/widgets/glass_surface.dart` | Translucent glass container with 22px BackdropFilter blur, 24px radius, 1px border | Default (radius 24, 22px blur), tappable, non-blur toggle | `g.fill`, `g.edge`, `g.shadow` | **Consolidate:** Merge into `AscentCard.glass` to eliminate redundant card abstractions. |
| **`AscentAtmosphereBackground`** | `lib/shared/widgets/ascent_atmosphere.dart` | CustomPainter rendering dual soft radial ambient color glows | Custom glows (`glow1`, `glow2`), home variant | Softens solid colors automatically to ambient alpha thresholds | **Retain:** Core visual signature. Already wrapped cleanly inside `AscentScaffold`. |
| **`AscentDrawer`** | `lib/shared/widgets/ascent_drawer.dart` | Navigation drawer with categorized tool links and active route highlighting | Default | Translucent surface, dark/light theme aware, divider border | **Retain:** Central drawer accessible from MainScaffold. |
| **`EmptyState`** | `lib/shared/widgets/empty_state.dart` | Standardized placeholder for empty lists, search results, and unconfigured states | Default with icon, title, description, optional action CTA | `g.ink`, `g.inkMuted`, `g.fill` | **Retain & Enforce:** Use across all lists when data is empty. |
| **`SkeletonShimmer`** | `lib/shared/widgets/skeleton_shimmer.dart` | Skeleton loading placeholder with subtle shimmer animation | Custom height, width, radius | Theme-aware base and highlight colors | **Retain:** Standard loading state across all data streams. |
| **`LiveSessionBar`** | `lib/shared/widgets/live_session_bar.dart` | Persistent live ticking bar for active study, walk, or lecture timers | Walk tracking, study focus, lecture player | Dynamic category accent tint, pulse animation, dismissible | **Retain:** Core multitasking element above bottom nav. |
| **`ChatBubbleCard`** | `lib/shared/widgets/chat_bubble_card.dart` | Message and activity card with optional comic tail and pulsing glow | Tail position (bottomLeft, none), pulsing toggle | Accent tint, translucent background | **Retain:** Used in Thought Wall, AI Assistant, and LiveSessionBar. |
| **`UndoSnackBar`** | `lib/shared/widgets/undo_snackbar.dart` | Floating snackbar with action button for reversible operations | Default | `context.isDark`, floating behavior | **Consolidate:** Expand into comprehensive `AscentSnackBar` utility (`.show`, `.error`, `.success`, `.undo`). |
| **`NewDayDialog`** | `lib/shared/widgets/new_day_dialog.dart` | Midnight day-transition prompt prompting new daily targets | Modal dialog | Theme-aware container, button styling | **Retain:** Handles day-change lifecycle cleanly. |
| **`JarvisCopilotCard`** | `lib/shared/widgets/jarvis_copilot_card.dart` | Persistent copilot card with prompt chips | Single implementation | Hardcoded colors, unimported | **PURGE (Dead Code):** Completely unreferenced across all screens. |
| **`JarvisOmnibar`** | `lib/shared/widgets/jarvis_omnibar.dart` | Universal omnibar search input for AI assistant | Single implementation | Hardcoded colors, unimported | **PURGE (Dead Code):** Completely unreferenced across all screens. |
| **`RiyaFloatingGateway`** | `lib/features/home/widgets/riya_floating_gateway.dart` | Floating pill button linking to `/ai-assistant` | Single implementation | Floating shadow, gradient fill | **PURGE (Dead Code):** Replaced by header gateway pill in `HomeHeader`. Unreferenced anywhere in project. |

---

## 2. Missing Core Abstractions to Create

To make consistency the default rather than something developers must remember manually, the following centralized components must be established in `lib/shared/widgets/`:

1. **`AscentBottomSheet` (`lib/shared/widgets/ascent_bottom_sheet.dart`):**
   - Centralized modal sheet launcher wrapping `showModalBottomSheet`.
   - Automatically handles: standard 24px top radius, drag handle, `context.bgSurface` background, edge border, keyboard insets (`viewInsets.bottom`), and 90% screen height constraints.
2. **`AscentDialog` (`lib/shared/widgets/ascent_dialog.dart`):**
   - Standardized dialog launcher for confirmations, alerts, and destructive actions.
   - Built with `AscentButton` controls, 20px radius, theme-aware background, and tactile haptics.
3. **`AscentTextField` (`lib/shared/widgets/ascent_text_field.dart`):**
   - Standardized text input supporting: standard form field, search input, numeric input, and chat pill input.
   - Eliminates 40+ ad-hoc `InputDecoration` and `OutlineInputBorder` definitions.
4. **`AscentSnackBar` (`lib/shared/widgets/ascent_snack_bar.dart`):**
   - Standardized floating toast helper: `AscentSnackBar.success()`, `AscentSnackBar.error()`, `AscentSnackBar.info()`, `AscentSnackBar.undo()`.
