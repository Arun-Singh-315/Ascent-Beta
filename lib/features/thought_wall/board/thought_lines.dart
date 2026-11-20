import '../utils/thought_checklist_helper.dart';

/// How bullets of a thought are drawn. A view choice only: the stored text
/// ("- [ ] item" / "- [x] item" / "- item") is never rewritten by switching.
enum BulletStyle {
  /// A circle before each bullet; tapping it ticks the line.
  todo,

  /// A plain bullet, no circle.
  bullet;

  static BulletStyle? fromStorage(String? value) => switch (value) {
    'todo' => BulletStyle.todo,
    'bullet' => BulletStyle.bullet,
    _ => null,
  };

  String get storage => name;
}

/// Stored style, falling back to the user's default.
BulletStyle resolveBulletStyle(String? stored, BulletStyle fallback) =>
    BulletStyle.fromStorage(stored) ?? fallback;

/// One non-empty line of a thought.
class ThoughtLine {
  const ThoughtLine({
    required this.text,
    this.itemIndex,
    this.isDone = false,
    this.isHighlighted = false,
    this.glyph,
  });

  /// Text without its typed marker ("- ", "→ ", "[ ] " ...).
  final String text;

  /// Index among the checklist items of the thought (the index
  /// [ThoughtChecklistHelper.toggleItemDone] expects), or null for plain text.
  final int? itemIndex;
  final bool isDone;
  final bool isHighlighted;

  /// The typed bullet glyph ("→", "•", "-", "1." ...), kept so plain style can
  /// draw the arrow the user chose.
  final String? glyph;

  bool get isItem => itemIndex != null;
}

final _glyph = RegExp(r'^\s*(-->|->|→|[-*•]|\d{1,3}[.)])(?=\s)');

/// Splits [content] into lines. This is the only place that decides what a
/// bullet is: it reuses [ThoughtChecklistHelper], so card, checklist toggles
/// and conversion always agree.
List<ThoughtLine> parseThoughtLines(String content) {
  final lines = content.split(RegExp(r'\r?\n'));
  final byLine = {
    for (final item in ThoughtChecklistHelper.parseItems(content))
      item.lineIndex: item,
  };
  final out = <ThoughtLine>[];
  for (var i = 0; i < lines.length; i++) {
    final raw = lines[i];
    if (raw.trim().isEmpty) continue;
    final item = byLine[i];
    if (item == null) {
      out.add(ThoughtLine(text: raw.trimRight()));
      continue;
    }
    final glyph = _glyph.firstMatch(item.rawLine)?.group(1);
    out.add(
      ThoughtLine(
        text: item.text,
        itemIndex: item.index,
        isDone: item.isDone,
        isHighlighted: item.isHighlighted,
        glyph: glyph == '-' || glyph == '*' ? '•' : glyph,
      ),
    );
  }
  return out;
}

/// Bullet items of a list-like thought, or empty when it is not list-like
/// (fewer than two items, or items are a minority of the lines).
List<ThoughtLine> listItems(String content) {
  final lines = parseThoughtLines(content);
  final items = lines.where((l) => l.isItem).toList();
  if (items.length < 2 || items.length * 2 < lines.length) return const [];
  return items;
}

/// "2/5" for the card footer, or null with fewer than two items.
String? progressLabel(String content) {
  final items = listItems(content);
  if (items.isEmpty) return null;
  final done = items.where((l) => l.isDone).length;
  return '$done/${items.length}';
}

/// True when every item is ticked (at least one item).
bool allItemsDone(String content) {
  final items = parseThoughtLines(content).where((l) => l.isItem).toList();
  return items.isNotEmpty && items.every((l) => l.isDone);
}
