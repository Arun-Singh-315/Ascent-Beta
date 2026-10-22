import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';

void main() {
  group('Thought Sharing Formatter Tests', () {
    test('Formats plain thought content cleanly for sharing to WhatsApp and other apps', () {
      final thought = Thought(
        category: 'general',
        id: 1,
        content: 'Consistency is more powerful than occasional intensity.',
        mood: 'calm',
        colorHex: '#0284C7',
        isPinned: false,
        isArchived: false,
        isCompleted: false,
        createdAt: DateTime(2026, 10, 9, 10, 0),
      );

      final formatted = formatThoughtForShare(thought);
      expect(formatted, contains('"Consistency is more powerful than occasional intensity."'));
      expect(formatted, contains('— Mind Space · Ascent'));
      expect(formatted, isNot(contains('Prompt:')));
    });

    test('Includes reflection prompt question when present', () {
      final thought = Thought(
        category: 'general',
        id: 2,
        content: 'I managed to finish all my deep work tasks despite feeling tired.',
        mood: 'focus',
        colorHex: '#0284C7',
        promptQuestion: 'What went surprisingly well today?',
        isPinned: true,
        isArchived: false,
        isCompleted: false,
        createdAt: DateTime(2026, 10, 9, 10, 0),
      );

      final formatted = formatThoughtForShare(thought);
      expect(formatted, contains('💭 Prompt: What went surprisingly well today?'));
      expect(formatted, contains('"I managed to finish all my deep work tasks despite feeling tired."'));
      expect(formatted, contains('— Mind Space · Ascent'));
    });
  });
}
