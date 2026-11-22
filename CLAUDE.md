# Ascent — Product & Design Constitution

**This file is the single source of truth.** `AGENTS.md`, `GEMINI.md`, and everything in `docs/` must agree with it. If any other document or old handoff conflicts with this file, this file wins. Update the other file to match; never "pick one" silently.

---

## 0. What Ascent is

**Ascent is a premium personal operating system.** It is not a job-prep app. It is one calm, iPhone-quality place where a person plans their day, captures thoughts, takes care of themselves, and grows. It works fully offline. When it's online it adds features but never depends on them.

### Product pillars (this order is also the navigation and priority order)

| Pillar | Hero surface | Contains |
|---|---|---|
| **Today** | **Home** | Header, Now card, today's timeline, user-chosen widgets |
| **Plan** | **Things Hub** (hero product) | To-dos, timed activities, routines, plans, reminders, calendar |
| **Think** | **Thought Wall / Mind Space** (hero product) | Thoughts, spaces, boards, checklists, conversions to Things |
| **Live** | Life shelf | Hydration, medicine, walk, money, breaks (Chai), focus |
| **Grow** | Growth hub | Learning/courses, momentum challenges, analytics, optional career tools (pipeline, DSA, interview prep, resume) |
| **Glue** | **Assistant** | Chat, commands and briefings across all pillars |

Modules in *Live* and *Grow* can be switched on or off by the user. Career tools are **off by default** and are just another optional module.

---

## 1. North star: USER EASE ("never later")

The user must never think *"I'll fill this in later."* Every rule below serves this one.

1. **Value in 10 seconds.** Every create flow can be finished with **one field** (usually a title) and one tap. Everything else is optional, has a smart default, and is shown progressively ("Add time", "Add reminder", "More options").
2. **No required setup.** Onboarding has at most 3 screens and every screen is skippable. It asks only for a first name (optional) and theme. Never block entry behind profile, goals, permissions or data import.
3. **Ask at the moment of need.** Request permissions (notifications, location, health, biometrics) only when the user turns on the feature that needs them, with a one-line reason. If they refuse, the feature still works in a reduced form.
4. **Smart defaults everywhere.** Time = next free 30-min slot, date = today, reminder = 10 min before, category = inferred from text, water goal = 2,000 ml, etc. Defaults are visible and editable in place.
5. **Capture from anywhere.** One global capture entry (Home + / long-press / share sheet / Assistant) that accepts natural language ("call mom at 6", "idea: …", "spent 250 on lunch") and routes it to the right pillar, with Undo.
6. **No dead ends.** Every card, tile, badge and preview row has a journey: view → edit → act → delete (with cascade cleanup and Undo). No dummy tiles, no "Coming soon" on visible primary surfaces.
7. **Empty never means blank.** Every empty state follows §6.1: it teaches, offers a one-tap start, and gives tappable examples or templates that create real (editable) items right away.
8. **Forgiving.** Destructive actions use Undo snackbars first; confirm dialogs only when the action can't be undone. Missed streak days are forgiven (grace day) and never shamed.
9. **Preview caps.** Home and dashboard previews show at most 4 items with "Show all"; lists handle 0 / 1–10 / 100+ items without layout breakage.

---

## 2. Non-negotiable engineering rules

1. **Tokens only.** No `Color(0x…)`, `Colors.*`, raw `TextStyle(fontSize: …)`, magic padding or ad-hoc radii in feature code. Everything resolves through the theme (`AscentColors` / `AppColors` / `context.glass`, `AscentTextStyles`, `AppSpace`, `AppGeometry`). Literals live **only** in `lib/app/theme/` and `lib/core/theme/`.
2. **One pattern = one component.** Each pattern has exactly one shared widget (§6). Never build a per-screen button, input, empty state, sheet, dialog, switch, segmented control, chip or snackbar.
3. **One input = one container.** A text input is a single enclosure (`AppTextField` / `AppComposer`). Never a bordered/filled field inside another bordered/filled box. Inner `TextField`s set `border`, `enabledBorder` and `focusedBorder` to `InputBorder.none`; focus is shown only by the container's border turning action-colored. `OutlineInputBorder` is not allowed in feature code.
4. **Light and dark are a token swap.** One widget tree. Dark mode never gets a separate layout.
5. **Assistant identity is configurable, never hardcoded.** UI, routes and prompts read the configured name (`settings` → defaulting to `AppConstants.assistantName`). The string literals "Riya", "Aria" or "Jarvis" never appear outside `AppConstants` and the settings presets list.
6. **Copy quality.** Correct plurals ("1 thought" / "2 thoughts"); title-case names; time-based greetings (morning 5–12, afternoon 12–17, evening 17–21, night 21–5); empty numbers show "–", never "0 ml" or "0 min"; sentence case for buttons and titles.
7. **Offline first.** The local Drift database is the source of truth; the UI reads only from it. Network features (weather, sync, online assistant, integrations) are additive, fail quietly and show an "Offline" state instead of errors.
8. **Performance.** Home's first frame is under 100 ms of work after data is ready. No continuous GPS or animation loops while off-screen; animations pause when not visible or when reduce-motion is on.
9. **Accessibility.** Tap targets ≥ 44 pt. Zero overflow at 320 px width and text scale 2.0. Text contrast ≥ 4.5:1 (3:1 for large text and icons). Every icon-only control has a `Semantics` label / tooltip.
10. **CRUD completeness and cascade.** Anything a user creates can be edited and deleted. Deleting cascades: reminders, scheduled notifications, timers and links are removed, with no orphans.
11. **Classification integrity.** A plain to-do has no timer/play control. Timed activities have countdown/stopwatch and focus sessions.
12. **No dead code.** When a feature is removed or replaced, purge its screens, routes, providers, DAOs, seeds, assets and tests in the same change (keep DB tables and migrations if user data or backups depend on them).
13. **Tests.** New behavior ships with widget/unit tests, including empty, 1-item and 100+ item states, light and dark, and text scale 2.0.

---

## 3. Visual language: Apple-premium iOS

The look is **iOS system design**: grouped backgrounds, clean white/graphite cards, one blue action color, hairline separators, large titles, generous whitespace, restrained color. **Premium = restraint + precision + motion**, not more gradients.

### 3.1 Color roles: one palette, Calm Blue

Ascent has **exactly one palette, Calm Blue** (`lib/app/theme/calm_blue_palette.dart`), mirrored for light and dark. There are no theme presets. Never add a second palette, a preset picker or per-screen colour overrides (`Theme(data: …)` wrappers that swap colours). Widgets only ever use roles. When a palette, preset or theme variant is retired, delete its files, enum values, providers, pickers, tests and docs in the same change.

Calm means easy on the eyes: muted, slightly desaturated blues, deep-navy ink by day and soft off-white ink by night (never pure white on pure black), no glossy gradients, glows, sparkles or neon. Body text ≥ 7:1, secondary and hint text ≥ 4.5:1 on its surface.

| Role | Light | Dark | Use |
|---|---|---|---|
| `canvas` | `#F2F5F9` | `#0B0E13` | Page background (grouped) |
| `surface` | `#FFFFFF` | `#161B23` | Cards, grouped list cells |
| `surfaceElevated` | `#FFFFFF` | `#1E242E` | Sheets, dialogs, menus, popovers (opaque) |
| `surfaceRecessed` | `#E8EDF3` | `#1E242E` | Segmented tracks, empty-state tiles (inputs have no fill, §6.5) |
| `separator` | `#D6DEE8` | `#2B323D` | 1 px hairlines |
| `label` | `#1A2332` | `#E4E9F0` | Primary text |
| `labelSecondary` | `#4A5668` | `#A9B4C2` | Secondary text |
| `labelTertiary` | `#5B677C` | `#8995A6` | Hints, placeholders, timestamps |
| `action` | `#2F68C8` | `#8EB1EC` | Links, active icons, focus, selection |
| `actionFill` | `#2F68C8` | `#3A66B8` | Filled primary buttons (white label) |
| `onAction` | `#FFFFFF` | `#FFFFFF` | Text on filled action |
| `actionTint` | `#E6EEF9` | `#1B2A42` | Tonal buttons, selected chips, user chat bubble |
| `success` | `#2E8B57` | `#5DBB84` | Completion, switches on |
| `warning` | `#B7731F` | `#E0A458` | Due soon, streak flame |
| `danger` | `#C6443A` | `#E8776D` | Overdue, destructive |
| `star` | `#D9A514` | `#E6C35A` | Importance star only |

Pillar tints (small icon tiles, charts, header accents only — never full-screen fills):
Plan = `action`, Think `#2F8F8A` teal (no purple anywhere; the user dislikes it), Live/health `#FF2D55`, water `#3A9CC9`, money `#3A9A63`, Grow `#FF9500`, Assistant gradient `#5E5CE6 → #BF5AF2 → #FF6482`.

Rules: one filled `action` button per screen region. Color carries meaning; it is never decoration. No 2 px outlines; all borders are 1 px `separator`.

### 3.2 Typography

- Family: **DM Sans** for all UI (the single UI family, already used by the core `AscentTextStyles` roles). Numbers in timers/stats use tabular figures (`AscentTextStyles.tabular`). JetBrains Mono only for timers/code. Source Serif 4 only inside the book reader. Plus Jakarta Sans, Bricolage Grotesque and Merriweather are legacy: migrate them when you touch the file.
- iOS scale (size/weight, letter-spacing): Large Title 34/700 (-0.4) · Title 1 28/700 · Title 2 22/700 · Title 3 20/600 · Headline 17/600 · Body 17/400 · Callout 16/400 · Subhead 15/400 · Footnote 13/400 · Caption 12/500.
- Home section headings all use one token (`AscentTextStyles.homeTitle`, Title 3). Never invent sizes.

### 3.3 Shape, space and depth

- Continuous (squircle) corners: cards 20, grouped list 12, controls/inputs 12, sheets 28 (top), floating composer 24, chips/pills 999, icon tiles 8 (30 px) / 12 (44 px).
- Spacing scale: 4 · 8 · 12 · 16 · 20 · 24 · 32 · 40. Screen gutter 16 (20 on ≥ 400 px). Section gap 28.
- Depth: light cards use a soft shadow (`y 2, blur 12, black @ 5%`) and no border; dark cards use no shadow, a fill only, and an optional 1 px `separator`.
- Inset grouped lists: rounded group, hairline separators inset 16 from leading (after the icon tile), chevron trailing, 30 px rounded-square tinted icon tile.

### 3.4 Materials (glass)

- `GlassSurface` (blur 24, tinted fill, 1 px white @ 10% rim) is **only** for persistent chrome: tab bar, collapsing nav bar, floating composer, live session bar. It falls back to solid when reduce-transparency is on.
- Overlays (sheets, dialogs, menus, pickers, tooltips, snackbars) are **opaque** `surfaceElevated` via `OpaqueOverlaySurface`, with shadow and a black @ 40% scrim. Never glass.

### 3.5 Motion and haptics

- Springs over curves: default `SpringDescription(mass: 1, stiffness: 300, damping: 30)`; fallback `Curves.easeOutCubic` 250–350 ms. Exits 200 ms.
- Press: scale 0.97 with spring back (`AscentPressFeedback`). Lists: staggered fade+rise 8 px, 30 ms apart, first 6 items only.
- Card → detail uses a shared-element (`Hero`) transition. Sheets slide up with spring.
- Completion moments: check draws itself (250 ms) + `HapticFeedback.lightImpact`; streak milestones get one tasteful celebration (no confetti storms).
- Haptics: `selectionClick` for toggles/chips/segments, `lightImpact` for send/complete, `mediumImpact` for destructive confirm.
- Reduce-motion: replace movement with fades; stop ambient loops.

### 3.6 Controls

Use the shared widgets: `AscentSwitch` / `AscentSwitchRow` (iOS-style, `success` track), `AscentSegmentedControl`, `AscentDialog` (iOS alert layout), `AscentSheet`, `AscentPopupMenu` / `AscentActionMenu`, `AscentSnackBar` / `showUndoSnackbar`, iOS activity indicator for loading, skeleton shimmer for content loading. Scroll physics: `BouncingScrollPhysics` everywhere. Never use raw Material `Switch`, `AlertDialog`, `DropdownButton`, `showModalBottomSheet`, `SnackBar` or `CircularProgressIndicator` in feature code.

---

## 4. Navigation

- **Tab bar (glass):** Home · Things · *Assistant (centre)* · Mind · You. "You" holds Life & Grow modules, Vault, Analytics, History and Settings as an inset grouped list. Reminders live inside Things (no duplicate tab).
- Large collapsing titles on every root tab; standard back chevron + title on pushed screens.
- Back from a non-Home tab goes to Home; double back on Home exits.
- Global capture button is reachable on Home, Things and Mind.

---

## 5. Hero surfaces

### 5.1 Home — "your day at a glance, alive"

Order (users may reorder/hide everything below the Now card from *Customize Home*):

1. **Living header.** Greeting + title-cased name + date, with a time-of-day scene that changes smoothly (cross-fade over 2 s) across four periods:
   - **Morning (5–12):** soft dawn gradient (peach → light sky), rising sun glow.
   - **Afternoon (12–17):** clear bright sky, light clouds drifting slowly.
   - **Evening (17–21):** golden hour → dusky rose/violet, sun near the horizon.
   - **Night (21–5):** deep indigo/midnight gradient, moon and a gentle aurora ribbon; "Quiet hours" badge when do-not-disturb is on.
   - Dark mode dims every scene by about 35% and keeps text ≥ 4.5:1. Weather (if online and allowed) adds a one-line condition chip; offline shows nothing (no error).
   - The scene compresses into the large-title nav bar on scroll (parallax 0.5).
2. **Now card** (`HomeNowCard`, logic in the pure `resolveNowFocus`). One card answering "what should I do now?" with one primary action. Priority: running/paused session (live timer, Pause/Resume) → overdue activity → overdue reminder (not already shown as an activity) → due medicine (Taken) → due activity, earliest scheduled first (Done, or Start for timed) → next scheduled activity ("Up next") → "All done for today" → "Your day is wide open" + **Plan your day**. A quiet "Then: …" line shows the following item.
3. **Quick tools row.** The user's chosen shortcuts (`HomeShortcutPanel`).
4. **Today timeline.** At most 4 rows for Things today, with "Show all".
5. **Mind preview.** The latest 2–3 thoughts plus an inline "What's on your mind?" capture field (one container).
6. **Life shelf.** Compact rings/tiles for enabled Live modules (water, medicine, walk, money), each with a one-tap log action.
7. **Assistant card.** "Ask {assistantName}" with a slow rotating gradient border (8 s, paused off-screen and under reduce-motion) and two contextual suggestions.

Home is never a wall of cards: at most 7 sections visible by default, 28 px between sections, one heading style.

### 5.2 Things Hub — the planning hero

- Segments: **Today · Upcoming · Anytime · Routines** (shared segmented control) plus a calendar toggle in the nav bar.
- **Quick add** at the bottom (floating `AppComposer`): type naturally ("gym 7am tomorrow 45m") → parsed live into chips (date, time, duration, reminder, category) the user can tap to adjust before saving. Enter saves with only a title.
- Rows: checkbox (circle, draws on complete) · title · one meta line (time · duration · category tint dot) · star for importance. Swipe right = complete, swipe left = reschedule / delete (themed action containers, no white gaps). Long-press = context menu.
- Timed rows show a play control; starting one shows the shared `LiveSessionBar`.
- Completed items collapse into "Completed (n)" with Undo.
- Overdue items are grouped at the top with a single "Move all to today" action.

### 5.3 Thought Wall / Mind Space — the thinking hero

- Feels like a calm, tactile board: thoughts are cards with a soft paper feel on the `canvas`, in a masonry layout, grouped into **Spaces** (user-coloured with pillar tints).
- Capture is instant: an inline composer at the top, voice input, paste-to-thought, share-sheet target. A thought needs only text; the space defaults to the last used one.
- Each thought supports: pin, colour, checklist, convert to To-do / Reminder (opens the Things quick-add pre-filled), link to other thoughts, merge, archive, share.
- Board view lets thoughts be dragged and grouped with spring physics; list view for quick scanning; search across all spaces.
- Opening a thought uses a Hero expand into the detail sheet.

### 5.4 Assistant chat

- App bar: back, centred assistant name, opaque overflow menu.
- Empty state: sparkle tile + "How can I help?" + 2×2 suggestion grid (`surfaceRecessed`), contextual to the time of day; it disappears after the first message.
- User messages: right-aligned `actionTint` bubble. Assistant replies: no bubble, full-width markdown (`flutter_markdown`, 8 px paragraph spacing), with a small name label at the start of a turn.
- Action row under replies: Copy, Regenerate, Thumbs (icon-only, `labelTertiary`). At most 2 follow-ups, only under the latest reply.
- Floating `AppComposer`: safe-area aware, mic when empty, spring-scaled send when there is text.
- Action results render as live record cards (e.g. a created to-do) with inline edit/undo.

---

## 6. Component contracts

### 6.1 Empty states (`EmptyState`)

Every empty list, section or screen uses `EmptyState`. Anatomy, top to bottom:

1. **Icon tile:** 64 px continuous-corner tile in the pillar tint at 12% with the pillar icon (outlined, 28 px). An optional subtle float animation (2 px, 3 s) that respects reduce-motion.
2. **Title:** Title 3, `label`. It says what will live here, invitingly ("Your day is wide open").
3. **Message:** Subhead, `labelSecondary`, max 2 lines, max width 300. It explains the value, not the mechanics.
4. **Primary action:** one filled button ("Add your first thing"). It opens the fastest create flow with focus in the title field.
5. **Starters (optional, recommended for hero surfaces):** up to 3 tappable example chips ("Drink water at 11", "Read 20 min", "Call mom") or templates. Tapping creates a real item immediately (with Undo), so the user sees value without typing.

Section-level (inline) empty states inside Home cards use the compact variant: a single row with icon tile, one line of text and a text button. Never just "No items". Never a grey box.

### 6.2 Placeholders and hints

- Input placeholders are examples, not labels: "e.g. Call mom at 6 pm", `labelTertiary`, and they disappear on typing. The field label sits above in Footnote when a label is needed.
- Loading content uses skeleton shimmer shaped like the real content (never a centred spinner for lists). Spinners only for actions under 2 s.
- Missing values display "–". Images and avatars fall back to an initial on a pillar-tint disc.

### 6.3 Buttons (`AscentButton`)

| Variant | Look | Use |
|---|---|---|
| `primary` | Filled `action`, `onAction` label, Headline 17/600, height 50 (compact 36), pill radius | The one main action in a region |
| `tonal` | `actionTint` fill, `action` label | Secondary actions next to a primary |
| `secondary` | `surfaceRecessed` fill, `label` text | Neutral actions (Cancel, Skip) |
| `ghost` / text | No fill, `action` label | Inline actions, "Show all" |
| `destructive` | `danger` label on `surfaceRecessed` (filled `danger` only in confirmations) | Delete, remove |
| `icon` | 44 px hit area, 22 px glyph, `labelSecondary` or `action` | Toolbar and row actions |
| `fab` / capture | 56 px circle, filled `action`, plus glyph, soft shadow | Global capture |

All buttons: press scale 0.97 with spring, haptic, disabled = 40% opacity, a loading state that swaps the label for an activity indicator while keeping the width, minimum 44 px height, labels in sentence case and verb-first ("Add thing", "Start focus").

### 6.4 Cards (`AscentCard` / `AppCard`)

`surface` fill, radius 20, padding 16, light-mode soft shadow, no border in light mode. Header row: 30 px tinted icon tile + title (Headline) + optional trailing chevron or text button. A card is a single tap target or contains explicit actions, never both ambiguously.

### 6.5 Inputs

`AppTextField` (single-line and multi-line forms) and `AppComposer` (chat/capture). Input bars on a page (quick add, capture, chat) use the **same `surface` as the cards** with a 1 px `separator` border, so they read as one more card on the screen. Form fields inside a card or sheet have **no fill of their own** and take that surface's colour. Never put an input on a strip or slab of its own colour: docks are transparent, and a list that scrolls under a bar fades out (`ScrollEdgeFade`) instead of ending in a hard cut. Focus is a 1 px `action` border; radius 12 (composer 24); a clear button when there is text; an error line in Footnote `danger` below.

### 6.6 Sheets and dialogs

Sheets: `AscentSheet`, grabber, title row with "Cancel" (left) and the primary action (right) as in iOS, detents medium/large, keyboard-safe. Dialogs: `AscentDialog`, centred title + message, stacked or side-by-side actions, destructive in `danger`.

---

## 7. Offline and online

- **Always offline:** everything in Today, Plan, Think and Live, the local assistant commands, notifications, the Vault, backup/restore.
- **Online adds:** weather, the online assistant model, cloud sync/multi-device, calendar/health/email integrations. These are opt-in and show an "Offline · changes saved on this device" state when there is no connection.
- New tables must be sync-ready: a `uuid` text key, `createdAt`, `updatedAt`, a nullable `deletedAt` (soft delete), and writes recorded through a single DAO path (so an outbox can be added).
- Vault data is only ever synced as ciphertext. API keys never ship in the app.

---

## 8. Device and data safety

Android updates must replace the existing installed app and keep its data: match the package and signing certificate, back up app data privately, install with `adb install -r`. Never uninstall, clear data, change the application ID or install a second variant on the user's phone. Never modify the user's personal records for testing; use the QA package (`com.arun.ascent.qa`) and in-memory data.

## 9. Workflow

- Work on `feature/<name>` branches. Commit and merge only when asked and tests are green.
- Before building something, inspect the existing equivalent and reuse its components and conventions.
- Temporary implementation plans are deleted when the work is done; maintained docs and these rules are kept.
- Redesigns must never remove or hide an existing functional entry point.
