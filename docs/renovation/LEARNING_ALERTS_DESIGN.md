# Learning and alert flow renovation

User direction: quiet reminders by default; explicit Alarm mode. Preserve warm surfaces and all existing course, syllabus and player entry points.

## Product decisions

Learning: one next-step card with course context, Start/Resume/Return to player, honest completion state, remaining workload and a daily-pace estimate. Course switching/catalog, lecture editing, modules and notes stay reachable. Course pace and the 120-minute study streak are distinct goals and are explained explicitly. A completed course must not suggest its first lecture as unfinished work.

Streak: show what counts, what does not, local-midnight deadline and the exact recovery target. Explain the first day and one-day recovery rather than presenting unexplained flame numbers. Keep the existing rules intact.

Quiet reminder: actual reminder title first, short collapsed summary, full expandable content, stable Reminders destination on warm/cold launch. Remove unsolicited motivational copy and automatic follow-up from ordinary reminders.

Live Learning/Focus: elapsed/remaining time, paused state, expansion and one real Play/Pause action. Dedicated IDs and player routes remain separate. An Android foreground service protects live session operation while the app is backgrounded; the existing Dart timer/provider remains the time authority. Seeking, pause/resume and completion all refresh/cancel the notification. Force-stop cannot be bypassed.

Alarm: optional persisted mode. Android AlarmManager + a ringing foreground service operate without a Flutter screen. High-priority expanded notification, lock-screen alarm activity where access allows, Snooze 10 min and Done. Native actions stop sound immediately and queue idempotent absolute database updates; Flutter reconciles them at startup/resume. Snooze immediately schedules its next native alarm. Multiple simultaneous alarms are queued instead of replacing one another. Boot reschedules pending alarms. Deletion/edit/restore cancel native alarms as well as ordinary notifications. Full-screen/exact-alarm/notification access is explained contextually; denied access never claims a guaranteed popup.

## Verification plan

Write specifications before implementation: concise/expanded presentation and payload safety; buffered cold-start routing after splash; completed-course next action and pace math; visible streak rules/recovery arithmetic; alarm defaults/migration/action reconciliation; native scheduling, ringing, Snooze/Done and player control sync. Exercise native operations in the isolated debug package before upgrading production. Test text scaling and both themes. Record actual device evidence and limits.
