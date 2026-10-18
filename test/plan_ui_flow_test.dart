import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/plans/plans_screen.dart';
import 'package:drift/drift.dart' hide isNotNull;
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
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<void> mount(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'ActivityRowItem reveals inline check-in response and Done completes session',
    (tester) async {
      final planService = container.read(planServiceProvider);
      // Create routine with check-in policy
      final plan = await planService.createPlan(
        title: 'Morning walk',
        startDate: '2026-10-18',
        endDate: '2026-10-20',
        recurrenceRule: 'daily',
        localTime: '07:00',
        reminderPolicy: 'at_start',
        checkInPolicy: 'gentle',
        addTodo: true,
      );

      final occs = await planService.getOccurrencesForPlan(plan.id);
      expect(occs, hasLength(3));
      final firstOcc = occs.first;

      // Simulate check-in reminder being due by updating scheduledAt to the past
      final links = await db.planDao.getAlertLinksForOccurrence(firstOcc.id);
      final checkLink = links.firstWhere((l) => l.role == 'check_in');
      await (db.update(
        db.reminderTable,
      )..where((r) => r.id.equals(checkLink.reminderId))).write(
        ReminderTableCompanion(
          scheduledAt: Value(
            DateTime.now().subtract(const Duration(minutes: 5)),
          ),
        ),
      );

      final activityItem = TodayActivityItem(
        id: 'task_${firstOcc.linkedTaskId}',
        title: 'Morning walk',
        sourceType: 'task',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        linkedTaskId: firstOcc.linkedTaskId,
        categoryTag: 'Task',
        kind: ActivityKind.todo,
      );

      await mount(tester, ActivityRowItem(activity: activityItem));

      // Inline check-in prompt should be visible
      expect(find.text('Did you finish: Morning walk?'), findsOneWidget);
      expect(find.text('Done'), findsOneWidget);
      expect(find.text('Later'), findsOneWidget);
      expect(find.text('Skip this time'), findsOneWidget);
      expect(find.text('Skip check-in'), findsOneWidget);

      // Tap Done
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      final updatedOcc = await db.planDao.getOccurrenceById(firstOcc.id);
      expect(updatedOcc!.outcome, equals('done'));

      // Check-ins for this session should be stopped
      final reminder = await db.reminderDao.getReminderById(
        checkLink.reminderId,
      );
      expect(reminder!.isActive, isFalse);
    },
  );

  testWidgets(
    'ActivityRowItem swipe-to-delete intercepts protected routine tasks with PlanProtectionDialog',
    (tester) async {
      final planService = container.read(planServiceProvider);
      final plan = await planService.createPlan(
        title: 'Morning walk',
        startDate: '2026-10-18',
        endDate: '2026-10-20',
        recurrenceRule: 'daily',
        localTime: '07:00',
        addTodo: true,
      );

      final occs = await planService.getOccurrencesForPlan(plan.id);
      final firstOcc = occs.first;

      final activityItem = TodayActivityItem(
        id: 'task_${firstOcc.linkedTaskId}',
        title: 'Morning walk',
        sourceType: 'task',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        linkedTaskId: firstOcc.linkedTaskId,
        categoryTag: 'Task',
        kind: ActivityKind.todo,
      );

      await mount(tester, ActivityRowItem(activity: activityItem));

      // Attempt to swipe dismiss the item
      await tester.drag(find.byType(Dismissible), const Offset(-500, 0));
      await tester.pumpAndSettle();

      // Protected dialog should be presented instead of silently deleting
      expect(find.text('Part of Morning walk'), findsOneWidget);
      expect(find.text('Skip this session'), findsOneWidget);
      expect(find.text('Open routine'), findsOneWidget);

      // Tap "Skip this session"
      await tester.tap(find.text('Skip this session'));
      await tester.pumpAndSettle();

      // Occurrence is now marked skipped, but task row was NOT deleted from DB
      final updatedOcc = await db.planDao.getOccurrenceById(firstOcc.id);
      expect(updatedOcc!.outcome, equals('skipped'));

      final task = await db.taskDao.getTaskById(firstOcc.linkedTaskId!);
      expect(task, isNotNull);
    },
  );

  testWidgets(
    'Plans board opens a reactive collection with lifecycle controls',
    (tester) async {
      await container
          .read(planServiceProvider)
          .createPlan(
            title: 'Reading routine',
            startDate: '2026-10-18',
            endDate: '2026-10-25',
            recurrenceRule: 'weekdays',
            localTime: '08:00',
          );
      await mount(tester, const SizedBox(height: 600, child: PlansScreen()));
      expect(find.text('Reading routine'), findsOneWidget);
      await tester.tap(find.text('Reading routine'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Plan actions'));
      await tester.pumpAndSettle();
      expect(find.text('Edit plan'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
      expect(find.text('Archive'), findsOneWidget);
      expect(find.text('Add items'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
