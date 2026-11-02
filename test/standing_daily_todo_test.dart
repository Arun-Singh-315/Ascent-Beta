import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/services/activity_entry_service.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/today/add_activity_sheet.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildTestApp({
    required Widget child,
    Size size = const Size(390, 844),
    double textScale = 1.0,
    bool dark = false,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
      child: MaterialApp(
        theme: dark ? AscentTheme.dark() : AscentTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Scaffold(body: child),
        ),
      ),
    );
  }

  group('Standing Daily To-Do: DAO & Service Lifecycle Tests', () {
    test('TaskDao persists isDailyStanding and includes in today query', () async {
      final taskId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Daily Sunlight 15m',
          isDailyStanding: const drift.Value(true),
          plannedDate: drift.Value(DateTime.now()),
        ),
      );

      final task = await db.taskDao.getTaskById(taskId);
      expect(task, isNotNull);
      expect(task!.isDailyStanding, isTrue);

      final todayTasks = await db.taskDao.watchTodayTasks().first;
      expect(todayTasks.any((t) => t.id == taskId), isTrue);

      final overdueTasks = await db.taskDao.watchOverdueTasks().first;
      expect(overdueTasks.any((t) => t.id == taskId), isFalse);
    });

    test('ActivityEntryService saves and updates isDailyStanding correctly', () async {
      final service = ActivityEntryService(db);
      final result = await service.save(
        title: 'Morning Breathwork',
        date: DateTime.now(),
        isDailyStanding: true,
      );

      var task = await db.taskDao.getTaskById(result.taskId);
      expect(task, isNotNull);
      expect(task!.isDailyStanding, isTrue);

      // Toggle off standing daily repeat
      await service.save(
        title: 'Morning Breathwork',
        date: DateTime.now(),
        taskId: result.taskId,
        isDailyStanding: false,
      );

      task = await db.taskDao.getTaskById(result.taskId);
      expect(task!.isDailyStanding, isFalse);
    });

    test('Standing task completes today and allows uncompleting', () async {
      final taskId = await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Evening Stretches',
          isDailyStanding: const drift.Value(true),
          plannedDate: drift.Value(DateTime.now()),
        ),
      );

      // Complete today
      final completed = await db.taskDao.markComplete(taskId);
      expect(completed, isTrue);

      var task = await db.taskDao.getTaskById(taskId);
      expect(task!.actualCompletedDate, isNotNull);

      // Uncomplete
      final incompleted = await db.taskDao.markIncomplete(taskId);
      expect(incompleted, isTrue);

      task = await db.taskDao.getTaskById(taskId);
      expect(task!.actualCompletedDate, isNull);
    });
  });

  group('Standing Daily To-Do: UI & Accessibility Tests', () {
    testWidgets('AddActivitySheet displays Repeat daily switch and toggles it', (tester) async {
      await tester.pumpWidget(
        buildTestApp(
          child: const AddActivitySheet(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Repeat daily'), findsOneWidget);
      expect(find.text('Keep this in your to-do list every day'), findsOneWidget);

      // Toggle the switch
      await tester.tap(find.text('Repeat daily'));
      await tester.pumpAndSettle();

      expect(find.text('Appears fresh every day until you turn it off'), findsOneWidget);
    });

    testWidgets('ActivityRowItem displays daily repeat badge and resets tomorrow subtitle', (tester) async {
      const standingItem = TodayActivityItem(
        id: 'task_1',
        title: 'Read 10 pages',
        sourceType: 'task',
        status: TodayActivityStatus.done,
        elapsedSecondsToday: 0,
        categoryTag: 'Task',
        isDailyStanding: true,
      );

      await tester.pumpWidget(
        buildTestApp(
          child: const ActivityRowItem(
            activity: standingItem,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
      expect(find.textContaining('Resets tomorrow'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('ActivityRowItem is immune to overflows at 320px width & 2.0x font scaling', (tester) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const standingItem = TodayActivityItem(
        id: 'task_2',
        title: 'Morning Yoga and Core Conditioning for Daily Health',
        sourceType: 'task',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        categoryTag: 'Task',
        priority: 'high',
        isDailyStanding: true,
      );

      await tester.pumpWidget(
        buildTestApp(
          size: const Size(320, 800),
          textScale: 2.0,
          child: const ActivityRowItem(
            activity: standingItem,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.repeat_rounded), findsOneWidget);
      expect(find.textContaining('Daily • High to-do'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
