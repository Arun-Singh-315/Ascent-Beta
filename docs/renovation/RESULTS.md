# Ascent · Mind Space renovation results

Latest follow-up: [Learning and notification flow · 1.0.8 (9)](LEARNING_ALERTS_RESULTS.md).

Follow-up quality upgrade: [1.0.7 (8) implementation and verification](QUALITY_UPGRADE.md). That follow-up supersedes this historical report’s onboarding and backup limitations.

12 October 2026 · Flutter/Riverpod/Drift retained · Android release 1.0.6 (7).

## Outcome and scope

The approved renovation adds a local, typed Riya action registry with confirmation, verified database outcomes and durable duplicate protection. It fixes first-day streak messaging and calendar refresh, simplifies writing and card actions, preserves the historical pale daytime atmosphere with warm accents, improves Chai controls, and bundles fonts for offline use. The original reflections work and independent multi-challenge tracking remain included.

This is a completed implementation of the approved local scope, **not a claim that every screen has passed physical-device, accessibility or performance certification**. Onboarding, account security, comprehensive backup, universal search and additional assistant operations remain proposals. The user approved the scoped Riya architecture and warm historical theme restoration. The APK was initially prepared for later installation. After the user connected the phone and authorized installation, ADB installed version 1.0.6 (7) successfully on 12 October 2026; package metadata and a live app process confirmed the installed version and launch.

The preimplementation deliverables A–F are in [AUDIT.md](AUDIT.md), including the screen inventory, concrete UX audit, original 16-point baseline, feature connections, capability matrix and prioritized roadmap. [SOURCE_INVENTORY.md](SOURCE_INVENTORY.md) lists feature/shared classes and DAO operations. The historical audit records what existed before these edits.

## Exact 16-point feedback status

“Implemented” below means the described code and automated checks exist. Device-only checks are explicitly separate.

| # | Feedback | Status and result | Verification / limits |
|---|---|---|---|
| 1 | Chai / Coffee | **Implemented within the preserved design.** Brown cup stays stable across audio presets; gentle steam, reduced-motion support, clearer purpose line, larger mode/preset controls, wrapping durations and a compact title. | Chai provider/resume tests; full-screen widget layout in both themes at 1.5× text; cup reduced-motion test. Physical audio and visual approval pending. |
| 2 | Riya as an app assistant | **Approved scope implemented; broader feature coverage partial.** Sixteen registry capabilities cover tasks, reminders, thought search, spending, hydration, Focus start/pause/resume, help and navigation. | Real SQLite writes/reads, confirmation widget, transaction rollback, retry/restart/migration tests. No cloud model, account isolation, arbitrary CRUD or universal content search claim. |
| 3 | Conditional Home reminders | **Implemented and retained.** Populated read-only preview above Activity; no empty container or Add action; tap opens Reminders. | Empty, cap and read-only widget checks. Native reminder delivery remains pending. |
| 4 | Duplicate Money actions | **Implemented.** One visible Add Expense primary; app-bar and empty-state duplicates removed. Challenge and wall creation entry points also simplified. | Money widget checks; challenge and thought workflows in regression suite. |
| 5 | Thought quotation styling | **Implemented.** Display wraps content once; existing balanced quotes stay intact. Stored and shared text is unchanged. | Quote model tests plus wall display/edit/archive checks. |
| 6 | First-use instructions | **Implemented.** Three concise steps per feature, once-only presentation, replay and optional guided tour. | First-use, returning-user, replay and tour navigation tests. Native accessibility reading order pending. |
| 7 | Input consistency | **Implemented.** Riya and wall share a multiline composer with 48dp send, disabled empty/busy states, focus treatment and Ctrl+Enter. Home keeps its inline field. | Both themes, 1.5× text, semantics/button size, keyboard and inline-send tests. |
| 8 | Thought card action hierarchy | **Implemented.** Date and Promise header; Edit/Copy directly below content; secondary actions in menu without duplicate Edit/Copy; Undo expires. | Wall layout, edit, copy-related presentation, archive/delete and expiring Undo tests. Clipboard/share platform sheets pending. |
| 9 | Daytime Thought Wall | **Implemented from approved reference.** Historical pale base and atmospheric layout, shared warm glows, no restoration of blue/violet accents. | Theme/widget checks and rendered component previews. Full wall physical screenshot review pending. |
| 10 | Streak accuracy and tone | **Implemented.** Separate fresh/day-one/active/risk/broken/recovered phases; no zero-day urgency or invented streak; calendar history and idle midnight refresh. | Calculator, rescue, history and injected-clock midnight tests; Home regression checks. OS clock/time-zone changes still need a device run. |
| 11 | Daytime Home | **Implemented from approved reference.** Pale historical surfaces retained; warmer muted text and atmosphere; meaningful study header. | Theme/component render and existing Home tests. No measured startup/frame-time claim. |
| 12 | Home thought field | **Implemented.** Transparent inline line with no inherited filled outline; warm focus underline; empty submit disabled; save preserves a newly typed draft. | Focus/decoration and inline write tests. Draft survival across app termination remains proposed. |
| 13 | Composer controls | **Implemented.** Shared aligned send controls; ordinary wall writing stays simple; Promise creation has one dedicated top entry point. | Composer and wall tests. |
| 14 | Ambiguous intentions | **Implemented for the approved examples.** Interview preparation offers task, reminder, timer or checklist; missing reminder time and multiple edit targets use short follow-up questions. | Resolver and database tests prove clarification does not write. Unrecognized language still falls back to honest local guidance. |
| 15 | Thought readability and font | **Implemented.** Plus Jakarta Sans matches reminder content; less crowded header; quotes, multiline/emoji and larger controls; offline fonts included. | Real-font component renders, text/layout and stored-content regression checks. Comprehensive screen-reader testing pending. |
| 16 | Conversational tone | **Implemented.** Brief greetings, thanks, light humor and useful limitations; proposals do not announce success; unavailable reads do not pretend records are empty. | Deterministic response and integration tests. This remains a local rules-based assistant. |

The original 12 reflections, matching reminder font and multi-challenge request are tracked in [../../FEEDBACK_CHECKLIST.md](../../FEEDBACK_CHECKLIST.md). That file's 1.0.5 installation evidence belongs to the previous release. Multiple challenges have independent linked evidence, a status chooser, archive/history behavior and a persistent Home selection; two real Focus records exercise independent tracking in `reflections_feedback_test.dart`.

## Screen and component changes, files and evidence

Paths below are relative to the repository root. Unlisted screens were audited; they were not silently redesigned.

| Area | Important files | Change and checks |
|---|---|---|
| Home | `lib/features/home/widgets/thought_wall_home_preview.dart`, `home_header.dart`, `study_streak_meter_card.dart`, `home_dismissible_reminders_section.dart` | Inline transparent composer, one Open Wall link, responsive heading, respectful real study status and conditional read-only reminders. Home, reflections, streak and UI tests. |
| Thought Wall | `lib/features/thought_wall/thought_wall_screen.dart`, `drop_thought_sheet.dart`, `thought_actions.dart`, `thought_action_ui.dart` | Shared ordinary composer; dedicated Promise creation; date/Promise/action hierarchy; bulk Todo/reminder/list conversion; archive/delete/Undo and quote presentation. Wall/edit/Promise/archive/reflections tests. |
| Riya | `lib/features/ai_assistant/ai_assistant_screen.dart`, `lib/core/ai/ai_service.dart`, `riya_intents.dart`, `riya_capabilities.dart`, `ai_action_execution.dart` | Typed proposals, explicit review, real result cards/routes, cached latest-chat stream, clarification context, safe read failures, proper expense parsing and friendly local fallback. Command, AI, medicine and UI tests. |
| Money | `lib/features/money/money_screen.dart` | One Add Expense primary and concise empty guidance. Money UI test and finance database checks. |
| Challenge Partner | `lib/features/momentum/momentum_screen.dart`, challenge providers/DAO and Home challenge preview | Multiple independent challenges; selection and persistent Home choice; contextual creation entry points. Reflections database and challenge/momentum tests. |
| Chai | `lib/features/chai_break/chai_break_screen.dart`, provider, `widgets/steaming_cup_painter.dart` | Warm stable cup, purpose text, 48dp preset/mode sizing, responsive labels and duration wrapping; stop decorative steam when reduced motion is requested. Provider/resume and new layout/motion tests. Audio hardware unverified. |
| Help / tour | `lib/shared/widgets/feature_guide.dart`, `lib/core/onboarding/onboarding_tour.dart` | Short once-only steps, replay and sequential optional exploration. Guidance and tour tests. |
| Shared presentation | `lib/shared/widgets/message_composer.dart`, `thought_presentation.dart`, `ascent_atmosphere.dart`, `lib/app/theme/glass_theme.dart`, `color_tokens.dart` | Shared composer and display quotes; preserved atmosphere; warm palette; daytime muted text changed to #74695F, measured 4.84:1 on #F4F3F8. This is one token check, not a whole-app WCAG certification. |
| Streak | `lib/core/streak/study_streak_models.dart`, `study_streak_provider.dart` | Calendar history, once-per-update calculation, active midnight watcher, injectable clock and phase-derived copy. Calculator/rescue/history/midnight tests. |
| Storage | `lib/core/database/app_database.dart`, generated `.g.dart`, `tables/ai_command_table.dart`, `daos/ai_assistant_dao.dart` | Schema 13 receipt table, atomic writes/results, latest 60 messages, committed-result recovery and history clearing. Actual file-based schema-12 migration, reopen, recovery and retry tests. |
| Notifications | `lib/core/notifications/notification_service.dart`, Android `MainActivity.kt`, iOS `AppDelegate.swift` | Checked scheduling outcome and native IANA zone bridge; Riya distinguishes saved rows from OS alerts. Zone-refresh mock checks and Android build. iOS compilation and alert delivery pending. |
| Settings / offline assets | `lib/features/settings/settings_screen.dart`, `lib/main.dart`, `pubspec.yaml`, `assets/fonts/` | Honest partial-export/profile-only restore copy, bundled fonts and runtime fetching disabled, version bump. Existing Settings tests, asset render and Android build. |

Shared fonts: 41 variants across seven existing families, approximately 8 MiB, with OFL notices and a SHA-256 manifest. No new runtime dependencies, remote model, credentials or analytics service were added.

## Riya's actual capabilities

The maintained registry is `lib/core/ai/riya_capabilities.dart`; discovery examples come from it. All writes require explicit confirmation. Reads do not mutate user records.

| Capability | Supported behavior | Important boundary |
|---|---|---|
| `tasks.today` | Read today's stored tasks | Calendar-local date; unavailable query produces an error rather than an invented empty result. |
| `tasks.create` | Create Todo, timed or flexible activity; optional linked reminder | Validated title/priority/duration/date; flexible -1 is preserved. |
| `tasks.checklist` | Create a parent preparation task with linked child steps | Preview is shown before creation; no hidden automatic checklist. |
| `tasks.reschedule` | Atomically reschedule chosen IDs | Every target must exist; rollback on a missing target. Does not silently alter reminders. |
| `reminders.list` | Read upcoming reminders | Permission to notify is separate from reading local rows. |
| `reminders.create` | Save a future reminder | Missing time is clarified. OS scheduling is reported separately. |
| `reminders.edit` | Change a chosen reminder's time | Multiple matches require selection; cancelled review does not change it. |
| `thoughts.search` | Literal local search, including archive, up to 20 matches | Saved text stays inert; it cannot become an instruction. This is not semantic/vector search. |
| `expenses.create` | Add a finite positive expense | Confirm amount/title; transaction and saved row verified. |
| `expenses.summary` | Sum expense rows within a selected calendar period | Excludes income; reports the actual period and number of rows. |
| `hydration.log` | Add water intake | Positive validated volume, confirmed write. |
| `focus.start` | Start an existing Focus session with a duration target | Refuses a second active session. Existing stopwatch does not automatically stop at the target. |
| `focus.pause` / `focus.resume` | Control the selected active Focus session | Validates the selected ID again; a changed/missing session fails. Finish and task completion stay in Focus. |
| `help.feature` | Explain registered feature steps | Unknown feature is rejected; uses the same guidance as the UI. |
| `navigation.open` | Open allowlisted real screens | Arbitrary routes and external instructions are rejected. |

Additional legacy read insights remain available. Unsupported operations, including arbitrary deletion/reset/sharing and lecture completion through chat, explicitly direct the user to the appropriate screen. No unverified lecture persistence is announced as success.

Examples exercised: “Add 200 rupees for coffee”, “Find what I wrote about my interview”, “Show my spending this week”, “Remind me to call tomorrow” followed by “7 PM”, “Change my reminder to 7 PM” followed by choosing a target, “Start a 25-minute timer”, “Pause my timer”, “Resume my timer”, “Show me how to use Thought Wall” and “I need to prepare for my interview”.

## Architecture and cross-feature integrity

The assistant pipeline is interpretation → typed command → context/validation → review → transactional handler → re-read verification → receipt → chat result/navigation. A request ID belongs to a persisted user chat turn. Its approved arguments and verified result commit in the same SQLite transaction as the data mutation. A retry with the same ID and arguments returns the receipt; different arguments with that ID fail. A newly submitted request is a separate user intention. Concurrent identical requests and database reopen are tested.

Chat recovery restores a committed result whose response was interrupted, once, while its user turn still exists. Clearing chat clears its receipts too. It does not resurrect a cleared conversation. OS notification delivery is outside SQLite's transaction: a receipt proves the reminder row, not an alarm firing. Alert failures leave the saved reminder available and report the permission/scheduling issue.

The database remains a single local profile. No secure multi-user permission boundary or cloud tenancy was added. Parser/schema validation, allowlisted navigation, confirmation and inert retrieved text constrain local operations. No database/notification exception or saved thought is reflected into an executable command.

Existing connections retained and checked: Thought → Todo / Promise task / selected reminder list; Task → Reminder and Focus; Focus/Learning → independently linked Challenge evidence → selected Home preview; Medicine → dose log / task / reminder cascade. Added connections: chat → verified feature records and routes, interview intention → chosen task/reminder/Focus/checklist, thought archive → local retrieval, and expense rows → period summary. No automatic redundant objects were introduced for ordinary notes.

### Migration and rollback

Schema 12 → 13 only adds `ai_command_table`. Existing records are not removed or rewritten. A file-based test downgrades a fixture to schema 12, reopens it with the new application, and checks preserved thoughts plus the receipt table.

Before a production rollback, preserve the complete database (including SQLite WAL state using a safe SQLite backup) and SharedPreferences through trusted device/developer tooling. The app's JSON export is **not** a full rollback backup; restore currently imports the profile only. Prefer restoring an actual pre-upgrade snapshot. A controlled developer rollback can remove the new receipt table and set `user_version` to 12 before running the older APK, after preserving a copy and validating old-version compatibility. Merely installing the older APK over schema 13 is not a verified rollback procedure. No rollback or data reset was performed on the user's phone.

## Before / after and metrics

These are source/widget observations, not timed usability measurements. No analytics baseline exists.

| Flow | Before | After |
|---|---|---|
| Riya expense | Proposal could execute automatically and appear green despite failure | Confirm → saved row/result receipt → verified card; failure is not green |
| Riya retry | No persistent action identity | Same user turn replays the stored result without another write |
| Home thought | Popup entry in the original feedback; inherited outline during audit | Inline write + Send, no popup; focused warm underline |
| Money expense | Competing Add controls | One visible primary entry point |
| Thought editing | Edit/Copy duplicated in direct actions and menu | Direct common actions, secondary menu |
| Reminder ambiguity | Missing time could fall through / multiple targets unclear | Ask for time or target, then review |
| Study start | Zero-day urgency and stale legacy counter | First-day guidance; historical users get a fresh start; calendar refresh |
| Writing controls | Uneven 40dp assistant send and separate implementations | Shared 48dp send, multiline and disabled state |

Rendered **component** previews use actual bundled fonts and shared Home/chat widgets at 390×844 logical pixels. They are not screenshots of the full production screens or the phone, and no pixel-matched old capture was available: [day-writing-preview.png](day-writing-preview.png), [night-writing-preview.png](night-writing-preview.png).

Future metrics: median time to create task/expense/reminder, confirmed writes / attempted writes, database failures, duplicate-write count, saved-reminder-to-scheduled-alert ratio, search result opened rate, first-use feature completion, layout errors at supported text scales, p95 initial render and frame jank. Collect locally or with explicit analytics consent; do not invent before/after percentages.

## QA and delivery

**Full regression suite: 261 tests passed, zero failures** (`flutter test --reporter expanded --timeout 90s`). **Flutter analysis: no issues**. `git diff --check` passed. Logs: [flutter-test.txt](qa/flutter-test.txt), [flutter-analyze.txt](qa/flutter-analyze.txt). Android release build **passed** (160.6 seconds, 100.5 MB universal APK). Package metadata confirms `com.arun.ascent`, versionName `1.0.6`, versionCode `7`, minimum API 24 and target API 36. `apksigner verify` passed; all 41 packaged font hashes and seven license notices match the source. [Build log](qa/flutter-build-apk.txt) · [APK verification and SHA-256](qa/apk-verification.txt).

Ready artifact: [Ascent-1.0.6-7.apk](../../releases/Ascent-1.0.6-7.apk). Installation **completed** after the user connected the phone and authorized it. `adb install -r` returned Success; package metadata reports versionName 1.0.6 and versionCode 7. Cold launch returned Status: ok; the running app was visually confirmed at the notification permission prompt over the first onboarding screen. No app records were manually created, edited or reset during these checks. [Installation evidence](qa/device-installation.txt) · [Launch screenshot](qa/device-1.0.6-launch.png). Earlier failures exposed stale product expectations and a fake-async medicine fixture; those fixtures were updated to the current contract. Tests were not deleted. Guidance-sensitive workflow tests explicitly model returning users; separate tests retain first-use coverage. A preview-theme transition needed to settle before capture, and fonts are preloaded in the render harness.

Automated evidence covers actual SQLite reads/writes, atomic rollback, concurrent duplicate protection, schema migration, database restart, chat recovery, parser/clarification, financial periods, active timer conflict and controls, history/first-day/midnight streaks, Home reminders, inline writing, Promise/task integrity, challenge independence, guide replay, Undo expiry, both themes, 1.5× text for selected components, reduced motion and native-zone refresh mocks.

**Device-only checks remaining:** notification permission denial and actual delivery; alarm fallback/exact timing; app background/kill/restart timers; GPS accuracy/background battery; custom audio and interruptions; native clipboard/share/file/date-time pickers; TalkBack; physical keyboard/IME; OS date/time-zone change; real storage/export/restore; full-screen visual approval. iOS compilation was not available on this Linux host. No measured Home <100ms or battery/performance certification is claimed.

## Prioritized recommendations

1. **P0 — Complete backup and recovery.** Export/import all related records transactionally with versioned validation and a tested restore. This is the highest remaining reliability gap.
2. **P1 — Optional career onboarding.** Let notes, reminders and daily tools open immediately; defer company selection and career configuration. Requires the product flow approval identified in the audit.
3. **P1 — Device QA and accessible contrast.** Verify alarms/background behavior and TalkBack; audit every small-text/control contrast pair and 2× text on full screens. The current token check is only a starting point.
4. **P1 — Challenge workload and templates.** Show total daily commitment across active challenges, offer reusable templates and a quiet weekly review; warn about conflicting schedules before saving.
5. **P1 — Persistent writing drafts and reminder retry.** Preserve unsent Home/wall drafts across app termination; show saved-but-unscheduled reminders with a clear retry action.
6. **P2 — Search and connected reflection.** Build optional universal local search across thoughts/tasks/learning and source-linked reminder checklists. Offer a completion reflection without forcing one.
7. **P2 — Assistant expansion.** Add selected task edit/completion and learning reads only through verified tools; retain timed-completion constraints. Evaluate a remote model only if language coverage justifies privacy, cost and account architecture.
8. **P2 — Pin useful Home shortcuts.** User-selected favorites and a relevant next action, keeping preview caps and avoiding extra noise.

Account security/cloud sync would need a separate design and migration; the unused hardcoded login is not a secure account system. No such architecture was introduced in this scope.

### Device installation follow-up · 12 October 2026

The connected Nothing A142 accepted the update. USB briefly disconnected between commands and recovered; the launch screenshot and live process confirm the app opened. The OS notification permission prompt is left for the user to choose; onboarding is also left for the user to enter their own name, role and preferences. Home and feature smoke checks remain pending completion of setup. No claim of notification delivery or full device QA is made.
