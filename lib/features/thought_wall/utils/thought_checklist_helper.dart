class ThoughtChecklistItem {
  const ThoughtChecklistItem({
    required this.index,
    required this.lineIndex,
    required this.text,
    required this.isDone,
    required this.rawLine,
    this.isHighlighted = false,
  });

  final int index;
  final int lineIndex;
  final String text;
  final bool isDone;
  final String rawLine;
  final bool isHighlighted;

  ThoughtChecklistItem copyWith({
    int? index,
    int? lineIndex,
    String? text,
    bool? isDone,
    String? rawLine,
    bool? isHighlighted,
  }) {
    return ThoughtChecklistItem(
      index: index ?? this.index,
      lineIndex: lineIndex ?? this.lineIndex,
      text: text ?? this.text,
      isDone: isDone ?? this.isDone,
      rawLine: rawLine ?? this.rawLine,
      isHighlighted: isHighlighted ?? this.isHighlighted,
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

  static ({String cleanText, bool isHighlighted}) _extractHighlight(
    String content,
  ) {
    var isHighlighted = false;
    var cleanText = content;

    if (cleanText.startsWith('★ ') ||
        cleanText.startsWith('⭐ ') ||
        cleanText.startsWith('[!] ')) {
      isHighlighted = true;
      cleanText = cleanText.substring(cleanText.indexOf(' ') + 1).trim();
    } else if (cleanText.startsWith('★') || cleanText.startsWith('⭐')) {
      isHighlighted = true;
      cleanText = cleanText.substring(1).trim();
    } else if (cleanText.startsWith('==') &&
        cleanText.endsWith('==') &&
        cleanText.length > 4) {
      isHighlighted = true;
      cleanText = cleanText.substring(2, cleanText.length - 2).trim();
    }

    return (cleanText: cleanText, isHighlighted: isHighlighted);
  }

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
          final parsed = _extractHighlight(content);
          items.add(
            ThoughtChecklistItem(
              index: itemIndex++,
              lineIndex: i,
              text: parsed.cleanText,
              isDone: true,
              rawLine: line,
              isHighlighted: parsed.isHighlighted,
            ),
          );
          continue;
        }
      }

      final uncheckedMatch = _uncheckedBoxRegex.firstMatch(line);
      if (uncheckedMatch != null) {
        final content = uncheckedMatch.group(1)?.trim() ?? '';
        if (content.isNotEmpty) {
          final parsed = _extractHighlight(content);
          items.add(
            ThoughtChecklistItem(
              index: itemIndex++,
              lineIndex: i,
              text: parsed.cleanText,
              isDone: false,
              rawLine: line,
              isHighlighted: parsed.isHighlighted,
            ),
          );
          continue;
        }
      }

      final bulletMatch = _bulletOrNumberedRegex.firstMatch(line);
      if (bulletMatch != null) {
        final content = bulletMatch.group(1)?.trim() ?? '';
        if (content.isNotEmpty) {
          final parsed = _extractHighlight(content);
          items.add(
            ThoughtChecklistItem(
              index: itemIndex++,
              lineIndex: i,
              text: parsed.cleanText,
              isDone: false,
              rawLine: line,
              isHighlighted: parsed.isHighlighted,
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
    final highlightMarker = targetItem.isHighlighted ? '★ ' : '';
    lines[targetItem.lineIndex] = '$prefix$highlightMarker${targetItem.text}';

    return lines.join('\n');
  }

  /// Toggles the highlight / importance of the item at [targetIndex].
  static String toggleItemHighlight(String text, int targetIndex) {
    final lines = text.split(RegExp(r'\r?\n'));
    final items = parseItems(text);

    if (targetIndex < 0 || targetIndex >= items.length) {
      return text;
    }

    final targetItem = items[targetIndex];
    final newHighlighted = !targetItem.isHighlighted;
    final highlightMarker = newHighlighted ? '★ ' : '';

    String prefix;
    if (_checkedBoxRegex.hasMatch(targetItem.rawLine)) {
      prefix = '- [x] ';
    } else if (_uncheckedBoxRegex.hasMatch(targetItem.rawLine)) {
      prefix = '- [ ] ';
    } else {
      final match = RegExp(
        r'^\s*(?:[-*•]|-->|->|→|\d+[\.\)])\s*',
      ).firstMatch(targetItem.rawLine);
      prefix = match != null ? match.group(0)! : '- ';
    }

    lines[targetItem.lineIndex] = '$prefix$highlightMarker${targetItem.text}';

    return lines.join('\n');
  }

  /// Sets all checklist items in [text] to [done].
  static String setAllDone(String text, bool done) {
    final lines = text.split(RegExp(r'\r?\n'));
    final items = parseItems(text);

    if (items.isEmpty) return text;

    final prefix = done ? '- [x] ' : '- [ ] ';
    for (final item in items) {
      final highlightMarker = item.isHighlighted ? '★ ' : '';
      lines[item.lineIndex] = '$prefix$highlightMarker${item.text}';
    }

    return lines.join('\n');
  }

  /// Whether all checklist items are completed.
  static bool areAllDone(List<ThoughtChecklistItem> items) {
    if (items.isEmpty) return false;
    return items.every((i) => i.isDone);
  }
}
