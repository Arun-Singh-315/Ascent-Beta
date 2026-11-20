import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
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

  group('ThoughtChecklistHelper unit tests', () {
    test('parses plain bullets, numbered items, and bracket checkboxes', () {
      const text = '''
Morning Routine:
- Wake up early
• Drink lemon tea
1. Morning walk
- [ ] Revise project
- [x] Gym session
''';
      final items = ThoughtChecklistHelper.parseItems(text);
      expect(items.length, 5);
      expect(items[0].text, 'Wake up early');
      expect(items[0].isDone, isFalse);

      expect(items[1].text, 'Drink lemon tea');
      expect(items[1].isDone, isFalse);

      expect(items[2].text, 'Morning walk');
      expect(items[2].isDone, isFalse);

      expect(items[3].text, 'Revise project');
      expect(items[3].isDone, isFalse);

      expect(items[4].text, 'Gym session');
      expect(items[4].isDone, isTrue);
    });

    test('toggles item done and undone correctly', () {
      const text = '''
- Wake up
- [ ] Drink lemon tea
- [x] Gym
''';
      // Toggle item 0 to done
      final t1 = ThoughtChecklistHelper.toggleItemDone(text, 0);
      expect(t1.contains('☑ Wake up'), isTrue);

      // Toggle item 2 to undone
      final t2 = ThoughtChecklistHelper.toggleItemDone(t1, 2);
      expect(t2.contains('☐ Gym'), isTrue);
    });

    test('setAllDone updates all items in thought', () {
      const text = '''
- Item 1
- [ ] Item 2
- [x] Item 3
''';
      final allDone = ThoughtChecklistHelper.setAllDone(text, true);
      expect(allDone.contains('☑ Item 1'), isTrue);
      expect(allDone.contains('☑ Item 2'), isTrue);
      expect(allDone.contains('☑ Item 3'), isTrue);

      final allUndone = ThoughtChecklistHelper.setAllDone(allDone, false);
      expect(allUndone.contains('☐ Item 1'), isTrue);
      expect(allUndone.contains('☐ Item 2'), isTrue);
      expect(allUndone.contains('☐ Item 3'), isTrue);
    });
  });

  group('Thought Wall Checklist UI, Activities Conversion & Completion Tests', () {
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
      'Renders checklist with individual checkboxes in thought bubble and toggles them',
      (tester) async {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: '''
☐ Wake up early
☐ Drink lemon tea
☐ Morning walk
''',
          ),
        );
        final thought = (await db.thoughtDao.getThoughtById(id))!;

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            timeTrackingProvider.overrideWith(_FakeTimeTrackingNotifier.new),
            studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
            recentThoughtsStreamProvider.overrideWith(
              (ref) => Stream.value([thought]),
            ),
            latestHomeThoughtProvider.overrideWith(
              (ref) => Stream.value(thought),
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

        // Verify all 3 items appear as checklist items
        expect(find.text('Wake up early'), findsOneWidget);
        expect(find.text('Drink lemon tea'), findsOneWidget);
        expect(find.text('Morning walk'), findsOneWidget);

        // Verify individual check boxes exist
        final check0 = find.byKey(ValueKey('thought_${id}_check_0'));
        expect(check0, findsOneWidget);

        // Tap first check box
        await tester.tap(check0);
        await tester.pumpAndSettle();

        // Verify database content has been updated to marked done
        final updatedThought = await db.thoughtDao.getThoughtById(id);
        expect(updatedThought!.content.contains('☑ Wake up early'), isTrue);
      },
    );

    testWidgets(
      'Convert to Activities button converts thought checklist items into today tasks',
      (tester) async {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: '''
- Wake up
- Drink lemon tea
- Morning walk
- Revise notes
- Gym session
''',
          ),
        );
        final thought = (await db.thoughtDao.getThoughtById(id))!;

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            timeTrackingProvider.overrideWith(_FakeTimeTrackingNotifier.new),
            studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
            recentThoughtsStreamProvider.overrideWith(
              (ref) => Stream.value([thought]),
            ),
            latestHomeThoughtProvider.overrideWith(
              (ref) => Stream.value(thought),
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

        // Find "Convert to activities" button
        final convertBtn = find.byKey(
          ValueKey('thought_${id}_convert_to_activities'),
        );
        expect(convertBtn, findsOneWidget);

        await tester.ensureVisible(convertBtn);
        await tester.tap(convertBtn);
        await tester.pumpAndSettle();

        // Verify 5 tasks were inserted into the task DAO
        final tasks = await db.select(db.taskTable).get();
        expect(tasks.length, 5);
        final titles = tasks.map((t) => t.title).toSet();
        expect(titles.contains('Wake up'), isTrue);
        expect(titles.contains('Drink lemon tea'), isTrue);
        expect(titles.contains('Gym session'), isTrue);
      },
    );

    testWidgets(
      'Mark full thought done toggles completion on the whole thought',
      (tester) async {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(content: '- Task 1\n- Task 2'),
        );
        final thought = (await db.thoughtDao.getThoughtById(id))!;

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            timeTrackingProvider.overrideWith(_FakeTimeTrackingNotifier.new),
            studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
            recentThoughtsStreamProvider.overrideWith(
              (ref) => Stream.value([thought]),
            ),
            latestHomeThoughtProvider.overrideWith(
              (ref) => Stream.value(thought),
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

        final fullDoneBtn = find.byKey(ValueKey('thought_${id}_full_done_btn'));
        expect(fullDoneBtn, findsOneWidget);

        await tester.tap(fullDoneBtn);
        await tester.pumpAndSettle();

        final completedThought = await db.thoughtDao.getThoughtById(id);
        expect(completedThought!.isCompleted, isTrue);
      },
    );

    testWidgets(
      'Thought Wall empty state is clean and free of prompt spark chips',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            timeTrackingProvider.overrideWith(_FakeTimeTrackingNotifier.new),
            studyStreakProvider.overrideWith(_FakeStudyStreakNotifier.new),
            recentThoughtsStreamProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            latestHomeThoughtProvider.overrideWith((ref) => Stream.value(null)),
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

        // Zero cheap spark chips
        expect(find.text('Spark idea'), findsNothing);
        expect(find.text('Spark an idea'), findsNothing);
        expect(find.text('Daily win'), findsNothing);
        expect(find.text('Log a win'), findsNothing);
        expect(find.text('Self-reflection'), findsNothing);
        expect(find.text('Reflect'), findsNothing);

        // Clean tranquil empty state
        expect(find.text('Your mindspace is clear'), findsOneWidget);
      },
    );
  });
}
