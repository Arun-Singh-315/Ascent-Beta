import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:flutter/material.dart';

import '../../app/theme/glass_theme.dart';

/// Measures the rendered text rather than guessing truncation by character count,
/// with rich styled arrow markers (`→ `) for plan items.
class ThoughtExcerpt extends StatelessWidget {
  const ThoughtExcerpt({
    super.key,
    required this.content,
    required this.style,
    required this.onReadMore,
    this.maxLines = 2,
    this.arrowColor,
  });

  final String content;
  final TextStyle style;
  final VoidCallback onReadMore;
  final int maxLines;
  final Color? arrowColor;

  /// Formats raw text by replacing ASCII `-->` with clean `→ ` and `--` with `• `.
  static String formatArrowContent(String raw) {
    return raw
        .replaceAll(RegExp(r'(^|\n)\s*-->\s*', multiLine: true), r'$1→ ')
        .replaceAll(RegExp(r'(^|\n)\s*--\s*', multiLine: true), r'$1• ')
        .replaceAll('-->', '→');
  }

  /// Builds a [TextSpan] that visually styles arrow indicators (`→ `) and bullets (`• `)
  /// with vibrant theme accent ink.
  static TextSpan buildRichArrowSpan({
    required BuildContext context,
    required String text,
    required TextStyle baseStyle,
    Color? arrowColor,
  }) {
    final formatted = formatArrowContent(text);
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
  Widget build(BuildContext context) {
    final richSpan = buildRichArrowSpan(
      context: context,
      text: content,
      baseStyle: style,
      arrowColor: arrowColor,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: richSpan,
          maxLines: maxLines,
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
              maxLines: maxLines,
              overflow: TextOverflow.ellipsis,
            ),
            if (overflow)
              TextButton(
                onPressed: onReadMore,
                style: context.surfaces.buttonStyle(
                  TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(48, 48),
                    alignment: Alignment.centerLeft,
                  ),
                  filled: false,
                  icon: false,
                ),
                child: const Text('Read more'),
              ),
          ],
        );
      },
    );
  }
}
