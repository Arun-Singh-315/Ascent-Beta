import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/home_layout_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/plans/widgets/plan_collection_editor.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'package:ascent/features/thought_wall/thought_quick_actions.dart';

class FakeStudyStreakNotifier extends StudyStreakNotifier {
  @override
  StudyStreakStatus build() => StudyStreakCalculator().calculate(
    todaySeconds: 0,
    yesterdaySeconds: 0,
    priorStreakDays: 0,
    historicalLongestStreak: 0,
    historicalShortestStreak: 1,
    now: DateTime.now(),
  );
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late ProviderContainer container;
  late SharedPreferences prefs;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({
      'feature_guide_v1_Thought Wall': true,
    });
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        currentStreakStreamProvider.overrideWith((ref) => Stream.value(0)),
        studyStreakProvider.overrideWith(FakeStudyStreakNotifier.new),
        homeStreakVisibleProvider.overrideWithValue(true),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Widget wrap(Widget child, {ThemeData? theme}) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: theme ?? AscentTheme.light(),
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  group('Mind Space Home Preview Permanent Actions', () {
    testWidgets(
      'Thought capture does not open plan automatically and keeps Plan, Todo, Reminder visible without Ask Riya',
      (tester) async {
        await tester.pumpWidget(wrap(const ThoughtWallHomePreview()));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.byType(TextField),
          'Tomorrow at 5 pm check in on project. Remind me then.',
        );
        await tester.pump();
        await tester.tap(find.byTooltip('Send capture'));
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 150)),
        );
        await tester.pumpAndSettle();

        // 1. Must NOT show plan sheet automatically
        expect(find.byType(PlanCollectionEditor), findsNothing);

        // 2. Must show transient options for a few seconds
        expect(find.text('Plan'), findsOneWidget);
        expect(find.text('Todo'), findsOneWidget);
        expect(find.text('Reminder'), findsOneWidget);

        // 3. Ask Riya must be removed from the card
        expect(find.text('Ask Riya'), findsNothing);

        await tester.pump(const Duration(seconds: 10));
        await tester.pumpAndSettle();
        expect(find.text('Plan'), findsOneWidget);
        expect(find.text('Todo'), findsOneWidget);
        expect(find.text('Reminder'), findsOneWidget);
        expect(find.byTooltip('Expand actions'), findsNothing);
        expect(find.byTooltip('Collapse actions'), findsNothing);
        // 6. User selects Plan manually to open PlanCollectionEditor
        await tester.tap(find.text('Plan'));
        await tester.pumpAndSettle();
        expect(find.byType(PlanCollectionEditor), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('HomeHeader Transparent and Compact Styling', () {
    testWidgets(
      'HomeHeader has Start streak pill and does not render Ask Riya banner above thoughts',
      (tester) async {
        await tester.pumpWidget(
          wrap(
            const HomeHeader(profile: null),
            theme: AscentTheme.light(preset: DayThemePreset.nordicSky),
          ),
        );
        await tester.pumpAndSettle();

        // Check Ask Riya is NOT rendered in HomeHeader (moved to floating pill)
        expect(find.text('Ask Riya'), findsNothing);

        // Check Start streak pill is present
        expect(find.text('Start'), findsOneWidget);

        await tester.pumpWidget(const SizedBox());
      },
    );
  });

  group('Thought Wall Selection and Quick Actions Include Plan', () {
    testWidgets('Thought Wall selection bar includes Plan alongside Todo', (
      tester,
    ) async {
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Note for testing plan selection',
        ),
      );

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(home: ThoughtWallScreen()),
        ),
      );
      for (var i = 0; i < 5; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      // Long press to enter selection mode
      await tester.longPress(find.textContaining('Note for testing'));
      await tester.pumpAndSettle();

      // Open more actions menu
      await tester.tap(find.byTooltip('More selected actions'));
      await tester.pumpAndSettle();

      // Must find Plan, Todo, Reminder on selection
      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Create Todo'), findsOneWidget);
      expect(find.text('Set reminder'), findsOneWidget);

      // Tap Plan from selection mode
      await tester.tap(find.text('Plan'));
      await tester.pumpAndSettle();

      // Must open schedule sheet
      expect(find.byType(PlanCollectionEditor), findsOneWidget);
    });

    testWidgets('ThoughtQuickActions offers Plan, Todo, Reminder, Both', (
      tester,
    ) async {
      final id = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Quick note'),
      );
      final thought = await db.thoughtDao.getThoughtById(id);

      await tester.pumpWidget(
        wrap(ThoughtQuickActions(thought: thought!, db: db)),
      );
      await tester.pumpAndSettle();

      expect(find.text('Plan'), findsOneWidget);
      expect(find.text('Todo'), findsOneWidget);
      expect(find.text('Reminder'), findsOneWidget);
      expect(find.text('Both'), findsOneWidget);
    });
  });
}
