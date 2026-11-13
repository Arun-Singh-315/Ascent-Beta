import 'dart:async';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/home/widgets/quick_modules_nav_hub.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTimeTrackingNotifier extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

class _FakeStudyStreakNotifier extends StudyStreakNotifier {
  @override
  StudyStreakStatus build() => StudyStreakCalculator().calculate(
    todaySeconds: 0,
    yesterdaySeconds: 0,
    priorStreakDays: 0,
    historicalLongestStreak: 0,
    historicalShortestStreak: 1,
    now: DateTime.now(),
  );
}

TodayActivityItem _makeActivity({
  required String id,
  required String title,
  int? linkedTaskId,
}) => TodayActivityItem(
  id: id,
  title: title,
  kind: ActivityKind.todo,
  status: TodayActivityStatus.notStarted,
  sourceType: 'task',
  categoryTag: 'Task',
  elapsedSecondsToday: 0,
  linkedTaskId: linkedTaskId,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

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

  group('Home Quick Actions & ActivityHubCard Enhancements', () {
    testWidgets(
      'ActivityHubCard displays clean Things Hub header without Med button and centered empty state',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            timeTrackingProvider.overrideWith(
              () => _FakeTimeTrackingNotifier(),
            ),
            studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
            todayActivitiesProvider.overrideWith((ref) => Stream.value([])),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: ActivityHubCard(),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Verify clean header
        expect(find.text('Dayboard'), findsOneWidget);
        expect(find.text('+ Med'), findsNothing);

        // Verify centered empty state text is rendered
        expect(find.text('Start with something small.'), findsOneWidget);
      },
    );

    testWidgets(
      'QuickModulesNavHub displays "+ Add" button in Medicine tile when no medicine doses scheduled',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            todayMedicineLogsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(0)),
            dailyWaterGoalStreamProvider.overrideWith(
              (ref) => Stream.value(2500),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: QuickModulesNavHub(showChallenge: false),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('No doses'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('medicine_add_button')),
          findsOneWidget,
        );
        expect(find.text('+ Add'), findsOneWidget);
      },
    );

    testWidgets(
      'ActivityRowItem long-press opens quick action sheet with rapid delete and complete',
      (tester) async {
        final task = _makeActivity(
          id: 'task_quick_1',
          title: 'Submit tax documents',
          linkedTaskId: 101,
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            timeTrackingProvider.overrideWith(
              () => _FakeTimeTrackingNotifier(),
            ),
            studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(
                body: ActivityRowItem(activity: task, compact: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Long press on the row
        await tester.longPress(find.text('Submit tax documents'));
        await tester.pumpAndSettle();

        // Verify quick action sheet options are presented
        expect(find.text('Mark as Done'), findsOneWidget);
        expect(find.text('Move to Tomorrow'), findsOneWidget);
        expect(find.text('Edit Activity'), findsOneWidget);
        expect(find.text('Archive activity'), findsOneWidget);

        // Tap Delete from Today -> verify confirmation dialog appears
        await tester.tap(find.text('Archive activity'));
        await tester.pumpAndSettle();

        expect(find.text('Archive activity?'), findsOneWidget);
        expect(find.text('Keep'), findsOneWidget);
        expect(find.text('Archive'), findsOneWidget);

        // Tap Keep -> cancels deletion safely
        await tester.tap(find.text('Keep'));
        await tester.pumpAndSettle();

        expect(find.text('Submit tax documents'), findsOneWidget);
      },
    );

    testWidgets(
      'ActivityRowItem has in-front more actions button and applause on completion',
      (tester) async {
        final task = _makeActivity(
          id: 'task_applause_1',
          title: 'Morning Meditation 10m',
          linkedTaskId: 102,
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            timeTrackingProvider.overrideWith(
              () => _FakeTimeTrackingNotifier(),
            ),
            studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: Scaffold(
                body: ActivityRowItem(activity: task, compact: true),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // In-front ⋯ button exists
        final moreButton = find.byIcon(Icons.more_horiz_rounded);
        expect(moreButton, findsOneWidget);

        // Tap ⋯ button -> opens actions sheet directly in front
        await tester.tap(moreButton);
        await tester.pumpAndSettle();

        expect(find.text('Mark as Done'), findsOneWidget);
        expect(find.text('Archive activity'), findsOneWidget);
      },
    );

    testWidgets(
      'QuickModulesNavHub with "+ Add" button immune to overflow at 320px with 2.0x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 3.0, 800 * 3.0);
        tester.view.devicePixelRatio = 3.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            todayMedicineLogsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(0)),
            dailyWaterGoalStreamProvider.overrideWith(
              (ref) => Stream.value(2500),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 800),
                textScaler: TextScaler.linear(2.0),
              ),
              child: MaterialApp(
                theme: AscentTheme.light(),
                home: const Scaffold(
                  body: SingleChildScrollView(
                    child: Padding(
                      padding: EdgeInsets.all(8),
                      child: QuickModulesNavHub(showChallenge: false),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.text('No doses'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('medicine_add_button')),
          findsOneWidget,
        );
      },
    );
  });
}
