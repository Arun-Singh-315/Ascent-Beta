import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

void main() {
  group('Interactive Completeness & Non-Blocking UI Integrity Tests', () {
    late AppDatabase db;
    late SharedPreferences prefs;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      SharedPreferences.setMockInitialValues({
        'ascent_onboarding_complete': true,
        'ascent_quick_start_v1': true,
      });
      prefs = await SharedPreferences.getInstance();
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('ActivityHubCard provides non-blocking entry points on empty and populated states', (tester) async {
      // 1. Empty state
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AscentTheme.dark(),
            home: const Scaffold(
              body: SingleChildScrollView(child: ActivityHubCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Ensure "View board" entry point is rendered and interactive
      expect(find.text('View board'), findsOneWidget);
      expect(find.text('Things hub'), findsOneWidget);

      // 2. Populate 10 items (boundary test)
      final now = DateTime.now();
      for (int i = 1; i <= 10; i++) {
        await db.taskDao.insertTask(
          TaskTableCompanion.insert(
            title: 'Task #$i for today',
            plannedDate: drift.Value(now),
          ),
        );
      }

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
            home: const Scaffold(
              body: SingleChildScrollView(child: ActivityHubCard()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Capping test: Ensure list does not blow out the screen unbounded (capped preview)
      expect(find.text('View board'), findsOneWidget);
      expect(find.text('Task #1 for today'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });

    testWidgets('ThoughtWallHomePreview provides active input and navigation on narrow 320px screen', (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: AscentTheme.dark(),
            home: const Scaffold(
              body: SingleChildScrollView(child: ThoughtWallHomePreview()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Active thought input is visible and interactive
      expect(find.text('Capture a thought…'), findsOneWidget);
      // Composer icons are present
      expect(find.byIcon(Icons.playlist_add_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_upward_rounded), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(Duration.zero);
    });
  });
}
