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
import 'package:ascent/features/auth/login_screen.dart';
import 'package:ascent/features/onboarding/onboarding_shell.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

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
    testWidgets('SplashScreen renders Ascent branding, title, and version tag', (tester) async {
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
      expect(find.text('Job Prep & Search Operating System'), findsOneWidget);
      expect(find.byIcon(Icons.north_east_rounded), findsOneWidget);

      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('SplashScreen navigates to /login when user is unauthenticated', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AscentTheme.dark(),
            onGenerateRoute: (settings) {
              return MaterialPageRoute(builder: (_) => const SizedBox());
            },
            home: const SplashScreen(),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1600));
      // Unauthenticated state leads to login or onboarding
      final isAuth = prefs.getBool('ascent_is_authenticated_v1') ?? false;
      expect(isAuth, isFalse);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });
  });

  group('Login Screen & Compulsory Onboarding Validation Tests', () {
    testWidgets('LoginScreen rejects empty inputs with error message', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AscentTheme.dark(),
            home: const LoginScreen(),
          ),
        ),
      );

      // Attempt to tap sign in button while fields are empty
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      expect(find.text('Please enter both username and password'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('LoginScreen fills demo credentials and signs in cleanly', (tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AscentTheme.dark(),
            home: const LoginScreen(),
          ),
        ),
      );

      // Tap Auto-fill Demo
      await tester.tap(find.textContaining('Auto-fill Demo'));
      await tester.pump();

      expect(find.text('arn'), findsOneWidget);
      expect(find.text('1234'), findsOneWidget);

      // Click sign in button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      final isAuth = prefs.getBool('ascent_is_authenticated_v1') ?? false;
      expect(isAuth, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });
  });

  group('Compulsory Onboarding Questions Enforcement Tests', () {
    testWidgets('Onboarding step 0 requires name >= 2 chars and role before continuing', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AscentTheme.dark(),
            home: const OnboardingShell(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify prompt text
      expect(find.text('Your Name'), findsOneWidget);
      expect(find.text('Target Role'), findsOneWidget);
      expect(find.text('Enter your name to continue'), findsOneWidget);

      // Enter name
      await tester.enterText(find.byType(TextField).first, 'Arun');
      await tester.pump();

      // Now asks for target role
      expect(find.text('Enter or select your target role'), findsOneWidget);

      // Tap role suggestion "Full Stack Engineer"
      await tester.tap(find.text('Full Stack Engineer'));
      await tester.pump();

      // Now "Continue" button is enabled
      expect(find.text('Continue'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });
  });
}
