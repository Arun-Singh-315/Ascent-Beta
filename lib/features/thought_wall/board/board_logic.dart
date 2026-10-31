import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';

/// The category key every plain wall thought lives in. Every other category is
/// a "space" (Movies, Books, Bugs …) with its own page.
const wallCategoryKey = 'general';

/// Virtual space key used for the archive page.
const archiveSpaceKey = '__archive';

/// How a thought is drawn on the board. It is chosen from the text itself so
/// the wall has variety without the user configuring anything.
enum BoardCardKind {
  /// One short line: drawn in large type.
  spark,

  /// A normal paragraph or two.
  note,

  /// Two or more bullet/numbered/checkbox lines: drawn as a mini list.
  list,

  /// A long passage: clipped with a fade, opened in full on tap.
  long,
}

final _bulletLine = RegExp(r'^\s*(?:[-*•]|\d{1,3}[.)]|\[[ xX]?\])\s+(.+)$');
final _bulletPrefix = RegExp(r'^\s*(?:[-*•]|\d{1,3}[.)]|\[[ xX]?\])\s+');
final _lineBreak = RegExp(r'\r?\n');

/// True when the text carries the legacy high-priority markers.
bool isHighPriorityContent(String content) {
  final lower = content.toLowerCase();
  return content.contains('[HIGH]') ||
      lower.contains('#high') ||
      lower.contains('#urgent');
}

/// A private promise that has not been unlocked in this session. Its text must
/// not be shown anywhere (card, hero, detail, share).
bool isPrivateLocked(
  Thought thought,
  Set<int> privatePromiseIds,
  Set<int> unlockedPromiseIds,
) =>
    thought.mood == 'promise' &&
    privatePromiseIds.contains(thought.id) &&
    !unlockedPromiseIds.contains(thought.id);

/// Text shown on a card, without the "[HIGH] " storage marker.
String displayContent(String content) =>
    content.startsWith('[HIGH] ') ? content.substring(7) : content;

/// Adds or removes the "[HIGH] " marker (same storage format as before).
String toggleHighPriorityContent(String content) {
  if (content.contains('[HIGH]')) {
    return content.replaceAll('[HIGH] ', '').replaceAll('[HIGH]', '').trim();
  }
  return '[HIGH] $content';
}

List<String> _nonEmptyLines(String text) =>
    text.split(_lineBreak).where((l) => l.trim().isNotEmpty).toList();

/// Bullet items of a list-like thought (marker removed), or an empty list when
/// the text is not list-like.
List<String> bulletItems(String content) {
  final lines = _nonEmptyLines(displayContent(content));
  final bullets = lines.where(_bulletLine.hasMatch).toList();
  if (bullets.length < 2 || bullets.length * 2 < lines.length) return const [];
  return [for (final line in bullets) _bulletLine.firstMatch(line)!.group(1)!];
}

/// Picks the visual treatment for a thought from its text.
BoardCardKind boardCardKind(String content) {
  final text = displayContent(content).trim();
  final lines = _nonEmptyLines(text);
  if (bulletItems(content).isNotEmpty) return BoardCardKind.list;
  if (text.length > 280 || lines.length > 8) return BoardCardKind.long;
  if (lines.length <= 1 && text.length <= 48) return BoardCardKind.spark;
  return BoardCardKind.note;
}

/// Rough card height, only used to balance the two columns.
double estimateCardHeight(Thought thought, {required double columnWidth}) {
  final kind = boardCardKind(thought.content);
  final text = displayContent(thought.content);
  final charsPerLine = (columnWidth / (kind == BoardCardKind.spark ? 12 : 7.5))
      .clamp(8, 80);
  final paragraphs = text.split(_lineBreak);
  var lines = 0.0;
  for (final p in paragraphs) {
    lines += (p.trim().length / charsPerLine).ceil().clamp(1, 99);
  }
  final maxLines = switch (kind) {
    BoardCardKind.spark => 3,
    BoardCardKind.note => 7,
    BoardCardKind.list => 6,
    BoardCardKind.long => 9,
  };
  final lineHeight = kind == BoardCardKind.spark ? 32.0 : 22.0;
  return 64 + lines.clamp(1, maxLines).toDouble() * lineHeight;
}

/// Splits [items] into [columns] lists, always adding the next item to the
/// currently shortest column. Order inside each column follows the input.
List<List<T>> balanceColumns<T>(
  List<T> items,
  int columns,
  double Function(T item) heightOf,
) {
  final count = columns < 1 ? 1 : columns;
  final result = List.generate(count, (_) => <T>[]);
  final heights = List<double>.filled(count, 0);
  for (final item in items) {
    var shortest = 0;
    for (var i = 1; i < count; i++) {
      if (heights[i] < heights[shortest]) shortest = i;
    }
    result[shortest].add(item);
    heights[shortest] += heightOf(item);
  }
  return result;
}

/// A dated group of thoughts on the board.
class BoardSection {
  const BoardSection(this.label, this.thoughts);
  final String label;
  final List<Thought> thoughts;
}

/// Everything the board draws, derived from the active wall thoughts.
class BoardContent {
  const BoardContent({
    required this.hero,
    required this.sections,
    required this.done,
  });
  final Thought? hero;
  final List<BoardSection> sections;
  final List<Thought> done;

  bool get isEmpty => hero == null && sections.isEmpty && done.isEmpty;
}

DateTime _dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// Section label for a thought written on [at], viewed on [now].
String boardDayLabel(DateTime at, DateTime now) {
  final days = _dayOf(now).difference(_dayOf(at)).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return 'This week';
  if (at.year == now.year) return DateFormat('MMMM').format(at);
  return DateFormat('MMMM y').format(at);
}

int _newestFirst(Thought a, Thought b) {
  final byDate = b.createdAt.compareTo(a.createdAt);
  return byDate != 0 ? byDate : b.id.compareTo(a.id);
}

/// Builds the board from the non-archived thoughts that belong on the wall.
///
/// * [heroId] (a thought opened from Home) or else the newest open thought
///   becomes the hero card, unless it is in [excludedFromHero].
/// * Pinned open thoughts form a "Pinned" section.
/// * The rest are grouped by day, newest first.
/// * Completed thoughts are returned separately.
BoardContent buildBoardContent(
  List<Thought> wallThoughts, {
  required DateTime now,
  int? heroId,
  Set<int> excludedFromHero = const {},
}) {
  final open = wallThoughts.where((t) => !t.isCompleted).toList()
    ..sort(_newestFirst);
  final done = wallThoughts.where((t) => t.isCompleted).toList()
    ..sort(_newestFirst);

  Thought? hero;
  if (heroId != null) {
    hero = open.where((t) => t.id == heroId).firstOrNull;
  }
  hero ??= open.where((t) => !excludedFromHero.contains(t.id)).firstOrNull;
  final rest = open.where((t) => t.id != hero?.id).toList();

  final sections = <BoardSection>[];
  final pinned = rest.where((t) => t.isPinned).toList();
  if (pinned.isNotEmpty) sections.add(BoardSection('Pinned', pinned));

  final labels = <String>[];
  final byLabel = <String, List<Thought>>{};
  for (final thought in rest.where((t) => !t.isPinned)) {
    final label = boardDayLabel(thought.createdAt, now);
    if (!byLabel.containsKey(label)) labels.add(label);
    byLabel.putIfAbsent(label, () => []).add(thought);
  }
  for (final label in labels) {
    sections.add(BoardSection(label, byLabel[label]!));
  }
  return BoardContent(hero: hero, sections: sections, done: done);
}

/// Summary of one space for the shelf.
class SpaceSummary {
  const SpaceSummary({
    required this.key,
    required this.name,
    required this.total,
    required this.done,
    required this.latest,
  });
  final String key;
  final String name;

  /// Non-archived entries.
  final int total;

  /// Completed non-archived entries.
  final int done;
  final DateTime? latest;

  bool get isBuiltIn => ThoughtDao.builtInCategories.containsKey(key);
}

/// Spaces for the shelf: every category except the wall itself.
///
/// Built-in spaces with no entries stay hidden; spaces the user created are
/// always shown. Spaces with recent activity come first.
List<SpaceSummary> buildSpaceSummaries(
  Map<String, String> categories,
  List<Thought> active,
  List<Thought> archived,
) {
  final summaries = <SpaceSummary>[];
  for (final entry in categories.entries) {
    if (entry.key == wallCategoryKey) continue;
    final mine = active.where((t) => t.category == entry.key).toList();
    final archivedCount = archived.where((t) => t.category == entry.key).length;
    final builtIn = ThoughtDao.builtInCategories.containsKey(entry.key);
    if (builtIn && mine.isEmpty && archivedCount == 0) continue;
    DateTime? latest;
    for (final t in mine) {
      if (latest == null || t.createdAt.isAfter(latest)) latest = t.createdAt;
    }
    summaries.add(
      SpaceSummary(
        key: entry.key,
        name: entry.value,
        total: mine.length,
        done: mine.where((t) => t.isCompleted).length,
        latest: latest,
      ),
    );
  }
  summaries.sort((a, b) {
    if (a.latest != null && b.latest != null) {
      return b.latest!.compareTo(a.latest!);
    }
    if (a.latest != null) return -1;
    if (b.latest != null) return 1;
    return a.name.toLowerCase().compareTo(b.name.toLowerCase());
  });
  return summaries;
}

/// Splits pasted or typed text into separate entries, one per non-empty line.
/// List markers ("-", "•", "1.", "[ ]") are removed. At most [max] entries.
List<String> splitEntries(String raw, {int max = 100}) {
  final entries = <String>[];
  for (final line in raw.split(_lineBreak)) {
    final clean = line.replaceFirst(_bulletPrefix, '').trim();
    if (clean.isEmpty) continue;
    entries.add(clean);
    if (entries.length >= max) break;
  }
  return entries;
}

/// First line (title) and remaining text (notes) of an entry.
({String title, String? body}) entryParts(String content) {
  final lines = displayContent(content).trim().split(_lineBreak);
  final title = lines.first.trim();
  final body = lines.skip(1).join('\n').trim();
  return (title: title, body: body.isEmpty ? null : body);
}

/// Short time label: clock time for today, "Oct 28" otherwise.
String boardTimeLabel(DateTime at, DateTime now) {
  final sameDay = _dayOf(at) == _dayOf(now);
  return DateFormat(sameDay ? 'h:mm a' : 'MMM d').format(at);
}

/// Stable small hash (String.hashCode is not guaranteed stable across runs).
int stableHash(String value) {
  var hash = 7;
  for (final unit in value.codeUnits) {
    hash = (hash * 31 + unit) & 0x7fffffff;
  }
  return hash;
}

/// Result of [parseSpaceTag].
typedef SpaceTag = ({String key, String text});

/// Reads a leading "#space" tag, so "#movies Inception" files "Inception"
/// straight into the Movies space. Matches the longest existing space name,
/// ignoring case. Returns null when there is no tag, no matching space, or
/// nothing is left after the tag.
SpaceTag? parseSpaceTag(String raw, Map<String, String> categories) {
  final text = raw.trimLeft();
  if (!text.startsWith('#')) return null;
  final lower = text.toLowerCase();
  final candidates = categories.entries
      .where((e) => e.key != wallCategoryKey)
      .toList()
    ..sort((a, b) => b.value.length.compareTo(a.value.length));
  for (final entry in candidates) {
    final tag = '#${entry.value.toLowerCase()}';
    if (!lower.startsWith(tag)) continue;
    final rest = text.substring(tag.length);
    if (rest.isNotEmpty && !RegExp(r'^\s').hasMatch(rest)) continue;
    final clean = rest.trim();
    if (clean.isEmpty) return null;
    return (key: entry.key, text: clean);
  }
  return null;
}
