# Mind Space feedback — implementation plan and product review

Planning draft · 12 October 2026 · inspected source baseline: `1.0.9+10`.

This is a proposal based on the eleven shared notes, current source, existing test coverage, and earlier review documents. No app behavior has been changed and no tests have been run for this planning task. Historical review results are evidence for their recorded builds, not fresh verification of this checkout.

## 1. Honest assessment

The strongest theme is **capture quickly, turn an idea into an action easily, and see the same state everywhere**. That is a useful direction for Ascent. The feedback identifies both discoverability problems and real integrity gaps; treating every note as a brand-new feature would create unnecessary work.

My recommendations:

- Prioritize quick capture, readable thought cards, clear action chips, and reliable lecture completion. These improve everyday use and trust.
- Expand Riya substantially, using the same commands as the screens. “Control every feature” is a long-term coverage goal, not a credible single-release promise.
- Keep Home customization bounded: show/hide, reorder, compact/expanded presentation where useful, and a few supported groups. An arbitrary dashboard builder would make navigation, accessibility, and maintenance much harder.
- Offer optional daily logging without another compulsory startup question. A helpful assistant should not turn opening the app into filling a form.
- Treat merging as a recoverable editorial action. Combining words is easy; preserving linked tasks, reminders, and history is the difficult part.
- Do not make the Todo/Reminder choices available only for a few seconds. Temporary visibility is useful, but permanent access is essential.
- A 50% completion threshold is convenient but does not mean a lecture was fully watched. Use explicit labels and a visible policy rather than overstating progress.

## 2. What already exists and what is missing

| Feedback | Source finding | Implementation decision |
| --- | --- | --- |
| 1. Thought header/content divider | Thought Wall has a dated header, actions and chat-like surfaces | Interpret this as a quieter bubble with a designed separator below the header; review a mockup before changing the card structure |
| 2. Watch before completing | The player button can call `markLectureCompleted` immediately; provider completion has no eligibility gate | Add a shared completion policy and evidence model, enforced below the UI |
| 3. Broader Riya and shorter contextual answers | Typed capability registry, verified local execution and request receipts exist; thought support includes search; reminder listing currently returns upcoming rows without date scoping | Extend the registry and conversation handling; keep the existing verification safeguards |
| 4. Multiple pins | `isPinned`, independent pin toggles, a Pinned filter and menu action already exist | Expose an accessible pin button directly on each card; improve ordering/discoverability |
| 5. Activity becomes a course lecture | Learning already contributes activities; Add activity needs a deliberate course/module linking flow | Create or link a canonical lecture instead of a disconnected timer task |
| 6. Grouped or individual conversion | Selected thoughts support Todo, individual reminders and one list reminder | Add an explicit conversion sheet for Individual / Grouped and Todo / Reminder / Both |
| 7. Immediate Mind Space access | Home already has inline writing; persisted draft recovery was added previously | Make the composer easy to reach and focus in one tap; reuse draft handling |
| 8. Better Money capture | Money already has transactions, budgets and savings goals; Riya can create expenses and summarize a period | Improve capture and optional check-in before adding more financial modules |
| 9. Custom Home | Home customization is already specified in `NEXT_UPDATE_PLAN.md` | Reuse that registry/settings approach; add only justified card variants and groups |
| 10. Truncated Home thought | Home preview uses two lines with ellipsis | Add explicit “Read more” for truncated content and a full-note destination |
| 11. Merge and temporary chips | Bulk actions exist; no merge workflow was found in inspected thought actions | Add recoverable merging and post-save chips with a persistent fallback |

Working assumption: “Mind palace,” “Mind Space,” and “Thought Wall” refer to the same capture-and-organize experience. Do not create a separate module for each name. Use Mind Space as the user-facing umbrella and Thought Wall as the full notes view.

## 3. Proposed experience, note by note

### Notes 1, 4 and 10 — readable cards and visible pins

Keep a compact header: date/time, pin, and overflow actions. Separate it from content with a thin, inset separator that fades toward its ends and includes a small warm accent/dot. Use the existing theme tokens, sufficient contrast, and generous spacing. Avoid animation, heavy glow, or ornament that competes with the text. The meaning comes from spacing and hierarchy, so the accent can disappear in accessibility modes.

Allow several notes to be pinned independently. Show a labeled Pinned section above Recent, preserving a stable newest-first order within each section initially. Unpinning returns a note to its chronological place. Archived notes keep their pin metadata but do not appear in the active Pinned section. A completed pinned note remains pinned and visibly completed.

Home stays a preview. Display a bounded excerpt, ellipsis, and “Read more” only when content really overflows. Opening it shows the full note and its actions. Preserve line breaks, links, Unicode and original text; never save the truncated representation. Keep edit/copy reachable without crowding a narrow header.

### Notes 6, 7 and 11 — capture first, organize afterward

Place a compact “Write a thought…” entry near the top of the default Home layout. One tap focuses the existing inline composer. An always-reachable capture shortcut remains available when users hide or move the Mind Space card. Preserve separate Home/Wall drafts, keyboard behavior, double-submit protection and failed-save recovery.

After a successful save, reveal `Todo`, `Reminder`, and `Both` below the new note. Proposed starting behavior: roughly eight seconds, with the timer paused during interaction and extended/disabled when accessibility requires it. These actions remain in the note menu afterward. Do not show a saved receipt or clear the draft before persistence succeeds.

For multiple notes, use a bottom sheet:

1. Select notes and inspect the selection count.
2. Choose Individual items or One grouped item, with a preview.
3. Choose Todo, Reminder or Both.
4. Ask for scheduling only when needed; offer Today / Tomorrow / Pick date and an explicit time.
5. Save once and show a concise result with a destination and recovery action.

“Both” creates the selected task structure and reminder links together. Individual creates one task per source note; Grouped creates one parent task with a checklist, rather than one unreadable title containing all notes. A grouped reminder previews the list without duplicating task titles. Reminder-only must not create hidden todos. If a note already has a linked task, reuse it or explain a conflicting grouping choice.

AI may offer “Would you like to turn these into tasks?” when the user asks for organization. Avoid interrupting every reflection with unsolicited productivity suggestions. Saving a thought must remain possible without organizing it.

**Merge is a separate action from grouping.** Grouping coordinates several records; merging creates an editable combined note. Select two or more notes, preview their order and combined text, then save a new note with provenance links. Keep originals by default; offer an explicit archive-originals option. Do not automatically transfer, complete, delete or duplicate their tasks/reminders. List existing links in the preview. The merged note starts without completion or pin status unless selected explicitly. Provide Undo; restore only the changes from that merge, preserving subsequent edits and actions. Exclude archived sources from initial selection and detect a source edited/deleted while the preview was open.

### Notes 2 and 5 — honest lecture progress and one learning identity

The current Learning provider advances an elapsed timer and permits seeking. That is study-time evidence, not proof of external-video playback. Introduce separate concepts:

- Playback position: where the learner resumes.
- Credited engagement: qualifying active study time, excluding pauses and duplicated sessions.
- Verified watched coverage: distinct media intervals actually played, only where a player integration exposes trustworthy events.
- Completion eligibility and completed state: governed by a policy shared by all entry points.

Recommended default: completion requires the full supported evidence target, with only a documented media-end tolerance for rounding. Offer an explicit flexible policy that unlocks the manual button at 50%, matching the feedback's alternative. Display “Eligible to mark complete” at 50%; never display “Fully watched” because the user pressed it. Do not automatically complete at 50%. For measured full playback, auto-completion can follow the policy. For timer-only study, label the evidence “Study time,” and for external content without measurable playback, explain that full watching cannot be verified; offer an explicitly self-reported completion route rather than inventing watched coverage.

Seeking forward cannot earn credit; replaying the same interval cannot increase unique watched coverage. Real replay study time may count once as elapsed engagement, with the existing overlap rules. Progress belongs to `(courseId, lectureId)`; a shared numeric lecture ID across courses cannot identify the record alone. Unknown/zero duration must have a clear duration-entry or self-report flow, never a divide-by-zero or automatic-complete outcome.

Enforce eligibility in a domain command/provider, so the player, syllabus, Today, Home, Riya, and notification actions cannot bypass it. Return an explicit result; only show success after saved state is verified. Preserve existing completed records on upgrade, even when their historical evidence is unknown. Do not fabricate qualifying playback for old completions. Existing tests that complete a fresh lecture immediately must gain valid evidence fixtures or explicitly test legacy migration; their old expectation must not silently override the new requirement.

For Add activity, let users select Lecture, then choose an existing course/module and either Link existing lecture or Create lecture. Resolve this before creating a session. A generic timed activity remains a generic timed activity until the user explicitly converts it. Conversion must preserve recorded sessions, adopt the lecture policy for future completion, and disclose that earlier generic time is not verified playback. Provide Create course/module inline when needed, without silently putting lectures in the default course.

Home, Today and Learning display projections of the same lecture. Removing it from Today hides today's projection; deleting the lecture is a separate catalog action. Do not create an ordinary checkbox task that can complete the lecture indirectly. Starting from any entry point resumes the same eligible active session. Preserve current completed-task locking and strict streak rules.

### Note 3 — Riya as a capable, contextual assistant

The concern about too many test cases is valid: a bot built from phrase-by-phrase conditions becomes brittle. Tests should specify behavior; they should not be the runtime conversation script.

Use a capability registry with typed arguments, validation, entity resolution and shared domain commands. Resolve intent to a structured operation, retain the necessary conversational context, ask one useful clarification, execute through the same service as the screen, and verify the result. An optional model-backed language resolver can interpret varied phrasing into these allowed operations; authorization, completion rules and database writes stay in deterministic app code. Preserve useful local/offline commands and explain unavailable online assistance.

The existing resolver includes phrase matching, so expand the underlying conversation/action model before simply adding many more conditionals. Maintain a coverage manifest with each operation marked Supported / Partial / Planned / Unavailable. Distinguish an actual action from opening a screen. Do not advertise all-feature control before every supported operation has an executor and lifecycle tests.

| Area | Coverage target | Important constraint |
| --- | --- | --- |
| Thoughts | List/search/read/create/edit/archive/delete/pin/unpin/merge/convert | Saved-text retrieval and new reflection generation are distinct; generated suggestions save only on request |
| Tasks | Read/create/edit/delete/reschedule/subtasks/complete | Reuse timed eligibility and completed-item rules |
| Reminders | Read/create/edit/delete/snooze/done/mode changes | Saved record and device alert status are reported separately |
| Learning | Courses/modules/lectures, linking, progress, playback controls, eligible completion | Real identity, active-session ownership and evidence policy |
| Focus | Start/pause/resume/stop/read history | No duplicate timer or false time credit |
| Money | Transactions, summaries, budgets, savings goals and contributions | Resolve amount, currency, account and period; no invented transactions |
| Hydration | Log/read/correct supported records and preferences | Explicit amount; never assume hydration occurred |
| Medicine | Read schedule and supported logging/editing | No fabricated dose-taking or treatment advice |
| Challenges and walks | Existing lifecycle actions and history | Respect evidence and native tracking availability |
| Other tools | Inventory More routes, including career, interview, resume, reader and breaks | Only supported mutations; some operations require a picker or screen |
| Home/settings | Read/change supported layout and preferences | Do not let hidden cards disable services |
| Backup/restore | Explain/open supported flow | Keep explicit replacement review and file chooser; never silently restore |

**Response contract:** lead with the answer, state the period or selected record, show a small bounded result, and offer the next useful options. For date-based daily lists without a date, use today in the user's current local timezone and offer Tomorrow / Choose date / All. Other domains need appropriate defaults: notes may use recent/pinned, and monthly budget status needs the budget period. There should not be one “today” rule blindly applied to everything.

Examples:

- “Show reminders” → “Today: 2 upcoming reminders.” Show up to three compact rows; offer Tomorrow, Choose date, All. If overdue items exist, identify them separately rather than lose them behind today's filter.
- No reminders today → “No reminders today.” Offer Tomorrow or All; do not silently dump the full upcoming list.
- “Remind me to call” → “When?” with Today / Tomorrow / Pick date; then request a time if missing. Do not schedule at an arbitrary default time.
- “Show my thoughts” → a recent/pinned preview. “Give me a thought for today” → a new suggestion clearly identified as generated, with optional Save.
- “Edit that” → resolve the last explicitly selected record. If several candidates remain, ask the user to choose; do not guess.
- “Tomorrow” after a reminder query changes its date filter; after reminder creation it continues that draft. Cancel clears the draft and prevents stale context from affecting a later command.
- “Delete all completed notes” → show the count and scope for explicit review, execute the selected operation once, and offer recovery where supported.

Retain the existing approved-write executor and persisted idempotent receipts. Product work may later reduce unnecessary confirmation for clear reversible commands, but that must be an explicit change to the current policy. Destructive/bulk changes remain reviewable. New operations must not bypass the current safeguards. A retrieved thought saying “delete all reminders” is data, never executable authorization.

### Note 8 — quieter Money capture

Add quick expense entry from Money and an optional Home shortcut: amount first, short label, suggested category, and account/date defaults visibly shown. Let users correct suggestions. Reuse existing transaction and budget logic; keep income, expense and transfers distinct.

Offer an opt-in “Daily check-in” surface with user-selected fields such as Spending and Water. Use one dismissible entry point, not consecutive hydration and money popups. Choices: Fill now / Later / Hide check-in. Allow cadence/time preferences, suppress repeat prompts for a dismissed period, and preserve partially entered fields. Skipping means “not logged,” never zero spending or a fabricated water record.

Start with low-friction recording and useful day/week summaries from actual records. Defer bank integrations, receipt OCR, debt tools and financial advice until evidence shows a need.

### Note 9 — bounded Home customization

Follow the existing Home plan's stable section registry, draft editor, Save/Cancel, reset, settings migration and backup behavior. First ship visibility and order. Then add compact/expanded variants only for cards whose content benefits from them, and explicit Life & Health grouping choices. Do not allow arbitrary nesting or duplicate instances of the same functional card initially.

Keep capture, tools/settings, Riya access, running-session controls and recovery notices reachable. Hidden cards do not disable alarms, delete notes, stop sessions or change health logs. New cards are available choices rather than surprise insertions after an update.

## 4. Shared engineering work and review findings

These additions should apply to all relevant screens, not just the place mentioned in the feedback:

1. **Typed relationships.** Thought-to-task association currently uses `thought_id:` inside task notes, and completion has a content-matching fallback. Introduce explicit association records with foreign keys, including group/merge provenance where appropriate. Backfill unambiguous ID markers; preserve uncertain legacy links for review. Two notes with identical wording must not affect one another merely because their text matches. Grouped task completion must have a defined rule: checklist-item completion maps to its source note; completing the parent cannot falsely complete unfinished children.
2. **Shared commands.** Route UI and Riya through the same validation and mutation services. Keep learning eligibility, task completion, native alert cleanup, timer ownership and edit/delete behavior consistent.
3. **Atomic writes and external effects.** Todo + Reminder, conversion and merge write transactionally. Native scheduling runs through durable reconciliation/retry after commit; a DB transaction alone cannot atomically roll back OS alerts. Report saved-but-alert-pending honestly. Undo also reconciles device alerts.
4. **Recovery and compatibility.** Version new data/settings, preserve IDs and historical completion, update whole-workspace backup/restore, and handle interrupted writes. Coordinate new relationships with the planned project associations; avoid competing migration designs.
5. **Accessibility and performance.** Reuse shared card/sheet/confirmation tokens. Verify narrow screens, both themes, 2× text, screen readers, reduced motion, keyboard and scroll behavior. Bound previews and paginate/search full lists; avoid a blur per note or loading every record for chat.
6. **Real-device confidence.** Earlier reviews leave broader OEM/battery-restricted alert, accessibility and low-end performance coverage open. Changed timers/alerts need device checks; a widget test cannot establish overnight alarm reliability or external-video watching.

Historical issues in earlier audits may already be fixed. Revalidate affected behavior rather than importing their entire blocker list unchanged.

## 5. Delivery order and scope

| Stage | Work | Exit criterion |
| --- | --- | --- |
| A — Contracts and designs | Card/capture/conversion mockups; lecture evidence policy; Riya operation inventory; relationship/migration design | States and edge cases reviewable; existing functionality separated from new work |
| B — Daily usability and integrity | Separator, direct pins, Read more, quick capture, persistent action fallback; shared lecture eligibility gate | Notes stay recoverable; no completion bypass from any current entry point |
| C — Connected actions | Typed note links, Individual/Grouped/Both, merge provenance/recovery, activity-to-lecture linking | One identity across views; no duplicate writes, lost links or alert mismatches |
| D — Riya core expansion | Contextual date filters, bounded answers, thought create/read/edit/pin/convert, reminder/task lifecycle commands | Natural variants and follow-up context work; state-changing results verified |
| E — Personal Home and Money | Existing Home customization plan, optional expense shortcut/check-in | Preferences persist; hidden tools remain reachable; startup stays calm |
| F — Broader Riya coverage | Remaining supported learning, money, health and other-tool commands | Coverage manifest matches actual executors and tested lifecycle behavior |

Stages B and E can ship independently after their dependencies and regression checks pass. Stage C's schema/service work precedes the Riya commands that use it. Keep the existing `NEXT_UPDATE_PLAN.md` Home specification as the detailed Home reference. Treat Projects as its own later scope decision; these eleven notes do not require shipping Projects or every Riya capability simultaneously. No release date or effort estimate is promised before the operation inventory and design work.

## 6. Acceptance and regression cases

Test shared domain rules once at their boundary, then add targeted UI and device cases for distinct paths. Test natural-language variants against structured outcomes rather than one exact response string. Existing coverage is a starting point, not proof the proposed behavior works.

### Thought capture and presentation

- N01: A long multiline note has a clear excerpt and Read more; full view/edit/copy/share preserve the exact original content.
- N02: Short notes have no false Read more action; large text and narrow widths keep date, pin and menu accessible in both themes.
- N03: Pin three notes, restart, filter pinned, unpin one; other pins remain. Archive/restore/completion follow the defined ordering rule.
- N04: Home capture is reachable in one tap; hidden/reordered Mind Space still has a capture entry. Keyboard does not hide Send or saved-note actions.
- N05: Failed save preserves draft; double tap/retry inserts once. Restart and separate Home/Wall drafts retain Unicode and line breaks.
- N06: Chips appear only after persistence, time out accessibly, and stay available in the menu. Opening a sheet stops expiry from dismissing an active interaction.

### Conversion, grouping and merge

- N07: Repeated Todo conversion reuses the linked task; Reminder-only creates no task; Both creates the right task-reminder relationships once.
- N08: Multiple selected notes work in Individual and Grouped modes; selection/filter changes cannot accidentally include unseen records.
- N09: Past/missing reminder time requests correction; cancelling any sheet writes nothing.
- N10: A failed Both write leaves neither half committed; failed native scheduling leaves durable retry and an honest saved/pending status.
- N11: Identical note text does not cross-complete unrelated notes. Checklist completion affects only its explicit source relationship.
- N12: Merge preserves selected order and source links; archive-originals is explicit; source edits/deletion during preview are detected.
- N13: Merge Undo preserves later edits and original tasks/reminders; recovered alerts are reconciled without duplicate notifications.

### Learning and activities

- L01: Before threshold, the button explains what is missing; direct provider, syllabus, Home, Today and Riya attempts also reject completion.
- L02: Test immediately below, exactly at and above the selected threshold; full-policy and 50%-policy behavior are distinct and clearly labeled.
- L03: Seek forward, replay, pause and buffering do not fabricate watched coverage; changing playback rate follows documented media-versus-study-time rules.
- L04: Background/pause/restart/course switch restore the correct record and progress without duplicate session or credit.
- L05: Unknown duration uses its explicit fallback; two courses with equal lecture IDs cannot update one another.
- L06: Old completed lectures survive migration without invented evidence; persistence failure cannot display a success or advance to the next lesson.
- L07: Add activity links or creates one lecture in the chosen module; all views show the same progress. Existing generic sessions remain historical engagement after conversion.
- L08: Removing from Today does not delete from the course; replaying/reselecting follows existing dismissal rules. Completing a reminder cannot complete an ineligible timed lecture/task.
- L09: Concurrent Focus/Learning credit follows existing unique-second streak rules; overlapping timers and fast seeking cannot inflate totals.

### Riya behavior and coverage

- A01: “Show reminders” means today in the local timezone; Tomorrow/Pick date/All change the explicit range. Overdue records remain discoverable separately.
- A02: Empty results give a concise scoped answer; large results are bounded with Show more, never an unbounded transcript dump.
- A03: Missing time/date, ambiguous names, multiple matches and “edit that” get the necessary clarification; no silent record selection.
- A04: Mixed English/Hinglish, spelling variants and paraphrases resolve to the same supported command or a useful clarification. Unsupported requests do not claim success.
- A05: Switching topic/cancelling clears pending mutation state; relative-day follow-ups use the current conversation and timezone, including midnight/month/year rollover.
- A06: New generated reflections are distinguishable from saved thoughts; Save is explicit and saved-text instructions remain inert.
- A07: Every supported write has validation, rejected/missing-record, persistence-failure and duplicate/concurrent-submission cases. Replayed receipts must not create another record.
- A08: Deletes/edits clean up correct links and native alerts; bulk review shows the actual selected scope. Denied alert permission is reported separately from a saved reminder.
- A09: UI and Riya produce the same domain result for the same operation; chat navigation alone cannot masquerade as successful editing.
- A10: Offline/unavailable model or tool keeps supported local actions useful; partial multi-action outcomes are explicit and recoverable.

### Money, Home and release integrity

- H01: Expense entry validates amount/date/account and persists once; day/week totals match actual transaction types without counting transfers as spending.
- H02: Skipped check-in creates no zero or health record; dismissal/cadence prevents repeated startup prompts. Cancelling an expense does not discard another field's draft.
- H03: Show/hide/reorder/variants save together; Cancel changes nothing; Reset changes only layout. All-hidden, unknown/duplicate section IDs and corrupt preferences stay usable.
- H04: Hiding Learning/Medicine/Reminders does not stop sessions or alerts; all tools, capture and recovery controls remain reachable.
- H05: Upgrade and export/restore round trips preserve pin states, merge provenance, typed links, lecture evidence/policy, layouts and check-in preferences. Interrupted restore recovers under existing rules.
- H06: Screen reader and large-text users can select, pin, merge, reorder and schedule without time pressure; keyboard and reduced-motion paths remain usable.
- H07: On real devices, verify changed native alert scheduling, pause/resume/deep links and restart recovery using an isolated QA package. Measure Home/list rendering against the existing build with large real-shaped datasets.

Relevant existing regression suites include `reflections_feedback_test.dart`, `thought_editing_test.dart`, `thought_wall_chat_style_test.dart`, `thought_wall_archiving_and_done_test.dart`, `home_modular_architecture_test.dart`, `lecture_activity_lifecycle_test.dart`, `pre_release_rules_and_completion_integrity_test.dart`, `renovation_commands_test.dart`, `workspace_backup_test.dart`, and the reminder/learning integration tests. Update superseded completion expectations intentionally; do not weaken other lifecycle tests merely to make the suite pass.

## 7. How to judge whether the update helped

Use a small beta task set: capture an idea from Home, find a long pinned note, turn two notes into Both, merge without losing reminders, add a lecture from Today, ask Riya for tomorrow's reminders, log an expense and hide a Home card.

Measure completion difficulty, time/taps to capture, cancelled/failed conversions, mistaken completion, duplicate records and whether users understand the response scope. Set quantitative targets after measuring the current build. Collect only necessary aggregate diagnostics with appropriate opt-in; do not log private note text or financial details for product analytics.

First concrete implementation task: prepare card/capture/conversion mockups and the lecture completion contract, then implement the shared eligibility gate and quick-capture/pin/read-more improvements. This makes the most visible feedback useful while establishing the rules that broader Riya control will depend on.

## Source references

- Current behavior: `lib/features/thought_wall/`, `lib/features/home/widgets/thought_wall_home_preview.dart`, `lib/core/database/daos/thought_dao.dart`, `lib/core/database/daos/task_dao.dart`.
- Learning evidence/completion: `lib/core/learning_hub/learning_hub_provider.dart`, `lib/core/learning_hub/learning_hub_models.dart`, `lib/features/study_plan/lecture_focus_player_sheet.dart`, `lib/features/today/add_activity_sheet.dart`.
- Riya actions/conversation: `lib/core/ai/riya_capabilities.dart`, `lib/core/ai/riya_intents.dart`.
- Existing product plan: [Next update plan](NEXT_UPDATE_PLAN.md).
- Earlier reviews: [Renovation audit](renovation/AUDIT.md), [Quality upgrade](renovation/QUALITY_UPGRADE.md), [Learning and notification results](renovation/LEARNING_ALERTS_RESULTS.md).
