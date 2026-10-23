import 'package:flutter/material.dart';

import '../../app/theme/glass_theme.dart';

/// Measures the rendered text rather than guessing truncation by character count,
/// with rich styled arrow markers (`→ `) for plan items.
class ThoughtExcerpt extends StatefulWidget {
  const ThoughtExcerpt({
    super.key,
    required this.content,
    required this.style,
    this.maxLines = 2,
    this.arrowColor,
  });

  final String content;
  final TextStyle style;
  final int maxLines;
  final Color? arrowColor;

  /// Formats raw text by replacing ASCII `-->` with clean `→ ` and `--` with `• `.
  static String formatArrowContent(String raw) {
    return raw
        .replaceAllMapped(
          RegExp(r'(^|\n)[ \t]*-->[ \t]*', multiLine: true),
          (m) => '${m[1]}→ ',
        )
        .replaceAllMapped(
          RegExp(r'(^|\n)[ \t]*--[ \t]*', multiLine: true),
          (m) => '${m[1]}• ',
        )
        .replaceAll('-->', '→');
  }

  static String displayContent(String raw) => formatArrowContent(
    raw,
  ).replaceAll(RegExp(r'^[ \t]*→[ \t]*', multiLine: true), '').trimRight();

  /// Builds a [TextSpan] that visually styles arrow indicators (`→ `) and bullets (`• `)
  /// with vibrant theme accent ink.
  static TextSpan buildRichArrowSpan({
    required BuildContext context,
    required String text,
    required TextStyle baseStyle,
    Color? arrowColor,
  }) {
    // Planning markers remain in storage for editing/conversion, but are not note text.
    final formatted = displayContent(text);
    final accent = arrowColor ?? context.glass.clay;
    final lines = formatted.split('\n');
    final List<InlineSpan> spans = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i > 0) spans.add(const TextSpan(text: '\n'));

      if (line.trimLeft().startsWith('→ ')) {
        final leadingWhitespace = line.substring(0, line.indexOf('→ '));
        final restOfLine = line.substring(line.indexOf('→ ') + 2);
        if (leadingWhitespace.isNotEmpty) {
          spans.add(TextSpan(text: leadingWhitespace, style: baseStyle));
        }
        spans.add(
          TextSpan(
            text: '→ ',
            style: baseStyle.copyWith(
              color: accent,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
            ),
          ),
        );
        spans.add(TextSpan(text: restOfLine, style: baseStyle));
      } else if (line.trimLeft().startsWith('• ')) {
        final leadingWhitespace = line.substring(0, line.indexOf('• '));
        final restOfLine = line.substring(line.indexOf('• ') + 2);
        if (leadingWhitespace.isNotEmpty) {
          spans.add(TextSpan(text: leadingWhitespace, style: baseStyle));
        }
        spans.add(
          TextSpan(
            text: '• ',
            style: baseStyle.copyWith(
              color: accent,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
        spans.add(TextSpan(text: restOfLine, style: baseStyle));
      } else {
        spans.add(TextSpan(text: line, style: baseStyle));
      }
    }

    return TextSpan(children: spans, style: baseStyle);
  }

  @override
  State<ThoughtExcerpt> createState() => _ThoughtExcerptState();
}

class _ThoughtExcerptState extends State<ThoughtExcerpt> {
  bool _expanded = false;

  @override
  void didUpdateWidget(covariant ThoughtExcerpt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.content != widget.content) _expanded = false;
  }

  @override
  Widget build(BuildContext context) {
    final richSpan = ThoughtExcerpt.buildRichArrowSpan(
      context: context,
      text: widget.content.trimRight(),
      baseStyle: widget.style,
      arrowColor: widget.arrowColor,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: richSpan,
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          ellipsis: '…',
        )..layout(maxWidth: constraints.maxWidth);
        final overflow = painter.didExceedMaxLines;
        painter.dispose();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text.rich(
              richSpan,
              maxLines: _expanded ? null : widget.maxLines,
              overflow: _expanded
                  ? TextOverflow.visible
                  : TextOverflow.ellipsis,
            ),
            if (overflow)
              TextButton.icon(
                onPressed: () => setState(() => _expanded = !_expanded),
                style: TextButton.styleFrom(
                  foregroundColor: widget.arrowColor ?? context.glass.clay,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  minimumSize: const Size(0, 48),
                  alignment: Alignment.centerLeft,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                  backgroundColor: Colors.transparent,
                  side: BorderSide.none,
                ),
                icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                ),
                label: Text(_expanded ? 'Read less' : 'Read more'),
              ),
          ],
        );
      },
    );
  }
}
