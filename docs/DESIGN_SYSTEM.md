# Ascent design system

Current contributor guide · reviewed November 2026. The definitions in `lib/app/theme/` and active component APIs are authoritative; this guide establishes the core rules and visual language across all screens.

## 1. Global Rules

- **INPUT RULE**: One input = one container. Use a single `TextField` with `InputDecoration` (filled, one border, `prefixIcon` inside decoration). NEVER put a bordered/filled field inside another bordered/filled box. Build and use the reusable `AppTextField` everywhere; no raw `TextField` with custom wrappers.
- **No pure black (#000) fills, outlines or text anywhere**. No 2px dark outlines. Borders are 1px warm hairlines (`#E9E1D5`).
- **Sticky headers/app bars must have an opaque (or blurred+opaque-tinted) background** so content never shows through.
- **Scroll bottom padding** = bottom nav height + safe-area inset + 16. No fixed big spacers.
- **All colors come from ThemeData/ColorScheme / AppColors tokens**. No hardcoded hex in widgets.
- **Every section header uses the same pattern**: title left, "View all" or chevron right-aligned.

## 2. Palette "Sand & Dusk" (warm base, cool accent, no blue/green)

### Light Theme Tokens
- `background`: `#FBF8F3` (warm paper)
- `surface` (cards): `#FFFDF9`
- `surfaceAlt` (inputs, empty states): `#F4EEE6`
- `border/outline`: `#E9E1D5`
- `text primary`: `#2A2521` (warm charcoal)
- `text secondary`: `#6B635A`
- `text hint`: `#9A9086`
- `primary` (warm clay, CTAs): `#BF5A36`, `onPrimary` `#FFFFFF`
- `primaryContainer` (soft buttons, selected chips): `#FBE6DA`, `onPrimaryContainer` `#6B2E14`
- `secondary` (cool dusk lavender, icons, links, focus ring): `#7C6FB0`
- `secondaryContainer`: `#ECE8F6`, `onSecondaryContainer` `#3A3266`
- `tertiary` (soft gold, highlights/streaks): `#C99A3C`, `tertiaryContainer` `#F7EBCF`
- `error`: `#B3473F`

### Dark Theme Tokens (Warm dark #1F1B18, not black)
- `background`: `#1F1B18`
- `surface`: `#2A2420`
- `surfaceAlt`: `#352F2A`
- `border/outline`: `#433C35`
- `text primary`: `#F5EFEB`
- `text secondary`: `#BAAFA4`
- `text hint`: `#8C8176`
- `primary`: `#E28A6D`, `onPrimary` `#1F1B18`
- `primaryContainer`: `#4D2415`, `onPrimaryContainer` `#FBE6DA`
- `secondary`: `#A79BD6`
- `secondaryContainer`: `#2D2545`, `onSecondaryContainer` `#ECE8F6`
- `tertiary`: `#E3B863`, `tertiaryContainer` `#4A3B18`
- `error`: `#E2756E`

### Surface & Dimension Rules
- Cards = surface + 1px border + very soft shadow (blur 16, 4% opacity warm brown: `Color(0x0A5C4A3E)`).
- Radii: 20 cards (`Rd.card`), 14 inputs (`Rd.field`), 999 chips/buttons (`Rd.chip`).
- Icon tiles use container colors, not saturated fills.
- Selected nav item = `primaryContainer` pill with `onPrimaryContainer` icon/label.
- Spacing scale: 4 / 8 / 12 / 16 / 24 (`AppSpacing.xs` through `AppSpacing.xl`).

## 3. Controls and Feedback
- Use `AppTextField` for all form and modal input requirements.
- Use `AppChip` for filter, selection, and quick-add chips.
- Reuse `AscentButton` variants and appropriate tactile feedback.
- Feature sheets use `showModalBottomSheet`, with safe areas, keyboard insets, sensible height limits, scrolling and shared surface/radius tokens.
- Back and navigation behavior belongs to the router and main scaffold.
