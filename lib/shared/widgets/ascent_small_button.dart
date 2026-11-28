import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/ascent_tokens.dart';
import '../../app/theme/text_styles.dart';
import 'ascent_icon.dart';

/// How an [AscentSmallButton] looks.
enum AscentSmallButtonStyle {
  /// Filled navy: the one main action in a section.
  filled,

  /// A 1 pt edge, no fill: neutral actions next to the main one.
  plain,

  /// Text only, in the action colour ("Select", "Move to today").
  ghost,
}

/// Home v7's small 28 pt button. The drawn shape is small; the tap area is
/// still at least 44 pt. Press scales to 0.97 with a light haptic.
class AscentSmallButton extends StatefulWidget {
  const AscentSmallButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = AscentSmallButtonStyle.plain,
    this.glyph,
    this.color,
    this.semanticLabel,
  });

  const AscentSmallButton.filled({
    super.key,
    required this.label,
    required this.onPressed,
    this.glyph,
    this.color,
    this.semanticLabel,
  }) : style = AscentSmallButtonStyle.filled;

  const AscentSmallButton.ghost({
    super.key,
    required this.label,
    required this.onPressed,
    this.glyph,
    this.color,
    this.semanticLabel,
  }) : style = AscentSmallButtonStyle.ghost;

  final String label;
  final VoidCallback? onPressed;
  final AscentSmallButtonStyle style;
  final AscentGlyph? glyph;

  /// Overrides the label colour (for example danger red for Delete).
  final Color? color;
  final String? semanticLabel;

  @override
  State<AscentSmallButton> createState() => _AscentSmallButtonState();
}

class _AscentSmallButtonState extends State<AscentSmallButton> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final enabled = widget.onPressed != null;
    final (bg, fg, edge) = switch (widget.style) {
      AscentSmallButtonStyle.filled => (t.actionFill, t.onAction, t.actionFill),
      AscentSmallButtonStyle.plain => (
        Colors.transparent,
        widget.color ?? t.label,
        t.line,
      ),
      AscentSmallButtonStyle.ghost => (
        Colors.transparent,
        widget.color ?? t.action,
        Colors.transparent,
      ),
    };
    final reduce = MediaQuery.disableAnimationsOf(context);
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.semanticLabel ?? widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: enabled ? () => setState(() => _down = false) : null,
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                HapticFeedback.lightImpact();
                widget.onPressed!();
              }
            : null,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: AnimatedScale(
              scale: _down && !reduce ? 0.97 : 1,
              duration: const Duration(milliseconds: 120),
              curve: Curves.easeOutCubic,
              child: Opacity(
                opacity: enabled ? 1 : 0.4,
                child: Container(
                  constraints: const BoxConstraints(minHeight: 28),
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.style == AscentSmallButtonStyle.ghost
                        ? 4
                        : 11,
                  ),
                  decoration: BoxDecoration(
                    color: bg,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: edge),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (widget.glyph != null) ...[
                        AscentIcon(widget.glyph!, size: 14, color: fg),
                        const SizedBox(width: 5),
                      ],
                      Flexible(
                        child: Text(
                          widget.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AscentTextStyles.button.copyWith(color: fg),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
