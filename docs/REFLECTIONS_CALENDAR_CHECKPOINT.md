# Mind Space conversion and challenge calendar

Date: 15 October 2026
Branch: `feature/reflections-calendar`

## Changes

- Thought conversion keeps Cancel and Save action together in a fixed footer. The form scrolls independently and reserves space above the keyboard. Cancel closes the sheet without creating tasks or reminders; saving still prevents duplicate writes and dismissal while pending.
- Added reusable `DateRangeCalendar` in shared widgets. It renders one month at a time, limits navigation to the inclusive range, labels start/finish dates, highlights today and endpoints, and crosses out elapsed dates within the range. Elapsed dates do not represent completed work.
- Challenge setup previews the dates as duration changes. Saved challenge details show the same component using the persisted dates.
- Added widget coverage for cancellation without writes with a keyboard open, inclusive dates, month/year navigation, range changes, leap years, single-day ranges, and narrow dark layouts at large text scale.

## Todo to Learning proposal (subsequently implemented)

The follow-up request implemented this flow; see [Send to lecture checkpoint](SEND_TO_LECTURE_CHECKPOINT.md). The notes below record the original proposal.

This is a useful fit with the existing `learningCourseId` / `learningLectureId` task associations and lecture player. A future “Move to Learning” action should choose or create a course/module and turn the timed todo into a linked lecture using the same task identity. Preserve notes, thought links, reminders, planned dates, and recorded timer time. Define how elapsed timer time maps to lecture progress before implementing; never count the same session twice. Handle an active timer explicitly before switching its association. After conversion, open the existing lecture player and follow the existing lecture completion policy.

## Validation

- Full `flutter test --no-pub`: 448 tests passed.
- New focused calendar/conversion suite: 4 tests passed (including the additional narrow dark layout check).
- `flutter analyze --no-pub`: no issues.
- Release arm64 APK 1.0.14 (15): built successfully; package metadata and APK signature verified.
- APK: `releases/Ascent-1.0.14-15-reflections-calendar-arm64.apk`, with adjacent SHA-256 file.
- Version supplied through build flags; source `pubspec.yaml` version retained.
- The initial build using `--no-pub` failed due to a generated test-only Android plugin registration. Regenerating release metadata with the normal build resolved it.
- Device installation and native visual verification: not performed.

Existing uncommitted changes were present across the workspace before this task. They were retained. No merge, commit or phone installation was performed.
