# Home capture and follow-up implementation

16 October 2026. Scope: Home capture and the shared Riya/reminder integration needed by it. Existing unrelated feature screens retain their workflows. No schema migration, remote model/API integration, commit or push.

## Delivered behavior

- Home's multiline composer accepts a thought or a scheduling request. Ordinary notes save directly; explicit planning requests open an editable review before any Todo/reminder creation.
- Persistent Plan / Todo / Ask Riya actions replace Home's disappearing-only action invitation. Thought bubbles have a subtle leading quote mark and an accessible open arrow; stored text is unchanged.
- Review title, absolute local date/time, linked Todo choice, and optional later check-in. Missing or unsupported dates use the date/time picker. Drafts survive dismissal/reopening and restart through existing preference backup coverage.
- Schedule creates one source-linked Todo (unless reminder-only is selected), its initial reminder, and an optional check-in reminder in one database transaction. A stable command receipt prevents duplicate creation on retry. Changing a saved plan uses Home's Change time action, preserving record IDs.
- Up next shows each Home plan once, including alert-pending feedback. Those linked tasks/reminders are excluded from the other Home preview rows; the normal Todo/Reminders screens still expose their records.
- Done follows existing Task completion guards and stops linked reminders. Later delays the check-in (15/30/60 minutes from Home; 30 minutes from notification). Skip check-in leaves the Todo unfinished and preserves an initial reminder that is still in the future. Ignored check-ins remain unresolved on Home.
- Check-in notifications carry Done / Later / Skip actions and the reminder occurrence identity. Stale actions after rescheduling or completion cannot complete another occurrence. Android and iOS notification configurations are present; device delivery remains a physical-device check.
- Ask Riya opens with the original thought prefilled. Supported scheduling requests in Riya use the same review and capture service instead of creating another independent task flow.

## Deliberate boundaries

Interpretation is local and conservative: today/tomorrow or an ISO calendar date, am/pm time, and optional duration in minutes. Other wording falls back to manual review. This is a one-time plan, not a recurring schedule engine. A duration determines the proposed check-in time; it does not start a Focus session or impose a Focus completion requirement on a quick Todo. Existing timed/learning tasks retain their completion guards.

Initial saves and alert scheduling are separate: a failed/denied OS effect remains durable and pending for retry. No notification delivery guarantee is inferred from an APK build or mock platform test. No test schedules were inserted into the user's phone database.

## Verification

- Targeted regression batch: 46 tests passed, covering new capture/service cases plus existing Home/Thought behavior.
- Additional platform contract test passed: initial alert opens Home; check-in contains all three foreground actions and the exact persisted occurrence payload.
- Android debug APK built successfully at `build/app/outputs/flutter-apk/app-debug.apk`.
- Static analysis: no new issues; one pre-existing unused import in `test/nordic_sky_theme_test.dart` remains.
- Final full suite: **488 tests passed, no failures**. `git diff --check` passed.

Meaningful checks include transactional save/replay, changed-source rejection, completion from Todo, future/overdue check-in responses, stale actions, timed-task guard, rescheduling, denied scheduling/retry, live-stream updates, backup/restore, deleting just the initial alert, and retaining drafts. Widget flow tests cover 360px/doubled text in Classic Clay, Nordic Sky, and dark mode. Native alert delivery, reboot, battery restrictions and iOS physical behavior require device verification.

## Device walkthrough

1. In Home type: “Tomorrow at 7 pm practise interviews for 30 minutes. Remind me and ask afterwards.”
2. Send; review the title, date/time and check-in. Change times to near-future values for a quick test. Tap Schedule once.
3. Check one Todo and the two linked reminder records. Close/reopen the app: the plan should remain in Up next.
4. Allow notifications and wait for the reminder and check-in. Try Later, then Done. Done should complete the Todo and stop pending linked alerts.
5. Separately try Skip check-in; the Todo should remain unfinished. Try completing the Todo before the check-in; a later stale notification must not change it again.
