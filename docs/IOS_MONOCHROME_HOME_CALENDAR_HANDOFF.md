# Ascent: crisp monochrome Home and Calendar implementation handoff

Date: 9 November 2026. Status: **implementation in progress; batch 2 checkpoint below**.

Requested outcome: keep the recently improved Home experience, make the current-date blue much quieter, and apply an iPhone-inspired visual discipline: clear typography, white/light-grey surfaces, true-black dark canvas, restrained cards, and clean Back/Next controls. This is a maintained user-requested handoff, not a temporary planning file.

## 0. Live implementation checkpoint — batch 2, 9 November 2026

This table is the resume point. “Complete” describes the bounded deliverable in that row, not every screen that will eventually use the new tokens. No percentage estimate: the remaining screens vary substantially in effort.

| ID | Deliverable | Status | Evidence / remaining boundary |
|---|---|---|---|
| B01 | Neutral surface tokens and Home canvas | Complete | Added `MonochromeSurfaces` with light/dark interpolation; mapped Home canvas, primary surfaces, icons and text colours. Dark canvas is black. Other routes/overlays remain to be migrated. |
| B02 | Subtle Home calendar date design | Complete | Shared `AscentCalendarDay` uses a small neutral today disc, separate tiny blue today marker and neutral scheduled marker. Home has no persistent selection; date routes/week browsing/error states retained. Removed redundant tap helper. |
| B03 | Header base styling | Complete | Neutral background, DM Sans greeting/name/date, lighter title weight, quiet circular controls, capped illustration opacity and four preserved time scenes. Existing optional festival/zodiac decoration remains for B07's detailed row audit. |
| B04 | Typography across all scoped screens | Partial | Added semantic DM Sans roles; applied to header, Home Calendar, full Calendar and agenda. Brief, Rhythm and other Home rows still use older recipes. Do not globally replace legacy recipes. |
| B05 | Full calendar / agenda | Complete | Shared date discs distinguish selected/today/events; neutral agenda rows, category labels and festival banner; readable 7-date week list on narrow/large-text screens; month/week navigation, Today, completion and routes retained. Calendar-only neutral theme restores the original preset when returning to list mode. App-bar actions remain in a labelled More menu. |
| B06 | Daily Brief visual migration | Pending — next | Neutral pages, restrained shared tabs, labelled Back/Next footer, scoped root overlay theme. Preserve PageStorage/live refresh safeguards. |
| B07 | Daily Rhythm and remaining Home cards | Pending | One hero surface, quieter artwork, shared selectors and row-by-row typography. `HomeOutlineSurface` now has no normal-contrast border; full surface hierarchy work is still required. |
| B08 | Shared navigation / overlay scope | Pending | Restrained segmented appearance, neutral navigation button treatment, bottom nav and sheet/root-dialog theme propagation. Existing other presets are preserved. |
| B09 | Final cross-screen and device release checks | Pending | Run after remaining screens are complete. No APK built or installed in batches 1–2. |

Batch 1 verification: **20 tests passed** across `home_calendar_test.dart`, `home_approved_layout_test.dart`, `home_day_layout_test.dart`, and `home_first_moment_and_rhythm_test.dart`. Includes real-date agenda routing, separate today/scheduled semantics, all four header periods, light/dark and 200% layouts, visible Rhythm tools and water/Undo behaviour. Scoped analysis of the 10 edited/new code and test files passed with no issues; `git diff --check` passed. A repository-wide analysis also reported issues outside the batch's files (Capture, Vault, integration tests and older tests); those unrelated findings were not fixed in this pass.

Mock-data screenshots were visually reviewed for the quiet calendar, large-text dark calendar, and night header; automated tests also capture full Home layouts. QA files are under ignored `build/qa/monochrome-home/` (`tests.log`, `analyze.log`, calendar `before/` and `after/`, header captures). Original baseline calendar screenshots did not load MaterialIcons, so their square icon glyphs are a test-harness limitation, corrected in the after captures. Existing full-Home captures are under `build/qa/home-refinement/`. No personal device records were used or changed. This is widget/mobile-viewport verification, not an installed-app review; no APK was built or installed.

Batch 2 verification: **31 tests passed** across `home_calendar_test.dart`, `reminders_calendar_integration_test.dart`, `festival_and_things_calendar_test.dart`, `reminders_ground_redesign_test.dart`, and `reminder_actions_test.dart`. Includes selected/today independence, actual-date agenda routing, compact/full calendar month changes, accessible week navigation, return to Today, read-only browsing, completion controls and existing list behaviour. Scoped analysis of all 6 edited/new source/test files passed with no issues; `git diff --check` passed. The reminder plugin is not initialized in widget tests and prints existing notification-service diagnostics; assertions still pass. This does not verify Android alarm delivery.

Batch 2 screenshots: `build/qa/monochrome-calendar/light-1.0.png`, `dark-1.0.png`, `light-2.0.png`, and `dark-2.0.png`; mock data, 390/320 logical-pixel viewports. Reviewed normal dark month and large-text light week layouts. Final logs: `build/qa/monochrome-calendar/tests.log` and `analyze.log`. The long date list scrolls with the page rather than introducing nested scrolling. Full date labels remain available to screen readers even though the visible week-row date uses an abbreviated month. Normal month navigation wraps beneath the title where the title and 48-pixel controls do not fit one row.

One navigation correction was necessary: month arrows now update the displayed compact week even when the selected date belongs to another month. Selection and agenda filtering remain unchanged. Reminder/task completion and Undo handlers remain intact; no provider, database schema, reminder scheduling, or notification service changes were made. The expanded month intentionally occupies more height for readable 17-pixel date labels. Popup/sheet surfaces and global bottom navigation are still B08; this batch does not claim those are finished.

**Next action:** Continue with **B06**, then B07 and B08; finish B04 typography migration within those screen passes and B09 last. Do not repeat B01–B03/B05 unless a failing check requires a fix. Current count: **4 complete, 1 partial, 4 pending**. No APK built or installed; on-phone visual review remains pending.

## 1. Instructions for the implementing IDE

Implement this document in order. Use the exact decisions below; do not invent another design, change the information architecture, or replace working features. Preserve the existing uncommitted Home/Calendar/Daily Brief work. Read the repository's AGENTS.md before editing.

This document takes precedence over conflicting **visual recommendations for the scoped screens** in APPLE_INSPIRED_IMPLEMENTATION_HANDOFF.md and APPLE_INSPIRED_VISUAL_REVIEW.md. Their older blue-heavy palette and mixed display-font direction are not the target here. Existing repository interaction and data rules remain in force.

The follow-up request authorizes sequential implementation with an explicit completed/remaining checkpoint. Installation is not part of this batch. A later installation request must follow the device rules in section 11.

### Preserve these accepted decisions

- Calendar stays immediately beneath the Home greeting, ahead of Your space.
- Header scenery still changes with morning, afternoon, evening, and night.
- Daily Rhythm retains its large illustrated active card, visible tool selectors, neighbouring-card hints, swipe, and previous/next controls. Never hide the available tools behind dots alone.
- Daily Brief retains Overview, Focus, and Reset, real personal data, useful destinations, and manual entry from Home.
- Keep module visibility preferences, route parameters, gesture direction, reduced-motion handling, and accessibility semantics.
- Do not change storage, task ordering, reminders, date calculations, logging amounts, undo, popup frequency, or notification routing for a visual change.

## 2. Source audit: where the improvement belongs

These findings come from the current source checkout, including the new uncommitted widgets. They are not a fresh device screenshot review. Line numbers will drift; locate the named classes/functions.

| Priority | Area and current observation | Required result | Main file(s) |
|---|---|---|---|
| P0 | Home Calendar fills the entire today tile blue | Small quiet date disc; no full-height blue pill | `lib/features/home/widgets/home_calendar.dart` |
| P0 | Home canvas is cream; dark surfaces lean navy | Neutral white/grey light mode and black/charcoal dark mode | `home_theme.dart`, `home_day_design.dart` in the same directory |
| P0 | Heading/body recipes mix DM Sans, Jakarta, Bricolage and mono | One consistent interface family with fewer weights | `lib/app/theme/text_styles.dart` and scoped consumers |
| P1 | Full Calendar uses blue selection fill/border and differently coloured event dots | Match Home date states; neutral event markers and labelled agenda categories | `lib/features/reminders/reminders_screen.dart` |
| P1 | Daily Brief has a different broad gradient on every page | One neutral dialog surface, quiet artwork, clear hierarchy | `lib/features/home/widgets/daily_welcome_dialog.dart` |
| P1 | Brief footer has icon-only Back and blue Next | Visible Back and Next/Done text, same baseline, neutral navigation ink | Same file |
| P1 | Daily Rhythm combines outer enclosure, inner card, colourful washes and accented selector | One main card hierarchy with restrained illustration colour | `lib/features/home/widgets/home_life_shelf.dart` |
| P1 | Home sections repeat outlined boxes and strong headings | Use spacing and grouped rows; reserve full cards for the primary experiences | Home section widgets listed in section 8 |
| P2 | Shared bottom navigation uses tonal capsules from the selected app preset | A neutral capsule treatment within the new monochrome appearance | `lib/shared/widgets/main_scaffold.dart` |
| P2 | Sheets/buttons can inherit a different palette from Home | Matching neutral overlay surfaces and navigation controls | Shared surface/button tokens and Home entry sheets |

## 3. Fixed visual tokens

All dimensions below are Flutter logical pixels. These are **Ascent design decisions**, not claims about exact Apple system values. Centralize them; do not scatter new hex colours through screen widgets.

Add a `MonochromeSurfaces` ThemeExtension in `lib/app/theme/monochrome_surfaces.dart`. It owns the neutral roles below, supports `copyWith`/`lerp`, and is supplied for both brightness modes. Map it into existing AscentGlass/AppSurfaces at the scoped theme boundary so existing components keep working. Do not build a parallel card framework.

| Role | Light | Dark | Use |
|---|---|---|---|
| canvas | `#F5F5F7` | `#000000` | Page background |
| surface | `#FFFFFF` | `#1C1C1E` | Main cards and calendar |
| elevated | `#FFFFFF` | `#2C2C2E` | Dialogs/sheets above the page |
| groupedFill | `#EFEFF1` | `#252527` | Recessed control tracks and inline groups |
| primaryText/navigationInk | `#1C1C1E` | `#F5F5F7` | Titles, body, Back/Next, navigation icons |
| secondaryText | `#636366` | `#AEAEB2` | Dates, explanations and metadata |
| tertiaryText | `#6C6C70` | `#98989D` | Noncritical supporting labels |
| separator | `#E5E5EA` | `#38383A` | Decorative hairlines, not sole control boundaries |
| controlOutline | `#76767A` | `#8E8E93` | A boundary when required to identify a control |
| neutralSelection | `#E9E9ED` | `#38383A` | Selected navigation segment/date disc |
| pressedFill | `#E5E5EA` | `#3A3A3C` | Visible pressed feedback |
| disabledText | `#8E8E93` | `#757579` | Disabled controls only |

Use primary/secondary text at full specified opacity. Do not make small text faint by repeatedly applying opacity. Check actual composited contrast: normal text at least 4.5:1; large text and meaningful control graphics at least 3:1. Decorative separators need not become heavy dark borders. In high contrast, use controlOutline where a boundary communicates a control or state.

### Colour policy: small functional accents

`SharedControlColors` continues to own action blue, selection blue, overdue/destructive red, and shared interaction states. Retain its existing light/dark blue and red values. Do not globally redefine blue as black.

- Black/white navigation ink: Back, Next, Done/dismiss, chevrons, month navigation, opening a section, tab labels, headings, and ordinary text.
- Blue: a small today marker, the thin selected indicator in selectors, actionable inline links, active input focus, selected form options, switch-on state, and the single primary data action such as Log water or Add task.
- Red: genuinely overdue/destructive information, with a textual or icon cue. Past calendar dates alone are not overdue.
- Neutral: category labels, counts, structural icons, event dots, ordinary progress context.
- User-selected importance remains a star. No yellow priority badge.
- Do not add green success panels, amber task chips, or pink/purple background washes to these surfaces. Existing user-authored content colours are preserved.

This gives the requested predominantly black-and-white look while retaining the shared semantic interaction rules.

## 4. Typography: make the text feel crisp

Use **DM Sans**, already shipped in `assets/fonts/`, for this scope. It minimizes font churn and works offline; runtime Google Fonts fetching is disabled in main.dart. Use the existing GoogleFonts.dmSans path with bundled files. Do not add a network font dependency or download Apple's SF fonts. This is an iOS-inspired composition, not a claim of native iOS typography.

Define/reuse named semantic roles in AscentTextStyles. Migrate the scoped widgets to these roles. Do not globally rewrite the large legacy AppTypography recipe list: it has unrelated consumers.

| Role | Size | Weight | Line height | Tracking |
|---|---:|---:|---:|---:|
| Home name / page display | 32 | 600 | 1.12 | -0.6 |
| Brief page title | 28 | 600 | 1.15 | -0.4 |
| Section heading | 22 | 600 | 1.20 | -0.3 |
| Card / agenda title | 20 | 600 | 1.25 | -0.2 |
| Body / main list row | 17 | 400 | 1.40 | 0 |
| Button / navigation | 17 | 600 | 1.20 | 0 |
| Supporting text | 15 | 400 | 1.35 | 0 |
| Compact label | 13 | 500 | 1.30 | 0 |
| Calendar date | 17 | 600 | 1.20 | 0 |
| Metric | 30 | 600 | 1.10 | -0.4 |

- Keep sentence case: Daily brief, Daily rhythm, Due today, Next reminder. Remove decorative all-caps blue eyebrows; genuine weekday abbreviations remain uppercase.
- Do not use weight 800/900 in this scope. Use 600 for hierarchy; 700 only for an exceptional accessibility emphasis, not the default.
- Use tabular figures for changing metrics and calendar numerals. Keep JetBrains Mono only for existing dedicated timer/code displays outside this typography migration.
- Use one primary heading per card, one explanatory line only when it adds information. Do not repeat the heading in its subtitle.
- Respect system text scaling; no fixed-height text containers, shrinking body text with FittedBox, or global text-scale clamp.
- At 200%, allow multi-line titles, vertically arranged metrics and existing segmented-control fallback. Keep full task/reminder titles readable in their detail destination.

## 5. Geometry and surface hierarchy

Use the existing AppSpace/AscentDimensions owners for spacing and radii; add named constants there when needed.

- Page horizontal margin: 20. At widths below 360, use 16 consistently across all Home sections.
- Main section gap: 24. Header-to-calendar gap: 12. Heading-to-content gap: 12. Inline row gap: 8.
- Main card padding: 16. Hero/Daily Brief content padding: 20.
- Main card radius: 24. Dialog and active rhythm card: 28. Small inline group: 16. Controls: 12. Circular icons stay circular.
- Use opaque surfaces. Standard content cards have no blur, no shadow, and no visible border in normal contrast; surface/background difference establishes grouping.
- In high contrast, allow a 1-pixel neutral outline. Keep an outline around form controls when needed for identification.
- A surface must not contain a second full card unless it represents independently actionable content. Prefer inset separators and whitespace for rows.
- Keep existing restrained navigation blur only. Do not add blur to every card, or attempt a new Liquid Glass rendering system.
- Every action target: at least 48 high. For compact seven-column calendars, allow 44 minimum width on narrow screens; prevent overlapping hit regions. At 320 widths use the explicit large/narrow layout described below.
- Press feedback: neutral pressedFill, existing haptic conventions, 120 ms colour transition. Page transitions: 220 ms easeOutCubic. Reduce Motion: immediate state change; no parallax or bounce.

## 6. Calendar: first implementation priority

### Home calendar

Edit `HomeCalendar` in `home_calendar.dart`. Keep week offsets, Monday boundaries, providers, destination query parameters, keys, empty/loading/error states, and Back to today functionality.

1. Remove the full blue fill from the today tile. The weekday, date, and event area must not share a blue background.
2. Ordinary dates: transparent cell, primaryText numeral; weekday label secondaryText.
3. Today: **32 × 32 neutralSelection circle around the numeral only**, primaryText numeral. Add a **3 × 3 blue dot directly below the numeral disc**, separated by 3 pixels. Weekday stays outside the disc.
4. Scheduled content: one 4 × 4 neutral secondaryText dot in a separate event-marker row below the today marker slot. Reserve identical vertical space on all dates. Never reuse the blue today marker to mean scheduled content.
5. At large text, the numeral disc may grow to 40 and then to the measured numeral size plus 12 padding; do not clip scaled text. The surrounding cell grows naturally.
6. Home has no persistent selected date: tapping a date opens the full agenda immediately. Do not introduce a selection provider or retain a second blue active tile.
7. Calendar heading: sectionHeading 22/600. Month/week range: supporting 15/400. Previous/next: neutral chevrons 18 inside 48 targets. Today return control: neutral text button.
8. Remove the permanent helper sentence “Tap a date to see your day”; retain useful error/loading messages. Each date's semantic label includes full date, Today if applicable, and Has scheduled items if true.
9. Preserve the existing seven-column normal layout and 4+3 narrow/large-text fallback. Never horizontally scroll dates offscreen merely to preserve seven columns.

**Result:** substantially less blue than the current pill, while today remains unmistakable through shape, position, semantics, and a tiny blue accent.

### Full calendar / agenda

Edit `_buildGoogleCalendarView`, `_buildWeekStrip`, `_buildMonthGrid`, and `_buildCalendarDayCell` in `reminders_screen.dart`; do not rewrite their filtering and deduplication logic.

| Date state | Visual result |
|---|---|
| Ordinary current-month date | Transparent, primary numeral |
| Outside-month date | Transparent, secondary numeral; remains tappable |
| Today, not selected | Same neutral date disc + tiny blue today marker as Home |
| Selected, not today | Neutral date disc with 1.5-pixel controlOutline ring; no blue block |
| Selected and today | Neutral disc + selection ring + blue today marker |
| Has scheduled content | One neutral event dot in the event row, independent of today/selection |
| Festival | Preserve festival data and agenda row; no separate coloured day-cell fill/border |

- Extract a shared presentational calendar date widget into `lib/shared/widgets/ascent_calendar_day.dart` and use it in both calendars. Inputs: date, today, selected, outsideMonth, hasScheduledItems, semantic label, onTap, optional weekday label. Keep data providers outside it.
- Keep selected and today semantics distinct. Dates do not become disabled just because they are in the past.
- Month title left; Today plus previous/next chevrons right on one baseline. Wrap controls below at large text. Preserve expand/collapse functionality and tooltip.
- At normal text the month grid stays seven columns. At 320/200%, switch to a labelled, scrollable vertical week agenda within the existing calendar mode: month controls, week previous/next, then seven date rows with full weekday/date and event presence. Each row selects its date. Do not compress numerals to illegibility or alter the Home 4+3 layout.
- Use 17/400 agenda rows, 15 secondary time metadata, neutral category icons. Replace blue/amber/green category count capsules with plain labelled counts separated by 12 pixels; wrap when necessary. One add action remains blue.
- No colour-only category legend. Keep festival name, reminder/task/activity labels, actual times, overdue labels, and real empty state.

## 7. Header, Daily Brief and Daily Rhythm

### Home header

Files: `home_header.dart`, `home_day_design.dart`, `home_header_landscape.dart`, `home_theme.dart`.

- Greeting: supporting role, secondaryText. Name: display role, primaryText. Date: supporting role. Daily brief link: neutral navigationInk with existing icon and 48 target.
- Preserve date, profile, theme toggle, zodiac/streak/festival conditions; do not add competing badges.
- Keep time-dependent artwork right aligned and fading before text. Cap its **decorative layer opacity at .30 light / .22 dark**; text/icons are drawn separately at full opacity.
- Remove the full-width blue/peach/lavender header wash. Base fill matches canvas. Keep sun/cloud/moon/stars distinct so afternoon and night never look identical.
- Theme/avatar controls: neutral groupedFill circle, no outlined ring in normal contrast, 20-pixel icons, 48 target.
- Keep wrapping rules for long names and dates; don't push the calendar below an unnecessarily tall hero.

### Daily Brief

File: `daily_welcome_dialog.dart`. This is the current three-page Daily Brief, not the older similarly named `daily_briefing_card.dart`.

- One elevated neutral surface across all three pages. Remove page-wide colour gradients and full coloured statistic panels.
- Keep existing sun/landscape, walking and leaf illustrations, with neutral outlines and a blue detail limited to one small focal element. Do not remove the illustrations and leave a blank white data sheet.
- Top bar: Daily brief 17/600 left, close button right. Thin neutral separator below tabs only where it helps grouping.
- Use the existing AscentSegmentedControl with the restrained variant specified in section 9. Overview / Focus / Reset remain visible and tappable; PageView swipe stays synchronized.
- Overview: greeting 28/600; two metrics on one unboxed row with a separator; upcoming reminder is one groupedFill inset row with title, time, and neutral disclosure chevron. No duplicate reminder title/summary.
- Focus: title 28/600; first task is the dominant content with 20/600 title on a neutral inset surface. Metadata 15/400. Retain Open this task and the next two real tasks. Keep a small blue actionable link; do not make the entire task card blue.
- Reset: keep real overdue/unscheduled sections and yesterday data. Neutral rows and separators; red confined to an actual overdue number/label. Preserve capture and Pause destinations and meaningful empty states.
- **Footer:** full-width row with `‹ Back` at leading edge, `1 of 3` centred, and `Next ›` at trailing edge. On the final page show `Done` without an extra check icon. All navigation text uses primaryText, size17/600; chevrons16 with 6 gap. Each target is at least48 high. Back remains visible but disabled on page1. Use the existing close behaviour for Done.
- At large text, put page position on a separate centred line above a row containing Back and Next/Done. Never truncate navigation labels or overlap them.
- Preserve loading/error handling: no navigation into absent content; Retry remains a clear blue action; close/dismiss stays available.
- **Regression guard:** preserve PageStorage bucket, PageView key, individual scroll keys, controller, and `skipLoadingOnReload: true`. A minute-triggered provider refresh must not show Overview under the Focus tab or reset vertical scroll.
- Preserve automatic once-per-day rules and manual reopening without marking/resetting seen history. No fabricated positive statements or data.

### Daily Rhythm

Files: `home_life_shelf.dart`, `home_rhythm_artwork.dart`.

- Section title sits on the canvas, outside the hero card. Remove the outer full enclosure's border/background; keep its layout/key. One surface card is the hero.
- Tool selector sits between heading and hero, using the existing shared segmented control. All enabled tool names remain visible. Large text keeps the shared vertical fallback.
- Active hero radius28, neutral surface, padding20. Keep natural height and animated size. Adjacent hints remain 20–28 pixels wide with neutral fill; remove coloured edge bars.
- Header: tool title22/600 plus meaningful cue15/400; value30/600. Supporting sentence17/400. Avoid duplicating the tool name in a badge and title.
- Keep the recognisable drop, trail, leaves, heart and flag artwork. Use primary/secondary neutral strokes and one small shared-blue detail per artwork; remove green/orange/pink/purple surface tints.
- Water progress remains blue on neutral track. Amount choices remain shared segmented form selection, blue only for active state. Log water remains the single primary blue action; preserve actual amount, loading, error, retry and Undo.
- Previous/Next become neutral labelled chevron controls matching Brief footer. Keep current index/count. Remove redundant “Swipe left or right” helper when visible selectors and arrows already convey browsing; give the active card a swipe accessibility hint.
- Preserve RTL-aware looping in both directions, selector/swipe/button sync, close details, tool destinations and reduced motion. Never replace the carousel with a grid of tiny boxes.

## 8. Remaining Home sections: exact application list

Keep current ordering and conditional visibility in `home_screen.dart`. Use the updated margin/spacing constants, not ad-hoc per-section offsets.

| Widget/file under `lib/features/home/` | Required treatment |
|---|---|
| `widgets/home_shortcut_panel.dart`, `home_shortcut_icon.dart` | Keep Your space and editor; neutral icon tiles, primary labels13/500, no per-module pastel tile fills. Selected/editing state uses small blue indication, not a blue-filled whole panel. Preserve summaries and destinations. |
| `widgets/home_first_moment.dart` | One compact neutral inline surface,20/600 title,17 body, one blue capture action. Preserve new-user conditions. |
| `widgets/thought_wall_home_preview.dart` | Keep Mindspace content; remove an extra container if nested. One preview with17 body,15 timestamp and neutral disclosure. Preserve user content colours inside actual content. |
| `widgets/activity_hub_card.dart`, `activity_row_item.dart` | Keep Dayboard and status data; neutral grouped rows with inset separators. Task title17/400, time15 secondary. Retain completion semantics, overdue red and selected importance star. |
| `widgets/learning_hub_card.dart` | Growth heading22/600; neutral progress track and small blue fill; actual progress text. No decorative coloured metric blocks. |
| `widgets/home_promise_section.dart` | Commitments as readable grouped rows; same title/metadata hierarchy. Preserve due/destructive meaning and actions. |
| `daily_checkin_card.dart` | Neutral evening check-in surface, shared controls, one primary action; preserve hour-based visibility. |
| Vault preview and quick expense modules instantiated by `home_screen.dart` | Trace the imported actual widget, apply the same surface/text rules; preserve privacy masking, amounts and existing destinations. Do not implement unrelated full-module redesigns. |
| `home_customization_sheet.dart`, `widgets/home_shortcut_editor.dart` | Elevated neutral sheets,24 title,17 rows, shared switches/selection. Preserve module ordering and saved preferences. |
| `widgets/smart_catch_up_banner.dart`, Home empty/error/loading states | Neutral structural fills; clear primary message and one action. Red only for genuine error/overdue. Keep retries and skeletons legible in black mode. |

Do not globally restyle full Mindspace, Dayboard, Growth, Vault, finance, or task-detail screens in this pass. Shared-component changes must be checked there for accidental regressions.

## 9. Shared controls, navigation and overlays

- Keep AscentSwitch/AscentSwitchRow and AscentSegmentedControl. Do not introduce Cupertino-only screen replacements, raw switches, or new per-screen segmented implementations.
- Add an **opt-in restrained appearance** to AscentSegmentedControl, defaulting to existing appearance for other consumers. Track=groupedFill; selected surface=surface in light / neutralSelection in dark; text primary/secondary. Add a 2-pixel blue underline inset8 under the selected label, plus selected semantics. Keep raised neutral shape so selection is not colour-only. At large text use the same line/shape on the selected vertical row. Apply to Brief tabs and Rhythm tool navigation only; retain existing form-selection styling for water amount/settings.
- In AscentButton, use a shared opt-in neutral navigation treatment for Back/Next/open/dismiss controls. Background transparent, primaryText foreground, pressedFill feedback, disabledText when disabled. Keep primary data actions blue; avoid adding local raw TextButton styles for every screen.
- `main_scaffold.dart` bottom nav: preserve tabs/order/safe area and blur fallback. Within the monochrome theme only, active icon+label primaryText, inactive secondaryText, selected capsule neutralSelection and a small 3-pixel blue indicator. Labels13/500, active600; icons22. Do not remove labels or change route persistence.
- Do not silently override a person's existing non-monochrome preset globally. Provide the new neutral role mapping for Home, the full Calendar mode, Daily Brief and their entry overlays. For global nav apply it only while those routes are active, through one shared route/theme decision. Other routes retain their preset. Switching to/from Calendar list mode must restore the normal owning screen theme without state loss.
- Apply the scoped theme above `showAscentFrostedDialog`/sheet route builders so overlays actually inherit it; verify root-navigator dialogs rather than assuming a nested Home Theme propagates.
- Header, Calendar and Brief use chevrons for navigation; forward/back direction follows Directionality. Keep Android system back, predictive back support and existing pop behaviour.
- Shared archive swipes are the interaction reference. If touching swipe decoration, retain themed reveal containers and no white gaps in either direction. Do not change archive/delete behaviour for this visual task.

## 10. Implementation sequence and stop conditions

1. **Capture baseline:** inspect current diff, read this handoff and AGENTS, identify exact active widgets. Save mock-data screenshots; do not commit generated screenshots or personal records.
2. **Tokens and typography:** add neutral extension/mapping and scoped text roles; verify both brightness modes and existing preset isolation before screen migration.
3. **Home calendar:** implement the shared date visual and subtle today marker first. Confirm date navigation and month/year boundaries.
4. **Full calendar:** apply matching states, neutral agenda and accessible fallback. Preserve current data filtering.
5. **Header and Home rows:** map canvas/surfaces, simplify text and nested boxes, keep all conditional sections.
6. **Brief:** neutral pages, restrained tabs, labelled footer. Verify live reload preservation before moving on.
7. **Rhythm:** one hero surface, visible selectors, quiet artwork and clear navigation. Verify all tool paths and logging using isolated test data.
8. **Shared nav/overlays:** finish scoped theme propagation and shared control opt-ins. Audit callers so other presets remain intact.
9. **Verification and delivery:** run relevant checks once; fix actual failures; provide before/after evidence and list any remaining issues explicitly.

Do not rewrite Riverpod providers, database models, services or route contracts to simplify styling. If a visual implementation appears to require that, revisit the widget composition first. Keep temporary task planning files out of the final change; retain this requested handoff.

## 11. Required verification

Use mock data or an isolated test database for mutations. These tests already cover the current behaviours; inspect and update visual expectations only when this specification intentionally changes them. Do not delete behavioural assertions to make tests pass.

```sh
flutter analyze
flutter test test/home_calendar_test.dart test/home_first_moment_and_rhythm_test.dart test/home_approved_layout_test.dart test/home_editorial_redesign_test.dart test/home_day_layout_test.dart
flutter test test/morning_briefing_redesign_test.dart test/daily_welcome_test.dart test/daily_briefing_test.dart test/dynamic_island_report_and_shine_test.dart
git diff --check
```

Add focused assertions to existing tests for today/selected distinction, themed foreground/background, Brief Back/Next semantics, and the full-calendar large-text fallback. Shared segmented/button changes require their existing component tests as well; locate them with `rg --files test`. Do not claim a full suite passed when only this selection ran. Investigate pre-existing failures against the unchanged baseline and report them separately.

### Screenshot matrix and acceptance checklist

Capture light/dark at390×844 text1.0 and320×780 text2.0, using safe-area insets. For header periods use injected time:08:00,14:00,19:00,23:00. Screenshots alone do not prove tap/route behaviour.

- [ ] Calendar remains the first Home content block after greeting.
- [ ] Today is a small neutral date disc and blue dot; no large blue date background remains.
- [ ] Selected, today, both, outside month, scheduled and festival states are visually distinct and semantically named.
- [ ] Home date navigation opens the exact requested date; week/month/year boundaries and return to Today work.
- [ ] Full-calendar agenda contents, counts and deduplication match the unchanged data baseline.
- [ ] Light backgrounds are neutral, not cream/blue; dark page canvas is #000000 with distinguishable charcoal cards.
- [ ] Text hierarchy follows the role table; no oversized bold rainbow headings or decorative uppercase labels remain in scope.
- [ ] All Brief pages retain useful real data/actions and visible tabs. Back/Next/Done have readable labels and one consistent baseline.
- [ ] While Focus is open and scrolled, a provider refresh keeps selected page, body content and scroll position. Repeat on Reset.
- [ ] Manual Brief reopening preserves once-a-day history; automatic preference behaviour is unchanged.
- [ ] Every enabled rhythm tool can be identified and selected without first swiping; both swipe directions, loop, button selection and RTL stay synchronized.
- [ ] Water amount selection, exact logging amount, Undo/error/retry work in isolated tests.
- [ ] No clipped scaled text, overlapping targets or missing dark-mode icons; 200% alternatives are usable and preserve all actions.
- [ ] Screen-reader order follows visual order, selected states are announced, icon buttons have labels, focus remains visible.
- [ ] Reduce Motion and high contrast work; actual text/control contrast meets section3.
- [ ] Root dialogs/sheets and calendar/list transitions inherit the intended palette; unrelated presets remain intact.
- [ ] No new storage writes occur simply from viewing the redesigned screens beyond existing lifecycle behaviour.

### If installation is separately requested

Follow the repository device-update rules: inspect the installed package and signing certificate, build the matching variant, privately back up data unless the user explicitly waives it for that installation, and use `adb install -r`. Never uninstall, clear data, change app ID or install another variant as a workaround. Verify original data before launching. A signing/package mismatch is a blocker to report, not a reason to reset the app. Test navigation without changing personal records.

## 12. Required final delivery from the implementing IDE

Return the changed-file list, before/after mock screenshots for Home, both calendars, all Brief pages and Rhythm, checks actually run, and unresolved failures if any. State whether an APK was only built or actually installed. Do not report this specification's checklist as completed evidence until implementation and verification have happened.

### Copy-paste implementation instruction

> Implement docs/IOS_MONOCHROME_HOME_CALENDAR_HANDOFF.md starting from its live checkpoint in section 0; skip completed batches and follow the remaining order. Preserve the existing uncommitted work and AGENTS.md rules. Use its exact token, typography, date-state and navigation contracts; keep Calendar first, time-aware header artwork, all visible Rhythm selectors and the useful three-page Brief. Add shared opt-in styling rather than duplicating controls or changing other presets. Preserve business logic, records, routes and live-refresh state. Complete the specified verification and deliver evidence. Do not install unless my implementation request also asks for installation.

## 13. Apple references and interpretation

Apple's typography guidance treats legibility and information hierarchy as central; its colour guidance calls for consistent meanings and appearance-aware colours. This handoff applies those principles through Ascent's own bundled typography and semantic tokens. [Apple Typography](https://developer.apple.com/design/human-interface-guidelines/typography), [Apple Color](https://developer.apple.com/design/human-interface-guidelines/color).

Apple distinguishes base and elevated backgrounds in dark appearance. The black canvas and charcoal elevated layers here apply that depth principle. The exact hex values are project choices. [Apple Dark Mode](https://developer.apple.com/design/human-interface-guidelines/dark-mode).

Apple describes button style, content and role as working together to communicate function. The explicit Back/Next labels and consistent controls here apply that principle; neutral navigation is the user's requested art direction, not a universal claim that iOS uses black buttons everywhere. [Apple Buttons](https://developer.apple.com/design/human-interface-guidelines/buttons).
