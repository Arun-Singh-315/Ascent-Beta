# Ascent visual upgrade — implementation handoff

Version 1.0 · 29 October 2026 · Status: specification ready for implementation; implementation and visual approval are not yet complete.

## 1. Instructions to the implementer

Implement this document as written. It resolves the alternatives in [the research review](APPLE_INSPIRED_VISUAL_REVIEW.md). The review explains the reasoning; this handoff defines the deliverable. Do not choose a different palette, font, control style, animation, or navigation structure because it seems more premium.

All measurements below are Flutter logical pixels. All colors are opaque sRGB hex unless an alpha is explicitly given. Durations are milliseconds. Minimum dimensions must grow when text needs more room. Start/end directions mean logical directions and must respect RTL.

Rule precedence: user instructions and repository `AGENTS.md`; this handoff; existing maintained documentation; research suggestions. Preserve existing behavior wherever this document specifies presentation only. If an implementation detail prevents a requirement, record the exact conflict and leave that item incomplete. Do not silently invent a visual substitute.

This document is a requested handoff deliverable. Retain it after implementation. Temporary working plans must still be deleted as required by `AGENTS.md`.

## 2. Fixed scope and exclusions

Deliver a coherent Apple-inspired control system across the existing app, with the existing `nordicSky` preset providing the blue appearance. Keep the enum name, stored preference value, existing preset display name, application ID, defaults, and selected user appearance unchanged. Do not create a fourth theme. The currently selected preset must remain selected after updating.

Apply the common geometry, typography, state handling, and accessibility rules to `nordicSky`, `merlotLinen`, and `classicClay`, each in light and dark mode. Replace the blue preset's colors using section 3. Preserve the existing Merlot and Clay palette colors except for the explicitly shared control-state colors in section 3.2. Do not recolor those entire themes blue.

Preserve screen order, card order, labels, routes, database models, queries, permissions, notification scheduling, reminder protection, transaction logic, lock behavior, and user-customized layouts. Do not add widgets, Live Activities, Siri/Shortcuts, new search functionality, new gestures, onboarding steps, or theme migrations. Preserve existing specialized reader typography, credential artwork, maps, breathing/cup/water animations, and course/player content; apply shared chrome around them only.

Do not bundle Apple system fonts or SF Symbols assets into Android. Keep the existing Material icon library, with the sizing and outlined/selected conventions below. No new package or network font dependency is required.

## 3. Exact color specification

### 3.1 Blue preset: replace these roles

Centralize these roles in the existing theme system. Resolve them through semantic getters/extensions, not per-screen literals. All equivalent `ColorScheme`, `AscentGlass`, and `AppSurfaces` roles must resolve consistently.

| Role | Light | Dark |
| --- | --- | --- |
| Page canvas | `#F5F5F7` | `#171819` |
| Content/card surface | `#FFFFFF` | `#202224` |
| Elevated surface: sheet/dialog/menu | `#FFFFFF` | `#292B2D` |
| Recessed surface: inputs/segment track | `#ECEEF2` | `#171819` |
| Primary text | `#1D1D1F` | `#F3F4F6` |
| Secondary text | `#51545C` | `#C5C8CE` |
| Helper/placeholder text | `#626670` | `#A7ABB3` |
| Decorative separator | `#D8DBE2` | `#41454D` |
| Required control outline | `#747985` | `#8D939F` |
| Action ink: links/active icons/focus | `#1D64B4` | `#5EA0F0` |
| Filled primary background | `#1D64B4` | `#1D64B4` |
| Filled primary foreground | `#FFFFFF` | `#FFFFFF` |
| Filled primary pressed background | `#174F8F` | `#174F8F` |
| Tonal/selection background | `#DFEAF8` | `#203853` |
| Tonal/selection foreground | `#174F8F` | `#A8D0FF` |
| Focus ring | `#1D64B4` | `#5EA0F0` |

The bright dark action ink must never double as a white-label filled-button background. White on `#5EA0F0` is approximately 2.71:1; white on `#1D64B4` is approximately 5.94:1. Keep the action-ink and filled-button roles separate.

### 3.2 Shared control colors: all three presets

| Role | Light | Dark |
| --- | --- | --- |
| Enabled settings switch track | `#16803C` | `#16803C` |
| Switch thumb | `#FFFFFF` | `#FFFFFF` |
| Off switch track | `#737984` | `#656C78` |
| Disabled control background | `#E5E7EB` | `#292B2D` |
| Disabled control foreground | `#475467` | `#A7ABB3` |
| Error/danger ink | `#B42318` | `#FFB4AB` |
| Error/danger soft background | `#FEE4E2` | `#4A2525` |
| Filled destructive background | `#B42318` | `#B42318` |
| Filled destructive foreground | `#FFFFFF` | `#FFFFFF` |
| Filled destructive pressed | `#912018` | `#912018` |
| Success ink | `#166534` | `#86EFAC` |
| Success soft background | `#E8F5EC` | `#173426` |
| Warning ink | `#854D0E` | `#FDE68A` |
| Warning soft background | `#FFF3CD` | `#3B301B` |

Switch green means a setting is enabled. Checkmarks plus success text indicate completed actions. Keep existing hydration/finance/chart/category accents on domain content, but use theme action ink for controls that change that content. Never rely on color alone for status.

For Merlot and Clay, map primary/secondary/helper text, content/elevated surfaces, separators, action ink, tonal backgrounds, and focus rings to their existing semantic palette roles. Filled primary buttons use the current palette action color, with white foreground in light mode and `#171819` foreground in dark mode; pressed fill uses the palette's pressed token when present, otherwise the same fill with a 10% black overlay. Use the shared disabled and destructive pairs above. Preserve existing category colors.

## 4. Geometry and typography

Extend existing dimension/text tokens; do not scatter new numeric recipes through feature files.

| Element | Required value |
| --- | --- |
| Screen horizontal gutter | 16 |
| Gap between content sections | 24 |
| Card internal padding | 16 |
| Card-to-card vertical gap | 12 |
| Icon-to-label gap | 8 |
| Label-to-helper gap | 4 |
| Standard content card radius | 16 |
| Button/input radius | 12 |
| Dialog radius | 20 |
| Bottom sheet top radius | 24 |
| Tab-bar outer radius | 24 |
| Filter/segment/search capsule radius | 999 |
| Regular control minimum hit region | 48 × 48 |
| Standard button visual minimum height | 48 |
| Compact button visual minimum height | 36, inside at least a 48-high hit region |
| Hero button minimum height | 52 |
| Settings/list row minimum height | 56; with helper text 72 |
| Input minimum height | 52 |
| Standard content outline | 1 logical pixel, separator color |
| Interactive unselected outline | 1 logical pixel, required control-outline color |
| Focus ring | 2 logical pixels, focus color, no glow |

Do not put an extra card border around a list already inside a grouped card. Keep one nesting level of content containers; existing domain graphics may have their own internal shapes. Do not remove functional nested content to meet this rule; remove its redundant decorative wrapper instead.

Use **DM Sans** for ordinary UI titles, body, labels, menus, buttons, forms, and metadata. Reuse the existing font setup and assets. Preserve branding/logo artwork and specialized reading fonts. Use **JetBrains Mono** only for countdown timers, technical/code content, and existing explicitly technical values. Money and ordinary statistics use DM Sans with tabular figures.

| Text role | Size | Weight | Line-height multiplier | Letter spacing |
| --- | --- | --- | --- | --- |
| Page title | 28 | 600 | 1.20 | -0.4 |
| Focus timer | 48 | 500 | 1.15 | 0 |
| Headline metric | 32 | 600 | 1.20 | -0.3 |
| Section heading | 20 | 600 | 1.25 | -0.2 |
| Card/dialog title | 18 | 600 | 1.30 | -0.1 |
| Body and editable input | 16 | 400 | 1.45 | 0 |
| Button/segment label | 15 | 600 | 1.30 | 0 |
| List-row title | 16 | 500 | 1.35 | 0 |
| Supporting text | 14 | 400 | 1.40 | 0 |
| Caption/tab label | 12 | 500 | 1.35 | 0 |

Use sentence case for new shared UI labels. Preserve existing feature copy. Do not make helpers uppercase or add tracking. Never use a sub-12 size for ordinary UI copy. Preserve source code/reader font sizes controlled by their dedicated settings.

At 200% text scale: wrap text, increase row height, and stack actions vertically when they no longer fit. Primary labels must remain readable. No text-scale clamps. For a segmented control that cannot fit, use a vertically stacked single-choice list with the same options, order, and selection behavior.

## 5. Shared component implementation contracts

Use the existing components below. Proposed new wrappers are explicitly identified; create them only once in `lib/shared/widgets/` and reuse them.

### C01 — Buttons: `ascent_button.dart`

Preserve all named constructors and callbacks. Apply section 4 geometry across all palettes; remove palette-dependent shape/size branches.

- `primary` and `fab`: filled-primary token pair. FAB visible shape is a 56-diameter circle; icon 24. Keep its existing placement and label behavior.
- `secondary` and `tonal`: tonal pair; no border. Keep both constructors as compatibility aliases for this appearance.
- `outlined`: content-surface fill, primary text, required-control outline.
- `ghost`: transparent fill, action ink, no border.
- `destructive`: filled-destructive pair.
- `icon`: 48 × 48 hit region, 20-sized icon, transparent normal fill, 12 radius. Require a tooltip and semantic label; add optional API parameters without breaking existing callers, then populate them at every icon-only call site.
- Padding: regular horizontal 16, compact horizontal 12. Icon-label gap 8.
- Press feedback: 0.98 scale, 100 ms, `Curves.easeOutCubic`; release to 1.0 in 140 ms using the same curve. No scale for reduced-motion mode.
- Primary/destructive use the pressed colors. Other enabled controls use a 6% primary-text overlay while pressed; do not lower text opacity.
- Disabled/loading: disable activation and use the shared disabled pair. During loading retain the label and reserve a leading 16 × 16 spinner with 2 stroke; announce busy state. Preserve width by reserving the spinner slot while idle.
- Emit one `lightImpact` when an enabled button accepts activation. No haptic on pointer-down, canceled gestures, disabled controls, or loading controls. Remove duplicate haptics in callers when the shared button owns the feedback.

### C02 — Settings switches: new `ascent_switch_row.dart`

Implement a shared `AscentSwitchRow` that accepts title, optional helper, value, enabled, busy, and change callback. Use the same visual switch on Android and iOS: a `CupertinoSwitch` with explicit shared track/thumb colors inside the shared row. Do not rely on adaptive selection to produce identical styling.

Row padding: horizontal 16, vertical 12; minimum heights from section 4. Leading text expands; gap before switch 12. The row has no navigation chevron. Single semantics node announces label, helper, enabled state, and toggle value; exclude duplicate thumb semantics. Tapping any part of an enabled row changes it exactly once. Direct switch activation must also change it exactly once.

On/off track colors are section 3.2. Thumb stays white. Disabled switch uses disabled background for track and disabled foreground for thumb. During asynchronous persistence, retain the last committed state, disable repeat input, and show a 16-sized spinner in the switch slot; on success show the new state, on failure restore interaction and show `Could not update setting. Try again.` through `AscentSnackBar`. For local form-only values, change immediately without pretending to persist. Emit one `selectionClick` after the value changes successfully; none for failure/cancel. Do not introduce extra persistence calls.

Migrate settings switches, not task checkboxes. Permissions that open OS prompts/settings remain action/disclosure rows and show actual granted state; never present them as freely editable switches.

### C03 — Completion and multi-selection

Keep checkbox/checkmark semantics. Use a 20-sized visible completion indicator inside a 48 × 48 hit region. Unchecked outline uses required-control outline; checked fill uses theme filled-primary pair with a checkmark. Label remains primary text; use strikethrough only where it already exists. Do not turn selection into an immediate database write unless the current flow already does so.

### C04 — Segmented selection: new `ascent_segmented_control.dart`

Implement one generic single-selection wrapper. Container: recessed fill, 4 padding, capsule radius, minimum height 48. Selected segment: content surface, radius 999, primary text; unselected: transparent, secondary text. Segment padding: horizontal 12, vertical 8. No check icon before selected labels. Existing option labels and order remain unchanged. Move the highlight over 180 ms, `easeOutCubic`; reduced motion switches instantly. Emit one `selectionClick` only when choosing a different option. Apply to existing mutually exclusive segmented/pill selectors, not multi-select filter chips. At large text use the fallback in section 4.

Multi-select chips retain their behavior: minimum hit height 48, tonal fill and check icon when selected, content fill and required-control outline when unselected.

### C05 — Fields and scheduling rows

Update `app_theme.dart` input theme and existing field call sites. Inputs use recessed fill, radius 12, 12 horizontal/14 vertical padding. Editable text uses body style. Always retain a visible field label above the field; do not rely on the placeholder as its only label. Gap to label 8; helper/error below 4. Idle border 1 in required-control outline color; focused border 2 in focus color; error border 1 in error color plus visible error message. A disabled field uses disabled colors. Read-only text that opens a picker is a disclosure row, with current value and chevron.

Preserve keyboard types and validation; correct a missing keyboard type only for unambiguous number/email fields. Keep submit/save callbacks unchanged. Never auto-submit after selection unless the existing flow already does so.

Reuse `schedule_picker.dart` and existing feature scheduling validation. Keep platform Material calendar/time dialogs on Android and the currently implemented picker types on iOS. Theme them with the current content/elevated surface and action colors. Do not add wheel pickers or rewrite date math. Respect locale, current 12/24-hour preference, and existing date limits. Picker cancellation must not change the selected value.

### C06 — Content surfaces and glass

Update `GlassSurface`, `AscentCard`, `AppCard`, and existing Home outline surfaces rather than adding another card system. Standard content is opaque content-surface color, radius 16, separator border 1, no gradient/glow/blur/shadow. Grouped lists use separators inset 16 from each edge, with no last separator. Existing themed text/chat tails remain, using the same content fill. Preserve user-selected Thought Wall density/alignment and existing text alignment.

Limit blur to the persistent floating bottom navigation and popup menus. Blur sigma: 12 on both axes, clipped to the control's shape. Glass fill: elevated-surface color at 92% opacity in light mode, 94% in dark mode; separator border 1. No moving highlight, refraction shader, or shimmer on glass. All other content, including sheets/dialogs, remains opaque. With high-contrast or reduced-transparency requirements active, use 100% opaque fill and no blur. Reduced-transparency detection must use available platform support; where unavailable use the opaque fallback, never silently assume transparency is allowed. Existing translucency preferences must remain stored; apply them only to these allowed glass surfaces.

The only permitted new shadow is on floating navigation or a popup: light black at 10% alpha, dark black at 20%; blur 16, offset (0,4), spread 0. Sheets/dialogs use their scrim and surface separation, without a decorative shadow.

### C07 — Navigation and rows

Preserve the four current tabs, their order, destinations, and independent stacks. Floating bar: outside margins left/right 16 and bottom 8 plus device safe inset; internal padding 4; minimum height 64 before bottom safe inset. Divide available width equally. Icons 22; labels use caption role with 4 gap below icon. Current tab: tonal capsule and tonal foreground, filled existing icon. Other tabs: secondary text and outlined existing icon. Allow the bar to grow with text; do not truncate tab labels. Do not add bounce, extra tabs, badges, or auto-hiding behavior.

Use disclosure rows for navigation: 20-sized leading icon only if one currently exists, gap 12, title expanded, optional trailing value, gap 8, 16-sized chevron. Entire row is tappable with 6% primary-text pressed overlay. No chevron for direct actions or settings switches. Preserve Android back behavior.

### C08 — Sheets, dialogs, menus, and feedback

Feature sheets remain `showModalBottomSheet`; add a shared styling helper only, not a new navigation system. Top radius 24, opaque elevated fill, horizontal content padding 16, bottom padding 16 plus safe inset/keyboard inset as applicable. Visible drag handle only where drag-dismiss is already enabled: 36 × 4, radius 2, helper-text color, margin 8 above/12 below. Header title uses card-title role; existing close control gets a 48 target. Do not enable dismissal on protected or unsaved forms. Preserve existing confirmation and cancel rules.

Dialog: `AscentDialog`, radius 20, content padding 20, title/body gap 8, body/actions gap 20, action gap 8. At normal text scale show Cancel then confirm in reading order; stack full-width when they cannot fit. Never change which action is destructive or bypass existing confirmations. Scrim: black 32% light / 56% dark.

Popup: update `ascent_popup_menu.dart` and popup theme to use the current appearance, rather than forcing night colors in day mode. Radius 16; menu rows minimum 48; icons 20; icon-label gap 12; text 16; horizontal padding 16. Keep actions/order/conditions unchanged. Destructive text and icon use error ink. Tooltip text must describe the action.

Snackbars: reuse `AscentSnackBar`/`showUndoSnackbar`, opaque elevated fill, primary text, action ink for Undo, radius 12, screen margins 16, minimum height 48. Preserve current durations and undo operations. Do not add success messages for every toggle. Errors must stay visible to assistive technologies.

### C09 — Swipe actions

Use Thought Wall's existing archive swipe as the geometric reference. Preserve each screen's existing enabled directions and callback behavior. In particular, Thought Wall currently enables start-to-end archive; its declared secondary delete background does not authorize enabling delete swipes.

For each enabled direction: action background must match the foreground card bounds and radius, fill the entire exposed area, and use 20 start/end padding, 20 icon, 8 icon-label gap. Archive/restore: tonal pair. Delete: danger soft background/error ink. Label 15/600. No visible white strips in either appearance. Keep existing confirmation, undo, selection-mode disabling, and protected-record behavior. Disabled directions must leave the row in place with no newly exposed action. Provide the same action through the existing menu/button alternative.

### C10 — Sliders and progress

Existing slider: active track action ink, inactive track required-control outline color, 4 track height, 20 circular thumb in action ink, 48 minimum hit height. Preserve current range, divisions, values, labels, seeking, and accessibility increment behavior. No glass thumb or glow. For domain progress/chart graphics preserve category colors and numerical calculations; change ordinary labels to section 4 typography and neutral text roles. Include a text value for any existing unlabeled progress that otherwise communicates solely by color.

## 6. File and screen application matrix

Paths below are relative to `lib/`. Apply only the contracts listed. Preserve all unlisted specialized feature behavior. Shared-component changes propagate everywhere; this matrix identifies places to remove local overrides that would defeat those changes.

| Location | Required application |
| --- | --- |
| `app/theme/{app_theme,color_tokens,frozen_palette,dimension_tokens,text_styles,surface_tokens,glass_theme,day_glass_material}.dart` | Implement sections 3–4 and role consistency; preserve preference keys and theme identities. |
| `shared/widgets/{ascent_button,app_surfaces,glass_surface,ascent_card,ascent_scaffold,main_scaffold}.dart` | C01, C06, C07; unify geometry without breaking public constructors. |
| `shared/widgets/{ascent_dialog,ascent_popup_menu,ascent_snack_bar,undo_snackbar,schedule_picker}.dart` | C05, C08. |
| `features/settings/settings_screen.dart` | C02, C05, C07, C08; retain current section order and collapse states; group existing related rows inside one card per current section. Permissions remain OS action rows. |
| `features/home/home_customization_sheet.dart`, `daily_checkin_card.dart`, `widgets/{daily_briefing_card,home_overview_card}.dart` | C02 for settings; C03 for completion/multi-select; preserve user section visibility/order and services. |
| Remaining `features/home/widgets/`, `home_screen.dart` | C01, C06–C08; shared typography; preserve current card content/order and personalized header/assistant name. Remove only verbatim duplicate adjacent labels within the same card, retaining the first occurrence. |
| `features/reminders/` | C01, C02, C05, C06, C08, C09; retain date bounds, repeat rules, alarms, protection, confirmations, and edit routes. |
| `features/today/` | C01–C06, C08; switches only for settings, checkmarks for completion; preserve task states and scheduling. |
| `features/focus/`, `shared/widgets/live_session_bar.dart` | C01, C06, C08; timer role; preserve clock logic, running state, task switching, and session bar placement. |
| `features/money/` | C01, C04–C06, C08; Expense/Income remains mutually exclusive; preserve calculations, signs, currency, budgets, and categories. |
| `features/plans/` | C01–C06, C08; retain dependencies, repeat rules, locks, protected reminders, and scheduling behavior. |
| `features/promises/` | C01–C06, C08; preserve proposal/reflection/chat structure, calendar dates, schedules, and commitments. |
| `features/study_plan/` | C01–C06, C08, C10; preserve course/module/lecture selection, playback and completion. |
| `features/medicine/` | C01, C05, C06, C08; preserve dosage units, time validation, reminders, and protected actions. |
| `features/thought_wall/` | C01, C03–C06, C08, C09; preserve user appearance/density, capture, merge, archive, undo, and data. |
| `features/vault/`, `features/resume_vault/` | C01, C05, C06, C08 for chrome; preserve credential artwork, masking, encryption, authentication, auto-lock, and file handling. |
| `features/{analytics,consistency,momentum,dsa,interview_prep,pipeline}/` | C01, C03–C06, C08, C10 wherever corresponding controls already exist; no new filters or charts. |
| `features/{hydration,walk,chai_break}/` | Shared buttons, text, cards, menus/sheets; C10 for existing sliders. Preserve maps, tracking, custom water/breathing/cup artwork and sound controls. |
| `features/ai_assistant/`, `shared/widgets/{message_composer,chat_bubble_card}.dart` | Shared text/control/surface roles; preserve conversation behavior, streaming, message layout, and action confirmation. |
| `features/book_reader/` | Shared menu/slider/button chrome only; preserve reading canvas, reading font settings, pagination and annotations. |
| `features/{more,backup,onboarding,splash}/`, drawer and remaining shared widgets | Apply common text, surfaces, buttons and existing fields only. Preserve onboarding steps, branding/logo, backups and navigation. |

For any existing screen not matched above, apply shared component changes only. Do not invent a new local layout. For any specialized graphic whose appearance is not specified, preserve it.

## 7. Implementation sequence and change boundaries

1. Record the starting commit and working-tree diff. Preserve all user/uncommitted changes. Read `AGENTS.md`, `DESIGN_SYSTEM.md`, and `COMPONENT_CATALOG.md`; inspect actual component APIs.
2. Implement tokens/typography and fix the dark blue button color pair. Build a local component gallery using synthetic data under test tooling; do not add a production route or menu entry.
3. Implement C01–C10 in shared components, keeping existing APIs compatible. Add the two explicitly specified wrappers. Remove double haptics introduced by shared ownership.
4. Migrate the matrix screens in its listed order. Remove only overrides that conflict with this handoff. Do not refactor unrelated state/database/service code.
5. Complete section 8. Fix failures caused by this work. Record pre-existing failures separately with baseline evidence. Do not change test expectations simply to make a failure disappear.
6. Provide a diff, test results, screenshot evidence, and requirement checklist. Delete temporary plans. Retain this specification, the review, and completion evidence. No claim of completion while required visual checks remain unverified.

## 8. Required verification and pass/fail criteria

Use synthetic fixtures on an emulator/test harness. No personal records may be created, changed, archived, deleted, or marked complete for testing on the user's phone.

### 8.1 Automated checks

- Run `flutter analyze` and the repository's relevant existing tests. Run theme/contrast, Home, reminder, privacy/lock, and shared interaction tests impacted by the change. Record commands and outcomes.
- Add meaningful parameterized checks for the six theme/appearance combinations: specified token roles resolve correctly; enabled text/background pairs meet contrast; icons/required boundaries meet 3:1 against adjacent backgrounds.
- Body/helper/button text must meet at least 4.5:1. Large text may meet 3:1 only at 24 logical pixels regular or 18.67 bold and above. Decorative separators need not meet control-boundary contrast. Test actual composites when alpha is used.
- Verify a switch activated through row tap, switch tap, keyboard/screen-reader action changes exactly once. Verify busy, disabled, failure, and local-form behavior.
- Verify canceled pointer gestures do not emit haptics or invoke actions; accepted activation emits only one haptic. Loading suppresses repeated submission. Reduced motion disables custom scale/highlight motion.
- Verify system appearance changes update the UI while preserving the selected preset and all stored preferences.

### 8.2 Screenshot matrix

Create screenshots with fixed synthetic content and record device dimensions, text scale, preset, and mode. Required fixture states: normal, empty, long title, long helper, disabled, loading, validation error, menu open, sheet with keyboard, focused input, selected/unselected controls, and swipe reveal.

| Set | Required captures |
| --- | --- |
| Component gallery | All controls/states, all three presets × light/dark, at width 390 and 100% text. |
| Primary flows | Home, settings, customization, reminder editor, Focus, Money, Thought Wall: blue light/dark at widths 360, 390, 430, 100% text. |
| Large text | Same seven flows: blue light/dark, width 360, 200% text. |
| Remaining features | Every screen group in section 6: one populated view and its main existing editor/menu in blue light/dark, width 390. |
| Theme regression | Home, settings and one editor each in Merlot/Clay light/dark, width 360, 200% text. |
| Gestures | Each distinct enabled swipe implementation: before/partial/threshold/cancel states in light/dark; opposite disabled direction remains unchanged. |

Pass only when: no overflow stripes, clipped text, unintended horizontal scroll, white swipe gaps, obscured actions, keyboard-covered fields, duplicate visible adjacent card labels, wrong-appearance popups, or incorrect safe-area padding appears. Large-text controls expand or stack. Check touch targets with layout/semantics bounds, not screenshot estimates.

### 8.3 Interaction and device checks

Verify tab stacks/back, form cancel/unsaved protection, picker cancel, save success/failure, completion, archive undo, protected reminders, vault lock, focus pause/resume, slider seeking, and screen-reader labels/order. Use existing fixture capabilities; do not introduce unrelated production changes just to make a test easier. Check high-contrast and reduced-motion behavior. Measure scrolling in profile mode on the target Android device/emulator; report frame timings and any new sustained jank relative to baseline.

If the user's phone is connected, inspect the existing package and signing certificate before any update. Privately back up app data, build the matching variant, install only with `adb install -r`, and verify original data is unchanged before launch. Never uninstall, clear data, change application ID, or install another variant as a workaround. Signing/package mismatch is a blocker; report it without resetting anything. If no phone is available, record phone validation as pending; do not claim it passed.

## 9. Required delivery package

Deliver the code diff and a completion record containing one row for each C01–C10 plus each section 6 screen group: status (`PASS`, `FAIL`, or `NOT VERIFIED`), changed files, test evidence, screenshot filenames, and remaining defect/blocker. Summarize preserved user settings/data verification separately without exposing personal content or backup files.

The visual upgrade is complete only when all implementation requirements and applicable acceptance checks pass. An unavailable phone may be recorded explicitly as pending device validation; it must never be represented as a completed check. Keep design choices exactly as specified. Any requested deviation must identify the requirement, technical reason, and proposed replacement for the owner to decide before it is applied.

## 10. Research references

These explain the design principles; the exact Ascent values above are fixed project decisions, not a claim that they reproduce native iOS components.

- [Apple: Color](https://developer.apple.com/design/human-interface-guidelines/color)
- [Apple: Materials](https://developer.apple.com/design/human-interface-guidelines/materials)
- [Apple: Toggles](https://developer.apple.com/design/human-interface-guidelines/toggles)
- [Apple: Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode)
- [Apple: Typography](https://developer.apple.com/design/human-interface-guidelines/typography)
- [Apple: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility)
- [Apple: Motion](https://developer.apple.com/design/human-interface-guidelines/motion)
