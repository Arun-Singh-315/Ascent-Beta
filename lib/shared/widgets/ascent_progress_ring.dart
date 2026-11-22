import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/glass_theme.dart';

/// Determinate circular progress ring (completion, goals).
///
/// Not a loading indicator: use `CupertinoActivityIndicator` for actions and
/// skeleton shimmer for loading content. Sizes itself to its parent.
class AscentProgressRing extends StatelessWidget {
  const AscentProgressRing({
    super.key,
    required this.value,
    this.strokeWidth = 4,
    this.color,
    this.trackColor,
    this.semanticsLabel,
  });

  /// Progress between 0 and 1.
  final double value;
  final double strokeWidth;
  final Color? color;
  final Color? trackColor;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final clamped = value.isNaN ? 0.0 : value.clamp(0.0, 1.0);
    return Semantics(
      label: semanticsLabel,
      value: '${(clamped * 100).round()}%',
      child: CustomPaint(
        painter: _RingPainter(
          value: clamped,
          strokeWidth: strokeWidth,
          color: color ?? g.actionInk,
          trackColor: trackColor ?? g.track,
        ),
        child: const SizedBox.expand(),
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.value,
    required this.strokeWidth,
    required this.color,
    required this.trackColor,
  });

  final double value;
  final double strokeWidth;
  final Color color;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(
      strokeWidth / 2,
      strokeWidth / 2,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;
    canvas.drawArc(rect, 0, math.pi * 2, false, base..color = trackColor);
    if (value > 0) {
      canvas.drawArc(
        rect,
        -math.pi / 2,
        math.pi * 2 * value,
        false,
        base..color = color,
      );
    }
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.value != value ||
      old.strokeWidth != strokeWidth ||
      old.color != color ||
      old.trackColor != trackColor;
}
