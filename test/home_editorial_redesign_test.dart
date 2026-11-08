import 'package:ascent/features/home/widgets/day_one_tutorial_card.dart';
import 'package:ascent/features/home/widgets/smart_catch_up_banner.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ascent/features/home/widgets/home_life_shelf.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/home_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
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

final _testUserProfile = UserProfile(
  id: 1,
  name: 'Arun Singh',
  targetRole: 'Software Engineer',
  targetCompanies: '["Google"]',
  weeklyHoursAvailable: 10,
  preferredStudyWindow: 'morning',
  skillSelfRatings: '{}',
  createdAt: DateTime.now(),
  updatedAt: DateTime.now(),
  onboardingComplete: true,
  interviewDate: null,
  lastOpenedAt: null,
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SharedPreferences prefs;

  setUpAll(() async {
    await (FontLoader(
      'AscentZodiacSymbols',
    )..addFont(rootBundle.load('assets/fonts/AscentZodiacSymbols.ttf'))).load();
    GoogleFonts.config.allowRuntimeFetching = false;
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      'ascent_day_one_tutorial_v2_dismissed': true,
      'ascent_daily_briefing_seen_v1': DateTime.now().toIso8601String(),
      'ascent_daily_briefing_auto_open_v1': false,
    });
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildApp({
    Widget? home,
    UserProfile? profile,
    List<Reminder> reminders = const [],
    List<dynamic> extraOverrides = const [],
    bool dark = false,
    double scale = 1,
    GlobalKey? capture,
  }) {
    final effectiveProfile = profile ?? _testUserProfile;
    return ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeTrackingProvider.overrideWith(() => _FakeTimeTrackingNotifier()),
        studyStreakProvider.overrideWith(() => _FakeStudyStreakNotifier()),
        userProfileStreamProvider.overrideWith(
          (ref) => Stream.value(effectiveProfile),
        ),
        currentStreakStreamProvider.overrideWith((ref) => Stream.value(3)),
        dailyWaterGoalStreamProvider.overrideWith((ref) => Stream.value(2000)),
        todayWalkDistanceStreamProvider.overrideWith(
          (ref) => Stream.value(1500.0),
        ),
        todaySpendingStreamProvider.overrideWith((ref) => Stream.value(200.0)),
        overallBudgetStreamProvider.overrideWith((ref) => Stream.value(null)),
        activeMedicinesStreamProvider.overrideWith((ref) => Stream.value([])),
        todayWaterLogsStreamProvider.overrideWith(
          (ref) => const Stream.empty(),
        ),
        todayMedicineLogsStreamProvider.overrideWith((ref) => Stream.value([])),
        activeMomentumChallengeStreamProvider.overrideWith(
          (ref) => Stream.value(null),
        ),
        todayMomentumCommitmentsStreamProvider.overrideWith(
          (ref) => Stream.value([]),
        ),
        recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([])),
        nextUpcomingReminderProvider.overrideWith((ref) => Stream.value(null)),
        todayFocusTaskProvider.overrideWith((ref) => Future.value(null)),
        allRemindersProvider.overrideWith((ref) => Stream.value(reminders)),
        ...extraOverrides,
      ],
      child: RepaintBoundary(
        key: capture,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: dark ? AscentTheme.dark() : AscentTheme.light(),
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: home ?? const HomeScreen(),
        ),
      ),
    );
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  }

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  const reviewOutput = String.fromEnvironment(
    'HOME_REVIEW_OUTPUT',
    defaultValue: '/tmp/ascent-home-review',
  );
  Future<void> capture(WidgetTester tester, GlobalKey key, String name) async {
    await tester.runAsync(() async {
      final image =
          await (key.currentContext!.findRenderObject()
                  as RenderRepaintBoundary)
              .toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await Directory(reviewOutput).create(recursive: true);
      await File(
        '$reviewOutput/$name.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  testWidgets(
    'Home hierarchy and empty states fit mobile without fake progress',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final key = GlobalKey();
      await tester.pumpWidget(
        buildApp(
          capture: key,
          extraOverrides: [
            todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(0)),
          ],
        ),
      );
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(find.text('TODAY’S EXECUTION'), findsNothing);
      expect(find.byType(LinearProgressIndicator), findsNothing);
      expect(
        tester.getTopLeft(find.byType(ActivityHubCard)).dy,
        greaterThan(tester.getTopLeft(find.byType(ThoughtWallHomePreview)).dy),
      );
      await capture(tester, key, 'home-light-empty');
      await tester.scrollUntilVisible(
        find.byType(HomeLifeShelf),
        280,
        scrollable: find.byType(Scrollable).first,
      );
      await settle(tester);
      expect(
        find.byKey(const ValueKey('home_routine_medicine')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('home_routine_momentum')), findsOneWidget);
      final waterCard = find.byKey(const ValueKey('home_routine_hydration'));
      final initialX = tester.getTopLeft(waterCard).dx;
      await tester.drag(waterCard, const Offset(-220, 0));
      await settle(tester);
      expect(tester.takeException(), isNull);
      expect(tester.getTopLeft(waterCard).dx, closeTo(initialX, 1));
      await capture(tester, key, 'home-life-shelf');
      await tester.drag(waterCard, const Offset(300, 0));
      await settle(tester);
      expect(tester.getTopLeft(waterCard).dx, closeTo(initialX, 1));
      await unmount(tester);
    },
  );

  testWidgets('Populated home and large text remain usable in both themes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.runAsync(
      () => db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Make things that feel like you.',
        ),
      ),
    );
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        tester.view.physicalSize = Size(scale == 1 ? 390 : 320, 844);
        final key = GlobalKey();
        await tester.pumpWidget(
          buildApp(
            profile: _testUserProfile.copyWith(
              dateOfBirth: drift.Value(DateTime(1998, 6, 10)),
            ),
            reminders: [
              Reminder(
                id: 73,
                title: 'Evening supplements',
                scheduledAt: DateTime.now().add(const Duration(hours: 2)),
                alarmEnabled: false,
                alertSyncPending: false,
                isActive: true,
                createdAt: DateTime.now(),
              ),
            ],
            capture: key,
            dark: dark,
            scale: scale,
            extraOverrides: [
              todayActivitiesProvider.overrideWith(
                (ref) => Stream.value(const [
                  TodayActivityItem(
                    id: 'sample-1',
                    title: 'Read a chapter of Atomic Habits',
                    sourceType: 'custom',
                    status: TodayActivityStatus.notStarted,
                    elapsedSecondsToday: 0,
                    categoryTag: 'Personal',
                  ),
                  TodayActivityItem(
                    id: 'sample-2',
                    title: 'Prepare the portfolio presentation',
                    sourceType: 'custom',
                    status: TodayActivityStatus.notStarted,
                    elapsedSecondsToday: 0,
                    categoryTag: 'Work',
                  ),
                ]),
              ),
            ],
          ),
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        await capture(tester, key, 'home-${dark ? 'dark' : 'light'}-$scale');
        if (scale == 1) {
          await tester.scrollUntilVisible(
            find.descendant(
              of: find.byType(ActivityHubCard),
              matching: find.text('Done'),
            ),
            200,
            scrollable: find.byType(Scrollable).first,
          );
          await tester.ensureVisible(
            find.descendant(
              of: find.byType(ActivityHubCard),
              matching: find.text('Done'),
            ),
          );
          await tester.pumpAndSettle();
          await tester.tap(
            find.descendant(
              of: find.byType(ActivityHubCard),
              matching: find.text('Done'),
            ),
          );
          await settle(tester);
          expect(
            find.byKey(const ValueKey('activity_quick_input')),
            findsNothing,
          );
          expect(find.text('Read a chapter of Atomic Habits'), findsNothing);
          await tester.tap(
            find.descendant(
              of: find.byType(ActivityHubCard),
              matching: find.text('Plans'),
            ),
          );
          await settle(tester);
          expect(
            find.byKey(const ValueKey('activity_quick_input')),
            findsNothing,
          );
          await tester.tap(
            find.descendant(
              of: find.byType(ActivityHubCard),
              matching: find.text('Today'),
            ),
          );
          await settle(tester);
          expect(find.text('Read a chapter of Atomic Habits'), findsOneWidget);
        }
        await tester.scrollUntilVisible(
          find.byType(HomeLifeShelf),
          280,
          scrollable: find.byType(Scrollable).first,
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        await capture(tester, key, 'life-${dark ? 'dark' : 'light'}-$scale');
        await unmount(tester);
      }
    }
  });
  testWidgets('First Home opens without blocking welcome or catch-up dialogs', (
    tester,
  ) async {
    await prefs.setBool(DayOneTutorialDialog.prefKey, false);
    await tester.pumpWidget(buildApp());
    await settle(tester);
    expect(find.byType(DayOneTutorialDialog), findsNothing);
    expect(find.byType(Dialog), findsNothing);
    expect(find.byType(SmartCatchUpBanner), findsNothing);
    await tester.runAsync(
      () async => expect(await db.select(db.taskTable).get(), isEmpty),
    );
    expect(tester.takeException(), isNull);
    await unmount(tester);
  });
}
