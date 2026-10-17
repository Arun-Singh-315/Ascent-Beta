# Audit queue implementation status

Checked 17 October 2026 against the current working tree and the 27 rows in `AUDIT_MODEL_WORK_PLAN.md`. Includes existing uncommitted work. This is a source inspection, not new execution of the acceptance tests or device verification. No app implementation or build was performed for this check.

Count: **3 implemented in code, 2 partial, 22 pending/not demonstrated**. H6 counts as one plan row but contains five separate screen changes. “Implemented” does not mean fully verified or released. Performance items remain pending until the requested measurements exist.

| Row | Status | Current evidence / remaining work |
| --- | --- | --- |
| Q1 first-activity contrast | Implemented; device check pending | `day_one_tutorial_card.dart` uses `textOnPrimary` in dark mode, retains white in light mode, and defines disabled colors. `day_one_tutorial_card_contrast_test.dart` covers the pairings. Not rerun in this check. |
| Q2 schema documentation | Pending | `app_database.dart` is schema 17; `APP_ARCHITECTURE.md` still says 15. |
| Q3 destructive labels | Pending | Money transaction/goal and Walk history delete buttons lack specific tooltips. |
| Q4 redundant selection controls | Pending | Share/Exit controls remain; do after M1. |
| H1 Thought delete/Undo | Implemented; device check pending | Both paths use the same handler and single-use deletion token. Relationship restoration preserves newer task/merge edits; stale tokens are rejected. Failures are visible and Undo offers Retry. Twenty focused regression tests pass. See `qa/thought-delete-undo.md`. |
| M1 selection reconciliation | Partial | Edit/Copy and bulk actions exist, but select-all compares counts rather than ID membership. Stale selected IDs can survive list changes. |
| H4 Money deletion | Pending | Transaction and savings-goal delete handlers delete immediately. |
| H4 Walk deletion | Pending | History delete handler calls `deleteWalk` immediately. |
| H2 calendar refresh | Pending | Money month providers capture `DateTime.now()` when created; requested shared midnight/resume refresh and controlled acceptance coverage not demonstrated. |
| H5 startup recovery | Pending | Splash catches profile-read errors as no valid profile, resets onboarding completion, and navigates to onboarding. No retry recovery. |
| H6 screen data errors | Pending | Pipeline, DSA, Resume Vault, Consistency and Analytics still lack the complete requested loading/empty/error/retry contract. Implement one screen at a time. |
| H3 full Money history | Pending | Money watches `recentTransactionsStreamProvider`, capped at 25. DAO all-history query exists, but the requested history UI does not. |
| H3 transaction editing | Pending | No transaction-edit flow in Money. Existing assistant commands do not meet the requested form/restart/receipt acceptance. |
| M2 linked Todo navigation | Pending | Thought menu `open_todo` pushes generic `/today`, without task identity. |
| M3 savings validation/layout | Pending | Invalid target fails silently; saved amount falls back to zero and negative values are not rejected; no repeated-save guard. |
| M3 arbitrary savings correction | Pending | Existing goal action adds a fixed 500; no validated arbitrary correction UI. |
| M4 session boundaries | Pending | Session report queries filter by start time; analytics buckets an entire session into its start day rather than splitting overlap and pauses across days. |
| M4 streak labels | Pending | Consistency substitutes legacy streak when study streak is zero, under the same CURRENT STREAK label. |
| M5 PDF errors | Pending | PDFView has render/page callbacks but no `onError`/`onPageError` recovery contract. |
| M5 reader persistence | Pending | Theme is persisted; selected document reference/page remain transient widget state. |
| M6 semantics/hit targets | Partial | Shared buttons include 48px targets and many actions have tooltips; compact controls can be 36px and thought selected styling does not establish the required announced selected state. Shared-caller and TalkBack verification remain. |
| M7 narrow-screen fix, one screen | Implemented for a bounded screen; device check pending | Medicine schedules/edit sheet have a 320px, 200% text regression test; Mind Space also has narrow-screen tests. This is not an app-wide overflow certification. |
| M8 Analytics subscriptions | Pending/not demonstrated | Streams are constructed in nested build-time StreamBuilders. Requested measurement and stabilization evidence absent. |
| M8 Learning subscriptions/serialization | Pending/not demonstrated | Broad learning state consumption and periodic course persistence remain. Requested measurement-backed optimization and lifecycle acceptance not demonstrated. |
| Later: safe route parsing | Pending | Router still uses unchecked `int.parse` for application/series IDs. Some other routes already use `tryParse`. |
| Later: naming consistency | Pending/not demonstrated | No agreed naming mapping or verified completed flow tied to this queue. |
| Later: guide hierarchy/status labels | Pending/not demonstrated | Guide remains a multi-row card; no completed queue-specific hierarchy/tiny-label acceptance check established. |

## Next sequence

1. **H1:** implemented and focused regressions pass; retain the device check before calling it fully verified.
2. **M1 only:** reconcile surviving IDs and membership-based select-all, then verify bulk/single-note actions and Back/cancel.
3. **H4 Money**, then **H4 Walk**, as separate changes.
4. Continue the main queue in the original plan order. Q2 is a tiny optional documentation task, not a prerequisite for H1. Q4 waits for M1.

H1 implementation and the latest build were subsequently authorized by the user. Next incomplete main-queue task: M1 selection reconciliation. Do not start it until requested.
