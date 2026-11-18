import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../../../app/theme/home_design.dart';
import '../../../app/theme/shared_control_tokens.dart';

/// The same transparent outlined icon treatment in the hub and its editor.
class HomeShortcutIcon extends StatelessWidget {
  const HomeShortcutIcon({
    super.key,
    required this.icon,
    this.selected = false,
    this.size = 44,
    this.framed = true,
    this.identity,
    this.progress,
  });
  final IconData icon;
  final bool selected;
  final bool framed;
  final String? identity;
  final double size;
  final double? progress;

  /// Returns the solid black / white ink color for strong, consistent shortcut icons.
  static Color inkFor(String id, BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return isDark ? const Color(0xFFF8FAFC) : const Color(0xFF0F172A);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconInk = selected
        ? (isDark
            ? SharedControlColors.actionBlueDark
            : SharedControlColors.actionBlue)
        : inkFor(identity ?? '', context);

    Widget coreIcon = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: isDark
            ? (selected
                ? SharedControlColors.actionBlueDark.withValues(alpha: 0.22)
                : const Color(0xFF1C2028))
            : (selected
                ? SharedControlColors.actionBlue.withValues(alpha: 0.12)
                : Colors.white),
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? (isDark
                  ? SharedControlColors.actionBlueDark
                  : SharedControlColors.actionBlue)
              : (isDark
                  ? const Color(0xFF2E3442)
                  : const Color(0xFFE2E8F0)),
          width: selected ? 1.6 : 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Icon(
        icon,
        size: size * .44,
        color: iconInk,
      ),
    );

    if (progress != null) {
      return SizedBox(
        width: size + 6,
        height: size + 6,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CustomPaint(
              size: Size(size + 6, size + 6),
              painter: _ShortcutProgressRingPainter(
                progress: progress!,
                color: isDark
                    ? const Color(0xFF60A5FA)
                    : const Color(0xFF2563EB),
                trackColor: (isDark ? Colors.white : Colors.black)
                    .withValues(alpha: 0.08),
                strokeWidth: 2.5,
              ),
            ),
            coreIcon,
          ],
        ),
      );
    }

    return coreIcon;
  }
}

class _ShortcutProgressRingPainter extends CustomPainter {
  final double progress;
  final Color color;
  final Color trackColor;
  final double strokeWidth;

  const _ShortcutProgressRingPainter({
    required this.progress,
    required this.color,
    required this.trackColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;
    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0) {
      final progressPaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -math.pi / 2,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShortcutProgressRingPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor ||
      oldDelegate.strokeWidth != strokeWidth;
}

/// The shortcut enclosure, glyphs and values share a neutral, high-contrast treatment.
abstract final class HomeShortcutStyle {
  static Color ink(BuildContext context) => HomeDesign.of(context).primaryText;
  static Color border(BuildContext context) => HomeDesign.of(context).separator;
  static Color badgeFill(BuildContext context) =>
      HomeDesign.of(context).elevated;
}
