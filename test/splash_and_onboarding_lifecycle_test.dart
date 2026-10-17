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

  group('Optional Career Onboarding Tests', () {
    testWidgets(
      'Onboarding offers Quick Start and allows a name without career details',
      (tester) async {
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
        expect(find.text('Target Role (optional)'), findsOneWidget);
        expect(find.text('Start now'), findsOneWidget);
        expect(find.text('Enter your name'), findsOneWidget);

        // Enter name
        await tester.enterText(find.byType(TextField).first, 'Arun');
        await tester.pump();

        // Now asks for target role
        expect(find.text('Continue'), findsOneWidget);

        // Tap role suggestion "Full Stack Engineer"
        await tester.tap(find.text('Full Stack Engineer'));
        await tester.pump();

        // Now "Continue" button is enabled
        expect(find.text('Continue'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
      },
    );
  });
}
