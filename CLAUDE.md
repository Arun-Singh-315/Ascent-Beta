# Ascent Contributor Guidelines & Global Rules

## Global Rules

1. **INPUT RULE**: One input = one container. Use a single `TextField` with `InputDecoration` (filled, one border, `prefixIcon` inside decoration). NEVER put a bordered/filled field inside another bordered/filled box. Build one reusable `AppTextField` and use it everywhere; no raw `TextField` with custom wrappers.
2. **No pure black (#000) fills, outlines or text anywhere**. No 2px dark outlines. Borders are 1px warm hairlines (`#E9E1D5`).
3. **Sticky headers/app bars must have an opaque (or blurred+opaque-tinted) background** so content never shows through.
4. **Scroll bottom padding** = bottom nav height + safe-area inset + 16. No fixed big spacers.
5. **All colors come from ThemeData/ColorScheme tokens**. No hardcoded hex in widgets.
6. **Every section header uses the same pattern**: title left, "View all" or chevron right-aligned.

## Palette "Sand & Dusk" (Warm Base, Cool Accent, No Blue/Green)

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

### Component Metrics
- Cards: Surface + 1px border + very soft shadow (blur 16, 4% opacity warm brown).
- Radius: 20 cards, 14 inputs, 999 chips/buttons.
- Spacing: 4/8/12/16/24 scale.
- Selected nav item: `primaryContainer` pill with `onPrimaryContainer` icon/label.
