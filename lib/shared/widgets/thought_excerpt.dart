import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_surfaces.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/theme/app_tokens.dart';

/// Registry that retains expanded states strictly by thought ID so that
/// list scrolling, item insertions, deletions, and undos never expand the wrong card.
class ThoughtExpandedRegistry {
  static final ValueNotifier<int> notifier = ValueNotifier<int>(0);
  static final Set<int> _expandedIds = <int>{};

  static bool isExpanded(int id) => _expandedIds.contains(id);

  static bool toggle(int id) {
    final bool result;
    if (_expandedIds.contains(id)) {
      _expandedIds.remove(id);
      result = false;
    } else {
      _expandedIds.add(id);
      result = true;
    }
    notifier.value++;
    return result;
  }

  static void setExpanded(int id, bool expanded) {
    if (expanded) {
      _expandedIds.add(id);
    } else {
      _expandedIds.remove(id);
    }
    notifier.value++;
  }

  static void collapse(int id) {
    _expandedIds.remove(id);
    notifier.value++;
  }

  static void clear() {
    _expandedIds.clear();
    notifier.value++;
  }
}

/// Measures the rendered text rather than guessing truncation by character count,
/// with rich styled arrow markers (`→ `) for plan items, smooth inline expansion,
/// and ID-based persistence.
class ThoughtExcerpt extends StatefulWidget {
  const ThoughtExcerpt({
    super.key,
    required this.content,
    required this.style,
    this.maxLines = 2,
    this.arrowColor,
    this.thoughtId,
    this.textKey,
    this.toggleKey,
  });

  final String content;
  final TextStyle style;
  final int maxLines;
  final Color? arrowColor;
  final int? thoughtId;
  final Key? textKey;
  final Key? toggleKey;

  /// Formats raw text by replacing ASCII `-->` and `->` with clean `• ` and `--` with `• `.
  static String formatArrowContent(String raw) {
    return raw
        .replaceAllMapped(
          RegExp(r'(^|\n)[ \t]*(?:-->|->)[ \t]*', multiLine: true),
          // An arrow the user typed stays an arrow; "--" is a plain bullet.
          (m) => '${m[1]}→ ',
        )
        .replaceAllMapped(
          RegExp(r'(^|\n)[ \t]*--[ \t]*', multiLine: true),
          (m) => '${m[1]}• ',
        )
        .replaceAll('-->', '→')
        .replaceAll('->', '→');
  }

  static String displayContent(String raw) {
    var text = raw;
    if (text.startsWith('[HIGH]')) {
      text = text.substring(6).trimLeft();
    }
    return formatArrowContent(
      text,
    ).replaceAll(RegExp(r'^[ \t]*→[ \t]*', multiLine: true), '').trimRight();
  }

  /// Builds a [TextSpan] that visually styles arrow indicators (`→ `), bullets (`• `),
  /// and numbered lists (`1. `, `2. `) with vibrant theme accent ink and readable typography.
  static TextSpan buildRichArrowSpan({
    required BuildContext context,
    required String text,
    required TextStyle baseStyle,
    Color? arrowColor,
  }) {
    final accent = arrowColor ?? context.glass.clay;
    final lines = text.trimRight().split('\n');
    final List<InlineSpan> spans = [];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (i > 0) spans.add(const TextSpan(text: '\n'));

      final arrowMatch =
          RegExp(r'^(\s*)(?:-->|->|--|•|→)\s*(.*)$').firstMatch(line);
      final numMatch =
          RegExp(r'^(\s*)(\d+[\.\)])\s*(.*)$').firstMatch(line);

      if (arrowMatch != null) {
        final ws = arrowMatch.group(1) ?? '';
        final rest = arrowMatch.group(2) ?? '';
        if (ws.isNotEmpty) spans.add(TextSpan(text: ws, style: baseStyle));
        spans.add(
          TextSpan(
            text: '• ',
            style: baseStyle.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        spans.add(TextSpan(text: rest, style: baseStyle));
      } else if (numMatch != null) {
        final ws = numMatch.group(1) ?? '';
        final numPrefix = numMatch.group(2) ?? '';
        final rest = numMatch.group(3) ?? '';
        if (ws.isNotEmpty) spans.add(TextSpan(text: ws, style: baseStyle));
        spans.add(
          TextSpan(
            text: '$numPrefix ',
            style: baseStyle.copyWith(
              color: accent,
              fontWeight: FontWeight.w700,
            ),
          ),
        );
        spans.add(TextSpan(text: rest, style: baseStyle));
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
  bool _localExpanded = false;

  @override
  void initState() {
    super.initState();
    ThoughtExpandedRegistry.notifier.addListener(_onRegistryChanged);
  }

  @override
  void dispose() {
    ThoughtExpandedRegistry.notifier.removeListener(_onRegistryChanged);
    super.dispose();
  }

  void _onRegistryChanged() {
    if (mounted) setState(() {});
  }

  bool get _isExpanded {
    if (widget.thoughtId != null) {
      return ThoughtExpandedRegistry.isExpanded(widget.thoughtId!);
    }
    return _localExpanded;
  }

  void _handleToggle() {
    HapticFeedback.lightImpact();
    setState(() {
      if (widget.thoughtId != null) {
        ThoughtExpandedRegistry.toggle(widget.thoughtId!);
      } else {
        _localExpanded = !_localExpanded;
      }
    });
  }

  @override
  void didUpdateWidget(covariant ThoughtExcerpt oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.thoughtId == null && oldWidget.content != widget.content) {
      _localExpanded = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final formatted = ThoughtExcerpt.displayContent(widget.content.trimRight());
    final hasArrows = widget.content.contains('-->') ||
        widget.content.contains('->') ||
        widget.content.contains('•') ||
        widget.content.contains('→') ||
        RegExp(r'(^|\n)\s*\d+[\.\)]\s+').hasMatch(widget.content);

    final richSpan = ThoughtExcerpt.buildRichArrowSpan(
      context: context,
      text: widget.content.trimRight(),
      baseStyle: widget.style.copyWith(height: 1.35),
      arrowColor: widget.arrowColor,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final painter = TextPainter(
          text: hasArrows ? richSpan : TextSpan(text: formatted, style: widget.style),
          maxLines: widget.maxLines,
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
          ellipsis: '…',
        )..layout(maxWidth: constraints.maxWidth);
        final overflow = painter.didExceedMaxLines;
        painter.dispose();
        final accent = widget.arrowColor ?? context.glass.clay;
        final expanded = _isExpanded;

        Widget textWidget;
        if (hasArrows) {
          textWidget = Text.rich(
            richSpan,
            key: widget.textKey,
            maxLines: expanded ? null : widget.maxLines,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          );
        } else {
          textWidget = Text.rich(
            TextSpan(text: formatted, style: widget.style),
            key: widget.textKey,
            maxLines: expanded ? null : widget.maxLines,
            overflow: expanded ? TextOverflow.visible : TextOverflow.ellipsis,
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: const Duration(milliseconds: 240),
              curve: Curves.easeInOutCubic,
              alignment: Alignment.topLeft,
              child: textWidget,
            ),
            if (overflow) ...[
              const SizedBox(height: AppSpacing.sm),
              Semantics(
                button: true,
                expanded: expanded,
                label: expanded
                    ? 'Show less thought content'
                    : 'Show more thought content',
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  child: AppTapArea(
                    key: widget.toggleKey ??
                        ValueKey('thought_excerpt_toggle_${widget.thoughtId}'),
                    onTap: _handleToggle,
                    borderRadius: BorderRadius.circular(AppRadius.chip),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 11,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: accent.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(AppRadius.chip),
                        border: Border.all(
                          color: accent.withValues(alpha: 0.28),
                          width: AppBorder.hairline,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            expanded ? 'Show less' : 'Show more',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: accent,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            expanded
                                ? Icons.keyboard_arrow_up_rounded
                                : Icons.keyboard_arrow_down_rounded,
                            size: 15,
                            color: accent,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        );
      },
    );
  }
}
