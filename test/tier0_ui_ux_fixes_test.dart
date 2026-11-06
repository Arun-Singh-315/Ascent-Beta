import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/daily_briefing_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_models.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/home/widgets/daily_welcome_dialog.dart';
import 'package:ascent/features/home/widgets/day_one_tutorial_card.dart';
import 'package:ascent/features/home/widgets/study_streak_meter_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/core/providers/settings_provider.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('Tier 0: DailyWelcomeDialog Pager and Honest Numbers', () {
    testWidgets('footer shows interactive Next button and no static Swipe label', (tester) async {
      final today = briefingDay(DateTime.now());
      final briefing = DailyBriefing(
        completedYesterday: 0,
        plannedYesterday: 0,
        finishedPlannedYesterday: 0,
        trackedMinutesYesterday: 0,
        dueToday: 0,
        overdue: 0,
        unscheduled: 0,
      );

      final container = ProviderContainer(
        overrides: [
          dailyBriefingProvider(today).overrideWithValue(AsyncValue.data(briefing)),
        ],
      );

      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Builder(
              builder: (ctx) => Scaffold(
                body: DailyWelcomeDialog(
                  day: today,
                  name: 'Alex',
                  host: ctx,
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Confirm 'Swipe' label is removed
      expect(find.text('Swipe'), findsNothing);

      // Confirm interactive 'Next' button is present
      final nextButton = find.widgetWithText(TextButton, 'Next');
      expect(nextButton, findsOneWidget);

      // Confirm Honest Numbers: does not display raw '0m' or '0' counters in pulse items
      expect(find.text('0m'), findsNothing);
      expect(find.text('0'), findsNothing);

      // Tap Next button to advance pager
      await tester.tap(nextButton);
      await tester.pumpAndSettle();

      // On Page 2, Next button is still present
      expect(find.widgetWithText(TextButton, 'Next'), findsOneWidget);

      // Tap Next button to advance to Page 3 (Launchpad)
      await tester.tap(find.widgetWithText(TextButton, 'Next'));
      await tester.pumpAndSettle();

      // On Page 3 (final page), 'Next' is replaced by 'Done'
      expect(find.widgetWithText(TextButton, 'Next'), findsNothing);
      expect(find.widgetWithText(TextButton, 'Done'), findsOneWidget);
    });
  });

  group('Tier 0: DayOneTutorial emoji purge', () {
    testWidgets('DayOneTutorialCard buttons do not contain emojis', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: DayOneTutorialCard(userName: 'Alex'),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.textContaining('🚀'), findsNothing);
      expect(find.textContaining('👍'), findsNothing);
      expect(find.text('Add First Activity'), findsOneWidget);
      expect(find.text('Got it'), findsOneWidget);
    });
  });

  group('Tier 0: ActivityRowItem Dismissible & Actions', () {
    testWidgets('provides both background and secondaryBackground with zero reveal glitch', (tester) async {
      final item = TodayActivityItem(
        id: 'todo-1',
        title: 'Review System Architecture',
        status: TodayActivityStatus.notStarted,
        kind: ActivityKind.todo,
        sourceType: 'task',
        priority: 'high',
        categoryTag: 'work',
        elapsedSecondsToday: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: ActivityRowItem(
                activity: item,
                compact: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final dismissibleFinder = find.byType(Dismissible);
      expect(dismissibleFinder, findsOneWidget);

      final dismissible = tester.widget<Dismissible>(dismissibleFinder);
      expect(dismissible.background, isNotNull);
      expect(dismissible.secondaryBackground, isNotNull);
    });

    testWidgets('untimed to-dos do not display play/pause timer buttons', (tester) async {
      final untimedTodo = TodayActivityItem(
        id: 'todo-untimed',
        title: 'Buy Groceries',
        status: TodayActivityStatus.notStarted,
        kind: ActivityKind.todo,
        sourceType: 'task',
        priority: 'normal',
        targetMinutes: null,
        categoryTag: 'personal',
        elapsedSecondsToday: 0,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: ActivityRowItem(
                activity: untimedTodo,
                compact: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Untimed to-do has a check target, NOT a play button
      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byIcon(Icons.timer_rounded), findsNothing);
    });
  });

  group('Tier 0: StudyStreakMeterCard Honest Numbers & 320px Overflow Immunity', () {
    testWidgets('displays honest invitation at 0 streak without longest: 0d', (tester) async {
      final zeroStreak = StudyStreakStatus(
        todaySeconds: 0,
        targetSeconds: 3600,
        displayStreakDays: 0,
        longestStreakDays: 0,
        isTodaySecured: false,
        isRescueMode: false,
        isUrgent: false,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: StudyStreakMeterCard(status: zeroStreak),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Start a streak today'), findsOneWidget);
      expect(find.textContaining('0 Day Streak'), findsNothing);
      expect(find.textContaining('Longest: 0d'), findsNothing);
    });

    testWidgets('320px width at 2.0x font scaling has zero RenderFlex overflow', (tester) async {
      tester.view.physicalSize = const Size(320 * 2.0, 640 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      final activeStreak = StudyStreakStatus(
        todaySeconds: 2700,
        targetSeconds: 3600,
        displayStreakDays: 14,
        longestStreakDays: 21,
        isTodaySecured: false,
        isRescueMode: true,
        isUrgent: true,
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(
                textScaler: TextScaler.linear(2.0),
              ),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: StudyStreakMeterCard(status: activeStreak),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
    });
  });
}
