import 'package:flutter/material.dart';

/// Icon and wording for a space, picked from its name so "Movies" feels like
/// a watch-list and "Books" like a reading list without any setup.
class SpaceStyle {
  const SpaceStyle({
    required this.icon,
    required this.noun,
    required this.doneLabel,
    required this.openLabel,
  });

  final IconData icon;

  /// What one entry is called ("movie", "book", "entry").
  final String noun;

  /// Past-tense label for a finished entry ("Watched").
  final String doneLabel;

  /// Label for an unfinished entry ("To watch").
  final String openLabel;

  String get addHint => 'Add a $noun…';
}

const _fallbackStyle = SpaceStyle(
  icon: Icons.folder_outlined,
  noun: 'entry',
  doneLabel: 'Done',
  openLabel: 'Open',
);

const _rules = <(List<String>, SpaceStyle)>[
  (
    ['movie', 'film', 'cinema'],
    SpaceStyle(
      icon: Icons.movie_outlined,
      noun: 'movie',
      doneLabel: 'Watched',
      openLabel: 'To watch',
    ),
  ),
  (
    ['series', 'show', 'anime', 'tv'],
    SpaceStyle(
      icon: Icons.live_tv_outlined,
      noun: 'show',
      doneLabel: 'Watched',
      openLabel: 'To watch',
    ),
  ),
  (
    ['book', 'novel', 'reading'],
    SpaceStyle(
      icon: Icons.menu_book_outlined,
      noun: 'book',
      doneLabel: 'Read',
      openLabel: 'To read',
    ),
  ),
  (
    ['song', 'music', 'playlist', 'album'],
    SpaceStyle(
      icon: Icons.music_note_outlined,
      noun: 'song',
      doneLabel: 'Heard',
      openLabel: 'To hear',
    ),
  ),
  (
    ['recipe', 'food', 'cook', 'restaurant', 'cafe'],
    SpaceStyle(
      icon: Icons.restaurant_outlined,
      noun: 'dish',
      doneLabel: 'Tried',
      openLabel: 'To try',
    ),
  ),
  (
    ['travel', 'trip', 'place', 'visit'],
    SpaceStyle(
      icon: Icons.flight_takeoff_outlined,
      noun: 'place',
      doneLabel: 'Visited',
      openLabel: 'To visit',
    ),
  ),
  (
    ['game', 'gaming'],
    SpaceStyle(
      icon: Icons.sports_esports_outlined,
      noun: 'game',
      doneLabel: 'Played',
      openLabel: 'To play',
    ),
  ),
  (
    ['buy', 'shopping', 'wishlist', 'gift'],
    SpaceStyle(
      icon: Icons.shopping_bag_outlined,
      noun: 'item',
      doneLabel: 'Bought',
      openLabel: 'To buy',
    ),
  ),
  (
    ['gym', 'workout', 'fitness', 'exercise'],
    SpaceStyle(
      icon: Icons.fitness_center_outlined,
      noun: 'workout',
      doneLabel: 'Done',
      openLabel: 'Planned',
    ),
  ),
  (
    ['learn', 'course', 'study'],
    SpaceStyle(
      icon: Icons.school_outlined,
      noun: 'topic',
      doneLabel: 'Learned',
      openLabel: 'To learn',
    ),
  ),
  (
    ['bug'],
    SpaceStyle(
      icon: Icons.bug_report_outlined,
      noun: 'bug',
      doneLabel: 'Fixed',
      openLabel: 'Open',
    ),
  ),
  (
    ['suggestion', 'idea'],
    SpaceStyle(
      icon: Icons.lightbulb_outline_rounded,
      noun: 'idea',
      doneLabel: 'Done',
      openLabel: 'Open',
    ),
  ),
  (
    ['goal'],
    SpaceStyle(
      icon: Icons.flag_outlined,
      noun: 'goal',
      doneLabel: 'Achieved',
      openLabel: 'In progress',
    ),
  ),
];

/// Style for the space called [name] (case-insensitive keyword match).
SpaceStyle spaceStyleFor(String name) {
  final lower = name.toLowerCase();
  for (final rule in _rules) {
    if (rule.$1.any(lower.contains)) return rule.$2;
  }
  return _fallbackStyle;
}
