/// Four starter prompts for an empty chat, matched to the time of day
/// (CLAUDE.md §5.4). Each is something the assistant can do offline.
List<String> assistantSuggestions(DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 12) {
    return const [
      'Plan my day',
      'What tasks do I have today?',
      'Remind me to drink water at 11',
      'Study plan',
    ];
  }
  if (h >= 12 && h < 17) {
    return const [
      "Today's agenda",
      'Log 250ml water',
      'Start a 25-minute timer',
      'Meal plan',
    ];
  }
  if (h >= 17 && h < 21) {
    return const [
      "Today's agenda",
      'Show my spending this week',
      'Remind me to call tomorrow at 7 PM',
      'Meal plan',
    ];
  }
  return const [
    'Plan my day',
    'Show my reminders',
    'Find what I wrote about my interview',
    'Study plan',
  ];
}

/// Greeting under the sparkle in an empty chat.
String assistantGreeting(DateTime now) {
  final h = now.hour;
  final part = h >= 5 && h < 12
      ? 'morning'
      : h >= 12 && h < 17
      ? 'afternoon'
      : h >= 17 && h < 21
      ? 'evening'
      : 'night';
  return 'How can I help this $part?';
}
