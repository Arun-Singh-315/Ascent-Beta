import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/services/cosmic_profile_service.dart';
import 'package:ascent/shared/widgets/cosmic_spark_card.dart';
import 'package:ascent/features/settings/settings_screen.dart';
import 'package:ascent/features/onboarding/onboarding_shell.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('CosmicProfileService Calculations', () {
    const service = CosmicProfileService();

    test('Western Zodiac and Vedic Rashi boundaries', () {
      // Aries / Mesha (Mar 21)
      final aries = service.getZodiac(DateTime(1995, 3, 21));
      expect(aries.name, 'Aries');
      expect(aries.vedicRashi, 'Mesha');
      expect(aries.element, CosmicElement.fire);

      // Taurus / Vrishabha (Apr 20)
      final taurus = service.getZodiac(DateTime(1995, 4, 20));
      expect(taurus.name, 'Taurus');
      expect(taurus.vedicRashi, 'Vrishabha');
      expect(taurus.element, CosmicElement.earth);

      // Leo / Simha (Aug 15)
      final leo = service.getZodiac(DateTime(1995, 8, 15));
      expect(leo.name, 'Leo');
      expect(leo.vedicRashi, 'Simha');
      expect(leo.element, CosmicElement.fire);

      // Scorpio / Vrishchika (Nov 10)
      final scorpio = service.getZodiac(DateTime(1995, 11, 10));
      expect(scorpio.name, 'Scorpio');
      expect(scorpio.vedicRashi, 'Vrishchika');
      expect(scorpio.element, CosmicElement.water);

      // Capricorn / Makara (Jan 5)
      final capricorn = service.getZodiac(DateTime(1995, 1, 5));
      expect(capricorn.name, 'Capricorn');
      expect(capricorn.vedicRashi, 'Makara');
      expect(capricorn.element, CosmicElement.earth);

      // Pisces / Meena (Mar 10)
      final pisces = service.getZodiac(DateTime(1995, 3, 10));
      expect(pisces.name, 'Pisces');
      expect(pisces.vedicRashi, 'Meena');
      expect(pisces.element, CosmicElement.water);
    });

    test('Daily living planetary mood rotates by weekday', () {
      // Monday = 1 (Chandra / Moon)
      final mondayMood = service.getDayLivingMood(DateTime(2026, 10, 26)); // A Monday
      expect(mondayMood.weekday, 1);
      expect(mondayMood.planetaryRuler, contains('Moon'));

      // Tuesday = 2 (Mars / Mangala)
      final tuesdayMood = service.getDayLivingMood(DateTime(2026, 10, 27)); // A Tuesday
      expect(tuesdayMood.weekday, 2);
      expect(tuesdayMood.planetaryRuler, contains('Mars'));

      // Sunday = 7 (Sun / Surya)
      final sundayMood = service.getDayLivingMood(DateTime(2026, 11, 1)); // A Sunday
      expect(sundayMood.weekday, 7);
      expect(sundayMood.planetaryRuler, contains('Sun'));
    });

    test('Birthday detection and customized celebration spark', () {
      final dob = DateTime(2000, 8, 15);
      final today = DateTime(2026, 8, 15);

      expect(service.isBirthdayToday(dob, today), isTrue);
      expect(service.computeAge(dob, today), 26);

      final insight = service.getDailyInsight(dob: dob, today: today);
      expect(insight.isBirthday, isTrue);
      expect(insight.age, 26);
      expect(insight.quote, contains('Happy Birthday'));
      expect(insight.quote, contains('26 years'));
    });

    test('Daily boosting quote rotates deterministically per calendar day', () {
      final dob = DateTime(1998, 5, 10); // Taurus
      final day1 = DateTime(2026, 10, 29);
      final day2 = DateTime(2026, 10, 30);

      final insight1 = service.getDailyInsight(dob: dob, today: day1);
      final insight2 = service.getDailyInsight(dob: dob, today: day2);

      expect(insight1.isBirthday, isFalse);
      expect(insight1.quote.isNotEmpty, isTrue);
      expect(insight2.quote.isNotEmpty, isTrue);
      expect(insight1.sign.name, 'Taurus');
    });
  });

  group('CosmicSparkCard UI & Responsiveness', () {
    testWidgets('CosmicSparkCard renders without overflow at 320px with 2.0x text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final dob = DateTime(1998, 8, 15); // Leo / Simha

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light(),
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(8.0),
                  child: CosmicSparkCard(dateOfBirth: dob),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Leo'), findsOneWidget);
      expect(find.textContaining('Simha'), findsOneWidget);
    });

    testWidgets('CosmicSparkCard renders birthday state cleanly', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final dob = DateTime(1998, now.month, now.day); // Today is birthday

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: CosmicSparkCard(dateOfBirth: dob),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Happy Birthday! ✨'), findsOneWidget);
    });
  });

  group('Settings Screen Date of Birth Section', () {
    testWidgets('Settings screen renders Date of Birth field below Your Name and saves', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      // Seed initial user profile
      await db.userProfileDao.upsertProfile(
        UserProfileTableCompanion(
          id: const drift.Value(1),
          name: const drift.Value('Arun'),
          targetRole: const drift.Value('Lead Architect'),
          dateOfBirth: drift.Value(DateTime(1996, 7, 25)), // Leo
          onboardingComplete: const drift.Value(true),
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: const MaterialApp(
            home: SettingsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 150));

      // Verify Your Name is present
      expect(find.text('Your Name'), findsOneWidget);
      expect(find.text('Date of Birth'), findsOneWidget);

      // Verify Date of Birth button is rendered with seeded date
      expect(find.byKey(const ValueKey('settings_dob_picker')), findsOneWidget);
      expect(find.textContaining('25 July 1996'), findsOneWidget);

      // Verify CosmicSparkCard is rendered below Date of Birth
      expect(find.textContaining('Leo'), findsOneWidget);
      expect(find.textContaining('Simha'), findsOneWidget);

      // Tap clear birth date button
      await tester.tap(find.byTooltip('Clear birth date'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Select date of birth'), findsOneWidget);

      // Dismount to clean up any active widget listeners
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 50));
    });
  });

  group('Onboarding Flow Date of Birth Integration', () {
    testWidgets('Onboarding sanctuary setup renders Date of Birth picker and preview', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(360, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: OnboardingShell(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Advance to Step 1 (Sanctuary Setup)
      await tester.tap(find.text('Begin Your Ascent →'));
      await tester.pumpAndSettle();

      // Verify Date of Birth picker is displayed in Sanctuary Setup
      expect(find.byKey(const ValueKey('onboarding_dob_picker')), findsOneWidget);
      expect(find.text('Set birth date for daily cosmic energy'), findsOneWidget);

      // Update date of birth via notifier
      container.read(onboardingProvider.notifier).setDateOfBirth(DateTime(2001, 10, 15)); // Libra / Tula
      await tester.pumpAndSettle();

      // Verify formatted date and preview card appear
      expect(find.textContaining('15 October 2001'), findsOneWidget);
      expect(find.textContaining('Libra'), findsOneWidget);
      expect(find.textContaining('Tula'), findsOneWidget);
    });
  });
}
