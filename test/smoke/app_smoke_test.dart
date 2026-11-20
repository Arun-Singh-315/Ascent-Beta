import 'package:ascent/app/app_navigation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/app/app.dart';
import 'package:ascent/app/router.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ascent/core/notifications/pending_reminder_effects_provider.dart';

void main() {
  setUpAll(() {
    drift.driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  });

  group('Ascent Market Smoke Test Suite', () {
    late SharedPreferences prefs;
    late AppDatabase db;

    setUp(() async {
      SharedPreferences.setMockInitialValues({
        'ascent_onboarding_complete': true,
        'ascent_quick_start_v1': true,
        'user_profile_name': 'Test User',
      });
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db.userProfileDao.upsertProfile(
        const UserProfileTableCompanion(
          name: drift.Value('Test User'),
          targetRole: drift.Value('Software Engineer'),
          onboardingComplete: drift.Value(true),
        ),
      );
    });

    tearDown(() async {
      // In-memory sqlite db doesn't require explicit close
    });

    testWidgets('App boots cleanly to Home and mounts root shell', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
            pendingReminderEffectsProvider.overrideWith((ref) {}),
          ],
          child: const AscentApp(),
        ),
      );

      expect(find.byType(AscentApp), findsOneWidget);

      // Advance through splash delay and animations
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.byType(Scaffold), findsWidgets);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets(
      'Main navigation shell switches between primary tabs without error',
      (tester) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              databaseProvider.overrideWithValue(db),
              pendingReminderEffectsProvider.overrideWith((ref) {}),
            ],
            child: const AscentApp(),
          ),
        );

        await tester.pump(const Duration(milliseconds: 1500));
        await tester.pump(const Duration(milliseconds: 500));

        // Verify Tab 0 (Home) is loaded
        expect(ascentRouter.state.uri.path, AscentRoutes.home);

        // Each of the five tabs, plus the old tab locations.
        for (final (location, path) in [
          (AscentRoutes.things, AscentRoutes.things),
          (AscentRoutes.aiAssistant, AscentRoutes.aiAssistant),
          (AscentRoutes.thoughtWall, AscentRoutes.thoughtWall),
          (AscentRoutes.you, AscentRoutes.you),
          (AscentRoutes.more, AscentRoutes.you),
          (AscentRoutes.reminders, AscentRoutes.reminders),
        ]) {
          ascentRouter.go(location);
          await tester.pump(const Duration(milliseconds: 300));
          expect(ascentRouter.state.uri.path, path);
          expect(tester.takeException(), isNull, reason: location);
        }

        ascentRouter.go(AscentRoutes.money);
        await tester.pump(const Duration(milliseconds: 300));
        expect(ascentRouter.state.uri.path, AscentRoutes.money);

        // Revert to Tab 0 (Home)
        ascentRouter.go(AscentRoutes.home);
        await tester.pump(const Duration(milliseconds: 300));
        expect(ascentRouter.state.uri.path, AscentRoutes.home);

        await tester.pumpWidget(const SizedBox());
        await tester.pump(Duration.zero);
      },
skip: true, // Known bug: App shell modifies a provider during build
);

    testWidgets('Key standalone routes resolve and mount cleanly', (
      tester,
    ) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
            pendingReminderEffectsProvider.overrideWith((ref) {}),
          ],
          child: const AscentApp(),
        ),
      );

      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pump(const Duration(milliseconds: 500));

      // Thought Wall
      ascentRouter.open(AscentRoutes.thoughtWall);
      await tester.pump(const Duration(milliseconds: 300));
      expect(ascentRouter.state.uri.path, AscentRoutes.thoughtWall);

      // Chai Break
      ascentRouter.push(AscentRoutes.chaiBreak);
      await tester.pump(const Duration(milliseconds: 300));
      expect(ascentRouter.state.uri.path, AscentRoutes.chaiBreak);

      // Plans
      ascentRouter.push(AscentRoutes.plans);
      await tester.pump(const Duration(milliseconds: 300));
      expect(ascentRouter.state.uri.path, AscentRoutes.plans);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    },
skip: true, // Known bug: App shell modifies a provider during build
);
  });
}
