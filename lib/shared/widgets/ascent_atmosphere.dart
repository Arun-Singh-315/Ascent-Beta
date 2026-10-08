import 'package:flutter/material.dart';

import '../../app/theme/glass_theme.dart';

/// Paints the soothing atmosphere ambient glows behind any Ascent screen or sheet:
/// - Primary warm glow (defaults to clay) at top-left
/// - Secondary aura glow (defaults to slate blue) at mid-right
/// - Bottom aura glow at bottom-left
/// Painted with [CustomPaint] inside a [RepaintBoundary], ensuring zero re-rendering overhead
/// while the foreground content scrolls fluidly at 60/120 FPS.
class AscentAtmosphereBackground extends StatelessWidget {
  final Widget child;
  final Color? glow1;
  final Color? glow2;

  const AscentAtmosphereBackground({
    super.key,
    required this.child,
    this.glow1,
    this.glow2,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final color1 = softenGlow(glow1 ?? g.glow1, maxAlpha: 0.18);
    final color2 = softenGlow(glow2 ?? g.glow2, maxAlpha: 0.14);

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: AscentAtmospherePainter(
                glow1: color1,
                glow2: color2,
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: child,
        ),
      ],
    );
  }

  static Color softenGlow(Color color, {double maxAlpha = 0.14}) {
    if (color.a > maxAlpha) {
      return color.withValues(alpha: maxAlpha);
    }
    return color;
  }
}

class AscentAtmospherePainter extends CustomPainter {
  final Color glow1;
  final Color glow2;

  const AscentAtmospherePainter({required this.glow1, required this.glow2});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Glow 1 top left: radial-gradient at (0%, 0%)
    final rect1 = Rect.fromCenter(
      center: Offset.zero,
      width: size.width * 1.5,
      height: size.height * 0.7,
    );
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [glow1, glow1.withValues(alpha: 0.0)],
        stops: const [0.0, 0.75],
      ).createShader(rect1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.5), paint1);

    // 2. Glow 2 mid right: radial-gradient at (105%, 52%)
    final rect2 = Rect.fromCenter(
      center: Offset(size.width * 1.05, size.height * 0.52),
      width: size.width * 1.6,
      height: size.height * 0.8,
    );
    final paint2 = Paint()
      ..shader = RadialGradient(
        colors: [glow2, glow2.withValues(alpha: 0.0)],
        stops: const [0.0, 0.75],
      ).createShader(rect2);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.2, size.width, size.height * 0.65), paint2);

    // 3. Glow 3 bottom left: radial-gradient at (-5%, 96%)
    final rect3 = Rect.fromCenter(
      center: Offset(size.width * -0.05, size.height * 0.96),
      width: size.width * 1.4,
      height: size.height * 0.6,
    );
    final paint3 = Paint()
      ..shader = RadialGradient(
        colors: [glow1, glow1.withValues(alpha: 0.0)],
        stops: const [0.0, 0.75],
      ).createShader(rect3);
    canvas.drawRect(Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4), paint3);
  }

  @override
  bool shouldRepaint(covariant AscentAtmospherePainter oldDelegate) =>
      oldDelegate.glow1 != glow1 || oldDelegate.glow2 != glow2;
}
