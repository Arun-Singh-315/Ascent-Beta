import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/reminders/reminders_screen.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'feature_guide_v1_Reminders & Alerts': true,
    });
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Google Calendar in Reminders Tests', () {
    testWidgets(
      'Toggles into Google Calendar view and renders week strip & navigation',
      (tester) async {
        final now = DateTime.now();
        await db.reminderDao.insertReminder(
          ReminderTableCompanion.insert(
            title: 'Review System Design Docs',
            scheduledAt: now,
          ),
        );
        await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: 'Prepare Sprint Retrospective',
            plannedDate: Value(now),
          ),
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const RemindersScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially in list mode
        expect(
          find.byKey(const ValueKey('reminders_calendar_card')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('calendar_toggle_button')),
          findsOneWidget,
        );

        // Tap calendar toggle button
        await tester.tap(find.byKey(const ValueKey('calendar_toggle_button')));
        await tester.pumpAndSettle();

        // Calendar card is now rendered
        expect(
          find.byKey(const ValueKey('reminders_calendar_card')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('calendar_today_button')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('calendar_prev_month')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('calendar_next_month')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('calendar_expand_toggle')),
          findsOneWidget,
        );

        // Verify that today's reminders and tasks are listed in the agenda
        expect(find.text('Review System Design Docs'), findsOneWidget);
        expect(find.text('Prepare Sprint Retrospective'), findsOneWidget);
        expect(find.text('Reminders'), findsOneWidget);
        expect(find.text('Tasks & to-dos'), findsOneWidget);

        // Expand to full month
        await tester.tap(find.byKey(const ValueKey('calendar_expand_toggle')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('reminders_calendar_card')),
          findsOneWidget,
        );
      },
    );

    testWidgets('Completes reminder and task from calendar view', (
      tester,
    ) async {
      final now = DateTime.now();
      final reminderId = await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Doctor Follow-up',
          scheduledAt: now,
        ),
      );
      final taskId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Submit Expense Report',
          plannedDate: Value(now),
        ),
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const RemindersScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to calendar
      await tester.tap(find.byKey(const ValueKey('calendar_toggle_button')));
      await tester.pumpAndSettle();

      // Find reminder circular completion button
      final reminderCompleteKey = ValueKey(
        'calendar_reminder_complete_$reminderId',
      );
      expect(find.byKey(reminderCompleteKey), findsOneWidget);
      await tester.ensureVisible(find.byKey(reminderCompleteKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(reminderCompleteKey));
      await tester.pumpAndSettle();

      // Reminder is finished in DB
      final updatedReminder = await db.reminderDao.getReminderById(reminderId);
      expect(updatedReminder?.isActive, false);

      // Find task circular completion button
      final taskCompleteKey = ValueKey('calendar_task_complete_$taskId');
      expect(find.byKey(taskCompleteKey), findsOneWidget);
      await tester.ensureVisible(find.byKey(taskCompleteKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(taskCompleteKey));
      await tester.pumpAndSettle();

      // Task is finished in DB
      final updatedTask = await db.taskDao.getTaskById(taskId);
      expect(updatedTask?.actualCompletedDate, isNotNull);
    });

    testWidgets(
      'Calendar view is immune to overflow at 320px width with 2.0x font scaling',
      (tester) async {
        final now = DateTime.now();
        await db.reminderDao.insertReminder(
          ReminderTableCompanion.insert(
            title:
                'Long Reminder Title Testing Overflow Safeguard On Narrow Viewports',
            scheduledAt: now,
          ),
        );
        await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title:
                'Super Long Task Title With Extended Description That Must Not Overflow',
            plannedDate: Value(now),
          ),
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        addTearDown(container.dispose);

        tester.view.physicalSize = const Size(320 * 2, 700 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const MediaQuery(
                data: MediaQueryData(
                  size: Size(320, 700),
                  textScaler: TextScaler.linear(2.0),
                ),
                child: RemindersScreen(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to calendar
        await tester.tap(find.byKey(const ValueKey('calendar_toggle_button')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(
          find.byKey(const ValueKey('reminders_calendar_card')),
          findsOneWidget,
        );

        // Expand to full month at 2.0x text scale
        await tester.tap(find.byKey(const ValueKey('calendar_expand_toggle')));
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
