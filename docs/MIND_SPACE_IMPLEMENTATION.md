# Mind Space implementation and verification

Working branch: `feature/mindspace-feedback`. Reviewed on 13 October 2026. This document describes the current worktree, not a shipped release. The original acceptance requirements remain in [the feedback plan](MIND_SPACE_FEEDBACK_PLAN.md).

## Implemented behavior

| Feedback | Current implementation |
| --- | --- |
| 1 — Thought message styling | Filled message surface with an inset fading divider and accent dot between metadata and content; selection has a distinct outline. |
| 2 — Honest lecture completion | Study time is separate from seek position. Full time is the default; an explicit 50% policy unlocks manual completion. Provider and task commands enforce the gate. Existing completed lectures remain completed without invented historical evidence. |
| 3 — Contextual Riya | Typed capabilities operate on real records, with confirmation for writes, persistent retry receipts, bounded results, date scope and clarification. Coverage below is explicit. |
| 4 — Multiple pins | Direct accessible pin/unpin controls, stable pinned-first ordering, and Pinned/Recent sections. |
| 5 — Lecture activities | Today can link or create a lecture in an explicitly selected course/module, including inline course/module creation. Generic task conversion retains its task identity and timer history. Historical generic engagement does not become verified lecture study. |
| 6 and 11 — Thought actions | Todo, Reminder and Both share transactional conversion. Multiple sources can become individual actions or a grouped checklist/reminder; existing relationships are reused. |
| 7 — Home Mind Space | User-requested rollback on 14 October: remove standalone Quick capture and place the familiar Mind Space input/preview below the profile. Collapsed by default with the latest active thought; expand shows up to four; View all opens the wall. Saved thoughts expose Todo/Reminder/Both. When hidden through customization, More still opens Mind Space and the header customization chip can restore the card. |
| 8 — Optional Money/check-in | Expense entry validates and saves once. Check-in is opt-in, configurable and quiet, with independent spending/water completion and skip behavior. Durable water receipts prevent duplicates after preference failure. |
| 9 — Personal Home | Save/cancel/reset, card visibility, order for other cards, compact Today, selected tools and up to four shortcuts. Mind Space has a fixed position below the profile with its own collapse/expand control. Hiding cards does not disable services. |
| 10 — Long Home thoughts | Measured overflow uses Read more and a full-detail sheet; source text is retained. |
| 11 — Merge | Ordered merge preview can be edited without reordering overwriting those edits. Source provenance and existing actions are preserved. Archive originals is explicit, and Undo rejects later conflicting work. |

## Data and lifecycle boundaries

Schema 16 adds typed thought/task/reminder relationships, merge provenance, scoped learning associations, and pending alert flags. Legacy text markers are backfilled only when unambiguous. Upgrade and backup transformations preserve existing data.

SQLite owns the Learning catalog after one-time migration. Preferences are a display cache. Standalone catalog saves publish state after the database commits; deleted courses cannot be revived by a stale cache. Course-scoped lecture IDs prevent collisions. Today dismissal preserves the lecture, converted task and timer history.

Stateful Riya commands prepare a durable request identity before changing Learning or Home. Receipt failure reports the already-saved outcome; recovery verifies current state and never reapplies an old uncertain request over newer work. Concurrent retries share one execution.

Task deletion Undo restores original IDs, descendants, explicit note/reminder links and recorded sessions atomically. Running sessions return paused, excluding the deleted interval from later timer calculations. Workspace replacement invalidates old Undo snapshots and selected Riya records; stale reviewed commands and writes during pending backup recovery are rejected. Learning session and catalog writes also check the workspace revision.

Native alert effects run after commit. Pending rows and cancellation receipts survive OS failures and retry on startup/resume. An asynchronous alert acknowledgement only clears the version that was actually scheduled; it cannot replace a newer edit. Reminder Undo restores identity and surviving source links without overwriting a newer record or reactivating a completed task's alert.

Task deletion uses explicit relationships and removes descendants, linked reminders and sessions atomically. Matching titles do not identify records. Medicine dose correction retains its existing explicit reversible domain transition; timed and lecture tasks cannot use it to bypass their completion gate.

## Riya coverage

The executable registry and executor are in `lib/core/ai/riya_capabilities.dart` and `lib/core/ai/riya_workspace_actions.dart`; intent resolution remains separate from domain mutation. Tests assert behavior, not a script for each test phrase.

- Thoughts: list/search/read/create/edit/pin/archive/restore/delete/merge/convert.
- Tasks: list/create/checklist/edit/reschedule/complete/delete, with timed/checklist/lecture restrictions.
- Reminders: scoped lists, create/edit/done/delete/snooze/alert mode, plus durable native reconciliation.
- Money: income/expense transaction create/read/edit/delete with explicit date, category, account and notes; bounded Today/date/All lists and SQL-aggregated income/spending/net summaries. Existing expense lists also default to Today. Record corrections preserve unspecified metadata and can explicitly clear notes. Legacy transfers remain readable and are excluded from income/spending totals; new transfers require a separate account-transfer model and are not fabricated. Monthly budget and savings goal lifecycle commands remain supported. Contributions update tracked savings without creating a transaction.
- Learning: bounded course/module/lecture reads; course, module and lecture create/edit/delete; scoped selection/playback, activity linking and gated completion. Catalog creation uses durable request identities; replay verifies existing outcomes without replacing later edits. Optional course URLs/dates can be explicitly cleared.
- Home: layout reads and card visibility changes.
- Hydration/Focus: water logging, day-scoped entry lists, correction/delete and daily goal updates; Focus start/pause/resume and stop, plus bounded date-scoped recorded Focus/Learning history. History pagination retains its selected date across midnight. Goal updates do not fabricate water entries.
- Medicine: schedule create/read/edit/delete/pause/resume, bounded schedule and day-scoped dose lists, and explicit taken/pending dose corrections. Writes use confirmation and durable receipts. Schedule creation requires the user’s name, dosage, form, times and duration. UI and bot use the same atomic lifecycle service. Edits preserve taken and historical doses, replace only future pending slots when scheduling changes, and retain record IDs for metadata changes. Alert scheduling and cancellation remain durable post-commit work using the dedicated Medicine channel and route.
- Other existing feature guides/navigation remain guides/navigation; they are not advertised as record mutations.

Offline reflection suggestions are authored suggestions, distinct from retrieved notes. They are saved only after an explicit Save request. They do not imply a connected model generated new content.

Phase F still requires challenges/walks and other-tool lifecycle coverage. Learning has catalog executors and supported natural command forms; broader conversational phrasing still needs an audit. Full bot control of every app feature is not claimed by this registry. Projects remain the separately deferred scope defined in the original plan.

## Verification evidence

- `mindspace_accessible_layout_test.dart`: 320 px screens, normal and 2× text, light/dark themes; checks capture-card actions, conversion, Home editing, lecture entry and merge preview preservation. Rendered screenshots are generated under `build/qa/mindspace/` with `--dart-define=MINDSPACE_SCREENSHOTS=true`.
- `mindspace_recovery_integrity_test.dart`: authoritative catalog recovery, monotonic study evidence, activity conversion/replay, rollback, scoped identity/dismissal, expense/water retries and concurrent alert edits.
- `connected_thought_actions_test.dart`: typed linking, grouped/individual conversion, stale inputs and safe merge Undo.
- `riya_money_hydration_lifecycle_test.dart`: budgets and savings CRUD, contribution replay, date-preserving water corrections, typed selection context, confirmation and failed-write rollback.
- `riya_external_recovery_test.dart`: prepare failure, concurrent retries, committed-result reporting after receipt failure, and recovery that preserves newer changes.
- `riya_workspace_commands_test.dart`: scoped bounded lists, context follow-ups, ambiguity/cancellation, receipt replay, domain gates and native retry behavior.
- Existing migration, backup, completion, reminder, medicine, Home and learning suites remain release gates.
- `integration_test/mindspace_device_test.dart` checks the isolated Android debug package, Home capture, pin/divider, Both, native alert schedule/cancellation, lecture policy and all-hidden Home access. It must pass on a real device before native behavior is claimed verified.

The isolated Android suite passed on the connected Nothing A142 on 13 October 2026: capture, pin/divider, Both replay, real native scheduling/cancellation, lecture eligibility, live Today projection and all-hidden capture. No production package was installed or modified. The four visual layout variants and ten recovery scenarios also passed. The native suite was refreshed successfully after the header and Learning command expansion. The performance audit remains a gate. Passing individual suites is not proof of every acceptance scenario or of zero remaining defects.


## Coverage audit still in progress

| Area | Status | Current boundary |
| --- | --- | --- |
| Thoughts and connected actions | Supported | Executable record operations and domain tests; suggestion authoring remains offline. |
| Tasks and reminders | Supported | Typed lifecycle commands, scoped pages and completion/native-effect gates. |
| Learning | Core lifecycle implemented | UI and bot catalog CRUD, activity linking, scoped playback, completion and recorded history; broader conversational phrasing remains under audit. |
| Focus | Core lifecycle implemented | Timer lifecycle and bounded recorded history with stable date pagination. |
| Money | Core lifecycle implemented | Income/expense transactions, scoped lists, metadata corrections, summaries, budgets and savings supported. Legacy transfer records are preserved; no new transfer behavior is advertised. |
| Hydration | Supported | Explicit logs, scoped reads, corrections, deletion and goal preferences. |
| Medicine | Core lifecycle implemented | Shared atomic schedule operations, history-preserving edits, explicit reversible dose logging, scoped bot reads and durable device alert reconciliation. Broader conversational phrasing remains under audit. |
| Challenges and walks | Planned for broader bot control | Existing UI/native services; evidence-aware bot executors remain required. |
| Other tools and settings | Partial | Existing guides/navigation; inventory and executable operations remain required. |
| Backup/restore | UI supported; bot partial | Replacement review and file picker remain explicit. |

Latest completed regression refresh: **363 tests passed**, `flutter analyze` reported no issues, and `git diff --check` passed. This includes Learning catalog CRUD/replay, converted-task routing, recorded history/date pagination, task-tree Undo, workspace replacement guards, Money/hydration coverage, calendar validation, bounded task pages and the header audit. The focused Money/hydration + workspace suites passed 18 tests; the header/layout regression batch passed 14 tests. The isolated native Android refresh also passed Home capture, Thought Wall styling/pinning, Both replay, notification scheduling/cancellation, lecture eligibility and all-hidden capture. These are verified checkpoints, not a claim that the full plan is complete.

The latest focused Learning/Undo/history regression batch passed 29 tests before the final 356-test refresh. New Learning work also verifies that converted tasks cannot start generic timers or bypass lecture completion gates.

Final review added a regression for history-to-reminder context switching: “Tomorrow” follows the newer reminder list, not the prior history query. Static analysis and the final full suite passed after this correction.

Money expansion: six new typed transaction capabilities use the existing receipt transaction, confirmation and workspace recovery guards. Focused Money/history/workspace/hydration regression batch: 29 tests passed. Monthly Money aggregates use `[month start, next month start)`; transaction summaries aggregate in SQL rather than retrieving every record. Full suite: 363 tests passed; static analysis clean. The final Money/UI regression batch passed 14 tests after the empty-state copy correction. The isolated Android suite also passed: Money displayed bot-created income, reflected metadata/title corrections, and removed the deleted record live; income did not increase today's spending.

Medicine expansion: generation, edits, dose corrections and deletion now commit atomically with linked tasks/reminders/logs. The edit sheet updates its original schedule instead of creating a duplicate. Failed database writes roll back projections; failed native scheduling remains pending for startup/resume recovery. Dedicated Medicine notifications retain their channel and `/medicine` route through both recovery paths. Narrow screens and large text wrap schedule titles and stack dosage/form controls; sheet-owned controllers dispose with the sheet. Regression coverage includes rollback, preserved dose timestamps/IDs, blocked linked-task completion, confirmation/replay, day pagination and edit-sheet save identity.

Medicine verification on 13 October 2026: full regression suite passed **373 tests**; the final permission guard was followed by a passing 28-test Medicine/Riya/notification batch and clean static analysis. The six-test schedule/layout batch verifies 320 px at 2× text, saving edits without duplication, controller disposal and blocked-dose rollback. The isolated Android suite passed after its setup enabled QA notification permission and suppressed the Medicine first-use guide: dedicated native Medicine scheduling, edit identity, live screen updates and durable deletion were verified alongside existing Mind Space/Money/Learning checks. Notification permission denial now leaves scheduling pending. Overnight delivery, battery restriction behavior and broader performance QA remain open.

Focused conversation update (1.0.10): polite English prefixes and selected Hinglish command framing now reach the typed Learning/Medicine operations. Medicine reads and edits accept an exact schedule name; duplicate names ask for a record number. Explicit AM/PM times are converted to schedule slots; missing meridiem is clarified. Successful Learning results preserve the selected course/module/lecture IDs in receipts so “edit that”, name/title changes and minute-based duration follow-ups target the selected record. Topic changes, cancellation and workspace replacement clear selection. Shared field names are routed to the selected domain. Confirmation and completion gates remain enforced. This is a bounded vocabulary expansion; the wider phrasing audit remains open. Full regression: 378 tests passed; final focused batch: 20 passed; static analysis clean.

The focused Android chat suite passed on the Nothing A142 in the isolated debug package: Hinglish Medicine list/read, “edit that” clarification, unchanged data until confirmation, original schedule identity after correction, Hinglish course creation and selected-course rename through the actual chat composer. Release 1.0.10 (11) packages this conversation update for device review. Other tools remain deferred.

Home UI revision requested on 14 October 2026: the standalone Quick capture block is removed. Mind Space retains the existing inline input and draft key, sits directly below the header when visible, and starts with the newest active thought. Its expand control shows up to four recent thoughts; View all opens the full wall. Post-save Todo/Reminder/Both reuse the existing reviewed conversion flow. The previous always-visible capture requirement is superseded by this explicit user preference; a hidden Home card remains reachable through More and the header customization chip. Existing thought records, links and other saved Home preferences are retained. Customization reflects the fixed top position rather than offering an ineffective reorder or compact toggle. The date is placed above the wrapping action group so it cannot be crowded by Start/Riya/profile. Thought Wall and Home message bubbles have a subtle rounded outline, with stronger selection borders and the existing inset divider preserved. Release target: 1.0.11 (12).

Home UI verification: all 382 regression tests passed; static analysis is clean. The 24-test focused batch includes latest/four-note toggle checks and non-overlapping header bounds at 320 px with normal/2× text in light/dark themes, plus existing save/draft/conversion/layout coverage. The isolated Nothing A142 Home UI suite passed: default latest note, four expanded previews, no duplicate Quick capture, post-save Todo/Reminder/Both, no Todo before review, saved Todo, View all routing and visible Thought Wall outlines.

Follow-up feedback in the same UI update: tapping a Home thought or Read more opens its actual note in the full wall, with the appropriate Today/History view, rather than a Home detail popup. Customize Home replaces the Mind Space profession-row shortcut; the separate customization row is removed. Selection shows Todo/Reminder/Both/Merge/Share chips below the view tabs, disables Merge until two notes are selected, and leaves selection only after a successful save. Cancel and failed saves retain selection. Selection taps are immediate rather than waiting for the normal double-tap-to-complete gesture. Archive indicators and swipe backgrounds use quiet neutral colors; running/paused Home activities use softer neutral surfaces.

Timed tasks retain their manual completion gate. The Today detail dialog opens a timer instead of offering Mark Done for a positive duration target. A running generic task session ends automatically when its active time plus previously completed sessions reaches the current target. Pauses do not earn time, the target is rechecked at commit, and completion is transactional/idempotent against a concurrent manual session finish. Learning lectures remain on their separate evidence policy. A stale deadline is rejected after workspace replacement.

Next separate feature requested by the user: a reusable compact calendar, starting with Challenges, showing start/end dates, today and crossed-out elapsed calendar days. Elapsed dates must remain distinct from verified challenge completion. This is queued after the bug-fix device review under the user's one-update-at-a-time workflow.

Final feedback verification: the full 392-test regression suite and combined Nothing A142 UI/timer suite passed. The final Medicine boundary guard was followed by a passing 11-test selection/timer batch and clean static analysis: a timer cannot fabricate dose-taking even if a linked dose task is assigned a duration. Native checks exercised Home note routing, visible selection chips, merge exit, original Home input, reviewed Todo creation, four-preview collapse/expand, Thought Wall outlines, timer-only detail controls and automatic task completion.

Release 1.0.11 (12), ARM64 phone build, installed and cold-launched successfully on 14 October 2026. Actual device Home inspection confirmed the unclipped date/actions, Customize Home beside Backend Engineer, one recent thought by default, no standalone Quick capture, and retained user note content.

## Thought Wall board and spaces (unverified draft, 31 October 2026)

`/thought-wall` now opens `ThoughtBoardScreen` (`lib/features/thought_wall/board/`): a spaces row, a hero card for the newest thought, then a two-column (or one-column) board grouped by day. Cards carry no buttons: tap opens the detail sheet, long-press selects (Move, Done, Archive, Delete, More), double-tap completes. A leading `#space` tag in the composer files the thought into that space. `/thought-wall/space?key=` opens `ThoughtSpaceScreen`: quick-add field that stays open, paste-a-list, To do / Done / All tabs, tap-circle completion, list or poster view, rename/delete for user-made spaces. The previous `ThoughtWallScreen` is kept for its existing tests and is no longer routed.

Not yet run: `dart format`, `flutter analyze`, `flutter test`, device check. New unit tests: `test/thought_board/board_logic_test.dart`.
