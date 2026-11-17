# Ascent Contributor Guidelines & Global Rules

## 0. Non-Negotiable Rules

1. **INPUT RULE: One input = one container**. Never a bordered/filled field inside another bordered/filled box. Build and use reusable `AppTextField` and `AppComposer`. Remove default Material focus border (set `border: InputBorder.none, focusedBorder: InputBorder.none, enabledBorder: InputBorder.none` in inner TextField so there is **no blue underline or outline** anywhere); focus state is shown solely by the single container's border color.
2. **No pure black (#000)** or pure white-on-black. No blue/green accents. No 2px dark outlines. All borders are 1px hairlines.
3. **No hardcoded colors**: `ThemeExtension` / `ColorScheme` tokens only, defined symmetrically for light AND dark.
4. **Assistant Identity**: Pick ONE assistant name everywhere: **"Jarvis"** for all UI copy, routes, strings, and prompts. Remove every reference to "Aria" and "Riya". Centralized in `AppConstants.assistantName`.
5. **Plurals & Formatting**: Use proper plurals (e.g., "1 message" / "2 messages"), title-case user names, and time-based greetings (morning <12, afternoon <17, evening <21, night).
6. **Unified Chat Component**: Exactly one chat UI component used for light and dark. Dark theme is purely a token swap, never a separate design or duplicate tree.

---

## 1. iOS Language

- **Adaptive Controls**: Use `CupertinoSwitch`, `CupertinoActivityIndicator`, `showCupertinoModalPopup`, `CupertinoActionSheet`, `CupertinoAlertDialog`, `BouncingScrollPhysics` everywhere.
- **Typography**: iOS type scale (Large Title 34/bold, Title 22, Headline 17/semibold, Body 17, Subhead 15, Footnote 13, Caption 12) with Inter and tight letter-spacing. Dynamic type safe (text scale 1.3x and 2.0x without overflow).
- **Shapes & Radii**: Continuous corners (`ContinuousRectangleBorder`) with radius 20 cards, 14 controls, 24 floating composer, 999 chips/pills. Spacing scale: 4 / 8 / 12 / 16 / 20 / 24. Tap targets >= 44dp.
- **Motion**: iOS-style `easeOutCubic` 250-350ms, spring-press feel (`scale: 0.97`), light haptics on toggles/sends (`HapticFeedback.selectionClick`).
- **Grouped Lists**: Inset grouped style (rounded group card, 1px hairline separators inset 16dp from left, chevron on right, leading icon in a 30px rounded-square tinted tile).

---

## 2. Palette "Sand & Ember" (Warm Only, Zero Lavender/Dusk/Blue/Green)

### Light Theme
- `background`: `#FAF6F0`
- `groupedBackground`: `#F3ECE2`
- `surface` (cards): `#FFFFFF` at 92% opacity
- `surfaceAlt` (inputs, chips, empty states): `#F1E9DD`
- `hairline` / `border`: `#E6DCCD`
- `text primary`: `#2B2622`
- `text secondary`: `#6F665C`
- `text hint`: `#A0958A`
- `primary` (ember): `#D2643A`, `onPrimary`: `#FFFFFF`
- `primaryContainer`: `#FCE5D8`, `onPrimaryContainer`: `#6E2E15`
- `accent2` (rose clay): `#C4506A`, `accent2Container`: `#F8E1E6`
- `gold` (streaks/success tint): `#D6A23E`, `goldContainer`: `#F8EDD0`
- `error`: `#B8433B`

### Dark Theme (Warm Graphite, Never Black)
- `background`: `#1B1714`
- `groupedBackground`: `#221D19`
- `surface` (cards, OPAQUE): `#2A2420`
- `surfaceAlt`: `#332C27`
- `hairline` / `border`: `#3D342E`
- `text primary`: `#F3EBE2`
- `text secondary`: `#B9AC9F`
- `text hint`: `#857A6F`
- `primary` (ember): `#F08A5D`, `onPrimary`: `#2B1408`
- `primaryContainer`: `#4A2A1B`, `onPrimaryContainer`: `#FFD9C6`
- `accent2` (rose clay): `#E27A93`, `accent2Container`: `#4A222E`
- `gold`: `#E8B65A`, `goldContainer`: `#45351C`
- `error`: `#E06D65`

---

## 3. Glass & Overlays (Dark Safe Architecture)

- **Persistent Chrome Only**: Glass (`GlassSurface`) with `BackdropFilter(sigma: 24)` is ONLY used for persistent chrome (Bottom Nav Bar, large-title nav bar, floating composer). Includes subtle top highlight gradient and 1px white@10% border. Falls back to solid if reduce-transparency is enabled.
- **Overlays Must Be Opaque**: Dropdowns, popup menus, bottom sheets, dialogs, action sheets, date pickers, tooltips, and snackbars MUST use `OpaqueOverlaySurface` with solid background (`#2A2420` dark / `#FFFDF9` light) + shadow + scrim black@45%. Never use `GlassSurface` for overlays.

---

## 4. Glowing "Ask Jarvis" Hero Card

- Card uses plain surface with a soft illuminated border: 1.5px `SweepGradient` stroke (ember `#F08A5D` -> rose `#E27A93` -> gold `#E8B65A` -> ember) rotating smoothly via 8s `AnimationController`.
- Dual outer glow box shadows (blur 24/48, opacity 0.18/0.08 in light, 0.35/0.15 in dark).
- Icon tile with primaryContainer tint and sparkle icon, title "Ask Jarvis", subtitle "Plan your day or ask anything", and soft "Chat" pill button. Respects reduce-motion.

---

## 5. ChatGPT-Clean Chat Screen

- App bar: Back button, centered "Jarvis", opaque overflow menu.
- Empty state: Centered sparkle icon + "How can I help?" + 2x2 surfaceAlt suggestion grid (disappears on first sent message).
- Messages:
  - User bubble: right-aligned in `primaryContainer`, rounded continuous corners.
  - Jarvis reply: NO bubble, plain text left, full width, small "Jarvis" label at start of turn.
  - Formatted text: Rendered with markdown (`flutter_markdown`), 8dp paragraph spacing.
  - Action row: Copy, Regenerate, Thumbs (icon-only, `textHint` color).
  - Suggestions: REMOVE repeating chips under replies. At most 2 subtle follow-ups only on the very latest reply.
- Floating composer: Single enclosure `AppComposer`, safe-area aware, scale-animated send button, mic icon when empty. Default Material focus border disabled.
