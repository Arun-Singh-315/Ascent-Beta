import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/ai/riya_alert_effects.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/services/home_capture_service.dart';
import 'package:ascent/core/streak/study_streak_models.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/home_schedule_sheet.dart';
import 'package:ascent/features/home/widgets/study_streak_meter_card.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/thought_wall/thought_actions.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
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
        homeScheduleEffectsProvider.overrideWith(
          (ref) => RiyaAlertEffects(
            db,
            cancel: (_) async => true,
            schedule: (_) async => false,
          ),
        ),
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

  group('Requirement 7: Home Activity Card - No Confusing Tabs', () {
    testWidgets(
      'ActivityHubCard displays today unfinished activities without Up next / Completed / All tabs',
      (tester) async {
        final today = DateTime.now();
        // Add one unfinished task for today
        await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: 'Review architecture diagram',
            plannedDate: drift.Value(today),
          ),
        );

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
              home: const Scaffold(
                body: SingleChildScrollView(child: ActivityHubCard()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Confusing tabs must NOT be present
        expect(find.text('Up next'), findsNothing);
        expect(find.text('Completed'), findsNothing);
        expect(find.text('All'), findsNothing);

        // The actionable task is visible
        expect(find.text('Review architecture diagram'), findsOneWidget);
        // Header has "Today" and "View board"
        // Heading plus the composer's default date control.
        expect(find.text('Today'), findsNWidgets(2));
        expect(find.text('View board'), findsOneWidget);
      },
    );
  });

  group('Requirement 8: Streak Card Redesign', () {
    testWidgets(
      'StudyStreakMeterCard renders compact progress with accurate calculation',
      (tester) async {
        const status = StudyStreakStatus(
          todaySeconds: 45 * 60,
          targetSeconds: 120 * 60,
          displayStreakDays: 3,
          longestStreakDays: 5,
          isTodaySecured: false,
        );

        await tester.pumpWidget(
          MaterialApp(
            theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
            home: const Scaffold(body: StudyStreakMeterCard(status: status)),
          ),
        );
        await tester.pumpAndSettle();

        // Compact streak information displayed
        expect(find.textContaining('3 Day Streak'), findsOneWidget);
        expect(find.textContaining('45 / 120m'), findsOneWidget);
        expect(find.textContaining('75m left'), findsOneWidget);
        expect(find.textContaining('Longest: 5d'), findsOneWidget);
      },
    );
  });

  group('Requirement 2: Thought Input Placement and Placeholder', () {
    testWidgets(
      'Thought input has intentional placeholder "Capture a thought…"',
      (tester) async {
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
              home: const Scaffold(
                body: SingleChildScrollView(child: ThoughtWallHomePreview()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Capture a thought…'), findsOneWidget);
        // The generic confusing placeholder must NOT be present
        expect(
          find.text('A thought, a task, or something to remember…'),
          findsNothing,
        );
      },
    );
  });
}
