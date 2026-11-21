import 'package:flutter/material.dart';

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

/// A small glyph for a suggestion tile, from the words it uses.
IconData assistantSuggestionIcon(String title) {
  final t = title.toLowerCase();
  if (t.contains('water')) return Icons.water_drop_outlined;
  if (t.contains('timer') || t.contains('focus')) return Icons.timer_outlined;
  if (t.contains('meal')) return Icons.restaurant_outlined;
  if (t.contains('spend') || t.contains('money')) {
    return Icons.account_balance_wallet_outlined;
  }
  if (t.contains('remind')) return Icons.notifications_none_rounded;
  if (t.contains('study')) return Icons.school_outlined;
  if (t.contains('find') || t.contains('wrote')) return Icons.search_rounded;
  if (t.contains('task') || t.contains('agenda')) {
    return Icons.checklist_rounded;
  }
  return Icons.wb_sunny_outlined;
}
