# Learning and notification flow · 1.0.8 (9)

12 October 2026. Follow-up to the user's usability, Learning redesign and notification request. Quiet notifications remain the default; ringing Alarm mode is an explicit choice.

## What changed

Learning now leads with a Start/Resume/Return-to-player card, next unfinished lecture, honest completion state and remaining workload. A daily-pace estimate explains the plan without claiming a guaranteed completion date. Course search and All/In progress/Completed filters have a clear empty state. Syllabus, course switching, module/lecture editing, notes and the book reader remain accessible. The syllabus header is compact; lecture filters and cards scroll without overflowing the remaining viewport. The Notes action opens Mind Space instead of a missing route. The player's course switcher starts collapsed to keep its main controls visible.

Study streaks explain the 120-minute target, qualifying Study Focus/Learning time, local-midnight deadline, paused/manual-checkbox exclusions and the exact one-day recovery requirement. Course pace is explicitly a separate goal. Concurrent Study Focus and Learning credit each real second once. The unexplained “Base” statistic was removed from the card; underlying history remains.

Ordinary reminder notifications show the actual content in the title, with a short body and full expandable text. Automatic motivational follow-ups are disabled for ordinary reminders. Rescheduling clears legacy follow-ups, and switching to Alarm mode cancels the prior ordinary notification before scheduling its native alarm, preventing duplicate alerts. Cold-start destinations survive splash/onboarding rather than being overwritten by Home. Live Learning and Focus notifications use Android media sessions, dedicated IDs, direct player routes and functioning pause/resume controls. Learning seeking refreshes its notification and media position. Focus exposes elapsed time; the heartbeat duration is not treated as a countdown target. A foreground service and a single retained Flutter engine keep the timer authority alive while the Activity is backgrounded or closed. Paused sessions retain a resume entry without continuously running a service.

Alarm mode persists per reminder. Android AlarmManager and a ringing foreground service work independently of Flutter, using the phone's alarm tone and vibration. Snooze 10 min and Done stop ringing and queue durable absolute state updates, reconciled transactionally when the app resumes or reopens. Multiple alarms queue independently. Native alarms are canceled when records are edited/deleted, and rebuilt on restore/boot where access permits. A stopped process does not show a phantom ringing dialog. Full-screen popup access is requested contextually; Android may show heads-up controls instead while the phone is in use.

Missed active reminders stay in an Overdue section instead of appearing completed. Direct list actions provide Snooze and Done. Completing a reminder does not falsely complete a linked timed task.

## Data compatibility

Schema 14 → 15 adds `reminders.alarm_enabled` with false as its default. Existing reminders remain ordinary notifications. Whole-workspace backups from schema 14 import with the same quiet behavior; schema 15 backups preserve the optional alarm mode. Old profile-only exports remain unsupported. Native pending alarms/action receipts are reconstructed or reconciled rather than imported as foreign device state. Android notification/exact-alarm/popup permissions are device settings and are not part of a backup.

## Validation

- Full Flutter suite: **293 passed**. [Log](qa/learning-alerts-flutter-test.txt).
- Static analysis: **no issues**. [Log](qa/learning-alerts-flutter-analyze.txt).
- Tests include completed/empty course behavior, pace math, searchable course empty-state recovery, 2× text in both themes, explicit streak rules, overlapping-second credit, overdue completion, quiet defaults, cancellation when switching alert modes, idempotent alarm actions, cold reminder routing and schema-14 backup compatibility.
- Physical Android checks use only `com.arun.ascent.debug` plus a temporary QA inspector. Instrumentation refuses production and never writes a fake profile. Test permissions are changed only for the debug package. Native cold-process checks validate ringing, Snooze and Done receipts and actual database recovery.

- Latest native Learning/Focus integration: **passed**. Real Android media controls paused/resumed both providers; tapping each card opened its actual player route. [Integration](qa/learning-focus-native-device.txt), [controls](qa/learning-focus-native-controls.txt).
- With the debug app process closed, AlarmManager started a fresh ringing process and foreground service. The native notification Snooze action stopped its sound and scheduled an absolute ten-minute retry. Reopening the app updated the SQLite reminder time and acknowledged its durable receipt. The popup Done action stopped ringing; reopening marked the reminder inactive. [Foreground service](qa/alarm-native-foreground-service.txt), [Snooze](qa/alarm-cold-notification-snooze.txt), [saved native state](qa/alarm-cold-snooze-native-state.txt), [Snooze recovery](qa/alarm-cold-snooze-recovery.txt), [popup Done](qa/alarm-cold-popup-done.txt), [Done recovery](qa/alarm-cold-popup-done-recovery.txt).
- The in-app ringing dialog appeared over the Reminders screen during a foreground check. Three widget tests verify its Done/Snooze dismissal and retry behavior after a native failure. The corresponding native actions were verified physically in cold-process checks. Lock-screen presentation has not been physically certified. Device evidence applies to the Nothing A142; broader OEM, battery-restricted overnight and accessibility coverage remains a further test matrix. Android force-stop, denied permissions, muted alarm volume or device power-off cannot be bypassed by an app.

## Further product suggestions

1. A short daily plan that chooses the next lesson and a realistic time block, with one-tap start and a clear “what happens next”.
2. A configurable study-streak goal with goals frozen per calendar day, so changing a target never rewrites earned history or recovery requirements.
3. Named reminder presets, selectable alarm sound and an optional read-aloud title with a clear privacy choice.

## Final delivery

Final release APK: `releases/Ascent-1.0.8-9.apk`, **100,429,602 bytes**, version 1.0.8 (9), schema 15. SHA-256: `8e0e19f63a545e90fd5e9ac936644a86ef946eba18f3ca7c42e44cddac910e2f`. APK signature and package metadata verified. Installed over the existing production app on the Nothing A142; cold launch and the Reminders route verified. Its current list contained zero active reminders, so no future user alerts required rescheduling. Temporary QA packages have been removed. [Build](qa/learning-alerts-release-build.txt), [signature](qa/learning-alerts-apk-signature.txt), [installation](qa/learning-alerts-device-installation.txt).
