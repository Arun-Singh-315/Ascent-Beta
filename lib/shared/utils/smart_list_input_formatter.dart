import 'package:flutter/services.dart';

/// Intelligent text formatter that:
/// 1. Auto-converts ASCII bullet shorthand ("-> " or "--> ") into clean bullet "• ".
/// 2. Automatically continues bullet ("• ") or numbered ("1. ", "2. ") list items on Enter.
/// 3. Cleanly exits list mode if Enter is pressed on an empty bullet/number line.
class SmartListInputFormatter extends TextInputFormatter {
  const SmartListInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    if (newValue.text.length > oldValue.text.length &&
        newValue.selection.isCollapsed) {
      final changeStart =
          oldValue.selection.baseOffset.clamp(0, oldValue.text.length);
      final inserted = newValue.text.substring(
        changeStart,
        newValue.selection.baseOffset.clamp(0, newValue.text.length),
      );

      // 1. Auto-continue list on Enter (\n)
      if (inserted == '\n') {
        final textBeforeEnter = oldValue.text.substring(0, changeStart);
        final lineStart = textBeforeEnter.lastIndexOf('\n') + 1;
        final prevLine = textBeforeEnter.substring(lineStart);

        final bulletMatch =
            RegExp(r'^(\s*)(?:[•\-\*]|-->|->|→)\s*(.*)$').firstMatch(prevLine);
        final numberMatch =
            RegExp(r'^(\s*)(\d+)([\.\)])\s*(.*)$').firstMatch(prevLine);

        if (bulletMatch != null) {
          final indent = bulletMatch.group(1) ?? '';
          final content = bulletMatch.group(2) ?? '';
          if (content.trim().isEmpty) {
            // Empty bullet line -> cleanly exit list mode by deleting the bullet
            final newText =
                oldValue.text.replaceRange(lineStart, changeStart, '');
            return TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: lineStart),
            );
          } else {
            // Auto-continue bullet on the new line
            const nextMarker = '• ';
            final insertText = '\n$indent$nextMarker';
            final newText = oldValue.text.replaceRange(
              changeStart,
              oldValue.selection.end.clamp(0, oldValue.text.length),
              insertText,
            );
            final newCursor = changeStart + insertText.length;
            return TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: newCursor),
            );
          }
        } else if (numberMatch != null) {
          final indent = numberMatch.group(1) ?? '';
          final numVal = int.tryParse(numberMatch.group(2) ?? '1') ?? 1;
          final delimiter = numberMatch.group(3) ?? '.';
          final content = numberMatch.group(4) ?? '';
          if (content.trim().isEmpty) {
            // Empty number line -> cleanly exit list mode
            final newText =
                oldValue.text.replaceRange(lineStart, changeStart, '');
            return TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: lineStart),
            );
          } else {
            // Auto-continue with next number (e.g. "2. ")
            final nextMarker = '${numVal + 1}$delimiter ';
            final insertText = '\n$indent$nextMarker';
            final newText = oldValue.text.replaceRange(
              changeStart,
              oldValue.selection.end.clamp(0, oldValue.text.length),
              insertText,
            );
            final newCursor = changeStart + insertText.length;
            return TextEditingValue(
              text: newText,
              selection: TextSelection.collapsed(offset: newCursor),
            );
          }
        }
      }

      // 2. Auto-convert "-> " or "--> " at start of line into "• "
      if (inserted == ' ') {
        final textBeforeSpace =
            newValue.text.substring(0, newValue.selection.baseOffset);
        final lineStart = textBeforeSpace.lastIndexOf('\n') + 1;
        final currentLine = textBeforeSpace.substring(lineStart);

        if (RegExp(r'^\s*(?:-->|->)\s$').hasMatch(currentLine)) {
          final dashIndex = currentLine.indexOf('-');
          final ws = currentLine.substring(0, dashIndex);
          const replacement = '• ';
          final newText = newValue.text.replaceRange(
            lineStart,
            newValue.selection.baseOffset,
            '$ws$replacement',
          );
          final newCursor = lineStart + ws.length + replacement.length;
          return TextEditingValue(
            text: newText,
            selection: TextSelection.collapsed(offset: newCursor),
          );
        }
      }
    }

    return newValue;
  }
}
