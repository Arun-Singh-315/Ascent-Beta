import 'dart:async';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/today/things_hub_screen.dart';
import 'package:ascent/features/today/widgets/things_interactive_card.dart';
import 'package:ascent/shared/widgets/glass_chip.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

TodayActivityItem makeActivity({
  required String id,
  required String title,
  String? notes,
  ActivityKind kind = ActivityKind.todo,
  TodayActivityStatus status = TodayActivityStatus.notStarted,
  int? targetMinutes,
  String sourceType = 'task',
  String priority = 'normal',
  int? linkedTaskId,
}) =>
    TodayActivityItem(
      id: id,
      title: title,
      notes: notes,
      kind: kind,
      status: status,
      sourceType: sourceType,
      categoryTag: 'Task',
      elapsedSecondsToday: 0,
      targetMinutes: targetMinutes,
      priority: priority,
      linkedTaskId: linkedTaskId,
    );

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

  group('Things Hub Ground Border Style & UX Revamp', () {
    testWidgets('ThingsInteractiveCard renders single ground border enclosure with no nested cards', (
      tester,
    ) async {
      final activity = makeActivity(
        id: 'act_ground_1',
        title: 'Review production pull request',
        linkedTaskId: 10,
        priority: 'high',
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
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
              body: Padding(
                padding: const EdgeInsets.all(16),
                child: ThingsInteractiveCard(activity: activity),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify ground ActivityRowItem is rendered with ground style (no inner border/card)
      final rowFinder = find.byType(ActivityRowItem);
      expect(rowFinder, findsOneWidget);
      final rowWidget = tester.widget<ActivityRowItem>(rowFinder);
      expect(rowWidget.ground, isTrue);

      // Verify title is rendered prominently
      expect(find.text('Review production pull request'), findsOneWidget);

      // Verify Blueprint button exists
      expect(find.text('Blueprint'), findsOneWidget);

      // Tap Blueprint button to expand story micro-steps inline
      await tester.tap(find.text('Blueprint'));
      await tester.pumpAndSettle();

      expect(find.text('Hide'), findsOneWidget);
      expect(find.textContaining('Story Micro-Steps'), findsOneWidget);
    });

    testWidgets('ThingsHubScreen has zero horizontal scrolls and supports expand/collapse filter lenses', (
      tester,
    ) async {
      final task1 = makeActivity(
        id: 'task_1',
        title: 'Buy fresh coffee beans',
      );
      final task2 = makeActivity(
        id: 'task_2',
        title: 'System architecture deep dive',
        kind: ActivityKind.duration,
        targetMinutes: 45,
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
          studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
          todayActivitiesProvider.overrideWith(
            (ref) => Stream.value([task1, task2]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const ThingsHubScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure NO horizontal SingleChildScrollView exists anywhere on the screen
      final horizontalScrollFinder = find.byWidgetPredicate(
        (w) => w is SingleChildScrollView && w.scrollDirection == Axis.horizontal,
      );
      expect(horizontalScrollFinder, findsNothing);

      // Verify "More lenses" toggle exists (lenses start collapsed to prevent clutter)
      final toggleFinder = find.byKey(const ValueKey('things_hub_toggle_lenses'));
      expect(toggleFinder, findsOneWidget);
      expect(find.text('More lenses'), findsOneWidget);
      expect(find.widgetWithText(GlassChip, '⚡ Quick Wins'), findsNothing);

      // Tap "More lenses" to expand cognitive lenses
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(find.text('Less'), findsOneWidget);
      expect(find.widgetWithText(GlassChip, '⚡ Quick Wins'), findsOneWidget);

      // Tap "Less" to re-collapse
      await tester.tap(toggleFinder);
      await tester.pumpAndSettle();

      expect(find.text('More lenses'), findsOneWidget);
      expect(find.widgetWithText(GlassChip, '⚡ Quick Wins'), findsNothing);
    });

    testWidgets('ThingsHubScreen arranges activities into ground sections with counts and collapse toggles', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(400 * 3, 1200 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final activeTimer = makeActivity(
        id: 'active_1',
        title: 'Ongoing writing session',
        kind: ActivityKind.duration,
        status: TodayActivityStatus.inProgress,
      );
      final attentionTask = makeActivity(
        id: 'attention_1',
        title: 'Urgent tax submission',
        priority: 'high',
      );
      final nextTask = makeActivity(
        id: 'next_1',
        title: 'Plan weekend trip',
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
          studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
          todayActivitiesProvider.overrideWith(
            (ref) => Stream.value([activeTimer, attentionTask, nextTask]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const ThingsHubScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify arranged ground section headers exist with counts
      expect(find.text('In progress · 1'), findsOneWidget);
      expect(find.text('Needs attention · 1'), findsOneWidget);
      expect(find.text('Next · 1'), findsOneWidget);

      // Verify tasks are visible
      expect(find.text('Ongoing writing session'), findsOneWidget);
      expect(find.text('Urgent tax submission'), findsOneWidget);
      expect(find.text('Plan weekend trip'), findsOneWidget);

      // Tap "Next" header to collapse section
      await tester.tap(find.text('Next · 1'));
      await tester.pumpAndSettle();

      // Plan weekend trip is collapsed
      expect(find.text('Plan weekend trip'), findsNothing);

      // Tap "Next" header again to expand section
      await tester.tap(find.text('Next · 1'));
      await tester.pumpAndSettle();

      expect(find.text('Plan weekend trip'), findsOneWidget);
    });

    testWidgets('Things Hub Ground components immune to overflow at 320px with 2.0x text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 3, 800 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final task = makeActivity(
        id: 'extreme_task',
        title: 'An extremely long task title describing a complex end to end workflow that tests multi-line wrapping and responsiveness',
        priority: 'high',
        targetMinutes: 90,
      );

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
          studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
          todayActivitiesProvider.overrideWith((ref) => Stream.value([task])),
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
              theme: AscentTheme.dark(),
              home: const ThingsHubScreen(),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
