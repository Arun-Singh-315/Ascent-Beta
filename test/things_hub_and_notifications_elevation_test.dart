import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/notification_presentation.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/home/widgets/activity_composer.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Screenshot Bug Fixes: Root Navigator on Bottom Sheets', () {
    testWidgets('ActivityRowItem priority sheet uses root navigator and glass style', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final activity = TodayActivityItem(
        id: 'task_1',
        title: 'Review proposal',
        kind: ActivityKind.todo,
        status: TodayActivityStatus.notStarted,
        sourceType: 'task',
        categoryTag: 'tasks',
        elapsedSecondsToday: 0,
        linkedTaskId: 1,
        priority: 'medium',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: ActivityRowItem(
                activity: activity,
                compact: true,
              ),
            ),
          ),
        ),
      );

      // Verify compact priority micro-badge exists without the verbose "Priority:" prefix
      expect(find.byKey(const ValueKey('activity_priority_task_1')), findsOneWidget);
      expect(find.text('Important'), findsOneWidget);
      expect(find.text('Priority: Important'), findsNothing);

      // Tap to open priority sheet
      await tester.tap(find.byKey(const ValueKey('activity_priority_task_1')));
      await tester.pumpAndSettle();

      // Priority sheet header & options should be visible
      expect(find.text('Change priority'), findsOneWidget);
      expect(find.text('Urgent'), findsOneWidget);
      expect(find.text('Important'), findsNWidgets(2));
      expect(find.text('Normal'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });

    testWidgets('ActivityRowItem compact row safe at 320px with 2.0x text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final activity = TodayActivityItem(
        id: 'task_2',
        title: 'Super long activity title testing responsive flex wrap handling',
        kind: ActivityKind.todo,
        status: TodayActivityStatus.notStarted,
        sourceType: 'task',
        categoryTag: 'tasks',
        elapsedSecondsToday: 0,
        linkedTaskId: 2,
        priority: 'high',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
              child: Scaffold(
                body: ActivityRowItem(
                  activity: activity,
                  compact: true,
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Urgent'), findsOneWidget);
    });
  });

  group('Things Hub Hero Activity Composer', () {
    testWidgets('Hero mode toggle between To-do and Timer with fast duration presets', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: const Scaffold(
              body: Padding(
                padding: EdgeInsets.all(12),
                child: ActivityComposer(),
              ),
            ),
          ),
        ),
      );

      // Defaults to To-do mode
      expect(find.text('To-do'), findsOneWidget);

      // Switch to Timer via Activity type selector
      await tester.tap(find.byTooltip('Activity type'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Timer').last);
      await tester.pumpAndSettle();

      // Duration selector should be active
      expect(find.text('30 min'), findsOneWidget);

      // Entering text expands interactive mode switcher and duration chips
      await tester.enterText(
        find.byKey(const ValueKey('activity_quick_input')),
        'Study algorithms',
      );
      await tester.pumpAndSettle();

      // Quick duration preset 25m Pomodoro should be visible and selectable
      expect(find.text('25m'), findsOneWidget);
      await tester.tap(find.text('25m'));
      await tester.pumpAndSettle();
      expect(find.text('25 min'), findsOneWidget);

      // Can switch back to To-do easily while typing
      expect(find.text('To-do'), findsWidgets);
      await tester.tap(find.text('To-do').first);
      await tester.pumpAndSettle();
      expect(find.text('Checklist to-do · Quick tap completion'), findsOneWidget);
    });

    testWidgets('ActivityRowItem detail dialog allows switching task between To-do and Focus Timer', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final taskId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Review System Design',
          plannedDate: drift.Value(DateTime.now()),
        ),
      );

      final activity = TodayActivityItem(
        id: 'task_$taskId',
        title: 'Review System Design',
        kind: ActivityKind.todo,
        status: TodayActivityStatus.notStarted,
        sourceType: 'task',
        categoryTag: 'tasks',
        elapsedSecondsToday: 0,
        linkedTaskId: taskId,
        priority: 'medium',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: ThemeData.light(),
            home: Scaffold(
              body: ActivityRowItem(
                activity: activity,
                compact: true,
              ),
            ),
          ),
        ),
      );

      // Tap card to open detail dialog
      await tester.tap(find.text('Review System Design'));
      await tester.pumpAndSettle();

      // Should show option to switch to 25m Focus Timer
      expect(find.text('Switch to 25m Focus Timer'), findsOneWidget);
      await tester.tap(find.text('Switch to 25m Focus Timer'));
      await tester.pumpAndSettle();

      // Verify task in database has estimatedMinutes updated to 25
      final updated = await db.taskDao.getTaskById(taskId);
      expect(updated?.estimatedMinutes, 25);
    });
  });

  group('Caring Notifications & Deep Linking', () {
    test('Task linked reminder routes to /today?task=id instead of /reminders', () async {
      final taskId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Deep Work Session',
          plannedDate: drift.Value(DateTime.now()),
        ),
      );

      await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Deep Work Session',
          scheduledAt: DateTime.now().add(const Duration(hours: 2)),
          linkedTaskId: drift.Value(taskId),
        ),
      );

      final reminder = (await db.reminderDao.getRemindersByTaskId(taskId)).first;
      expect(reminder.linkedTaskId, taskId);
    });

    test('ReminderNotificationCopy provides caring, context-aware copy', () {
      final copy = ReminderNotificationCopy('Review architecture design');
      expect(copy.title, 'Review architecture design');

      // Smart body depending on destination
      expect(
        copy.bodyFor('/today?task=10'),
        '🎯 Time to focus · Tap to start this activity',
      );
      expect(
        copy.bodyFor('/hydration'),
        '💧 Time to hydrate · Keep your mind refreshed',
      );
      expect(
        copy.bodyFor('/thought-wall?thought=5'),
        '✨ Mind Palace · Tap to reflect on your thought',
      );
      expect(
        copy.bodyFor('/reminders'),
        'Due now · Tap to open Reminders',
      );
    });

    test('NotificationService destination routes recognize /today and /hydration', () {
      expect(
        NotificationService.destinationForPayload('/today?task=12'),
        '/today?task=12',
      );
      expect(
        NotificationService.destinationForPayload('/hydration'),
        '/hydration',
      );
    });
  });
}
