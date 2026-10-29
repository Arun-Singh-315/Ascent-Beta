import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/providers/daily_briefing_provider.dart';
import 'package:ascent/features/chai_break/chai_break_provider.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:ascent/features/home/widgets/ascent_dynamic_island.dart';

class _CustomTimeTrackingNotifier extends TimeTrackingNotifier {
  _CustomTimeTrackingNotifier([this._state = const TimeTrackingState()]);
  final TimeTrackingState _state;

  @override
  TimeTrackingState build() => _state;
}

class _CustomChaiNotifier extends ChaiBreakNotifier {
  _CustomChaiNotifier(this._state);
  final ChaiBreakState _state;

  @override
  ChaiBreakState build() => _state;
}

const _kDefaultBriefing = DailyBriefing(
  completedYesterday: 0,
  plannedYesterday: 0,
  finishedPlannedYesterday: 0,
  trackedMinutesYesterday: 0,
  dueToday: 0,
  overdue: 0,
  unscheduled: 0,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildIslandTestWidget({
    List<dynamic> overrides = const [],
    TimeTrackingState? timeState,
    ChaiBreakState? chaiState,
    DailyBriefing? briefing,
    Reminder? upcomingReminder,
    int? waterMl,
    int? thoughtCount,
    bool initiallyExpanded = false,
    double textScale = 1.0,
  }) {
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        chaiBreakProvider.overrideWith(
          () => _CustomChaiNotifier(
            chaiState ?? const ChaiBreakState(isRunning: false),
          ),
        ),
        timeTrackingProvider.overrideWith(
          () => _CustomTimeTrackingNotifier(
            timeState ?? const TimeTrackingState(),
          ),
        ),
        dailyBriefingProvider.overrideWith(
          (ref, day) async => briefing ?? _kDefaultBriefing,
        ),
        todayWaterMlStreamProvider.overrideWith(
          (ref) => Stream.value(waterMl ?? 0),
        ),
        todayThoughtsCountStreamProvider.overrideWith(
          (ref) => Stream.value(thoughtCount ?? 0),
        ),
        activePromisesStreamProvider.overrideWith(
          (ref) => Stream.value(const []),
        ),
        nextUpcomingReminderProvider.overrideWith(
          (ref) => Stream.value(upcomingReminder),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
          child: Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: AscentDynamicIsland(
                  initiallyExpanded: initiallyExpanded,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  group('AscentDynamicIsland Multi-App & Ambient States', () {
    testWidgets('Compact ambient state renders Apple micro-colors and expand trigger', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildIslandTestWidget(
          waterMl: 1250,
          thoughtCount: 4,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const ValueKey('dynamic_island_ambient_compact')), findsOneWidget);
      expect(find.textContaining('1250ml'), findsOneWidget);
      expect(find.text('4'), findsOneWidget);
    });

    testWidgets('Tapping expands island to show Apple micro-color pods and All Apps drawer', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildIslandTestWidget(
          waterMl: 500,
          thoughtCount: 2,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      // Tap to expand
      await tester.tap(find.byKey(const ValueKey('dynamic_island_ambient_compact')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      // Verify header and 4 Apple micro-color pods
      expect(find.text('Ascent Dynamic Island'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
      expect(find.text('Thoughts'), findsOneWidget);
      expect(find.text('Promises'), findsOneWidget);
      expect(find.text('Vault'), findsOneWidget);
      expect(find.text('+250ml'), findsOneWidget);

      // Verify "View All Tools & Apps" drawer toggle
      expect(find.text('View All Tools & Apps'), findsOneWidget);

      // Tap to reveal full app suite
      await tester.tap(find.text('View All Tools & Apps'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('Focus Timer'), findsOneWidget);
      expect(find.text('Chai Break'), findsOneWidget);
      expect(find.text('Today Tasks'), findsOneWidget);
      expect(find.text('Reminders'), findsOneWidget);
      expect(find.text('Challenges'), findsOneWidget);
    });

    testWidgets('Quick +250ml action logs water intake', (
      tester,
    ) async {
      await tester.pumpWidget(
        buildIslandTestWidget(
          initiallyExpanded: true,
          waterMl: 750,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('+250ml'), findsOneWidget);
      await tester.tap(find.text('+250ml'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Verify water record was inserted in database
      final todayLogs = await db.select(db.waterLogTable).get();
      expect(todayLogs.length, 1);
      expect(todayLogs.first.amountMl, 250);
    });
  });

  group('AscentDynamicIsland Live Activities Integration', () {
    testWidgets('Active focus timer takes priority and shows live running state', (
      tester,
    ) async {
      final runningSession = TimeSession(
        id: 1,
        label: 'Flutter Architecture',
        activityType: 'focus',
        categoryId: 1,
        startedAt: DateTime.now().subtract(const Duration(minutes: 15)),
        pausedIntervals: '[]',
        status: 'running',
        durationSeconds: 900,
        activityRefType: 'none',
        createdAt: DateTime.now(),
      );

      final runningTimerState = TimeTrackingState(
        activeSession: runningSession,
        elapsedSeconds: 900,
        isRunning: true,
      );

      await tester.pumpWidget(
        buildIslandTestWidget(
          timeState: runningTimerState,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const ValueKey('dynamic_island_focus_compact')), findsOneWidget);
      expect(find.textContaining('Flutter Architecture'), findsOneWidget);
      expect(find.textContaining('15:00'), findsOneWidget);

      // Tap to expand focus controls
      await tester.tap(find.byKey(const ValueKey('dynamic_island_focus_compact')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('ACTIVE FOCUS'), findsOneWidget);
      expect(find.text('Pause'), findsOneWidget);
    });

    testWidgets('Chai Break audio takes priority when active', (
      tester,
    ) async {
      const activeAudioState = ChaiBreakState(
        isRunning: true,
        isAudioMuted: false,
        selectedSoundscape: SoundscapePreset.tapriCafeRain,
      );

      await tester.pumpWidget(
        buildIslandTestWidget(
          chaiState: activeAudioState,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const ValueKey('dynamic_island_audio_compact')), findsOneWidget);
      expect(find.text('Tapri Cafe & Rain'), findsOneWidget);

      // Tap to expand audio controls
      await tester.tap(find.byKey(const ValueKey('dynamic_island_audio_compact')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('CHAI BREAK AUDIO'), findsOneWidget);
      expect(find.text('Pause Sanctuary'), findsOneWidget);
    });

    testWidgets('Yesterday leftover tasks count shows alert banner in compact and expanded', (
      tester,
    ) async {
      const briefingData = DailyBriefing(
        completedYesterday: 1,
        plannedYesterday: 4,
        finishedPlannedYesterday: 1,
        trackedMinutesYesterday: 45,
        dueToday: 2,
        overdue: 3,
        unscheduled: 1,
      );

      await tester.pumpWidget(
        buildIslandTestWidget(
          briefing: briefingData,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byKey(const ValueKey('dynamic_island_overdue_compact')), findsOneWidget);
      expect(find.textContaining('3 leftover tasks from yesterday'), findsOneWidget);
      expect(find.text('Review →'), findsOneWidget);
    });

    testWidgets('Upcoming scheduled reminder shows live activity banner when expanded', (
      tester,
    ) async {
      final scheduledReminder = Reminder(
        id: 42,
        title: 'Team Architecture Sync',
        scheduledAt: DateTime.now().add(const Duration(minutes: 30)),
        isActive: true,
        alarmEnabled: true,
        alertSyncPending: false,
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        buildIslandTestWidget(
          initiallyExpanded: true,
          upcomingReminder: scheduledReminder,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.textContaining('Next: Team Architecture Sync'), findsOneWidget);
      expect(find.text('View →'), findsOneWidget);
    });
  });

  group('AscentDynamicIsland Defensive Layout & Overflow Immunity', () {
    testWidgets('Zero overflow at 320px width with 2.0x text scale (Compact & Expanded)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        buildIslandTestWidget(
          initiallyExpanded: true,
          textScale: 2.0,
          waterMl: 1500,
          thoughtCount: 8,
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(tester.takeException(), isNull);
      expect(find.text('Ascent Dynamic Island'), findsOneWidget);
      expect(find.text('Water'), findsOneWidget);
    });
  });
}
