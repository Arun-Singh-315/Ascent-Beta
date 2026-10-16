# Send timed Todo to lecture

15 October 2026 · branch `feature/send-todo-to-lecture`

## Behavior

Timed Todo detail cards on Home and the task board now expose **Send to lecture**. The picker starts with the active course and its first module. Users can change the destination, add a course/module, create a lecture or link an existing one. Successful sending opens the selected lecture in the Learning player without auto-starting it.

This uses the existing transactional `saveLectureActivity` conversion, preserving the task ID, notes, planned date, reminders and recorded timer history. A running timer for the source task is paused before saving. Historical generic time remains engagement rather than watched study evidence. Future lecture study uses the established completion gate. Completed tasks and checklist parents are excluded from the board entry point; the conversion service also rejects invalid or conflicting associations.

The regression test exercises the actual task card, cancel without conversion, save to an existing course/module, original task/notes retention, duration and lecture selection, and opening the player. Existing lifecycle tests cover transaction rollback, idempotency, timer history and completion gating.

## Validation / deployment

- New end-to-end widget flow: passed.
- Full `flutter test --no-pub`: 449 tests passed.
- `flutter analyze --no-pub`: no issues.
- Version bumped to 1.0.15 (16). Release APK build and phone installation/launch verification pending.

Prior uncommitted workspace changes and the challenge calendar/card improvements were retained. No Git merge or commit was performed.
