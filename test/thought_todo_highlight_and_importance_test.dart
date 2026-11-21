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
      expect(toggled.contains('☑ ★ Important to-do'), isTrue);

      final undone = ThoughtChecklistHelper.toggleItemDone(toggled, 0);
      expect(undone.contains('☐ ★ Important to-do'), isTrue);
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



  });
}
