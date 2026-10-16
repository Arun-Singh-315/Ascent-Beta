# Ascent quality upgrade · 1.0.7 (8)

Later follow-up: [Learning and notification flow · 1.0.8 (9)](LEARNING_ALERTS_RESULTS.md), including schema-14 backup import compatibility.

12 October 2026. Follow-up to the user's request to raise the audited experience to the 8–9 range. The historical audit and 1.0.6 results remain preserved.

## Implemented

- **Start now:** enter everyday tools without a career profile. No invented name, role, companies or applications. Personalized onboarding only requires a name; role and companies are optional. Settings can supply details later. Home and cold-start guards use the same rule.
- **Writing recovery:** Home and Thought Wall keep separate local drafts, serialize writes, retry failed writes on lifecycle changes, and clear drafts after successful note submission. Existing asynchronous-send protection remains.
- **Whole-workspace backups:** Settings → Save or restore a backup opens a dedicated screen. Native save/open controls handle a versioned JSON file with all public database tables, IDs and relationships, all typed preferences and referenced Resume Vault attachments. Preview counts and an explicit replacement confirmation precede restore.
- **Recoverable restore:** checksum/schema/type/file validation, bound SQL values, generated attachment destinations, a pre-restore recovery copy, a SQLite transaction and foreign-key check. A durable database journal finishes preference replacement after interrupted app startup. Providers restart after restore. Imported running Focus sessions and walks become paused rather than collecting time while offline.
- **Reminder recovery:** contextually request notifications in Reminders, retry future active alerts, and report verified scheduling counts. Restore leaves a durable alarm-sync flag until scheduling finishes; cold start retries it. Operating-system permissions stay on the device.
- **Entry accessibility:** scrollable onboarding and shorter controls; entry and backup layouts checked at 2× text in both themes. Profileless Home uses “Your space” and a neutral greeting.

## Limits and next improvements

Backups are unencrypted personal files: keep them private. SHA-256 detects accidental modification; it is not authentication. This format currently requires the same database schema (14), with a 64 MB envelope and 40 MB attachment limit. Historical profile-only exports are rejected without replacing records. External reader/media content and operating-system permissions are excluded. Export refuses a missing resume attachment; restoring a good backup can repair it. If the existing workspace already has a missing resume, its automatic safety copy records that absence and cannot recover those missing bytes.

Physical-device evidence applies to the connected Nothing A142 and the scenarios recorded below. Broader screen-reader coverage, low-end performance measurements, battery-restricted overnight alert delivery, background GPS and interrupted audio need a wider device matrix. These are the strongest next improvements before calling the app a consistently 9/10 experience. A numeric score remains a product judgment, not a certification.

## Verification

- Full Flutter regression suite: **277 passed**. [Test log](qa/quality-flutter-test.txt).
- Flutter static analysis: **no issues**. [Analysis log](qa/quality-flutter-analyze.txt).
- Release build succeeded: **1.0.7 (8)**, schema 14, 100,100,654 bytes. Package metadata and APK signature verified. [Build](qa/quality-flutter-build-apk.txt), [verification](qa/quality-apk-verification.txt).
- APK SHA-256: `17da3ed47ec837fe361ea712845eeadf37be19a6c44c1894a2f6ebca1c4fa5e6`.
- Automated coverage adds Quick Start without fake profile/companies, persisted Unicode drafts, 2× text entry/backup layout in both themes, every-table/setting backup round trips, resume attachment remapping, checksum/confirmation rejection, foreign-key rollback, interrupted preference recovery, missing-file repair and paused imported tracking. Reminder tests cover denied permission, failed reset, scheduling failure and retry with the same IDs.
- Physical-device integration uses an isolated `com.arun.ascent.debug` package with an explicit package guard before changing fixtures. It checks actual Quick Start/Home, an idempotent Riya expense, SQLite/preferences export to disk and restore, native document chooser cancellation without replacing records, local timezone and an Android scheduled reminder. Test notification permission is granted only to this temporary package.

- Physical integration: **passed on Nothing A142**. [Integration log](qa/quality-device-integration.txt), [native chooser/notification evidence](qa/quality-native-checks.txt). Android posted QA notification ID 810007; this is observed delivery, rather than only a pending request. This short foreground check does not establish overnight/battery-restricted delivery.
- The Flutter test runner removed its temporary debug package after completion. No test fixtures were written to the production package.
- Production upgrade: ADB `install -r` returned **Success**; installed package metadata confirms **1.0.7 (8)**. Existing app storage was not reset. Cold launch succeeded; the existing Home profile and learning preview rendered, along with existing reminder UI. No production restore or fabricated health/task action was performed. [Installation and launch evidence](qa/quality-device-installation.txt).
