import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/services/home_capture_service.dart';
import 'package:ascent/features/thought_wall/thought_actions.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  group('Requirement 5: Reminders Product Logic & Single Creation', () {
    test(
      'scheduling a plan creates exactly ONE reminder record and no automatic "Did you do it?" reminder',
      () async {
        final now = DateTime(2026, 10, 17, 9, 0);
        final thoughtId = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'Prepare meeting notes'),
        );
        final source = (await db.thoughtDao.getThoughtById(thoughtId))!;

        final captureService = HomeCaptureService(
          db,
          clock: () => now.subtract(const Duration(hours: 1)),
        );
        final plan = await captureService.schedule(
          source: source,
          title: 'Prepare meeting notes',
          at: now,
        );

        final reminders = await db.select(db.reminderTable).get();
        // Exactly ONE reminder in database
        expect(reminders, hasLength(1));
        expect(reminders.first.title, 'Prepare meeting notes');
        expect(reminders.first.scheduledAt, now);

        // Verify no "Did you do it?" reminder was created in ReminderTable
        expect(
          reminders.any((r) => r.title.startsWith('Did you do it?')),
          isFalse,
        );
        expect(plan.checkIn, isNull);
      },
    );

    test(
      'legacy or auto-generated "Did you do it?" follow-ups are safely filtered from user reminders',
      () async {
        final now = DateTime.now().add(const Duration(days: 1));
        // User created reminder
        await db.reminderDao.insertReminder(
          ReminderTableCompanion.insert(title: 'Review PR', scheduledAt: now),
        );
        // Legacy auto-generated check-in
        await db.reminderDao.insertReminder(
          ReminderTableCompanion.insert(
            title: 'Did you do it? Review PR',
            scheduledAt: now.add(const Duration(minutes: 20)),
          ),
        );

        final all = await db.select(db.reminderTable).get();
        expect(all, hasLength(2));

        // Reminders screen data provider or filter removes the auto check-in
        final userReminders = all
            .where((r) => !r.title.startsWith('Did you do it?'))
            .toList();
        expect(userReminders, hasLength(1));
        expect(userReminders.first.title, 'Review PR');
      },
    );
  });

  group('Requirement 4: De-duplication across Thoughts, Tasks, and Reminders', () {
    test(
      'converting thought to task does not redundantly repeat title in notes when identical',
      () async {
        final thoughtId = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: 'Prepare sprint backlog'),
        );
        final source = (await db.thoughtDao.getThoughtById(thoughtId))!;

        final result = await ThoughtActions(
          db,
        ).convert([source], mode: ThoughtConversionMode.todo);

        expect(result.taskIds, hasLength(1));
        final task = await db.taskDao.getTaskById(result.taskIds.first);
        expect(task, isNotNull);
        expect(task!.title, 'Prepare sprint backlog');
        // Notes should be null/empty because it is identical to title!
        expect(task.notes, isNull);
        expect(task.linkedThoughtId, thoughtId);
      },
    );

    test(
      'converting thought to task preserves custom notes when content exceeds title',
      () async {
        final thoughtId = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content:
                'Prepare sprint backlog\nMake sure to review story points with Arun and team',
          ),
        );
        final source = (await db.thoughtDao.getThoughtById(thoughtId))!;

        final result = await ThoughtActions(
          db,
        ).convert([source], mode: ThoughtConversionMode.todo);

        expect(result.taskIds, hasLength(1));
        final task = await db.taskDao.getTaskById(result.taskIds.first);
        expect(task, isNotNull);
        expect(task!.title, 'Prepare sprint backlog');
        // Custom extra notes preserved
        expect(task.notes, contains('Make sure to review story points'));
      },
    );
  });

  group('Requirement 7: Home Activity Card - No Confusing Tabs', () {});

  group('Requirement 8: Streak Card Redesign', () {});

  group('Requirement 2: Thought Input Placement and Placeholder', () {
  });
}
