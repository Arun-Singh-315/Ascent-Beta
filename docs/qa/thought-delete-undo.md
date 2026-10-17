# H1 — Thought delete / Undo consistency

17 October 2026 · branch `feature/thought-delete-undo-consistency`.

## Implementation

- Menu delete and swipe delete now share a handler and a single-use, in-memory deletion token. The token captures the actual database record, task links, reminder links/records, and both directions of merge provenance.
- Undo uses a surviving ScaffoldMessenger rather than the removed card's context, so a reactive list removing the card does not also remove access to Undo.
- Restore preserves the note ID and fields. It reconnects unchanged detached tasks and reminder records, and restores unchanged merge tombstones. It never replaces newer tasks, merge snapshots, associations, occupied thought IDs, or explicitly removed incoming merge links.
- Tokens are bounded to the existing last-20-deletions cache, invalidated by workspace replacement, and consumed on successful restoration. Old tokens cannot act on a later deletion of the same ID.
- Restore is transactional. Failed restore rolls back relationships and leaves the token available for Retry. Delete/restore failures are visible; failed deletion leaves the row in place.
- No schema changes or new dependencies. Other uncommitted music/typography work is preserved.

Files: `thought_dao.dart`, `thought_wall_screen.dart`, `test/thought_delete_undo_test.dart`.

## Verification

- Focused tests: **20 passed** across `thought_delete_undo_test.dart`, `connected_task_undo_test.dart`, and `connected_thought_actions_test.dart`.
- Nine new tests cover relationship restoration in both merge directions, newer edits and associations, removed links, stale tokens/workspace replacement, transactional failure/retry, both delete handlers, and visible delete/restore failures.
- Menu regression dispatches the real menu selection callback; swipe regression performs the swipe gesture. Menu geometry and device interaction remain in the manual check.
- `flutter analyze --no-pub`: zero errors; five unrelated unused-import warnings in existing Home/test files.
- `git diff --check`: passed.

## Device acceptance still pending

Convert a note to Todo + Reminder, merge it with another note, then delete and Undo through the menu and through swipe. Check that the same Todo, reminder, and merge provenance remain connected. Change a detached task or merge before Undo and verify the newer record is retained. Test menu access and snackbar behavior on the device.

Latest release build and full-suite results will be recorded after completion. An Android device is connected; installation has not been requested.

Full suite result: **617 passed, 3 failed**. Failures outside H1:
- `home_capture_service_test.dart`: expects changed-title replay to throw, while the current service explicitly supports updating/rescheduling a plan; likely a stale contract expectation. Verify identity/duplicate behavior before updating the test.
- `home_day_layout_test.dart`: Home activity header/chip and check-in dialog overflow at 320px / 200% text.
- `home_reminders_refinement_test.dart`: expects no Completed control, while the current Home activity card includes one. Reconcile the intended design and test.

All H1 tests passed in the full run. Initial release attempt failed in generated plugin registration (`integration_test` referenced but unavailable to release Java compilation) while tests ran concurrently. Retrying the build sequentially after testing finished; no release-readiness claim is made while the broader suite has failures.

## Final build checkpoint

Sequential retry succeeded: `flutter build apk --release`.
APK: `/home/arunsinghvisen/Ascent-Beta/build/app/outputs/flutter-apk/app-release.apk` (103.5 MB reported by Flutter), version **1.0.20+21**.
No installation performed. Device acceptance remains pending. Full-suite status remains **617 passed / 3 failed** as detailed above; H1 focused status **20 passed**. Next incomplete main audit row: **M1 selection reconciliation**. The confirmed Home large-text overflow is also retained as a separate follow-up.

Installation subsequently authorized and completed on connected device `00069349A001176` using `adb install -r`: **Success**. Package/version verification performed after installation. Manual Undo and music playback interaction checks remain pending.
