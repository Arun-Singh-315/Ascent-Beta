# Audit implementation and model budget plan

Prepared 16 October 2026 from the latest chat **Audit Flutter app UX and flows** (chat ID `01a142c8-6f77-7dc1-8b6b-6d3b702b1125`). The older `renovation/AUDIT.md` is not the current implementation queue. No app implementation is authorized by this planning document.

## Budget and model choice

Account snapshot at preparation: five-hour window 93% used, weekly window 15% used, purchased credits 0; ordinary usage allowed. Five-hour reset: 16 October 2026, 2:01 PM IST. These values change with use; a reset is not a promise of unlimited work. Switching models does not create more allowance. Exact per-task credits and model-specific plan consumption are unknown.

Use GPT-6 Luna for small, clearly specified edits; GPT-6.1 Sol for connected Flutter behavior and persistence work; reserve GPT-6 Astra for genuinely unresolved architecture or difficult failures. Choose models actually available in your picker. Reasoning settings below are recommendations, not guarantees. Effort is relative work, not a credit quote.

Official model guidance: https://developers.openai.com/api/docs/guides/model-selection

## Small work while allowance is low

Do ONE row at a time. Pick a quick win if you want to progress now; this does not make it higher priority than H1. No need to repeat the whole audit.

| Task | Model / reasoning | Effort | Scope and acceptance |
|---|---|---|---|
| Q1: dark-mode first-activity button contrast | GPT-6 Luna / low | Small | `lib/features/home/widgets/day_one_tutorial_card.dart`: correct white-on-peach foreground pairing; preserve light-mode design. Verify both themes and disabled state if present. |
| Q2: architecture doc schema number | GPT-6 Luna / low | Tiny | Verify current schema in `lib/core/database/app_database.dart`, then correct stale schema reference in `docs/APP_ARCHITECTURE.md`. No code changes. |
| Q3: destructive icon labels, one screen | GPT-6 Luna / low | Small | Add specific tooltips/semantic labels to existing Money or Walk delete controls. Preserve current behavior; deletion protection remains H4. Check screen-reader names and avoid duplicate announcements. |
| Q4: one screen's redundant selection controls | GPT-6 Luna / medium | Small | Only after M1 is settled: remove redundant Share/Exit controls while preserving one discoverable route for each. Verify Back and cancel. |

First recommended low-budget task: **Q1**. Use Q2 if you want the smallest possible task.

## Main queue after allowance resets

Default sequence follows the latest audit. Split combined rows into the indicated independent changes. These findings still need verification against current code before editing.

| Order / audit ID | Work | Model / reasoning | Effort | Acceptance / device check |
|---|---|---|---|---|
| 1 / H1 | Thought Wall delete/Undo consistency: screen handlers + `ThoughtDao` | GPT-6.1 Sol / medium | Medium | Menu and swipe Undo restore note, task/reminder/merge relationships; failure visible; do not overwrite newer changes. Convert a note to Todo + Reminder, delete/Undo by both paths, verify connections. Add meaningful relationship regression coverage. |
| 2 / M1 | Thought selection reconciliation and actions | GPT-6.1 Sol / medium | Medium | Surviving selected IDs match count; select-all checks membership; one-note Edit/Copy remain discoverable. Select two, delete/archive one, select all, cancel, Back. Preserve bulk actions. |
| 3a / H4 | Money deletion protection | GPT-6.1 Sol / medium | Medium | Transactions and goals recoverable or confirmed; cancellation/Undo preserves totals and identity. Use existing recovery patterns. |
| 3b / H4 | Walk history deletion protection | GPT-6.1 Sol / medium | Medium | Cancel retains history; choose confirmation if complete restoration is unsafe. Labels describe the action. |
| 4 / H2 | Shared calendar refresh and date-bound providers | GPT-6.1 Sol / high | Large | Hydration/Medicine daily views and Money monthly totals refresh at midnight/resume; active sessions and alerts unaffected. Controlled date tests plus device rollover/resume. |
| 5a / H5 | Startup storage error recovery | GPT-6.1 Sol / medium | Medium | Failed profile read retains onboarding state and offers retry; absent profile still follows valid onboarding. Test both independently. |
| 5b / H6 | Screen data errors: Pipeline, DSA, Resume Vault, Consistency, Analytics | GPT-6.1 Sol / medium | Medium per screen | One screen per change. Distinguish loading, empty and error; no false zero statistics; retry recovers. Inject read failure for verification. |
| 6a / H3 | Money full transaction history | GPT-6.1 Sol / medium | Medium–large | Entries beyond latest 25 accessible with stable ordering and sensible loading. Create 26, locate oldest; handle empty/error states. |
| 6b / H3 | Money transaction editing | GPT-6.1 Sol / high | Large | Reuse form, preserve ID/relationships/receipts, refresh totals. Edit oldest entry and restart. Verify assistant receipt compatibility. |
| 7 / M2 | Navigate to linked Todo | GPT-6.1 Sol / medium | Medium | Pass identity and locate/highlight older/completed tasks; missing task produces explanation. Do not just open generic Today. |
| 8a / M3 | Savings form validation and keyboard layout | GPT-6 Luna / medium | Small–medium | Explicit invalid/negative feedback, scrollable form, repeated-save guard. Keyboard + enlarged text + double tap. Escalate to Sol if persistence is unclear. |
| 8b / M3 | Arbitrary saved-amount correction | GPT-6.1 Sol / medium | Medium | Replace fixed ₹500-only adjustment with validated correction using existing data semantics; retain goal identity. |
| 9a / M4 | Analytics sessions across day/report boundaries | GPT-6.1 Sol / high | Large | Split active duration at midnight, account for pauses, include sessions overlapping reporting window. Use deterministic boundary tests; preserve underlying records. |
| 9b / M4 | Consistency versus study streak labels | GPT-6.1 Sol / medium | Medium | No silent substitution of legacy streak for zero study streak; accurate distinct labels. Do not rewrite stored history. |
| 10a / M5 | PDF render failure recovery | GPT-6.1 Sol / medium | Medium | Error/page-error handling with readable recovery and Choose another file. Corrupt PDF then valid PDF on device. |
| 10b / M5 | Reader position persistence | GPT-6.1 Sol / high | Large | Stable document reference/page restored; missing/revoked files recoverable. Define file lifetime/backup handling before storage changes. |
| 11a / M6 | Selected-state semantics and shared hit targets | GPT-6.1 Sol / medium | Medium–large | Navigation/thought selection announced, targets usable without unintended geometry changes. TalkBack and both themes; check shared-control callers. |
| 11b / M7 | Reproduced narrow-screen overflow, one screen | GPT-6.1 Sol / medium | Medium | Reproduce at 320–390 logical pixels and 200% text; fix only failing layouts. Long content and keyboard checks. |
| 12a / M8 | Analytics subscriptions | GPT-6.1 Sol / high | Large | Measure rebuild/subscription behavior first; stabilize subscriptions without changing results/error states. No rewrite justified by file size alone. |
| 12b / M8 | Learning subscriptions/serialization | GPT-6.1 Sol / high | Large | Measure first; narrow consumers without changing timer/persistence/completion behavior. Lecture runs while navigating Home/catalog, then restart. |
| Later / low | Safe route ID parsing | GPT-6.1 Sol / medium | Medium | Replace unchecked parsing where present; malformed and absent records show recoverable navigation. Verify valid links too. |
| Later / low | Destination naming consistency | GPT-6 Luna / low | Small | Agree on labels, adjust one user-visible flow; preserve route names/storage keys unless explicitly needed. |
| Later / UX | First-use guide hierarchy / tiny status labels | GPT-6 Luna / medium | Small–medium | Preserve dismissal, emphasize primary action, expand secondary explanation; improve important tiny labels only. Both themes and large text. |

## Astra reservation

No current audit task automatically requires Astra. Start the larger tasks with Sol. Use Astra / medium or high only for a concrete unresolved question: unsafe relationship restoration under newer edits, conflicting session/pause history semantics, file ownership/backup design, or a measured performance problem Sol cannot resolve. Give Astra the failing case and focused evidence; request a decision or targeted patch, not another full audit. Defer optional architecture/storage rewrites. Credit reset alone is not a reason to use the strongest model.

## Rules to conserve allowance

1. Select the recommended model before sending an implementation request. The available tools here cannot change this chat's own model.
2. Specify one row, acceptance criteria, and relevant files. Verify that finding locally; do not rediscover the entire app.
3. Preserve uncommitted work and existing contracts. Avoid unrelated refactoring, dependencies, schema changes, or redesign.
4. Use focused analysis and relevant existing tests. Add tests for real recovery/persistence/boundary bugs; do not build ceremonial tests for copy or colors.
5. If scope grows materially, write a handoff explaining evidence, attempted fix, failure, and next step before escalating. Do not let a small task silently become a rewrite.
6. Record files changed, checks actually run, unresolved device checks, and next task. Carry this compact handoff forward instead of asking for another audit.
7. Before a large task, check current allowance; near exhaustion, complete a bounded checkpoint and defer optional work. These tasks have no known exact credit price.

## Ready-to-paste first task

```text
Implement only Q1 from docs/AUDIT_MODEL_WORK_PLAN.md.
Verify the current dark-mode Add First Activity button in
lib/features/home/widgets/day_one_tutorial_card.dart and correct its
foreground/background contrast. Preserve the existing light-mode design,
wording, and functionality. Read applicable repository instructions and
preserve uncommitted work. Inspect only relevant theme values and callers.
Verify both theme pairings and run appropriate focused checks.
Report actual results and a brief device check. Do not implement other
audit findings or repeat the full audit.
```

After reset, select GPT-6.1 Sol / medium and request **H1 only**, including its row's acceptance criteria. Track status as pending / in progress / verified / device check pending; do not mark completion solely because a build succeeds.
