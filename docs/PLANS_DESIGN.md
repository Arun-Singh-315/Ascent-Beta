# Plans: product and system design

**21 November 2026 · Living document.** CLAUDE.md wins on any visual or UX rule. The October proposal ([ROUTINES_AND_PLAN_UX_SPEC.md](ROUTINES_AND_PLAN_UX_SPEC.md)) is kept for history and its delivery/recovery requirements.

## 1. What a Plan is for

A Plan turns "I want to study every morning for a month" into real, dated things the user can tick off, without maintaining a to-do list, a reminder list and a calendar separately.

**Promise:** describe or pick once, adjust in place, then each session simply appears in Things on its day with its reminder. Progress is visible in one place.

Principles (from CLAUDE.md §1):

- **One tap to start.** Every plan has defaults (times, weeks, repeat). Nothing is required except pressing *Start plan*.
- **Plans are not a fourth list.** Sessions live where the user already works: Things (to-dos) and Reminders. The Plans screen is for setup and progress, not for daily ticking.
- **Forgiving.** A missed session is overdue, not failed. Pause, resume and archive never lose history.
- **Many plans at once.** A study routine, a meal routine and a fitness plan can run side by side.

## 2. The model in one picture

```
Plan  (plan_collections)            "Study routine", status active | paused | archived
 └─ Step  (plan_collection_items)    "Study session · 7:00 · every day · 60 min"
     └─ Definition (plan_definitions) schedule rule: dates, time, repeat, timer, reminder policy
         └─ Session (plan_occurrences) one per eligible date: Sat 22 Nov 7:00, Sun 23 Nov 7:00 …
             ├─ To-do   (tasks)        planned on that date; a timer when the step has minutes
             └─ Reminder (reminders)   at the session start, linked via occurrence_alert_links
```

- A **step without a time** becomes one ordinary to-do (no definition, no sessions).
- A **step with a time** becomes a definition with one session per eligible date between its start and end date.
- Repeat rules today: `once`, `daily`, `weekdays`. Repeating steps need an end date within **90 days** (engine limit, see §8).

## 3. Multiple plans

Yes, unlimited. Each plan is its own `plan_collections` row with its own steps, so:

- Two plans can both have a 7:00 step; they produce two separate to-dos and reminders.
- Pausing one plan pauses only its sessions; the others carry on.
- The Plans screen lists them under **Active · Paused · Archived**, each card showing progress (`3 of 20 done`), anything overdue, and the next session (`next tomorrow 7:00`).

## 4. Where everything goes

| What | Where the user sees it | Notes |
|---|---|---|
| Today's sessions | **Things → Today**, as normal rows | Timed steps show the play control and start a focus session. Ticking the row completes the session. |
| Overdue sessions | **Things → Today → Overdue** group | "Move all to today" works on them like any to-do. |
| Future sessions | **Things → Upcoming** | One line per plan per day, not one per repeated copy, so the list stays readable. |
| The routine itself | **Things → Routines** and the **Plans** screen | Setup, pause/resume, progress. |
| Reminders | **Things → Reminders** button, and a phone notification at the session start | Removed automatically when the session is completed, skipped or the plan is deleted. |
| What to do right now | **Home → Now card** | A due session is the "Start" or "Done" action. |
| Today at a glance | **Home → Today timeline** | Up to 4 rows, sessions included. |
| Progress | **Plans** card and plan page | Done, overdue, next session. |

Nothing from a plan lives *only* on the Plans screen: daily use happens in Things and Home.

## 5. Creating a plan

| Path | Status | What happens |
|---|---|---|
| **Template** (Study, Meals, Fitness, Morning) | **Shipped (#57)** | Opens ready: name, 2/4/8 weeks, steps on/off, time per step, Daily/Weekdays, live preview "12 sessions a week · first one tomorrow 7:00 · shows up in Things". *Start plan* saves it. |
| **Blank plan** | Existing | The plan creator: add steps one by one or paste a list. |
| **From a sentence** | Next | "Study DSA 1 hour daily till 15 Jan" → the same template sheet, pre-filled by the quick-add parser. |
| **From Riya** | Partly existing | Riya proposes a study or meal plan card; *Save* should open the same sheet so there is one review screen. |
| **From a thought** | Existing (conversion sheet) | A checklist thought can become plan steps. |

Rules for the sheet: a time already passed today starts tomorrow; weekday steps skip Saturday and Sunday; turning every step off disables *Start plan* with "Turn on at least one step".

## 6. Living with a plan

- **Do it:** tick the to-do (or finish its timer) in Things. The session is done; the plan's progress moves.
- **Not today:** swipe left → *Move to tomorrow* or *Delete* (Undo-first), like any to-do.
- **Pause** a plan (holiday, exams): its future sessions stop appearing and their reminders are cancelled. **Resume** brings them back from today.
- **Archive** when finished: history is kept; nothing new is scheduled.
- **Delete** a plan: its to-dos, reminders and scheduled notifications are removed in one transaction (CLAUDE.md §2.10), with confirmation because it cannot be undone in one step.

## 7. Progress and adapting (next slices)

1. **Plan page:** a 7-day strip (done / missed / upcoming dots), streak with a grace day, "on track" or "2 behind".
2. **Adapt in one tap:** *Catch up* (move missed sessions into free slots this week), *Make it lighter* (switch a daily step to weekdays or shorten its minutes), *Extend* (add weeks, within the 90-day limit).
3. **Riya rebalance:** "I missed two days of DSA" → proposes the catch-up as a reviewable card.

## 8. Reliability notes

- **Notifications are bounded.** Phones limit pending notifications (iOS keeps 64 per app). Reminders are stored for every session, but the device queue must be filled nearest-first and topped up on launch, resume and after edits. This is why repeating steps are limited to 90 days today. Open-ended routines wait until background top-up is proven on a device.
- **Device local time.** Sessions are generated from calendar dates and a local time, not by adding 24 hours, so daylight saving and time-zone changes keep 7:00 at 7:00.
- **Idempotent saves.** Every create carries a request id; a double tap or retry never creates a second plan.
- **Offline first.** Everything above works without network. Online only adds Riya's richer plan suggestions.

## 9. Acceptance checklist

- [x] Each template saves a valid plan with one repeating item per step (test: `plan_templates_test.dart`).
- [x] Two taps from Plans to a running plan.
- [x] Plans screen fits 320 px at 2× text in light and dark.
- [ ] On a phone: tomorrow's sessions appear in Things and the 7:00 reminder fires with the app closed.
- [ ] Pausing a plan removes its upcoming reminders; resuming restores them from today.
- [ ] Deleting a plan leaves no orphan to-dos, reminders or notifications.
- [ ] Plan page progress strip and adapt actions (§7).

## 10. Code map

| Piece | File |
|---|---|
| Templates and drafts | `lib/features/plans/plan_templates.dart` |
| Template sheet | `lib/features/plans/widgets/plan_template_sheet.dart` |
| Plans screen | `lib/features/plans/plans_screen.dart` |
| Plan page | `lib/features/plans/widgets/plan_collection_detail.dart` |
| Collections service | `lib/core/services/plan_collection_service.dart` |
| Definitions and sessions | `lib/core/services/plan_service.dart`, `plan_recurrence_engine.dart` |
| Tables | `lib/core/database/tables/plan_tables.dart` |
| Things upcoming grouping | `lib/features/today/things_providers.dart` |
