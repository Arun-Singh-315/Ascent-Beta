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
| 7 — Quick capture | Home always exposes capture, including all-hidden custom layouts. Action chips appear only after the note is committed. Full text remains reachable from previews. |
| 8 — Optional Money/check-in | Expense entry validates and saves once. Check-in is opt-in, configurable and quiet, with independent spending/water completion and skip behavior. Durable water receipts prevent duplicates after preference failure. |
| 9 — Personal Home | Save/cancel/reset, card visibility and order, supported compact variants, selected tools and up to four shortcuts. Hiding cards does not disable services. |
| 10 — Long Home thoughts | Measured overflow uses Read more and a full-detail sheet; source text is retained. |
| 11 — Merge | Ordered merge preview can be edited without reordering overwriting those edits. Source provenance and existing actions are preserved. Archive originals is explicit, and Undo rejects later conflicting work. |

## Data and lifecycle boundaries

Schema 16 adds typed thought/task/reminder relationships, merge provenance, scoped learning associations, and pending alert flags. Legacy text markers are backfilled only when unambiguous. Upgrade and backup transformations preserve existing data.

SQLite owns the Learning catalog after one-time migration. Preferences are a display cache. Standalone catalog saves publish state after the database commits; deleted courses cannot be revived by a stale cache. Course-scoped lecture IDs prevent collisions. Today dismissal preserves the lecture, converted task and timer history.

Stateful Riya commands prepare a durable request identity before changing Learning or Home. Receipt failure reports the already-saved outcome; recovery verifies current state and never reapplies an old uncertain request over newer work. Concurrent retries share one execution.

Native alert effects run after commit. Pending rows and cancellation receipts survive OS failures and retry on startup/resume. An asynchronous alert acknowledgement only clears the version that was actually scheduled; it cannot replace a newer edit. Reminder Undo restores identity and surviving source links without overwriting a newer record or reactivating a completed task's alert.

Task deletion uses explicit relationships and removes descendants, linked reminders and sessions atomically. Matching titles do not identify records. Medicine dose correction retains its existing explicit reversible domain transition; timed and lecture tasks cannot use it to bypass their completion gate.

## Riya coverage

The executable registry and executor are in `lib/core/ai/riya_capabilities.dart` and `lib/core/ai/riya_workspace_actions.dart`; intent resolution remains separate from domain mutation. Tests assert behavior, not a script for each test phrase.

- Thoughts: list/search/read/create/edit/pin/archive/restore/delete/merge/convert.
- Tasks: list/create/checklist/edit/reschedule/complete/delete, with timed/checklist/lecture restrictions.
- Reminders: scoped lists, create/edit/done/delete/snooze/alert mode, plus durable native reconciliation.
- Money: expense create/summary/read/edit/delete; monthly budget list/set/edit/delete; savings goal list/create/edit/delete and explicit contributions. Contributions update tracked savings without creating a transaction.
- Learning: bounded course progress, pause/resume and scoped completion.
- Home: layout reads and card visibility changes.
- Hydration/Focus: water logging, day-scoped entry lists, correction/delete and daily goal updates; Focus start/pause/resume and stop. Goal updates do not fabricate water entries.
- Other existing feature guides/navigation remain guides/navigation; they are not advertised as record mutations.

Offline reflection suggestions are authored suggestions, distinct from retrieved notes. They are saved only after an explicit Save request. They do not imply a connected model generated new content.

Phase F still requires additional Learning catalog commands, remaining transaction types, medicine, challenges/walks and other-tool lifecycle coverage. Full bot control of every app feature is not claimed by this registry. Projects remain the separately deferred scope defined in the original plan.

## Verification evidence

- `mindspace_accessible_layout_test.dart`: 320 px screens, normal and 2× text, light/dark themes; checks capture-card actions, conversion, Home editing, lecture entry and merge preview preservation. Rendered screenshots are generated under `build/qa/mindspace/` with `--dart-define=MINDSPACE_SCREENSHOTS=true`.
- `mindspace_recovery_integrity_test.dart`: authoritative catalog recovery, monotonic study evidence, activity conversion/replay, rollback, scoped identity/dismissal, expense/water retries and concurrent alert edits.
- `connected_thought_actions_test.dart`: typed linking, grouped/individual conversion, stale inputs and safe merge Undo.
- `riya_money_hydration_lifecycle_test.dart`: budgets and savings CRUD, contribution replay, date-preserving water corrections, typed selection context, confirmation and failed-write rollback.
- `riya_external_recovery_test.dart`: prepare failure, concurrent retries, committed-result reporting after receipt failure, and recovery that preserves newer changes.
- `riya_workspace_commands_test.dart`: scoped bounded lists, context follow-ups, ambiguity/cancellation, receipt replay, domain gates and native retry behavior.
- Existing migration, backup, completion, reminder, medicine, Home and learning suites remain release gates.
- `integration_test/mindspace_device_test.dart` checks the isolated Android debug package, Home capture, pin/divider, Both, native alert schedule/cancellation, lecture policy and all-hidden Home access. It must pass on a real device before native behavior is claimed verified.

The isolated Android suite passed on the connected Nothing A142 on 13 October 2026: capture, pin/divider, Both replay, real native scheduling/cancellation, lecture eligibility, live Today projection and all-hidden capture. No production package was installed or modified. The four visual layout variants and ten recovery scenarios also passed. The final device refresh after the later header and command expansion, plus the performance audit, remain gates. Passing individual suites is not proof of every acceptance scenario or of zero remaining defects.


## Coverage audit still in progress

| Area | Status | Current boundary |
| --- | --- | --- |
| Thoughts and connected actions | Supported | Executable record operations and domain tests; suggestion authoring remains offline. |
| Tasks and reminders | Supported | Typed lifecycle commands, scoped pages and completion/native-effect gates. |
| Learning | Partial | UI catalog CRUD and activity linking; bot progress, playback and completion. Bot catalog CRUD remains required. |
| Focus | Partial | Timer lifecycle; bounded history commands still required. |
| Money | Partial | Expenses, budgets and savings supported; income/general transaction commands remain required. |
| Hydration | Supported | Explicit logs, scoped reads, corrections, deletion and goal preferences. |
| Medicine | Planned for broader bot control | Existing UI/services preserved; bot scheduling/logging/editing requires shared lifecycle work. |
| Challenges and walks | Planned for broader bot control | Existing UI/native services; evidence-aware bot executors remain required. |
| Other tools and settings | Partial | Existing guides/navigation; inventory and executable operations remain required. |
| Backup/restore | UI supported; bot partial | Replacement review and file picker remain explicit. |

Latest completed regression refresh: **340 tests passed**, `flutter analyze` reported no issues, and `git diff --check` passed. This includes the additional Money/hydration coverage, calendar validation, bounded legacy task pages and header audit. The focused Money/hydration + workspace suites passed 18 tests; the header/layout regression batch passed 14 tests. These are verified checkpoints, not a claim that the full plan is complete.
