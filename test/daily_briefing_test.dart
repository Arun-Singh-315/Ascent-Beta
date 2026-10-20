import 'dart:async';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/daily_briefing_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/daily_briefing_card.dart';
import 'package:ascent/features/home/home_screen.dart';
import 'package:ascent/features/today/add_activity_sheet.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final day = DateTime(2026, 10, 20);
  late AppDatabase db;
  late SharedPreferences prefs;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() async => db.close());

  test(
    'briefing respects calendar boundaries and actual completion dates',
    () async {
      final yesterday = DateTime(2026, 10, 19);
      for (final entry in [
        ('Yesterday done', yesterday, yesterday),
        ('Yesterday unfinished', yesterday, null),
        ('Finished ahead of plan', yesterday, DateTime(2026, 10, 18)),
        ('Old task finished yesterday', DateTime(2026, 10, 18), yesterday),
        ('Today pending', day, null),
        ('No date', null, null),
        ('Finished at midnight today', yesterday, day),
        ('Future', DateTime(2026, 10, 21), null),
      ]) {
        await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: entry.$1,
            plannedDate: drift.Value(entry.$2),
            actualCompletedDate: drift.Value(entry.$3),
          ),
        );
      }
      final tasks = await db.taskDao.watchAllTasks().first;
      final summary = DailyBriefing.fromRecords(
        day: day,
        tasks: tasks,
        sessions: [],
      );
      expect(summary.completedYesterday, 2);
      expect(summary.plannedYesterday, 4);
      expect(summary.finishedPlannedYesterday, 2);
      expect(summary.overdue, 1);
      expect(summary.dueToday, 1);
      expect(summary.unscheduled, 1);
      expect(summary.nextTask, 'Today pending');
      expect(summary.encouragement, contains('overdue'));
    },
  );

  test('briefing updates after a task is added', () async {
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(db)],
    );
    final updated = Completer<DailyBriefing>();
    final subscription = container.listen(dailyBriefingProvider(day), (
      _,
      next,
    ) {
      if (next.value?.dueToday == 1 && !updated.isCompleted) {
        updated.complete(next.value!);
      }
    });
    await container.read(dailyBriefingProvider(day).future);
    await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Small next step',
        plannedDate: drift.Value(day),
      ),
    );
    final result = await updated.future.timeout(const Duration(seconds: 5));
    expect(result.nextTask, 'Small next step');
    subscription.close();
    container.dispose();
  });

  testWidgets('opens once per local day and can be dismissed', (tester) async {
    await prefs.setBool('ascent_day_one_tutorial_v2_dismissed', true);
    final now = DateTime.now();
    final profile = UserProfile(
      id: 1,
      name: 'Arun',
      targetRole: 'Engineer',
      targetCompanies: '[]',
      weeklyHoursAvailable: 10,
      preferredStudyWindow: 'morning',
      skillSelfRatings: '{}',
      createdAt: now,
      updatedAt: now,
      onboardingComplete: true,
    );
    Widget harness(int visit) => ProviderScope(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        userProfileStreamProvider.overrideWith((ref) => Stream.value(profile)),
      ],
      child: MaterialApp(
        theme: AscentTheme.light(),
        home: HomeScreen(
          key: ValueKey(visit),
          notificationUri: Uri.parse('/home'),
        ),
      ),
    );
    await tester.pumpWidget(harness(1));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Dismiss daily briefing'), findsOneWidget);
    expect(
      prefs.getString('ascent_daily_briefing_seen_v1'),
      briefingDay(now).toIso8601String(),
    );
    await tester.tap(find.byTooltip('Dismiss daily briefing'));
    await tester.pumpAndSettle();
    await tester.pumpWidget(harness(2));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Dismiss daily briefing'), findsNothing);
    await prefs.setString(
      'ascent_daily_briefing_seen_v1',
      DateTime(now.year, now.month, now.day - 1).toIso8601String(),
    );
    await tester.pumpWidget(harness(3));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Dismiss daily briefing'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    await tester.pump(Duration.zero);
  });

  testWidgets(
    'automatic welcome can be disabled without hiding Home check-in',
    (tester) async {
      await prefs.setBool('ascent_quick_start_v1', true);
      await prefs.setBool(dailyBriefingAutoOpenKey, false);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const HomeScreen(),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
      expect(find.byTooltip('Dismiss daily briefing'), findsNothing);
      await tester.ensureVisible(find.text('Open daily check-in'));
      await tester.tap(find.text('Open daily check-in'));
      await tester.pumpAndSettle();
      final toggle = find.byType(SwitchListTile);
      await tester.ensureVisible(toggle);
      await tester.tap(toggle);
      await tester.pumpAndSettle();
      expect(prefs.getBool(dailyBriefingAutoOpenKey), true);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    },
  );

  test('empty records do not imply failure or fabricate progress', () {
    final summary = DailyBriefing.fromRecords(
      day: day,
      tasks: [],
      sessions: [],
    );
    expect(summary.yesterdaySummary, contains('recorded'));
    expect(summary.yesterdaySummary, isNot(contains('failed')));
    expect(summary.nextTask, isNull);
  });

  test('tracked time excludes discarded and other-day sessions', () {
    TimeSession session(int id, String status, DateTime start) => TimeSession(
      id: id,
      label: 'Work',
      categoryId: 1,
      activityType: 'custom',
      startedAt: start,
      pausedIntervals: '[]',
      status: status,
      durationSeconds: 150,
      activityRefType: 'custom',
      createdAt: start,
    );
    final yesterday = DateTime(2026, 10, 19, 12);
    final summary = DailyBriefing.fromRecords(
      day: day,
      tasks: [],
      sessions: [
        session(1, 'completed', yesterday),
        session(2, 'paused', yesterday),
        session(3, 'discarded', yesterday),
        session(4, 'completed', day),
      ],
    );
    expect(summary.trackedMinutesYesterday, 5);
  });

  for (final scale in [1.0, 2.0]) {
    testWidgets('briefing actions work on a narrow screen at $scale text', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 780);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: SingleChildScrollView(child: DailyBriefingCard(day: day)),
            ),
          ),
          GoRoute(
            path: '/thought-wall',
            builder: (_, _) =>
                const Scaffold(body: Text('Thought destination')),
          ),
          GoRoute(
            path: '/ai-assistant',
            builder: (_, state) =>
                Scaffold(body: Text(state.uri.queryParameters['prompt'] ?? 'Riya destination')),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp.router(
            theme: AscentTheme.light(),
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Plan one small task'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Open daily check-in'));
      await tester.tap(find.text('Open daily check-in'));
      await tester.pumpAndSettle();
      final originalOnError = FlutterError.onError;
      FlutterError.onError = (details) {
        FlutterError.dumpErrorToConsole(details);
        originalOnError?.call(details);
      };
      final add = find.text('Plan one small task').last;
      await tester.ensureVisible(add);
      await tester.tap(add);
      await tester.pumpAndSettle();
      FlutterError.onError = originalOnError;
      expect(find.byType(AddActivitySheet), findsOneWidget);
      expect(tester.takeException(), isNull);
      Navigator.of(tester.element(find.byType(AddActivitySheet))).pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Open daily check-in'));
      await tester.tap(find.text('Open daily check-in'));
      await tester.pumpAndSettle();
      final action = find.text('Capture a thought').last;
      await tester.ensureVisible(action);
      await tester.tap(action);
      await tester.pumpAndSettle();
      expect(find.text('Thought destination'), findsOneWidget);
      expect(tester.takeException(), isNull);
      router.pop();
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.text('Ask Riya'));
      await tester.tap(find.text('Ask Riya'));
      await tester.pumpAndSettle();
      expect(
        find.text('Riya destination'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });
  }
}
