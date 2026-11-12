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

  group('Onboarding Glass Redesign Tests', () {
    testWidgets(
      'Renders calm, cute glass vision card without childish scrapbook visuals',
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

        // Check stage capsule
        expect(find.text('01 Vision'), findsOneWidget);

        // Check calm cute vision pill and title
        expect(find.text('Your Personal Sanctuary'), findsOneWidget);
        expect(find.text('Ascent'), findsOneWidget);
        expect(
          find.text('A quiet space for your mind & daily rhythm.'),
          findsOneWidget,
        );

        // Check the 3 vision pillars
        expect(find.text('Daily Rhythm & Focus'), findsOneWidget);
        expect(find.text('Study & Meal Plans'), findsOneWidget);
        expect(find.text('Personal Companion'), findsOneWidget);

        // Check action button
        expect(find.text('Let’s begin'), findsOneWidget);

        // Verify zero exceptions
        final err3 = tester.takeException();
        if (err3 != null) {
          debugPrint('RULE 13 ERROR DETAILS: ${(err3 as FlutterError).toStringDeep()}');
        }
        expect(err3, isNull);
      },
    );

    testWidgets(
      'Rule 13: Zero RenderFlex overflow at 320px width with 2.0x text scaling',
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

        // Must render cleanly without RenderFlex errors
        expect(tester.takeException(), isNull);
        expect(find.text('Let’s begin'), findsOneWidget);

        // Scroll to button and navigate to Step 2 under 320px + 2.0x text scale
        await tester.scrollUntilVisible(find.text('Let’s begin'), 100);
        await tester.pumpAndSettle();
        await tester.tap(find.text('Let’s begin'));
        await tester.pumpAndSettle();

        expect(find.text('Step 2 of 2 · Customization'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'Navigates between Step 0 and Step 1 with Back button and saves focus role',
      (tester) async {
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

        // Advance to step 1
        await tester.tap(find.text('Let’s begin'));
        await tester.pumpAndSettle();

        expect(find.text('Step 2 of 2 · Customization'), findsOneWidget);

        // Tap back to verify return to step 0
        await tester.tap(find.text('Back'));
        await tester.pumpAndSettle();
        expect(find.text('Your Personal Sanctuary'), findsOneWidget);

        // Return to step 1
        await tester.tap(find.text('Let’s begin'));
        await tester.pumpAndSettle();

        // Select a focus area
        await tester.tap(find.text('Study & Growth'));
        await tester.pumpAndSettle();

        // Enter name
        await tester.enterText(
          find.byKey(const ValueKey('onboarding_name')),
          'Arun',
        );
        await tester.pumpAndSettle();

        // Pick date of birth
        await tester.tap(find.byKey(const ValueKey('onboarding_dob')));
        await tester.pumpAndSettle();
        await tester.tap(find.text('OK'));
        await tester.pumpAndSettle();

        // Tap continue
        await tester.tap(find.text('Continue'));
        await tester.pumpAndSettle();

        // Check we navigated to /home
        expect(find.text('Home Destination'), findsOneWidget);

        // Verify profile in DB has targetRole saved
        final profile = await db.userProfileDao.getProfile();
        expect(profile, isNotNull);
        expect(profile!.name, 'Arun');
        expect(profile.targetRole, 'Study & Growth');
      },
    );
  });
}
