# Ascent Design System — iOS Language & "Sand & Ember"

Current contributor guide · reviewed November 2026. Authoritative tokens and rules for Ascent.

---

## 0. Non-Negotiable Rules

1. **INPUT RULE (ONE INPUT = ONE CONTAINER)**:
   - Never put a bordered/filled field inside another bordered/filled box.
   - Use `AppTextField` and `AppComposer` exclusively.
   - Remove default Material focus borders (zero blue underlines or outlines anywhere). Focus states are indicated exclusively by the single container's 1px border color (e.g. primary at 60%).
2. **ZERO PURE BLACK / WHITE-ON-BLACK**:
   - No pure black `#000000` fills, outlines, or text.
   - Dark theme uses warm graphite `#1B1714` (background) and `#2A2420` (surface).
   - No 2px dark outlines; all borders are 1px warm hairlines.
   - Zero blue/green accents anywhere in the UI.
3. **TOKEN DISCIPLINE**:
   - All colors resolve through `ThemeData`, `ColorScheme`, or `AppColors`. No hardcoded hex in widget trees.
   - Defined systematically for both Light and Dark themes.
4. **SINGLE ASSISTANT IDENTITY ("Jarvis")**:
   - Use `"Jarvis"` consistently across all UI copy, routes, strings, and prompts.
   - Remove all references to "Aria" and legacy "Riya".
   - Managed via the canonical constant `AppConstants.assistantName = 'Jarvis'`.
5. **ACCURACY & LOCALIZATION**:
   - Plurals handled properly (e.g. "1 message", "2 messages").
   - Title-case user names.
   - Time-based dynamic greetings (morning <12, afternoon <17, evening <21, night).
6. **UNIFIED CHAT COMPONENT**:
   - A single chat UI component used for both light and dark modes. Dark mode is a token swap, never a separate screen layout.

---

## 1. iOS Design Language

- **Adaptive Controls**:
  - `CupertinoSwitch` (tinted with primary ember).
  - `CupertinoActivityIndicator` for loaders.
  - `showCupertinoModalPopup` / `CupertinoActionSheet` for pickers and context actions.
  - `CupertinoAlertDialog` for confirmation dialogs.
  - `CupertinoSliverNavigationBar` with large collapsing titles.
  - `BouncingScrollPhysics` across all scrollables.
- **Typography**:
  - iOS type scale: Large Title (34/bold), Title (22/bold), Headline (17/semibold), Body (17/regular), Subhead (15/medium), Footnote (13/regular), Caption (12/regular).
  - Inter font with tight, legible letter-spacing.
  - Dynamic Type safe (verified with `TextScaler.linear(1.3)` and up to `2.0`).
- **Shapes & Radii**:
  - Continuous corners (`ContinuousRectangleBorder` / superellipse):
    - Cards: continuous radius 20 (`Rd.card`).
    - Controls & Inputs: continuous radius 14 (`Rd.field`).
    - Floating Composer: radius 24 (`Rd.bubble`).
    - Buttons & Chips: radius 999 (`Rd.chip`).
  - Spacing scale: 4 / 8 / 12 / 16 / 20 / 24 (`AppSpacing.xs` to `AppSpacing.xxl`).
  - Minimum tap target: 44dp (`AppTapTarget.minTarget`).
- **Motion & Haptics**:
  - iOS curve: `Curves.easeOutCubic` over 250–350ms.
  - Spring-press downscale (scale to 0.97 on press).
  - Tactile haptics: `HapticFeedback.selectionClick()` on toggles, chip taps, and sends.
- **Lists**:
  - Inset grouped style: rounded group card, 1px hairline separators inset 16 from left, chevron `>` on right, leading icon in a 30px rounded-square tinted tile.

---

## 2. Palette "Sand & Ember" (Warm Base, Ember Accents, No Blue/Green)

### Light Theme
- `background`: `#FAF6F0` (warm base)
- `groupedBackground`: `#F3ECE2` (inset list container)
- `surface`: `#FFFFFF` at 92% opacity (cards)
- `surfaceAlt`: `#F1E9DD` (inputs, empty states)
- `hairline` (borders): `#E6DCCD`
- `textPrimary`: `#2B2622` (warm charcoal)
- `textSecondary`: `#6F665C`
- `textHint`: `#A0958A`
- `primary` (ember): `#D2643A`, `onPrimary`: `#FFFFFF`
- `primaryContainer`: `#FCE5D8`, `onPrimaryContainer`: `#6E2E15`
- `accent2` (rose clay): `#C4506A`, `accent2Container`: `#F8E1E6`
- `gold` (streaks / highlights): `#D6A23E`, `goldContainer`: `#F8EDD0`
- `success`: `#D6A23E` (soft olive-gold, never green)
- `error`: `#B8433B`

### Dark Theme (Warm Graphite, Never Pure Black)
- `background`: `#1B1714` (warm graphite)
- `groupedBackground`: `#221D19`
- `surface`: `#2A2420` (solid opaque for content/sheets)
- `surfaceAlt`: `#332C27` (inputs, elevated cards)
- `hairline` (borders): `#3D342E`
- `textPrimary`: `#F3EBE2`
- `textSecondary`: `#B9AC9F`
- `textHint`: `#857A6F`
- `primary` (ember light): `#F08A5D`, `onPrimary`: `#2B1408`
- `primaryContainer`: `#4A2A1B`, `onPrimaryContainer`: `#FFD9C6`
- `accent2` (rose clay): `#E27A93`
- `gold`: `#E8B65A`
- `error`: `#E2756E`

---

## 3. Glass Architecture (Safe Dark Mode)

1. **Persistent Chrome ONLY**:
   - Glass is strictly confined to: Bottom navigation bar, large-title nav bar, floating composer.
   - Specification: `BackdropFilter(blur: 24)` + surface at 72% opacity + 1px white@10% border + subtle top highlight gradient.
   - Light theme: surface white@78% with blur 20.
   - Fallback: Solid background if reduce-transparency is enabled.
2. **Overlays MUST BE OPAQUE**:
   - Anything opening above content must be completely solid and darker: dropdowns, popup menus, bottom sheets, action sheets, dialogs, date/time pickers, tooltips, snackbars, context menus.
   - Overlays use solid `surface` (`#2A2420` or `#221D19` for sheets) + warm brown shadow + scrim black@45%. Zero transparency or blur on overlays.
   - Dedicated widgets: `GlassSurface` (chrome only) and `OpaqueOverlaySurface` (overlays only).

---

## 4. Glowing "Ask Jarvis" Hero Card

- Plain surface card with an illuminated rotating border:
  - 1.5px `SweepGradient` stroke: ember `#F08A5D` -> rose `#E27A93` -> gold `#E8B65A` -> ember `#F08A5D` rotating slowly (8s continuous loop).
  - Outer glow: double BoxShadows with blur 24/48 at 0.18/0.08 opacity (light) or 0.35/0.15 (dark).
  - PrimaryContainer avatar with primary sparkle icon.
  - "Ask Jarvis", "Plan your day or ask anything", and soft "Chat" pill.
  - Static gradient fallback when reduce-motion is enabled; animation pauses when not visible.

---

## 5. Chat Screen Specifications

- **App Bar**: Back button, centered "Jarvis" title, opaque overflow menu.
- **Empty State**: Centered sparkle tile, "How can I help?", 2x2 grid of surfaceAlt suggestion cards (disappears immediately after the first message).
- **Messages**:
  - User bubble: right-aligned, `primaryContainer` fill, `onPrimaryContainer` text, radius 20 with 6dp corner tail.
  - Jarvis reply: NO bubble, full width plain text, small "Jarvis" label with sparkle at start of turn.
  - Timestamps: hidden by default, visible on long-press or grouped per 5 min.
  - Markdown: rendered via `flutter_markdown` (bold headings, numbered lists, 8dp paragraph spacing).
  - Action row: Copy, Regenerate, Thumbs (icon-only, textHint).
  - Contextual follow-ups: At most 2 quiet text buttons only on the latest message; no repeating chip rows under every message.
- **Composer**:
  - Single rounded container (radius 24, surfaceAlt, 1px hairline).
  - Borderless multiline `TextField` (1–6 lines auto-grow, zero Material focus underline/border).
  - Send button: primary circle with scale animation when text exists; mic icon when empty.
  - Border illumination: container border transitions to primary @ 60% on focus.
- **Typing Indicator**: Three softly pulsing dots. Smooth streaming. Inline retry on error.

---

## 6. Home Screen Specifications

- Quick tiles: correct pluralization ("1 message"), 0-states show "-" (not "0 ml" or "0 min").
- Clean headers: "Peak hours" chip replaced with meaningful status or removed.
- Item rows: single scheduled time in card; created time reserved for details.
- Section cards: icon tile + title left, chevron `>` right-aligned.
- Bottom nav: glass in dark, solid-blur in light; selected item = `primaryContainer` pill.

---

## 7. Settings Redesign (iOS Style)

- Collapsing large title "Settings".
- User Profile card at the top.
- Inset grouped sections with uppercase footnote headers:
  1. **Appearance**: Theme (System / Light / Dark segmented control), Text size.
  2. **Notifications**: Smart reminders, daily check-in toggles.
  3. **Privacy & Security**: Vault lock, biometrics.
  4. **Data**: Export data, backup.
  5. **About**: Version, licenses, feedback.
- Rows: 30px tinted rounded-square icon tiles, title, optional secondary text, chevron.
- Toggles: `CupertinoSwitch` tinted with primary ember.
- Destructive actions: isolated group with error-colored text.
