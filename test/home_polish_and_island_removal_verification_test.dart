import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/home_screen.dart';
import 'package:ascent/features/home/widgets/activity_composer.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/home_quick_expense_card.dart';
import 'package:ascent/features/home/widgets/home_reveal.dart';
import 'package:ascent/features/money/add_transaction_sheet.dart';
import 'package:ascent/features/settings/settings_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/returning_user_guides.dart';

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
  name: 'Test User',
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

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      ...returningUserGuidePrefs,
      'ascent_day_one_tutorial_v2_dismissed': true,
      'ascent_onboarding_completed_v1': true,
      'ascent_quick_start_v1': true,
      'ascent_daily_briefing_seen_v1': DateTime.now().toIso8601String(),
    });
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  group('Home Quick Expense Card Verification', () {
    for (final isDark in [false, true]) {
      final mode = isDark ? 'Dark' : 'Light';

      testWidgets('Renders default zero state in $mode mode without budget', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              todaySpendingStreamProvider.overrideWith(
                (ref) => Stream.value(0.0),
              ),
              currentMonthSpendingStreamProvider.overrideWith(
                (ref) => Stream.value(0.0),
              ),
              overallBudgetStreamProvider.overrideWith(
                (ref) => Stream.value(null),
              ),
            ],
            child: MaterialApp(
              theme: isDark ? AscentTheme.dark() : AscentTheme.light(),
              home: const Scaffold(body: HomeQuickExpenseCard()),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('Log an expense'), findsOneWidget);
        expect(find.text('Takes five seconds'), findsOneWidget);
      });

      testWidgets('Renders spent amount without budget in $mode mode', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              todaySpendingStreamProvider.overrideWith(
                (ref) => Stream.value(350.0),
              ),
              currentMonthSpendingStreamProvider.overrideWith(
                (ref) => Stream.value(350.0),
              ),
              overallBudgetStreamProvider.overrideWith(
                (ref) => Stream.value(null),
              ),
            ],
            child: MaterialApp(
              theme: isDark ? AscentTheme.dark() : AscentTheme.light(),
              home: const Scaffold(body: HomeQuickExpenseCard()),
            ),
          ),
        );
        await tester.pump();

        expect(find.text('₹350'), findsOneWidget);
        expect(find.text('Spent today'), findsOneWidget);
      });

      testWidgets(
        'Renders "left today" pace when spending is below daily safe pace in $mode mode',
        (tester) async {
          final budget = FinanceBudget(
            id: 1,
            monthlyLimit: 30000.0,
            updatedAt: DateTime.now(),
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                todaySpendingStreamProvider.overrideWith(
                  (ref) => Stream.value(200.0),
                ),
                currentMonthSpendingStreamProvider.overrideWith(
                  (ref) => Stream.value(200.0),
                ),
                overallBudgetStreamProvider.overrideWith(
                  (ref) => Stream.value(budget),
                ),
              ],
              child: MaterialApp(
                theme: isDark ? AscentTheme.dark() : AscentTheme.light(),
                home: const Scaffold(body: HomeQuickExpenseCard()),
              ),
            ),
          );
          await tester.pump();

          expect(find.text('₹200'), findsOneWidget);
          expect(find.textContaining('left today'), findsOneWidget);
        },
      );

      testWidgets(
        'Renders "over today\'s pace" when spending exceeds daily safe pace in $mode mode',
        (tester) async {
          final budget = FinanceBudget(
            id: 1,
            monthlyLimit: 1000.0,
            updatedAt: DateTime.now(),
          );
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                databaseProvider.overrideWithValue(db),
                todaySpendingStreamProvider.overrideWith(
                  (ref) => Stream.value(500.0),
                ),
                currentMonthSpendingStreamProvider.overrideWith(
                  (ref) => Stream.value(900.0),
                ),
                overallBudgetStreamProvider.overrideWith(
                  (ref) => Stream.value(budget),
                ),
              ],
              child: MaterialApp(
                theme: isDark ? AscentTheme.dark() : AscentTheme.light(),
                home: const Scaffold(body: HomeQuickExpenseCard()),
              ),
            ),
          );
          await tester.pump();

          expect(find.text('₹500'), findsOneWidget);
          expect(find.textContaining('over today’s pace'), findsOneWidget);
        },
      );
    }

    testWidgets('Tapping HomeQuickExpenseCard opens AddTransactionSheet', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            todaySpendingStreamProvider.overrideWith(
              (ref) => Stream.value(0.0),
            ),
            currentMonthSpendingStreamProvider.overrideWith(
              (ref) => Stream.value(0.0),
            ),
            overallBudgetStreamProvider.overrideWith(
              (ref) => Stream.value(null),
            ),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(body: HomeQuickExpenseCard()),
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.byType(HomeQuickExpenseCard));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AddTransactionSheet), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets('Satisfies Rule 13 at 320px width and 2.0x text scaling', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 2.0, 700 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final budget = FinanceBudget(
        id: 1,
        monthlyLimit: 10000.0,
        updatedAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            todaySpendingStreamProvider.overrideWith(
              (ref) => Stream.value(450.0),
            ),
            currentMonthSpendingStreamProvider.overrideWith(
              (ref) => Stream.value(450.0),
            ),
            overallBudgetStreamProvider.overrideWith(
              (ref) => Stream.value(budget),
            ),
          ],
          child: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 700),
              textScaler: TextScaler.linear(2.0),
            ),
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(
                body: SingleChildScrollView(child: HomeQuickExpenseCard()),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('₹450'), findsOneWidget);
    });
  });

  group('HomeReveal Reduce Motion Verification', () {
    testWidgets('Renders TweenAnimationBuilder when animations are enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: false),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: HomeReveal(child: Text('Animated Content')),
          ),
        ),
      );
      expect(find.byType(TweenAnimationBuilder<double>), findsOneWidget);
    });

    testWidgets('Skips animation entirely when reduce motion is enabled', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: HomeReveal(child: Text('Direct Content')),
          ),
        ),
      );
      expect(find.byType(TweenAnimationBuilder<double>), findsNothing);
      expect(find.text('Direct Content'), findsOneWidget);
    });
  });

  group('Input Hint Verification', () {
    testWidgets('Things ActivityComposer shows an example hint', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(home: Scaffold(body: ActivityComposer())),
        ),
      );
      await tester.pump();

      expect(find.text('e.g. Gym 7am tomorrow 45m'), findsOneWidget);
    });
  });

  group('Plans Card Home Conditional Verification', () {
    testWidgets(
      'Plans card does not duplicate below Things when Things is visible',
      (tester) async {
        tester.view.physicalSize = const Size(400 * 2.0, 2000 * 2.0);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              timeTrackingProvider.overrideWith(
                () => _FakeTimeTrackingNotifier(),
              ),
              studyStreakProvider.overrideWith(
                () => _FakeStudyStreakNotifier(),
              ),
              userProfileStreamProvider.overrideWith(
                (ref) => Stream.value(_testUserProfile),
              ),
              todaySpendingStreamProvider.overrideWith(
                (ref) => Stream.value(0.0),
              ),
              currentMonthSpendingStreamProvider.overrideWith(
                (ref) => Stream.value(0.0),
              ),
              overallBudgetStreamProvider.overrideWith(
                (ref) => Stream.value(null),
              ),
              recentThoughtsStreamProvider.overrideWith(
                (ref) => Stream.value([]),
              ),
              currentStreakStreamProvider.overrideWith(
                (ref) => Stream.value(0),
              ),
              todayWaterMlStreamProvider.overrideWith((ref) => Stream.value(0)),
              dailyWaterGoalStreamProvider.overrideWith(
                (ref) => Stream.value(2000),
              ),
              todayWalkDistanceStreamProvider.overrideWith(
                (ref) => Stream.value(0.0),
              ),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const HomeScreen(),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 200));

        // Standalone Plans card is NOT rendered below Things
        expect(find.byKey(const ValueKey('home_plans_big_card')), findsNothing);

        // Things Hub card IS rendered
        expect(find.byType(ActivityHubCard), findsOneWidget);

        // And Things Hub card contains the "Plans" tab
        expect(find.text('Plans'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });

  group('Settings Screen Island Removal Verification', () {
    testWidgets('Settings screen contains no Dynamic Island reference or row', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          child: const MaterialApp(home: SettingsScreen()),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(
        find.textContaining('Dynamic Island', findRichText: true),
        findsNothing,
      );
      expect(find.textContaining('Island', findRichText: true), findsNothing);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  });
}
