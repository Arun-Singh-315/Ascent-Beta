# Home activity quick entry and conversion

17 October 2026.

Home’s Today card has an inline composer in place of the Add activity sheet entry. Typing and sending defaults to **To-do · Today · Reminder off · Medium priority**. The text is kept as the activity title; dates and types are set by the visible controls rather than guessed from prose. Optional controls choose To-do, Timer or Flexible, Today/Tomorrow/a calendar date, and reminder time. Timer duration appears only for Timer and starts at 30 minutes. Creating a timer does not start it.

The existing pencil/edit action changes an activity’s type later. The detailed editor and inline composer share atomic persistence. Type/target checks also run inside TaskDao updates, so bypassing the form does not bypass those checks.

| Scenario | Handled behavior | Verification |
|---|---|---|
| Type and send without opening options | One medium-priority To-do for today; no reminder or timer session | Widget + database tests |
| Empty/whitespace title | No save; empty send disabled | Widget + database tests |
| Title longer than 300 characters | Field limits input; persistence rejects oversized titles | Database boundary test |
| Rapid double send | One task; send is locked while saving | Widget test |
| Database save failure and retry | Draft stays visible; retry creates one task | Widget failure injection |
| To-do, Timer, Flexible creation | Null, positive minutes, or -1 stored respectively | Database tests |
| Choose Tomorrow/future date | Explicit calendar choice is preserved | Widget + database tests |
| Stale date in the past for a new task | Rejected; no silent date change | Database test |
| Invalid timer duration | Reject zero, invalid input, unsupported negative values and >1440 minutes | Widget + database tests |
| Duration boundaries | 1 and 1440 minutes accepted; Flexible uses -1 | Database tests |
| Cancel duration dialog | Existing duration remains | Widget test |
| Reminder off | No reminder created or permission request needed | Widget + database tests |
| Cancel reminder time picker | Reminder remains off | Widget test |
| Explicit future reminder | Linked reminder saved with pending notification sync; loud alarm stays off | Database test |
| Reminder now or in the past | Reject before writing; never silently move it to tomorrow | Database tests |
| Notification permission denied / alert scheduling unavailable | Task remains saved; durable reminder stays pending; retry sync acknowledges same reminder | Sync test |
| Reminder insertion fails | Whole task/reminder transaction rolls back | Database failure injection |
| Send succeeds | Text clears and options return to To-do/Today/Reminder off/30 min | Widget test |
| All idle type conversions | To-do ↔ Timer, To-do ↔ Flexible, Timer ↔ Flexible keep task identity | Six database conversion tests |
| Editor To-do → Timer → To-do | Type persists and task count stays one | Editor interaction test |
| Running or paused timer | Type and target changes rejected; existing session retained | Service + direct DAO tests |
| Other task has a running timer | Idle task can still change type | Database test |
| Same type/target, title edited while timer active | Allowed without changing the session | Database tests |
| Completed task | Type/target stays sealed; conversion rejected | Database test |
| Course lecture linked task | Generic conversion rejected; use Learning | Database test |
| Ended session history | Sessions and actualMinutes retained across conversion; conversion never marks task complete | Database + Today-provider tests |
| New timer target ≤ time already logged | Reject; new target must exceed logged duration | Database tests |
| Notes, priority and parent linkage | Retained during conversion | Database test |
| Same-title unrelated reminders | Untouched; only explicit task-linked reminder IDs are edited | Database test |
| Reminder time edit | Existing reminder ID reused | Database test |
| Turn reminder off explicitly | Reminder deactivated with durable OS cancellation pending | Database test |
| Home scheduled plan converted | Reminder and check-in IDs preserved; schedule/title changes routed to Home plan controls | Database test |
| Task deleted while editor open | Save rejected; deleted activity not recreated | Database test |
| Narrow screen / large text | Composer and options fit at 320px / 2× text; Home layout checked separately | Widget/layout tests |

Logged history is not reset by conversion. Timer targets describe total required time, rather than extra time added on top of prior sessions. An unfinished timer cannot be changed while it is running or paused; finish or discard the live session first. Conversion does not reopen completed work and does not award completion or streak credit.

## Validation

All **40 new tests** passed across activity_entry_service_test.dart, activity_composer_test.dart and activity_editor_conversion_test.dart. Full app suite: **550 tests passed, no failures**. Static analysis: **no issues found**. The ARM64 release APK built successfully (51.0MB). Installation and native notification delivery still need device review; no phone was connected at build completion. Home preview images were rendered from the actual widgets with sample content, including 320px at 2× text.
