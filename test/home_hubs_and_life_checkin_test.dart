import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
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
}
