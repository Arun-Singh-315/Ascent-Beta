# Glass UI polish · 1.0.9 (10)

12 October 2026. Small visual consistency pass ahead of user beta testing.

## Changes

- Riya user and assistant message bubbles use the shared blurred glass surface, theme ink and subtle edges. Verified action receipts use the same surface with a sage icon instead of a separate bright green card. Narrow headers now constrain the assistant name and subtitle.
- Home's upcoming-reminder preview has actual clipped backdrop blur. Reminder creation/update, sync, completion, snooze and deletion feedback use the shared glass snackbar; Undo remains available. Activity-save and chat-error feedback also use it.
- Reminder date/time controls use soft fills and edges; repeat-selection icons use the selected clay ink; Alarm mode lives in a glass card.
- In-app reminder and ringing dialogs use glass surfaces, scroll when content needs more room, and retain all snooze/completion actions. Shared confirmation dialogs follow the same treatment.
- Android's independent alarm activity uses bundled Jakarta typography, an atmospheric background, a translucent card, one prominent Done action, a quieter Snooze action, and an Open Reminders link. It respects the saved Light/Dark/System setting, window insets, and light/dark system-bar icon contrast. Native ringing/scheduling/action logic is unchanged.
- Android owns notification-tray surfaces. Those system notifications retain Android's standard appearance.

## Verification

- Full final Flutter suite: **299 passed**. [Log](qa/glass-flutter-test.txt).
- Flutter analysis: **no issues**. [Log](qa/glass-flutter-analyze.txt).
- Focused UI/lifecycle checks: **12 passed**, including both themes, 2× text in reminder dialogs and snackbars, Undo callback, actual glass ancestry for Riya messages, in-app native-action failure/retry, overdue reminders and notification/alarm mode transitions. [Log](qa/glass-focused-tests.txt).
- Riya screenshots rendered with bundled fonts and icons and visually reviewed in both themes: [light](qa/glass-riya-light.png), [dark](qa/glass-riya-dark.png).
- Nothing A142 native alarm checks used only the isolated `com.arun.ascent.debug` package and a guarded [QA fixture](../../integration_test/android_tools/GlassAlarmFixture.java). Actual light/dark native screens were visually reviewed. Tapping Snooze emptied the native ringing queue and created a future alarm plus a snooze receipt; tapping Done emptied the ringing queue and removed that alarm, with a done receipt. No AlarmRingingService remained afterward. [Snooze state](qa/glass-native-snooze.txt), [Done state](qa/glass-native-done.txt), [light](qa/glass-native-light.png), [dark](qa/glass-native-dark.png).
- The Flutter device integration runner disconnected after backgrounding, so that run is **not a passing integration test**. The subsequent independent native checks above completed successfully. [Interrupted runner](qa/glass-device-runner-interruption.txt). Both temporary QA packages were removed afterward.
- The first simultaneous release/integration build conflicted over the generated plugin registrant; the release was rebuilt sequentially. A final build includes the native system-bar contrast correction identified during visual inspection.

- Final release build: **successful**, 1.0.9 (10), schema 15. APK signature verification passed. ADB install returned **Success** on Nothing A142; installed metadata reports versionCode 10/versionName 1.0.9 and cold launch returned Status: ok. The release opened onboarding. No production profile or test reminder was inserted. [Build](qa/glass-release-build.txt), [APK verification](qa/glass-apk-verification.txt), [installation](qa/glass-phone-installation.txt), [launch](qa/glass-release-launch.png).
- Shareable APK: `releases/Ascent-1.0.9-10.apk`. SHA-256: `83988cf8cf85e06b688685bd738271ad33a809e1c9e775cc14992a4e275c7751`.

These checks cover this visual pass and a short real-device alarm cycle. They do not establish overnight delivery under battery restrictions or compatibility across every Android device. Beta-user feedback remains useful.
