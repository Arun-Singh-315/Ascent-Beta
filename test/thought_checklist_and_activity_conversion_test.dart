import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/streak/study_streak_provider.dart';
import 'package:ascent/features/thought_wall/utils/thought_checklist_helper.dart';
import 'package:drift/native.dart';
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




  });
}
