# Home: capture, schedule, remind, check in

Plan based on source inspected 16 October 2026. Implemented on 16 October; see [implementation results](HOME_CAPTURE_RESULTS.md). Scope: Home and the minimum shared Riya, Thought, Task and Reminder behavior needed to support Home. Preserve other screens and both daylight presets/night theme.

## Intended experience

Home should let me type first and organize with minimal effort. Example:

> Tomorrow at 7 pm practise interview questions for 30 minutes. Remind me and ask afterwards if I did it.

After Send, show the original message and a compact reply:

> Practise interview questions · Tomorrow, 17 Oct · 7:00–7:30 pm
> Reminder: 7:00 pm · Check-in: 7:40 pm
> [Schedule] [Change]

One Schedule tap creates ONE linked Todo and its reminder/check-in configuration. It does not ask the user to separately add each record. Confirm the full date and local timezone where relevant. The 10-minute post-end check-in is a proposed default, not existing behavior; let Change adjust it. Without duration/end time, ask for a check-in time or offer an editable “20 minutes after reminder” default. Do not invent an end time.

At the scheduled time, notify. At check-in, ask “Did you practise interview questions?” with Done / Later / Skip. Done completes the linked Todo through established completion rules and cancels pending checks. Later offers a short reschedule choice. Skip dismisses this occurrence without reporting it completed. No response leaves it unresolved and visible on Home; no escalating series of notifications by default.

## What exists today

- `features/home/widgets/thought_wall_home_preview.dart`: multiline field, send, saving guard, note insertion, retained input on save failure, recent-thought preview. Send inserts a thought; it does not interpret schedules.
- `features/thought_wall/thought_quick_actions.dart`: Todo / Reminder / Both after capture, normally disappearing after eight seconds. These should not be the only discoverable planning route.
- `features/thought_wall/thought_action_ui.dart`: existing conversion entry point to reuse rather than creating parallel conversion logic.
- `core/database/tables/reminder_table.dart`: reminders already link to Tasks via `linkedTaskId`; separate active/alarm/sync-pending state exists. No persisted configurable check-in state is declared here.
- `core/notifications/notification_service.dart`: optional 20-minute follow-up supported. `core/notifications/reminder_alert_sync.dart` currently sends `scheduleFollowUp: false`. Simply flipping this flag does not provide the proposed completion-aware lifecycle or persistence.
- Riya has an intent resolver and command/execution machinery. Inspect and reuse its command receipts and validation where applicable; do not duplicate the full assistant screen inside Home or assume its parser understands every natural-language expression.

## Home structure and visual direction

1. Compact greeting/date; keep the Riya gateway.
2. Primary composer near the top: “A thought, a task, or something to remember…” with a clear send arrow, multiline input and keyboard-safe layout. Keep it available in the first viewport; do not permanently cover content with a large chat panel.
3. Immediately below: latest capture and its compact interpretation/clarification/result. Show one relevant interaction, not a long chat history.
4. “Up next” combines upcoming linked activity/reminder into one row, plus unresolved check-ins when present. Avoid showing the same task twice just because it has a reminder.
5. Existing Activity/Learning cards remain available below; preserve customization. Keep other Home modules secondary and use conditional sections instead of empty gaps. Do not remove functioning cards indiscriminately.

For thoughts, use a subtle leading thought/speech mark or small arrow, breathing room, and a quiet left edge. The actionable trailing arrow means “open this thought”; label it accessibly. Plain notes can have gentle bubble styling; scheduled captures have clock/date metadata and linked-state chips. Do not insert decorative arrows into stored text, apply arrows to every sentence, or use a schedule icon for an ordinary thought. Preserve multiline text, emoji and full content. Contrast and text size take precedence over ornament.

## Capture behavior

| Input | Home response | Stored result |
|---|---|---|
| Ordinary reflection | Save quietly; persistent Plan / Ask Riya action | Thought only |
| Clear actionable request without schedule | Offer Add to Today / Pick date; ordinary thought remains an option | One Todo after approval |
| Explicit reminder with time | Show interpreted schedule and linked Todo toggle; default linked for actionable work | Linked Todo + reminder after approval; reminder-only available |
| Explicit schedule + follow-up | Preview schedule, primary reminder and check-in | One Todo, reminder and persisted check-in policy |
| Missing date/time or ambiguous intent | Ask one narrow question, with chips/date picker and text reply | Draft remains recoverable; no guessed scheduled write |
| “Ask Riya…” / selected Ask Riya | Route through shared supported Riya flow, keeping context | Only reviewed supported actions; conversational content is not automatically a Todo |

Classification offers a proposal; it must not silently turn every thought into a task. Clear date/time requests should not require a full form. Keep preview fields directly editable. For unsupported language, offer a compact date/time picker instead of pretending interpretation succeeded. “Tomorrow” resolves in the user's local calendar; dates in the past require clarification. Clarification replies apply to the pending draft, not a new unrelated capture.

## Integration and reliability contract

- Original text and reviewed structured intent remain associated. Decide before implementation whether scheduled messages are always retained as Thoughts or only retained on request; recommended: retain one source capture, with a clear linked status and no duplicate note per clarification.
- Use a shared capture coordinator/service consumed by Home and relevant Riya entry points. UI presents drafts and results; existing DAOs/services own writes, completion and alerts.
- Approve once for the reviewed linked operation. Save linked records transactionally where possible; use a durable request identity/receipt for retries and process restart. Verify existing receipts can represent this operation before adding another ledger.
- Database save and device notification delivery are separate. Report Saved / Alert ready / Alerts need permission or retry accurately. Notification success is not guaranteed merely because records saved.
- Follow-up configuration and outcome must survive restart, restore and reschedule. Audit backup coverage and migration needs before adding columns/tables; a process-local timer cannot be the source of truth.
- Completing from Home, Todo, Riya or notification must use the same completion rules and stop stale primary/check-in alerts. Editing time, deletion/Undo and linked-record cleanup must update schedules consistently.
- Preserve special timed/learning-task completion rules; a generic Done button must not bypass them. For such tasks, route to the established finish flow or clearly explain what remains.
- Notification actions need record/occurrence identity. Repeated taps are harmless; old notifications cannot complete a newly rescheduled occurrence. Check current completion before showing an overdue check-in in-app.
- Keep reminder alarm consent explicit. User scheduling request provides context to offer notifications, but do not silently enable alarm mode or global permissions. Ordinary gentle notifications and audible alarms need clear distinction.
- Do not treat Home reminder dismissal as task completion. Do not infer that ignored alerts mean skipped or failed work.
- Scheduled OS notifications may already be queued while the app is closed; cancellation/completion handling and tap-time validation must be tested on a physical device. Do not promise callback execution at an exact instant on every OS.

## Implementation sequence and model budget

| Step | Scope | Model / effort | Acceptance |
|---|---|---|---|
| 1 | Home composer and thought presentation; persistent Plan / Ask Riya entry, no automatic scheduling | Luna / medium; small | Fast multiline capture, recoverable errors, clear arrows, no saved-content edits; both day presets/night, keyboard, 360px and enlarged text |
| 2 | Shared draft resolution and compact schedule review | Sol / medium; medium | Example request parsed or clarified, editable absolute date/time, durable draft, ordinary thought remains ordinary; unsupported expressions fall back honestly |
| 3 | One approved linked Todo + reminder operation, exposed from Home | Sol / high; large | One task/reminder on double tap/retry/restart, existing links reused where appropriate, saved-versus-alert status, recovery from partial scheduling failure |
| 4 | Persisted check-in lifecycle and Done / Later / Skip through Home and notification entry | Sol / high; large | Restart/complete/reschedule/delete suppress stale check-ins, no false completion, occurrence-safe actions, permission failure handled; backup/migration tests if necessary |
| 5 | Compact Up next and Home hierarchy integration | Sol / medium; medium | No duplicate rows for linked records; unresolved check-ins visible; customization preserved; empty/loading/error states clear |
| 6 | Focused end-to-end/device verification | Sol / medium | Type → review → schedule → restart → reminder → completion/check-in; both themes, denied permissions, date rollover, past time, long text |

Use Astra only if a specific unresolved persistence/occurrence/completion contract needs deeper review. Finish one stage before expanding scope. This plan supersedes the general audit order only for the user's requested Home work; it does not authorize changes to unrelated feature screens.

## Test cases that matter

Clear request; ordinary reflection with words like “tomorrow”; missing time; ambiguous date; edit/cancel preview; repeated send/approval; failed DB save; DB saved but scheduling failed; restart during operation; complete before reminder; complete between reminder and check-in; reschedule; delete/Undo; stale notification tap; ignored check-in; task with timed completion rules; midnight/timezone change; notification permissions denied; backup/restore of pending checks. Native notification action/background/reboot behavior requires device verification.

## First implementation request

Implement Step 1 only. Preserve existing Home layout customization and both daylight presets/night theme. Keep the top composer simple and keyboard-safe; improve recent thought presentation with subtle leading marks and an accessible open arrow. Replace the disappearing-only planning invitation with a persistent, compact Plan action using existing conversion UI and an Ask Riya entry using existing supported navigation. Do not add schedule parsing, automatic task creation, a check-in migration, or redesign other screens in this step. Verify capture success/failure and 360px enlarged-text layouts, and report checks actually run.
