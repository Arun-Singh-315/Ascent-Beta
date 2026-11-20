import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/thought_wall/board/board_logic.dart';
import 'package:ascent/features/thought_wall/utils/thought_checklist_helper.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeTimeTrackingNotifier extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

class _FakeStudyStreakNotifier extends StudyStreakNotifier {
  @override
  StudyStreakStatus build() => const StudyStreakStatus(todaySeconds: 0);
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  group('ThoughtChecklistHelper Highlight & Importance Unit Tests', () {
    test('parses highlighted items marked with star or [!] marker', () {
      const text = '''
- Wake up early
- ★ Drink lemon tea
- [ ] Regular task
- [x] ★ Priority gym workout
''';
      final items = ThoughtChecklistHelper.parseItems(text);
      expect(items.length, 4);
      expect(items[0].text, 'Wake up early');
      expect(items[0].isHighlighted, isFalse);

      expect(items[1].text, 'Drink lemon tea');
      expect(items[1].isHighlighted, isTrue);

      expect(items[2].text, 'Regular task');
      expect(items[2].isHighlighted, isFalse);

      expect(items[3].text, 'Priority gym workout');
      expect(items[3].isHighlighted, isTrue);
      expect(items[3].isDone, isTrue);
    });

    test('toggles item highlight on and off cleanly in one call', () {
      const text = '''
- Wake up
- Drink lemon tea
''';
      // Highlight item 1 ("Drink lemon tea")
      final highlighted = ThoughtChecklistHelper.toggleItemHighlight(text, 1);
      expect(highlighted.contains('★ Drink lemon tea'), isTrue);

      // Unhighlight item 1
      final unhighlighted = ThoughtChecklistHelper.toggleItemHighlight(
        highlighted,
        1,
      );
      expect(unhighlighted.contains('★ Drink lemon tea'), isFalse);
      expect(unhighlighted.contains('Drink lemon tea'), isTrue);
    });

    test('toggling item done preserves highlight status', () {
      const text = '- [ ] ★ Important to-do';
      final toggled = ThoughtChecklistHelper.toggleItemDone(text, 0);
      expect(toggled.contains('- [x] ★ Important to-do'), isTrue);

      final undone = ThoughtChecklistHelper.toggleItemDone(toggled, 0);
      expect(undone.contains('- [ ] ★ Important to-do'), isTrue);
    });
  });

  group('Thought Wall Highlight & Importance UI Tests', () {
    late AppDatabase db;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets(
      'Tapping star on a checklist item highlights it in a second and converts as high priority task',
      (tester) async {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: '''
- Normal task
- Urgent promise
''',
          ),
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            timeTrackingProvider.overrideWith(_FakeTimeTrackingNotifier.new),
            studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
            recentThoughtsStreamProvider.overrideWith(
              (ref) => db.thoughtDao.watchRecentThoughts(),
            ),
            latestHomeThoughtProvider.overrideWith(
              (ref) => db.thoughtDao.watchLatestThought(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: ThoughtWallHomePreview(compact: true),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find star button for item 1 ("Urgent promise")
        final star1 = find.byKey(ValueKey('thought_${id}_star_1'));
        expect(star1, findsOneWidget);

        // Tap to highlight in 1 second
        await tester.tap(star1);
        await tester.pumpAndSettle();

        // Verify DB content has been updated with highlight star
        final updatedThought = await db.thoughtDao.getThoughtById(id);
        expect(updatedThought!.content.contains('★ Urgent promise'), isTrue);

        // Tap "Convert to activities"
        final convertBtn = find.byKey(
          ValueKey('thought_${id}_convert_to_activities'),
        );
        await tester.ensureVisible(convertBtn);
        await tester.tap(convertBtn);
        await tester.pumpAndSettle();

        // Verify tasks in database: "Urgent promise" must have priority 'high'
        final tasks = await db.select(db.taskTable).get();
        expect(tasks.length, 2);

        final urgentTask = tasks.firstWhere(
          (t) => t.title.contains('Urgent promise'),
        );
        expect(urgentTask.priority, 'high');

        final normalTask = tasks.firstWhere(
          (t) => t.title.contains('Normal task'),
        );
        expect(normalTask.priority, 'medium');
      },
    );

    testWidgets(
      'Tapping thought star highlights full statement with [HIGH] in header',
      (tester) async {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'Ship new version today without delay.',
          ),
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            timeTrackingProvider.overrideWith(_FakeTimeTrackingNotifier.new),
            studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
            recentThoughtsStreamProvider.overrideWith(
              (ref) => db.thoughtDao.watchRecentThoughts(),
            ),
            latestHomeThoughtProvider.overrideWith(
              (ref) => db.thoughtDao.watchLatestThought(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: ThoughtWallHomePreview(compact: true),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final highlightThoughtBtn = find.byKey(
          ValueKey('thought_${id}_star_thought_btn'),
        );
        expect(highlightThoughtBtn, findsOneWidget);

        // Tap to highlight full statement
        await tester.tap(highlightThoughtBtn);
        await tester.pumpAndSettle();

        final updated = await db.thoughtDao.getThoughtById(id);
        expect(isHighPriorityContent(updated!.content), isTrue);
      },
    );

    testWidgets(
      'Thought Wall preview checklist item and bubble render with zero overflow at 320px and 2.0x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: '''
- [ ] ★ Extremely urgent and important checklist item with very long text describing everything in detail
- [x] Standard second checklist item with moderate length
''',
          ),
        );

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            timeTrackingProvider.overrideWith(_FakeTimeTrackingNotifier.new),
            studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
            recentThoughtsStreamProvider.overrideWith(
              (ref) => db.thoughtDao.watchRecentThoughts(),
            ),
            latestHomeThoughtProvider.overrideWith(
              (ref) => db.thoughtDao.watchLatestThought(),
            ),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: MediaQuery(
                data: const MediaQueryData(
                  size: Size(320, 800),
                  textScaler: TextScaler.linear(2.0),
                ),
                child: const Scaffold(
                  body: SingleChildScrollView(
                    child: ThoughtWallHomePreview(compact: true),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byKey(ValueKey('thought_${id}_star_0')), findsOneWidget);
        expect(
          find.byKey(ValueKey('thought_${id}_star_thought_btn')),
          findsOneWidget,
        );
      },
    );
  });
}
