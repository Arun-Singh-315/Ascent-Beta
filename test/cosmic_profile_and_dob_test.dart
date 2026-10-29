import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/services/cosmic_profile_service.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
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

  group('CosmicProfileService Calculations & Quotes', () {
    const service = CosmicProfileService();

    test('Western Zodiac, Vedic Rashi, and Defining Essence quotes for all signs', () {
      // Aries / Mesha (Mar 21)
      final aries = service.getZodiac(DateTime(1995, 3, 21));
      expect(aries.name, 'Aries');
      expect(aries.vedicRashi, 'Mesha');
      expect(aries.element, CosmicElement.fire);
      expect(aries.definingEssence, contains('pioneer unpaved paths'));

      // Gemini / Mithuna (Jun 1)
      final gemini = service.getZodiac(DateTime(1995, 6, 1));
      expect(gemini.name, 'Gemini');
      expect(gemini.vedicRashi, 'Mithuna');
      expect(gemini.element, CosmicElement.air);
      expect(gemini.definingEssence, contains('Curious intellect'));

      // Leo / Simha (Aug 15)
      final leo = service.getZodiac(DateTime(1995, 8, 15));
      expect(leo.name, 'Leo');
      expect(leo.vedicRashi, 'Simha');
      expect(leo.element, CosmicElement.fire);
      expect(leo.definingEssence, contains('Radiant courage'));

      // Pisces / Meena (Mar 10)
      final pisces = service.getZodiac(DateTime(1995, 3, 10));
      expect(pisces.name, 'Pisces');
      expect(pisces.vedicRashi, 'Meena');
      expect(pisces.element, CosmicElement.water);
      expect(pisces.definingEssence, contains('Soulful imagination'));
    });

    test('Daily living planetary mood rotates by weekday', () {
      final mondayMood = service.getDayLivingMood(DateTime(2026, 10, 26)); // Monday
      expect(mondayMood.weekday, 1);
      expect(mondayMood.planetaryRuler, contains('Moon'));

      final tuesdayMood = service.getDayLivingMood(DateTime(2026, 10, 27)); // Tuesday
      expect(tuesdayMood.weekday, 2);
      expect(tuesdayMood.planetaryRuler, contains('Mars'));

      final sundayMood = service.getDayLivingMood(DateTime(2026, 11, 1)); // Sunday
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

  group('HomeHeader Cardless Zodiac & Defining Essence Typography', () {
    testWidgets('Renders zodiac & defining essence directly below name without bulky card', (
      tester,
    ) async {
      final now = DateTime.now();
      // Seed profile with Gemini birthday (June 5)
      final profile = UserProfile(
        id: 1,
        name: 'Arun Singh',
        targetRole: 'Inner Peace', // Should be replaced by Zodiac & defining essence!
        targetCompanies: '[]',
        weeklyHoursAvailable: 20,
        preferredStudyWindow: 'morning',
        skillSelfRatings: '{}',
        dateOfBirth: DateTime(1996, 6, 5), // Gemini / Mithuna
        createdAt: now,
        updatedAt: now,
        onboardingComplete: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ProviderScope(
                child: HomeHeader(profile: profile),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      // Check name is displayed
      expect(find.text('Arun Singh'), findsOneWidget);

      // Verify "Inner Peace" dummy placeholder is NOT shown
      expect(find.text('Inner Peace'), findsNothing);

      // Verify cardless zodiac symbol and Vedic rashi
      expect(find.textContaining('♊ Gemini · Mithuna'), findsOneWidget);

      // Verify defining essence quote is NOT cluttering below the name
      expect(find.textContaining('Curious intellect'), findsNothing);

      // Verify customize home tune button is present
      expect(find.byTooltip('Customize Home'), findsOneWidget);
    });

    testWidgets('Renders defensively without overflow at 320px with 2.0x text scale', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.now();
      final profile = UserProfile(
        id: 1,
        name: 'Alexander',
        targetRole: 'Engineer',
        targetCompanies: '[]',
        weeklyHoursAvailable: 20,
        preferredStudyWindow: 'morning',
        skillSelfRatings: '{}',
        dateOfBirth: DateTime(1994, 11, 15), // Scorpio / Vrishchika
        createdAt: now,
        updatedAt: now,
        onboardingComplete: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2.0)),
            child: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: ProviderScope(
                    child: HomeHeader(profile: profile),
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.textContaining('Scorpio'), findsOneWidget);
      expect(find.textContaining('Vrishchika'), findsOneWidget);
    });

    testWidgets('Renders fallback gracefully when dateOfBirth is null', (
      tester,
    ) async {
      final now = DateTime.now();
      final profile = UserProfile(
        id: 1,
        name: 'Guest User',
        targetRole: 'Explorer',
        targetCompanies: '[]',
        weeklyHoursAvailable: 20,
        preferredStudyWindow: 'morning',
        skillSelfRatings: '{}',
        dateOfBirth: null,
        createdAt: now,
        updatedAt: now,
        onboardingComplete: true,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(16),
              child: ProviderScope(
                child: HomeHeader(profile: profile),
              ),
            ),
          ),
        ),
      );

      await tester.pump();

      expect(tester.takeException(), isNull);
      expect(find.text('Guest User'), findsOneWidget);
      expect(find.text('Explorer'), findsOneWidget);
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

      // Verify cardless decorative rashi line is rendered below Date of Birth without raw quote
      expect(find.textContaining('Leo'), findsOneWidget);
      expect(find.textContaining('Simha'), findsOneWidget);
      expect(find.textContaining('Radiant courage'), findsNothing);

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
    testWidgets('Onboarding sanctuary setup renders Date of Birth picker and cardless preview', (
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

      // Verify formatted date and cardless preview appear without raw quote
      expect(find.textContaining('15 October 2001'), findsOneWidget);
      expect(find.textContaining('Libra'), findsOneWidget);
      expect(find.textContaining('Tula'), findsOneWidget);
      expect(find.textContaining('Graceful harmony'), findsNothing);
    });
  });
}
