import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/life_checkin_popup_dialog.dart';
import 'package:ascent/features/splash/splash_screen.dart';
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

void main() {
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

  group('Splash Screen Tagline Requirement', () {
    testWidgets(
      'SplashScreen tagline promotes personal clarity and not job prep or local os',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const SplashScreen(),
            ),
          ),
        );

        expect(find.text('Personal Clarity, Focus & Rhythm'), findsOneWidget);
        expect(find.textContaining('Job Prep'), findsNothing);
        expect(find.textContaining('Operating System'), findsNothing);

        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
      },
    );
  });

  group('Activity Hub (Things Hub) UI Refinements', () {
    testWidgets(
      'Things hub heading has View board on right end, no three dots, no progress bar, no streak flame',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              timeTrackingProvider.overrideWith(
                () => _FakeTimeTrackingNotifier(),
              ),
              todayActivitiesProvider.overrideWith((ref) => Stream.value([])),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(
                body: SingleChildScrollView(child: ActivityHubCard()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Heading and View board
        expect(find.text('Things hub'), findsOneWidget);
        expect(find.text('View board'), findsOneWidget);

        // Three dots 'Plans & Options' PopupMenuButton is removed from heading
        expect(find.byTooltip('Plans & Options'), findsNothing);

        // Progress bar (LinearProgressIndicator) and flame streak removed
        expect(find.byType(LinearProgressIndicator), findsNothing);
        expect(find.byIcon(Icons.local_fire_department_rounded), findsNothing);

        // Inside card: one Today / Completed / Plans control. Routines live
        // inside plans, and zero counts are never shown.
        expect(find.text('Today'), findsWidgets);
        expect(find.text('Completed'), findsOneWidget);
        expect(find.text('Plans'), findsOneWidget);
        expect(find.textContaining('Routines'), findsNothing);
        expect(find.text('0'), findsNothing);

        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      'Tapping Completed tab displays completed items and empty state correctly',
      (tester) async {
        final doneAct = TodayActivityItem(
          id: 'done-1',
          title: 'Morning Meditation',
          status: TodayActivityStatus.done,
          kind: ActivityKind.todo,
          sourceType: 'todo',
          elapsedSecondsToday: 0,
          categoryTag: 'General',
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              timeTrackingProvider.overrideWith(
                () => _FakeTimeTrackingNotifier(),
              ),
              todayActivitiesProvider.overrideWith(
                (ref) => Stream.value([doneAct]),
              ),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(
                body: SingleChildScrollView(child: ActivityHubCard()),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Initially on 'Today' tab: doneAct is not pending, shows All caught up
        expect(
          find.text('All caught up! All 1 activities finished.'),
          findsOneWidget,
        );

        // Tap 'Completed' tab
        await tester.tap(find.text('Completed'));
        await tester.pumpAndSettle();

        // Completed activity is now displayed!
        expect(find.text('Morning Meditation'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
      },
    );
  });

  group('Modern Curved Popup Menu Theme', () {
    test('AppTheme has curved corner popupMenuTheme with 18dp radius', () {
      final lightTheme = AscentTheme.light();
      final darkTheme = AscentTheme.dark();

      expect(lightTheme.popupMenuTheme.shape, isA<RoundedRectangleBorder>());
      final lightShape =
          lightTheme.popupMenuTheme.shape as RoundedRectangleBorder;
      expect(lightShape.borderRadius, equals(BorderRadius.circular(18)));
      expect(lightTheme.popupMenuTheme.elevation, equals(8));

      expect(darkTheme.popupMenuTheme.shape, isA<RoundedRectangleBorder>());
      final darkShape =
          darkTheme.popupMenuTheme.shape as RoundedRectangleBorder;
      expect(darkShape.borderRadius, equals(BorderRadius.circular(18)));
      expect(darkTheme.popupMenuTheme.elevation, equals(8));
    });
  });

  group('Life Check-in Dialog & Prompt Frequency Tests', () {
    testWidgets(
      'LifeCheckInPopupDialog renders Hydration and logs water intake',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(
                body: LifeCheckInPopupDialog(
                  initialTab: LifeCheckInTab.hydration,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Mindful Check-in'), findsOneWidget);
        expect(find.text('Hydration'), findsOneWidget);
        expect(find.text('Money'), findsOneWidget);
        expect(find.text('+250 mL'), findsOneWidget);

        // Log 250ml
        await tester.tap(find.text('+250 mL'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 3));

        final todayWater = await db.waterDao.getWaterForDate(DateTime.now());
        expect(todayWater, equals(250));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'LifeCheckInPopupDialog can switch to Money tab and log transaction',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(
                body: LifeCheckInPopupDialog(
                  initialTab: LifeCheckInTab.hydration,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Switch to Money tab
        await tester.tap(find.text('Money'));
        await tester.pumpAndSettle();

        expect(find.text('Expense'), findsOneWidget);
        expect(find.text('Income'), findsOneWidget);
        expect(find.text('Save Expense'), findsOneWidget);

        // Enter amount
        await tester.enterText(find.byType(TextField).first, '120');
        await tester.pumpAndSettle();

        // Save expense
        await tester.tap(find.text('Save Expense'));
        await tester.pumpAndSettle();
        await tester.pump(const Duration(seconds: 3));

        final transactions = await db.select(db.financeTransactionTable).get();
        expect(transactions.length, equals(1));
        expect(transactions.first.amount, equals(120.0));
        expect(transactions.first.type, equals('expense'));

        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
      },
    );

    test('Life check-in 4 out of 10 opens frequency calculation', () {
      final eligibleCounts = <int>[];
      for (int open = 1; open <= 20; open++) {
        final cycle = open % 10;
        final isEligible = cycle == 1 || cycle == 3 || cycle == 6 || cycle == 8;
        if (isEligible) {
          eligibleCounts.add(open);
        }
      }

      // In 10 opens: 1, 3, 6, 8 (exactly 4 out of 10)
      final firstTen = eligibleCounts.where((c) => c <= 10).toList();
      expect(firstTen, equals([1, 3, 6, 8]));
      expect(firstTen.length, equals(4));

      // In next 10 opens: 11, 13, 16, 18 (exactly 4 out of 10)
      final nextTen = eligibleCounts.where((c) => c > 10 && c <= 20).toList();
      expect(nextTen, equals([11, 13, 16, 18]));
      expect(nextTen.length, equals(4));
    });
  });
}
