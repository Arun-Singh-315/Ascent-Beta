class ThoughtChecklistItem {
  const ThoughtChecklistItem({
    required this.index,
    required this.lineIndex,
    required this.text,
    required this.isDone,
    required this.rawLine,
  });

  final int index;
  final int lineIndex;
  final String text;
  final bool isDone;
  final String rawLine;

  ThoughtChecklistItem copyWith({
    int? index,
    int? lineIndex,
    String? text,
    bool? isDone,
    String? rawLine,
  }) {
    return ThoughtChecklistItem(
      index: index ?? this.index,
      lineIndex: lineIndex ?? this.lineIndex,
      text: text ?? this.text,
      isDone: isDone ?? this.isDone,
      rawLine: rawLine ?? this.rawLine,
    );
  }
}

class ThoughtChecklistHelper {
  ThoughtChecklistHelper._();

  static final RegExp _checkedBoxRegex = RegExp(
    r'^\s*(?:[-*•]|-->|->|→|\d+[\.\)])?\s*\[[xX]\]\s+(.*)$',
  );
  static final RegExp _uncheckedBoxRegex = RegExp(
    r'^\s*(?:[-*•]|-->|->|→|\d+[\.\)])?\s*\[\s*\]\s+(.*)$',
  );
  static final RegExp _bulletOrNumberedRegex = RegExp(
    r'^\s*(?:[-*•]|-->|->|→|\d+[\.\)])\s+(.*)$',
  );

  /// Parses text into a list of [ThoughtChecklistItem]s.
  /// If a line is a bullet, numbered item, or bracket checklist, it is captured.
  static List<ThoughtChecklistItem> parseItems(String text) {
    final lines = text.split(RegExp(r'\r?\n'));
    final items = <ThoughtChecklistItem>[];
    var itemIndex = 0;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final checkedMatch = _checkedBoxRegex.firstMatch(line);
      if (checkedMatch != null) {
        final content = checkedMatch.group(1)?.trim() ?? '';
        if (content.isNotEmpty) {
          items.add(
            ThoughtChecklistItem(
              index: itemIndex++,
              lineIndex: i,
              text: content,
              isDone: true,
              rawLine: line,
            ),
          );
          continue;
        }
      }

      final uncheckedMatch = _uncheckedBoxRegex.firstMatch(line);
      if (uncheckedMatch != null) {
        final content = uncheckedMatch.group(1)?.trim() ?? '';
        if (content.isNotEmpty) {
          items.add(
            ThoughtChecklistItem(
              index: itemIndex++,
              lineIndex: i,
              text: content,
              isDone: false,
              rawLine: line,
            ),
          );
          continue;
        }
      }

      final bulletMatch = _bulletOrNumberedRegex.firstMatch(line);
      if (bulletMatch != null) {
        final content = bulletMatch.group(1)?.trim() ?? '';
        if (content.isNotEmpty) {
          items.add(
            ThoughtChecklistItem(
              index: itemIndex++,
              lineIndex: i,
              text: content,
              isDone: false,
              rawLine: line,
            ),
          );
          continue;
        }
      }
    }

    return items;
  }

  /// Whether the text contains at least one checklist item.
  static bool hasChecklistItems(String text) {
    return parseItems(text).isNotEmpty;
  }

  /// Toggles the item at [targetIndex] (0-based among checklist items).
  static String toggleItemDone(String text, int targetIndex) {
    final lines = text.split(RegExp(r'\r?\n'));
    final items = parseItems(text);

    if (targetIndex < 0 || targetIndex >= items.length) {
      return text;
    }

    final targetItem = items[targetIndex];
    final newDone = !targetItem.isDone;
    final prefix = newDone ? '- [x] ' : '- [ ] ';
    lines[targetItem.lineIndex] = '$prefix${targetItem.text}';

    return lines.join('\n');
  }

  /// Sets all checklist items in [text] to [done].
  static String setAllDone(String text, bool done) {
    final lines = text.split(RegExp(r'\r?\n'));
    final items = parseItems(text);

    if (items.isEmpty) return text;

    final prefix = done ? '- [x] ' : '- [ ] ';
    for (final item in items) {
      lines[item.lineIndex] = '$prefix${item.text}';
    }

    return lines.join('\n');
  }

  /// Whether all checklist items are completed.
  static bool areAllDone(List<ThoughtChecklistItem> items) {
    if (items.isEmpty) return false;
    return items.every((i) => i.isDone);
  }
}
