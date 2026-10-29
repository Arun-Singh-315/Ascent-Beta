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

  group('Creative Life OS Onboarding Journey Tests', () {
    testWidgets(
      'Vision screen communicates Mind Palace, Sacred Promises, Daily Rhythms & AI Companion',
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

        // 1. Verify Vision step branding and pillars
        expect(find.text('Where clarity meets quiet discipline.'), findsOneWidget);
        expect(find.text('Mind Palace'), findsOneWidget);
        expect(find.text('Sacred Promises'), findsOneWidget);
        expect(find.text('Daily Rhythms'), findsOneWidget);
        expect(find.text('AI Companion (Aria / Riya)'), findsOneWidget);
        expect(find.text('Start now'), findsOneWidget);
        expect(find.text('Begin Your Ascent →'), findsOneWidget);

        // 2. Tap "Begin Your Ascent →" to advance to Sanctuary Setup
        await tester.ensureVisible(find.text('Begin Your Ascent →'));
        await tester.tap(find.text('Begin Your Ascent →'));
        await tester.pumpAndSettle();

        // 3. Verify Sanctuary Setup prompt and controls
        expect(find.text('Shape your sanctuary.'), findsOneWidget);
        expect(find.text('Your Name'), findsOneWidget);
        expect(find.text('AI Companion Identity'), findsOneWidget);
        expect(find.text('Visual Atmosphere'), findsOneWidget);
        expect(find.text('Enter your name'), findsOneWidget);

        // 4. Enter name and choose companion/atmosphere
        await tester.enterText(find.byType(TextField).first, 'Arun');
        await tester.pump();

        expect(find.text('Establish Sanctuary →'), findsOneWidget);

        // Choose companion Riya
        await tester.ensureVisible(find.text('✦ Riya'));
        await tester.tap(find.text('✦ Riya'));
        await tester.pump();

        // Choose Clear Sky atmosphere
        await tester.ensureVisible(find.text('Nordic'));
        await tester.tap(find.text('Nordic'));
        await tester.pump();

        // Choose intention
        await tester.ensureVisible(find.text('Deep Focus'));
        await tester.tap(find.text('Deep Focus'));
        await tester.pump();

        // 5. Advance to Sanctuary Sealed step
        await tester.ensureVisible(find.text('Establish Sanctuary →'));
        await tester.tap(find.text('Establish Sanctuary →'));
        await tester.pumpAndSettle();

        // 6. Verify Sanctuary Sealed recap
        expect(find.text('Sanctuary Sealed.'), findsOneWidget);
        expect(find.text('✦ Riya'), findsOneWidget);
        expect(find.text('Clear Sky'), findsOneWidget);
        expect(find.text('Hardware-backed SQLite'), findsOneWidget);
        expect(find.text('Deep Focus'), findsOneWidget);
        expect(find.text('Enter Ascent →'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
      },
    );

    testWidgets(
      'Onboarding is overflow-immune at 320px width with 2.0x text scaling across all 3 steps',
      (tester) async {
        tester.view.physicalSize = const Size(320, 700);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
            child: MaterialApp(
              theme: AscentTheme.dark(),
              home: const MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(2.0)),
                child: OnboardingShell(),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Navigate to Step 2
        await tester.ensureVisible(find.text('Begin Your Ascent →'));
        await tester.tap(find.text('Begin Your Ascent →'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        // Enter name & navigate to Step 3
        await tester.enterText(find.byType(TextField).first, 'Arun');
        await tester.pump();
        await tester.ensureVisible(find.text('Establish Sanctuary →'));
        await tester.tap(find.text('Establish Sanctuary →'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox());
      },
    );
  });
}
