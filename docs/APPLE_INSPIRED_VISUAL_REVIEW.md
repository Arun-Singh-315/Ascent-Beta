# Ascent: Apple-inspired visual and interaction review

Reviewed 29 October 2026. Requested deliverable: research and recommendations, without implementing a redesign.

## Recommendation

Evolve Ascent toward a calm, precise interface: neutral content surfaces, one consistent action accent, readable typography, familiar grouped settings, and responsive controls. Use selective glass for floating navigation and transient controls. The premium effect should come from hierarchy, alignment, restraint, and reliable interactions.

Use the existing Clear Sky/Nordic Sky theme as the starting point for an Apple-inspired blue direction. Keep Merlot as an intentional alternative. Avoid introducing a competing blue system into every existing theme before validating a coherent light/dark pair.

## Scope and confidence

This is a source-code and documentation review of the current working tree, including its existing uncommitted changes. Reviewed theme tokens, typography, shared buttons/surfaces/navigation, switch styling and usages, reminder forms, date/time selection, and the Thought Wall archive gesture. No application code or personal data was changed. No Android device was connected when checked; no rendered mobile walkthrough was performed. Recommendations about overall screen balance require visual validation before implementation is accepted.

Apple's current Human Interface Guidelines were consulted directly, including their Markdown versions. References are linked below. Proposed Ascent values and timings are design recommendations, not Apple specifications.

## What already works

- Semantic themes and paired appearances exist in `lib/app/theme/`.
- `frozen_palette.dart` already defines a blue action family, neutral supporting text, and separate success/warning/danger roles.
- `merlot_palette.dart` already provides neutral charcoal night surfaces with a stepped elevated surface.
- `GlassSurface` now defaults to opaque content and opt-in blur. This is a good foundation for the content/control distinction in Apple's materials guidance.
- `AscentButton` already provides named variants, loading/disabled behavior, a 110 ms press animation, and haptics.
- Navigation already preserves tab stacks and supplies selection feedback.
- Theme mode already defaults to the system preference. Preserve this behavior.
- Thought Wall already has separate themed backgrounds for both swipe directions. Reuse that implementation as the gesture reference.

## Findings and priorities

| Priority | Evidence in the app | Recommendation |
| --- | --- | --- |
| P0 | The Clear Sky dark primary button resolves to white foreground on `FrozenPalette.darkAction` (`#5EA0F0`). The solid token pair calculates to approximately 2.71:1. | Give filled buttons their own foreground/background pair. Use dark ink on the bright blue or a darker blue with white. Verify every enabled/pressed/loading state against its rendered background. |
| P1 | Forms mix `Switch`, `SwitchListTile`, and `SwitchListTile.adaptive` across Home, reminders, promises, plans, and course/activity editors. | Establish one shared switch-row pattern and a documented platform policy. An adaptive switch on Android will not automatically acquire the iPhone appearance. |
| P1 | Switch theme uses `MaterialTapTargetSize.shrinkWrap`; selected Merlot night track is muted brown and the thumb is gray. | Make on/off differences unmistakable through position, fill, and contrast. Measure the entire interactive row, not just the switch graphic. |
| P1 | Primary button geometry differs by palette: Clear Sky uses 20/16 radii and 42/32 visual height; other themes use 10/8 radii with scaled height. | Define stable component geometry across themes; let color express the theme. Preserve large-text expansion and padded hit regions. Visual height alone does not establish actual touch target size. |
| P1 | The core scale uses Jakarta Sans and DM Sans, with additional Inter, Bricolage, and JetBrains recipes in the broader typography system. Many compact type recipes exist. | Reduce everyday UI to one sans family and a short role scale; retain a distinct display treatment only where useful. Reserve mono for genuine numeric/technical needs. |
| P2 | Shared input theme uses outlined fields; reminder and scheduling flows invoke Material date/time dialogs. | Introduce quieter grouped field layouts and consistent picker entry rows. Reuse the established schedule picker and reminder behavior instead of redesigning each form separately. |
| P2 | Several surface systems and palette-specific branches coexist. | Align semantic roles across `ColorScheme`, `AscentGlass`, and `AppSurfaces`. A change of palette should not change which controls appear primary or interactive. |

The contrast finding uses WCAG relative luminance for opaque sRGB token pairs. It is a reproducible token-level finding, not a full screenshot accessibility audit. For comparison, white on the existing light blue `#1D64B4` is approximately 5.94:1.

## Blue and color strategy

Apple does not use one permanent blue everywhere. Its colors adapt to appearance, contrast settings, materials, and platform releases. The current HIG table lists reference blue values of RGB 0/136/255 (`#0088FF`) in light appearance and 0/145/255 (`#0091FF`) in dark appearance, plus increased-contrast variants. These are reference swatches, not values to hard-code as universal native colors. On Apple platforms, prefer semantic system APIs where appropriate.

For Ascent's custom Flutter theme, use an explicit, independently validated palette. Recommended starting point:

| Semantic role | Day proposal | Night proposal | Usage |
| --- | --- | --- | --- |
| Canvas | `#F5F5F7` | `#171819` | Calm page background |
| Content surface | `#FFFFFF` | `#202224` | Lists and readable cards |
| Elevated surface | `#FFFFFF` | `#292B2D` | Sheets and menus; separate by placement/rim in day mode |
| Primary text | `#1D1D1F` | `#F3F1EC` | Titles and body |
| Action ink | Start from existing `#1D64B4` | Start from existing `#5EA0F0` | Links and selected indicators on neutral backgrounds |
| Filled primary action | `#1D64B4` + white text | Bright blue + dark ink, or darker blue + white | Separate button tokens; validate the chosen pair |

These are proposed Ascent tokens, not a claim that Apple uses this complete palette. All secondary text, borders, disabled states, and semantic statuses still require contrast checks.

Use blue for navigation selection, links, focus, selected segments, and principal actions. Keep ordinary titles and body text neutral. Keep success green, warning amber, and destructive actions red, reinforced by an icon or label. Preserve meaningful feature accents such as hydration and finance where they help recognition, but keep action styling consistent within those screens.

Avoid making every progress ring blue if that erases meaningful categories. Avoid using action blue for decorative, untappable text. Do not transfer Merlot's light/dark colors into the blue variant through unrelated helper branches.

## Controls and tap behavior

### Switches

Use rounded switch controls in grouped settings rows: label at the leading edge, optional concise helper text, switch at the trailing edge. Suitable examples include reminders enabled, repeat enabled, and Home section visibility. A switch changes state immediately; it should not open a picker or represent a multi-choice value.

Apple recommends switch-style toggles in list rows and normally uses green, while permitting an app accent when needed. Recommended Ascent policy: green for simple settings enabled/disabled, blue for selected filters and action buttons. If preserving blue switches is preferred, apply it consistently across the blue theme. Retain checkboxes/checkmarks for completion and multi-selection.

Specify on/off/disabled/loading states, semantic labels, announced state, and persistence failures. Do not announce success before a save succeeds. Make the row comfortably tappable without creating two competing accessibility elements for one toggle.

### Buttons, cards, and feedback

- Use one filled primary action in a local decision group, tonal secondary actions, and low-emphasis text actions for optional choices.
- Keep the existing brief press feedback, but reduce the current 0.96 scale if it feels exaggerated on large cards. A 0.98–0.99 trial is a proposal to validate on-device.
- The current haptic fires on pointer-down, even if the gesture is later canceled. Prefer feedback tied to an accepted action or meaningful selection; avoid buzzing for every incidental touch.
- Give tappable rows a consistent pressed surface, chevron where they navigate, and appropriate semantics. Preserve individual buttons within cards without making the whole card ambiguously interactive.
- Keep hit regions at least 48 Flutter logical pixels for the Android experience; Apple's default iOS control-size recommendation is 44×44 points. These units are platform design conventions, not physical-pixel equivalence.
- Add reduced-motion behavior and prevent repeated taps during writes. Preserve a stable label and size while loading.

### Segments, forms, and pickers

Use a shared segmented control for short, mutually exclusive choices such as Expense/Income or Today/Upcoming where those options fit the flow. Use a neutral track and a clearly selected segment, with color plus shape/position. Do not use several independently active filter chips to imply a single-choice segment.

For fields, prefer persistent labels, a quiet filled or grouped surface, a clear focus accent, and inline validation. Use appropriate keyboards and keyboard actions. Date/time rows should show the chosen value and open a consistent sheet/dialog. Wheel pickers may suit quick time selection on iOS; calendar selection is clearer for distant dates. Respect locale and 12/24-hour preferences.

## Day, night, layout, and materials

Day: neutral soft-gray canvas, clean content surfaces, dark readable text, restrained shadows, and hairline separators. Reduce blue washes over large reading areas. Keep nested cards limited so the page does not become a stack of outlines.

Night: preserve the existing Merlot charcoal surface ladder as a useful structural reference. Use a brighter blue for small interactive ink, with independently chosen filled-button colors. Separate sheets through lighter elevation and a subtle rim. Avoid depending on black shadows for depth or glowing outlines for every card.

Glass: reserve it for a floating tab bar, transient menus, or selected floating controls. Avoid glass on every Home card, text field, chart, and nested row. Flutter blur is a custom approximation; it does not reproduce Apple's native adaptive Liquid Glass behavior automatically. Provide opaque fallbacks for reduced transparency and profile scrolling performance.

Typography: trial 16–17 logical-pixel body text, 13–14 supporting text, and 28–32 screen titles where space permits. These are Ascent design proposals. Use regular body weight and selective semibold emphasis; avoid making most labels bold. Use tabular figures for timers and aligned amounts without making every number monospaced. Support 200% text scaling with reflow rather than clipping.

Spacing: reuse existing 4/8/12/16/24/32 spacing tokens. Align card text, section headers, and row content to consistent gutters. Keep one clear title per card and remove subtitle/badge duplication only when confirmed in the rendered screen.

## Familiar Apple patterns that fit Ascent

| Familiar pattern | Application in Ascent | Scope |
| --- | --- | --- |
| Settings-style grouped lists | Appearance, reminders, privacy, Home customization | Visual/control refinement |
| Reminders-style completion and contextual actions | Task board, Thought Wall, reminders | Reuse archive geometry; completion remains distinct from settings switches |
| Sheets with a clear title and action | Add task, medicine editor, transaction editor | Preserve keyboard handling, unsaved input, safe areas, and dismissal rules |
| Timer-style emphasis | Focus screen and live session bar | One readable timer, clear pause/resume, restrained secondary information |
| Quiet summaries with drill-down | Analytics, money, consistency | Clear headline value, range selection, accessible chart labels |
| Search and contextual menus | Thought Wall, learning catalog, vault | Expose common actions; preserve visible alternatives to gestures |
| Widgets, shortcuts, or Live Activities | Future quick capture and focus-session access | Separate platform integration work; not delivered by visual styling |

Keep Android back behavior and platform permission/picker expectations coherent. Use Apple's principles and familiar interaction structure while preserving Ascent's identity and the operating system's behavior.

## Suggested order and acceptance criteria

1. Correct color pairs and define shared roles for buttons, switches, fields, segments, and feedback. Start with contrast and state clarity.
2. Polish Home, appearance/customization, reminder editing, and focus as representative flows. Refine one component system before propagating it.
3. Apply the validated system to plans, course editors, medicine, money, Thought Wall, and vault. Preserve specialized reader/player experiences where appropriate.
4. Consider optional native integrations only after the core experience is consistent.

Before accepting implementation: inspect at 360/390/430 logical-pixel widths; test day/night and system switching; normal and 200% text; long labels; loading/error/disabled/selected states; screen-reader order; reduced motion/transparency; keyboard and safe areas; and scroll performance. Test both swipe directions against the existing archive implementation, with no white reveal gaps. Verify dialogs, date/time pickers, menus, and snackbars as well as page backgrounds.

On a connected phone, inspect the existing app without editing personal records for testing. Any Android update must follow the repository's package/signing inspection, private data backup, replacement-install, and unchanged-data verification requirements.

## Primary research sources

- [Apple HIG: Color](https://developer.apple.com/design/human-interface-guidelines/color) — semantic colors, current reference swatches, restrained color use, contrast variants.
- [Apple HIG: Materials](https://developer.apple.com/design/human-interface-guidelines/materials) — separate controls from content and use Liquid Glass sparingly.
- [Apple HIG: Toggles](https://developer.apple.com/design/human-interface-guidelines/toggles) — switch placement, state clarity, green default, and accent customization.
- [Apple HIG: Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode) — adaptive appearance, elevated surfaces, and legibility.
- [Apple HIG: Typography](https://developer.apple.com/design/human-interface-guidelines/typography) — text hierarchy, system/custom fonts, and Dynamic Type.
- [Apple HIG: Accessibility](https://developer.apple.com/design/human-interface-guidelines/accessibility) — control sizes, text scaling, contrast, and gesture alternatives.
- [Apple HIG: Motion](https://developer.apple.com/design/human-interface-guidelines/motion) — brief, purposeful feedback and optional motion.

Native Apple system fonts should be accessed through platform APIs; do not bundle Apple font files into the Android app to imitate iPhone typography.
