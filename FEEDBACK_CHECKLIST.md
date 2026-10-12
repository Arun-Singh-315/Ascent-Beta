# Mind Space feedback · 11 October 2026

- [x] 1. Replace blue/violet accents with warm or sage colors; keep the coffee cup dark brown with gentle animation.
- [x] 2. Write and send thoughts directly on Home without an input popup.
- [x] 3. Hide empty Home reminders; show a read-only preview that opens Reminders.
- [x] 4. Remove the brain/category button from the chat composer.
- [x] 5. Select several thoughts to add Todos, individual reminders, or one list reminder. Add reminders to a single note too.
- [x] 6. Put the Promise badge in the card header beside the date/time and actions.
- [x] 7. Explain swipe-to-archive/delete, Undo, and long-press selection on first use.
- [x] 8. Add a sequential guided tour with Back, Next, Try it, and replay from Settings.
- [x] 9. Move date/time left and expose Edit and Copy beside the menu.
- [x] 10. Add first-use explanations for feature screens and replayable help.
- [x] 11. Make archive/delete Undo snackbars expire automatically.
- [x] 12. Remove ordinary thought categories from filters, composer and edit sheets; retain Promise badges.
- [x] Use the reminder font (Plus Jakarta Sans) for thought-card content and Home notes.
- [x] Allow multiple active challenges, independent evidence tracking, a status chooser, history, and a persistent Home choice.
- [x] Complete analysis and regression checks: 29 focused tests passed; Flutter analysis clean.
- [x] Build version 1.0.5 (6), install on the connected Android device, and verify installation.

Verification: Android package `com.arun.ascent` reports versionName 1.0.5 and versionCode 6 after successful installation. The app launches; the device is currently in target-company onboarding. Home behavior was verified in widget tests, and independent challenge tracking was verified against an in-memory database with two real Focus-session records. Google Fonts HTTP requests are blocked by the widget-test runner, so those tests use fallback fonts.

Potential next improvements:

- Make target-company onboarding optional so notes, reminders and daily-life features are immediately accessible.
- Add a daily workload estimate across all active challenges, plus reusable challenge templates and a weekly review.
- Turn list reminders into editable checklists, with a quiet mode that disables follow-up nudges.
- Bundle the fonts for a consistent appearance offline and preserve unsent Home notes across app restarts.
- Let users pin a small set of favorite features on Home.

## Renovation follow-up · 12 October 2026

The next release is 1.0.6 (7). The full renovation suite passes 261 tests and Flutter analysis reports no issues. Fonts are now bundled; the previous fallback-font limitation no longer applies to the new render previews. See [the 16-point results and remaining roadmap](docs/renovation/RESULTS.md). The user requested a prepared APK and will connect the phone later; the previous installation evidence above must not be read as installation of 1.0.6.

### Installation follow-up · 12 October 2026

Version 1.0.6 (7) installed successfully after the phone was connected. Package metadata and cold launch were verified; the app is running at the notification permission prompt over onboarding. The user’s permission and profile choices were left untouched. See [device installation evidence](docs/renovation/qa/device-installation.txt).
