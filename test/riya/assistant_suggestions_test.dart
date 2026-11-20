import 'package:ascent/features/ai_assistant/assistant_suggestions.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  DateTime at(int h) => DateTime(2026, 11, 21, h);

  test('four suggestions, different for each part of the day', () {
    final morning = assistantSuggestions(at(8));
    final afternoon = assistantSuggestions(at(14));
    final evening = assistantSuggestions(at(19));
    final night = assistantSuggestions(at(23));
    for (final list in [morning, afternoon, evening, night]) {
      expect(list, hasLength(4));
    }
    expect(morning, isNot(equals(afternoon)));
    expect(evening, isNot(equals(night)));
  });

  test('greeting follows the time of day', () {
    expect(assistantGreeting(at(8)), 'How can I help this morning?');
    expect(assistantGreeting(at(14)), 'How can I help this afternoon?');
    expect(assistantGreeting(at(19)), 'How can I help this evening?');
    expect(assistantGreeting(at(2)), 'How can I help this night?');
  });
}
