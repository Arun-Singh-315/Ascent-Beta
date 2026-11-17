import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/features/home/home_screen.dart';
import 'package:ascent/features/home/widgets/home_weather.dart';
import 'package:ascent/features/plans/planning_providers.dart';
import 'package:ascent/core/services/plan_collection_service.dart';

class _FakeTimeTrackingNotifier extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

class _FakeStudyStreakNotifier extends StudyStreakNotifier {
  @override
  StudyStreakStatus build() => StudyStreakCalculator().calculate(
        todaySeconds: 2700, // 45 min focus
        yesterdaySeconds: 2400,
        priorStreakDays: 14,
        historicalLongestStreak: 21,
        historicalShortestStreak: 1,
        now: DateTime(2026, 11, 15, 14, 0),
      );
}

final _testProfile = UserProfile(
  id: 1,
  name: 'Arun',
  targetRole: 'Staff Software Engineer',
  targetCompanies: '["Google"]',
  weeklyHoursAvailable: 20,
  preferredStudyWindow: 'morning',
  skillSelfRatings: '{}',
  dateOfBirth: DateTime(1998, 6, 15),
  createdAt: DateTime(2026, 1, 1),
  updatedAt: DateTime.now(),
  onboardingComplete: true,
  interviewDate: null,
  lastOpenedAt: null,
);

final _sampleThought = Thought(
  id: 1,
  content: '''
- [x] ★ Drink lemon tea & morning hydration
- [ ] Deep focus study session (45m)
- [ ] ★ Work on Ascent feature redesign
- [ ] Evening mindful walk
''',
  mood: 'thought',
  category: 'daily',
  colorHex: '#2F6F6A',
  isPinned: false,
  isArchived: false,
  isCompleted: false,
  createdAt: DateTime(2026, 11, 17, 10, 30),
);

final _sampleActivities = [
  const TodayActivityItem(
    id: 'task_1',
    title: 'Deep System Design & Architecture',
    sourceType: 'task',
    categoryTag: 'Study',
    status: TodayActivityStatus.done,
    elapsedSecondsToday: 2700,
    kind: ActivityKind.duration,
    targetMinutes: 45,
  ),
  const TodayActivityItem(
    id: 'task_2',
    title: 'DSA Tree & Graph Algorithms',
    sourceType: 'task',
    categoryTag: 'Coding',
    status: TodayActivityStatus.done,
    elapsedSecondsToday: 1800,
    kind: ActivityKind.duration,
    targetMinutes: 30,
  ),
  const TodayActivityItem(
    id: 'task_3',
    title: 'Review pull requests & design docs',
    sourceType: 'task',
    categoryTag: 'Work',
    status: TodayActivityStatus.notStarted,
    elapsedSecondsToday: 0,
    kind: ActivityKind.todo,
  ),
  const TodayActivityItem(
    id: 'task_4',
    title: 'Team sync and daily planning',
    sourceType: 'task',
    categoryTag: 'Meeting',
    status: TodayActivityStatus.done,
    elapsedSecondsToday: 0,
    kind: ActivityKind.todo,
  ),
  const TodayActivityItem(
    id: 'task_5',
    title: 'Evening mindful walk & reflection',
    sourceType: 'task',
    categoryTag: 'Health',
    status: TodayActivityStatus.notStarted,
    elapsedSecondsToday: 0,
    kind: ActivityKind.todo,
  ),
];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      'ascent_new_day_shown': '2026-11-15',
      'ascent_daily_briefing_seen_v1': '2026-11-15',
    });
    prefs = await SharedPreferences.getInstance();

    // Seed budget
    await db.into(db.financeBudgetTable).insert(
      FinanceBudgetTableCompanion.insert(
        monthlyLimit: 15000.0,
        dailyLimit: const drift.Value(500.0),
      ),
    );

    // Seed medicine
    final medId = await db.into(db.medicineTable).insert(
      MedicineTableCompanion.insert(
        name: 'Vitamin D3 & Omega',
        dosage: '1 capsule',
        scheduledTimes: '["09:00", "20:00"]',
        startDate: DateTime(2026, 11, 1),
      ),
    );
    await db.into(db.medicineLogTable).insert(
      MedicineLogTableCompanion.insert(
        medicineId: medId,
        dateStr: '2026-11-15',
        timeSlot: '09:00',
        isTaken: const drift.Value(true),
        takenAt: drift.Value(DateTime(2026, 11, 15, 9, 5)),
      ),
    );
    await db.into(db.medicineLogTable).insert(
      MedicineLogTableCompanion.insert(
        medicineId: medId,
        dateStr: '2026-11-15',
        timeSlot: '20:00',
        isTaken: const drift.Value(true),
        takenAt: drift.Value(DateTime(2026, 11, 15, 20, 2)),
      ),
    );
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('Capture Home screen render photo with iOS summary', (tester) async {
    tester.view.physicalSize = const Size(780, 1688); // iPhone 14/15 390x844 logical
    tester.view.devicePixelRatio = 2;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    const outDir =
        '/home/arunsinghvisen/.gemini/antigravity/brain/c4562752-ff66-4729-a56a-7b6c5dbf97f2';
    Directory(outDir).createSync(recursive: true);

    for (final isDark in [false, true]) {
      final repaintKey = GlobalKey();
      final theme = isDark ? AscentTheme.dark() : AscentTheme.light();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
            studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
            currentStreakStreamProvider.overrideWith((ref) => Stream.value(14)),
            todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(1800)),
            dailyWaterGoalStreamProvider.overrideWith((ref) => Stream.value(2500)),
            todayWalkDistanceStreamProvider.overrideWith((ref) => Stream.value(3200.0)),
            todaySpendingStreamProvider.overrideWith((ref) => Stream.value(350.0)),
            currentMonthSpendingStreamProvider.overrideWith((ref) => Stream.value(4200.0)),
            activeMedicinesStreamProvider.overrideWith((ref) => Stream.value([])),
            activeMomentumChallengeStreamProvider.overrideWith((ref) => Stream.value(null)),
            todayMomentumCommitmentsStreamProvider.overrideWith((ref) => Stream.value([])),
            recentThoughtsStreamProvider.overrideWith((ref) => Stream.value(<Thought>[_sampleThought])),
            latestHomeThoughtProvider.overrideWith((ref) => Stream.value(_sampleThought)),
            nextUpcomingReminderProvider.overrideWith((ref) => Stream.value(null)),
            userProfileStreamProvider.overrideWith((ref) => Stream.value(_testProfile)),
            todayFocusTaskProvider.overrideWith((ref) => Future.value(null)),
            homeWeatherProvider.overrideWith((ref) => Future.value({
                  'current': {
                    'temperature_2m': 24.0,
                    'weather_code': 0,
                  },
                })),
            todayActivitiesProvider.overrideWith((ref) => Stream.value(_sampleActivities)),
            planCollectionsProvider.overrideWith((ref) => Stream.value(<PlanCollectionView>[])),
          ],
          child: MaterialApp(
            theme: theme,
            home: RepaintBoundary(
              key: repaintKey,
              child: const Scaffold(
                body: HomeScreen(),
              ),
            ),
          ),
        ),
      );

      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }

      await tester.runAsync(() async {
        final boundary = repaintKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 2.0);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final fileName = isDark ? 'home_ios_pulse_dark.png' : 'home_ios_pulse_light.png';
            final file = File('$outDir/$fileName');
            await file.writeAsBytes(byteData.buffer.asUint8List());
          }
          image.dispose();
        }
      });

      // Scroll down to capture Things Hub & Plans
      final scrollableFinder = find.byType(Scrollable).first;
      await tester.drag(scrollableFinder, const Offset(0, -380));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
      }

      await tester.runAsync(() async {
        final boundary = repaintKey.currentContext?.findRenderObject()
            as RenderRepaintBoundary?;
        if (boundary != null) {
          final image = await boundary.toImage(pixelRatio: 2.0);
          final byteData =
              await image.toByteData(format: ui.ImageByteFormat.png);
          if (byteData != null) {
            final fileName = isDark
                ? 'home_ios_full_dark.png'
                : 'home_ios_full_light.png';
            final file = File('$outDir/$fileName');
            await file.writeAsBytes(byteData.buffer.asUint8List());
          }
          image.dispose();
        }
      });

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    }
  });
}
