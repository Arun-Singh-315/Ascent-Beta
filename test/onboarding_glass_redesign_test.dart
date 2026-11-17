import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/onboarding/onboarding_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late SharedPreferences prefs;

  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  tearDown(() async {
    await db.close();
  });

  group('Onboarding 6-Screen Journey Tests', () {
    testWidgets(
      'Screen 1 Welcome renders branding, ascending bars, and sanctuary pill',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/onboarding',
          routes: [
            GoRoute(
              path: '/onboarding',
              builder: (_, _) => const OnboardingShell(),
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
              theme: AscentTheme.dark(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Check Ascent branding & Sanctuary Tag
        expect(find.text('Ascent'), findsOneWidget);
        expect(find.text('Your personal sanctuary'), findsOneWidget);
        expect(find.text('Climb a little,\nevery day.'), findsOneWidget);
        expect(
          find.text('Plans, focus, routines and a gentle companion, all in one calm place.'),
          findsOneWidget,
        );

        // Check action button
        expect(find.text('Let’s begin'), findsOneWidget);
        expect(find.text('Private, local and crafted for your peace of mind.'), findsOneWidget);

        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Rule 13: Zero RenderFlex overflow at 320px width with 2.0x text scaling across screens',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 2, 700 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = GoRouter(
          initialLocation: '/onboarding',
          routes: [
            GoRoute(
              path: '/onboarding',
              builder: (_, _) => const MediaQuery(
                data: MediaQueryData(
                  size: Size(320, 700),
                  textScaler: TextScaler.linear(2.0),
                ),
                child: OnboardingShell(),
              ),
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
              theme: AscentTheme.dark(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Screen 1: Welcome
        expect(tester.takeException(), isNull);
        expect(find.text('Let’s begin'), findsOneWidget);

        // Advance to Screen 2: What you get
        await tester.ensureVisible(find.text('Let’s begin'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Let’s begin'));
        await tester.pumpAndSettle();

        expect(find.text('1 of 4'), findsOneWidget);
        expect(find.text('Everything for your day, in one calm place.'), findsOneWidget);
        expect(tester.takeException(), isNull);

        // Advance to Screen 3: Your Name
        await tester.ensureVisible(find.text('Continue'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        expect(find.text('2 of 4'), findsOneWidget);
        expect(find.text('First, what should we call you?'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Navigates through all 6 screens, supports back navigation, and saves profile',
      (tester) async {
        tester.view.physicalSize = const Size(390 * 2, 844 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = GoRouter(
          initialLocation: '/onboarding',
          routes: [
            GoRoute(
              path: '/onboarding',
              builder: (_, _) => const OnboardingShell(),
            ),
            GoRoute(
              path: '/home',
              builder: (_, _) => const Scaffold(body: Text('Home Destination')),
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
              theme: AscentTheme.dark(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // 1 · Welcome screen
        expect(find.text('Your personal sanctuary'), findsOneWidget);
        await tester.ensureVisible(find.text('Let’s begin'));
        await tester.tap(find.text('Let’s begin'));
        await tester.pumpAndSettle();

        // 2 · What you get (1 of 4)
        expect(find.text('1 of 4'), findsOneWidget);
        expect(find.text('Daily rhythm'), findsOneWidget);
        expect(find.text('Study and meals'), findsOneWidget);
        expect(find.text('Riya, your companion'), findsOneWidget);
        expect(find.text('Care and wealth'), findsOneWidget);

        // Test Back to Welcome
        await tester.tap(find.byKey(const ValueKey('onboarding_back')));
        await tester.pumpAndSettle();
        expect(find.text('Your personal sanctuary'), findsOneWidget);

        // Advance to 1 of 4 again
        await tester.ensureVisible(find.text('Let’s begin'));
        await tester.tap(find.text('Let’s begin'));
        await tester.pumpAndSettle();
        expect(find.text('1 of 4'), findsOneWidget);

        // Advance to 2 · Your Name (2 of 4)
        await tester.ensureVisible(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('2 of 4'), findsOneWidget);
        expect(find.text('First, what should we call you?'), findsOneWidget);

        // Enter Name
        await tester.enterText(
          find.byKey(const ValueKey('onboarding_name')),
          'Arun',
        );
        await tester.pumpAndSettle();
        // Dynamic time-based greeting preview
        expect(find.textContaining(', Arun.'), findsOneWidget);

        // Advance to 3 · Birthday (3 of 4)
        await tester.ensureVisible(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('3 of 4'), findsOneWidget);
        expect(find.text('When is your birthday?'), findsOneWidget);
        expect(find.text('DAY'), findsOneWidget);
        expect(find.text('MONTH'), findsOneWidget);
        expect(find.text('YEAR'), findsOneWidget);
        expect(find.textContaining('Mithuna'), findsOneWidget);

        // Advance to 4 · Your Climb (4 of 4)
        await tester.ensureVisible(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('4 of 4'), findsOneWidget);
        expect(find.text('What do you want most right now?'), findsOneWidget);
        expect(find.text('Inner peace'), findsOneWidget);
        expect(find.text('Focus and flow'), findsOneWidget);
        expect(find.text('Study and growth'), findsOneWidget);
        expect(find.text('Daily vitality'), findsOneWidget);

        // Select 'Study and growth'
        await tester.ensureVisible(find.text('Study and growth'));
        await tester.tap(find.text('Study and growth'));
        await tester.pumpAndSettle();

        // Advance to 5 · Ready
        await tester.ensureVisible(find.text('Continue'));
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();
        expect(find.text('You are all set, Arun.'), findsOneWidget);
        expect(find.textContaining('study and growth'), findsOneWidget);

        // Tap 'Enter Ascent'
        await tester.ensureVisible(find.text('Enter Ascent'));
        await tester.tap(find.text('Enter Ascent'));
        await tester.pumpAndSettle();

        // Check we reached /home
        expect(find.text('Home Destination'), findsOneWidget);

        // Verify profile in DB
        final profile = await db.userProfileDao.getProfile();
        expect(profile, isNotNull);
        expect(profile!.name, 'Arun');
        expect(profile.targetRole, 'Study and growth');
        expect(profile.onboardingComplete, isTrue);
      },
    );
  });
}
