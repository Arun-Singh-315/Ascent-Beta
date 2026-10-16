import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:flutter/material.dart';

/// Measures the rendered text rather than guessing truncation by character count.
class ThoughtExcerpt extends StatelessWidget {
  const ThoughtExcerpt({
    super.key,
    required this.content,
    required this.style,
    required this.onReadMore,
    this.maxLines = 2,
  });
  final String content;
  final TextStyle style;
  final VoidCallback onReadMore;
  final int maxLines;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final painter = TextPainter(
        text: TextSpan(text: content, style: style),
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
          Text(
            content,
            style: style,
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
