import 'package:flutter/material.dart';

/// An open invitation state; a dashed rim distinguishes it from saved content.
class HomeDashedOutline extends StatelessWidget {
  const HomeDashedOutline({
    super.key,
    required this.color,
    required this.child,
  });
  final Color color;
  final Widget child;
  @override
  Widget build(BuildContext context) =>
      CustomPaint(foregroundPainter: _DashedRim(color), child: child);
}

class _DashedRim extends CustomPainter {
  _DashedRim(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          (Offset.zero & size).deflate(.75),
          const Radius.circular(26),
        ),
      );
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    for (final metric in path.computeMetrics()) {
      for (double distance = 0; distance < metric.length; distance += 5) {
        canvas.drawPath(
          metric.extractPath(
            distance,
            (distance + 2.5).clamp(0, metric.length),
          ),
          paint,
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRim oldDelegate) =>
      color != oldDelegate.color;
}
