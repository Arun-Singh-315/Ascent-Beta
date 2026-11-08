import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/splash/splash_screen.dart';
import 'package:ascent/features/onboarding/onboarding_shell.dart';
import 'package:ascent/shared/widgets/ascent_logo.dart';

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

  group('Splash Screen Visuals & Navigation Lifecycle Tests', () {
    testWidgets(
      'SplashScreen renders Ascent branding, title, and version tag',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(
              theme: AscentTheme.dark(),
              home: const SplashScreen(),
            ),
          ),
        );

        // Verify emblem and titles
        expect(find.text('Ascent'), findsOneWidget);
        expect(find.text('Personal Clarity, Focus & Rhythm'), findsOneWidget);
        expect(find.byType(AscentLogo), findsOneWidget);

        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
      },
    );
  });

  testWidgets(
    'Personalization saves the chosen name and companion without starter records',
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
            builder: (_, _) => const Scaffold(body: Text('Home ready')),
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
          ),
        ),
      );
      Future<void> settle() async {
        for (var i = 0; i < 8; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 15)),
          );
          await tester.pump(const Duration(milliseconds: 100));
        }
      }

      await settle();
      await tester.tap(find.text('Let’s begin'));
      await settle();
      await tester.enterText(
        find.byKey(const ValueKey('onboarding_name')),
        'Arun',
      );
      await tester.tap(find.byKey(const ValueKey('onboarding_dob')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue'));
      await settle();
      expect(find.text('Home ready'), findsOneWidget);
      await tester.runAsync(() async {
        final profile = await db.userProfileDao.getProfile();
        expect(profile!.name, 'Arun');
        expect(profile.onboardingComplete, isTrue);
        expect(await db.select(db.taskTable).get(), isEmpty);
        expect(await db.thoughtDao.watchAllThoughts().first, isEmpty);
      });
      expect(prefs.getBool('ascent_first_moment_pending_v1'), isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
    },
  );
}
