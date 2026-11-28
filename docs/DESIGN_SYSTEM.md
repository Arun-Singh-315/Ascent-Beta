# Ascent design system

Reviewed 20 November 2026. **The rules themselves live in [CLAUDE.md](../CLAUDE.md)** (§1 user ease, §3 visual language, §5 hero surfaces, §6 component contracts). This page only maps those rules to the code, so there is one definition and no drift.

## Where each rule is implemented

| Rule (CLAUDE.md) | Code |
|---|---|
| §3.1 Color roles | `lib/app/theme/color_tokens.dart` (`AscentColors`, `context.*` getters), `lib/core/theme/app_colors.dart` (`AppColors` ThemeExtension), the one palette in `calm_blue_palette.dart`, applied by `glass_theme.dart` |
| §3.1 Shared control colors | `lib/app/theme/shared_control_tokens.dart` |
| §3.2 Typography | `lib/app/theme/text_styles.dart` (`AscentTextStyles`, `AppTypeRoles`) |
| §3.3 Shape and space | `lib/app/theme/dimension_tokens.dart`, `surface_tokens.dart` (`AppSpace`, `AppGeometry`, `AppBorderScale`) |
| §3.4 Materials | `shared/widgets/glass_surface.dart` (chrome), `shared/widgets/opaque_overlay_surface.dart` (overlays) |
| §3.5 Motion | `shared/widgets/ascent_press_feedback.dart`, `features/home/widgets/home_reveal.dart` |
| §5.1 Home header scenes | `features/home/widgets/home_header.dart`, `home_header_scene.dart`, `home_header_landscape.dart` |
| §6.1 Empty states | `shared/widgets/empty_state.dart` (`EmptyState`, `EmptyState.inline`, `EmptyStarter`) |
| §6.3 Buttons | `shared/widgets/ascent_button.dart` |
| §6.4 Cards | `shared/widgets/ascent_card.dart`, `app_surfaces.dart` |
| §6.5 Inputs | `shared/widgets/app_text_field.dart`, `app_composer.dart` |
| §6.6 Sheets/dialogs | `shared/widgets/ascent_sheet.dart`, `ascent_dialog.dart`, `ascent_popup_menu.dart`, `undo_snackbar.dart` |

## Migration status (November 2026 audit)

The rules changed to the Apple-premium personal-OS language on 20 November 2026. The code is being migrated in batches; known gaps:

- ~440 inline `Color(0x…)` and ~210 `Colors.*` uses in feature code (largest: onboarding, assistant screen, vault card art, plan creator, Home header).
- 128 `OutlineInputBorder` uses that must move to `AppTextField`.
- Raw Material overlays (`showModalBottomSheet`, `AlertDialog`, `SnackBar`, `PopupMenuButton`, `DropdownButton`) that must move to the shared wrappers.
- Fonts: since 28 November 2026 every interface style renders in Inter (thoughts in Newsreader), both bundled offline. Older `AscentTextStyles` names still exist and move to the 14 Day Page roles screen by screen.
- Colours: new code reads `context.tokens` (`AscentTokens`). Home has no raw colours; other features migrate as they are touched.
- Hardcoded assistant names in about 10 files to move to the configured name.

When you touch a file, bring it to the rules. Don't add new violations.
