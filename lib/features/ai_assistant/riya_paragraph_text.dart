import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Renders multi-paragraph, structured conversational responses from Riya
/// with clean paragraph spacing, bulleted lists, numbered lists, section headers,
/// blockquotes, and inline bold/code formatting.
class RiyaParagraphText extends StatelessWidget {
  final String text;
  final TextStyle baseStyle;
  final Color accentColor;
  final bool isUser;

  const RiyaParagraphText({
    super.key,
    required this.text,
    required this.baseStyle,
    required this.accentColor,
    this.isUser = false,
  });

  @override
  Widget build(BuildContext context) {
    if (text.trim().isEmpty) return const SizedBox.shrink();

    // Fast path: single-line plain text with no linebreaks, lists, or markdown tokens
    if (!text.contains('\n') &&
        !text.contains('**') &&
        !text.contains('`') &&
        !text.contains('*') &&
        !text.startsWith('> ')) {
      return Text(text, style: baseStyle);
    }

    // Split on double (or more) newlines into distinct paragraph blocks
    final rawBlocks = text.split(RegExp(r'\r?\n\s*\r?\n'));
    final blockWidgets = <Widget>[];

    for (var i = 0; i < rawBlocks.length; i++) {
      final block = rawBlocks[i].trim();
      if (block.isEmpty) continue;

      if (blockWidgets.isNotEmpty) {
        blockWidgets.add(const SizedBox(height: 10));
      }

      // 1. Heading block: ### Title or ## Title
      if (block.startsWith('### ') || block.startsWith('## ')) {
        final headingText = block.replaceFirst(RegExp(r'^#{2,3}\s*'), '');
        blockWidgets.add(
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 2),
            child: Text(
              headingText,
              style: baseStyle.copyWith(
                fontSize: (baseStyle.fontSize ?? 14.5) + 1.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.1,
              ),
            ),
          ),
        );
        continue;
      }

      // 2. Blockquote: > Quote
      if (block.startsWith('> ')) {
        final quoteText = block.replaceFirst(RegExp(r'^>\s*'), '');
        blockWidgets.add(
          Container(
            padding: const EdgeInsets.only(left: 10, top: 4, bottom: 4),
            decoration: BoxDecoration(
              border: Border(
                left: BorderSide(
                  color: accentColor.withValues(alpha: 0.7),
                  width: 3,
                ),
              ),
            ),
            child: Text(
              quoteText,
              style: baseStyle.copyWith(
                fontStyle: FontStyle.italic,
                color: baseStyle.color?.withValues(alpha: 0.9),
              ),
            ),
          ),
        );
        continue;
      }

      // 3. Multi-line block with list items or single newlines
      final lines = block.split(RegExp(r'\r?\n'));
      if (lines.length > 1 && lines.any((l) => _isListLine(l))) {
        final listWidgets = <Widget>[];
        for (final line in lines) {
          final trimmedLine = line.trim();
          if (trimmedLine.isEmpty) continue;

          if (_isBulletLine(trimmedLine)) {
            final content = trimmedLine.replaceFirst(RegExp(r'^[-*•]\s*'), '');
            listWidgets.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 7, right: 8),
                      child: Container(
                        width: 5.5,
                        height: 5.5,
                        decoration: BoxDecoration(
                          color: isUser
                              ? baseStyle.color?.withValues(alpha: 0.7)
                              : accentColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildFormattedText(content, baseStyle, accentColor),
                    ),
                  ],
                ),
              ),
            );
          } else if (_isNumberedLine(trimmedLine)) {
            final match = RegExp(r'^(\d+)\.\s*(.*)').firstMatch(trimmedLine);
            final number = match?.group(1) ?? '1';
            final content = match?.group(2) ?? trimmedLine;
            listWidgets.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 22,
                      child: Text(
                        '$number.',
                        style: baseStyle.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isUser
                              ? baseStyle.color?.withValues(alpha: 0.8)
                              : accentColor,
                          fontSize: (baseStyle.fontSize ?? 14.5) - 0.5,
                        ),
                      ),
                    ),
                    Expanded(
                      child: _buildFormattedText(content, baseStyle, accentColor),
                    ),
                  ],
                ),
              ),
            );
          } else {
            listWidgets.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: _buildFormattedText(trimmedLine, baseStyle, accentColor),
              ),
            );
          }
        }
        blockWidgets.add(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: listWidgets,
          ),
        );
      } else {
        // Standard paragraph
        blockWidgets.add(_buildFormattedText(block, baseStyle, accentColor));
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: blockWidgets,
    );
  }

  static bool _isListLine(String line) =>
      _isBulletLine(line.trim()) || _isNumberedLine(line.trim());

  static bool _isBulletLine(String line) =>
      line.startsWith('- ') || line.startsWith('* ') || line.startsWith('• ');

  static bool _isNumberedLine(String line) =>
      RegExp(r'^\d+\.\s+').hasMatch(line);

  static Widget _buildFormattedText(
    String content,
    TextStyle baseStyle,
    Color accentColor,
  ) {
    if (!content.contains('**') &&
        !content.contains('`') &&
        !content.contains('*')) {
      return Text(content, style: baseStyle);
    }

    final spans = <InlineSpan>[];
    final pattern = RegExp(r'(\*\*[^*]+\*\*|`[^`]+`|\*[^*]+\*)');
    int lastIndex = 0;

    for (final match in pattern.allMatches(content)) {
      if (match.start > lastIndex) {
        spans.add(
          TextSpan(
            text: content.substring(lastIndex, match.start),
            style: baseStyle,
          ),
        );
      }
      final raw = match.group(0)!;
      if (raw.startsWith('**') && raw.endsWith('**') && raw.length >= 4) {
        spans.add(
          TextSpan(
            text: raw.substring(2, raw.length - 2),
            style: baseStyle.copyWith(fontWeight: FontWeight.w700),
          ),
        );
      } else if (raw.startsWith('`') && raw.endsWith('`') && raw.length >= 2) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
              margin: const EdgeInsets.symmetric(horizontal: 2),
              decoration: BoxDecoration(
                color: baseStyle.color?.withValues(alpha: 0.08) ??
                    Colors.black.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                raw.substring(1, raw.length - 1),
                style: GoogleFonts.jetBrainsMono(
                  fontSize: (baseStyle.fontSize ?? 14.5) - 1.5,
                  fontWeight: FontWeight.w600,
                  color: baseStyle.color,
                ),
              ),
            ),
          ),
        );
      } else if (raw.startsWith('*') && raw.endsWith('*') && raw.length >= 2) {
        spans.add(
          TextSpan(
            text: raw.substring(1, raw.length - 1),
            style: baseStyle.copyWith(fontStyle: FontStyle.italic),
          ),
        );
      }
      lastIndex = match.end;
    }

    if (lastIndex < content.length) {
      spans.add(
        TextSpan(
          text: content.substring(lastIndex),
          style: baseStyle,
        ),
      );
    }

    return Text.rich(
      TextSpan(children: spans),
      style: baseStyle,
    );
  }
}
