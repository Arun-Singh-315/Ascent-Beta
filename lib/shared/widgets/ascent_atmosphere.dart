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
    final g1 = glow1 ?? g.glow1;
    final g2 = glow2 ?? g.glow2;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    if (g1.a == 0 && g2.a == 0) return child;

    final color1 = softenGlow(
      g1,
      maxAlpha: g.frozen ? 0.32 : 0.18,
    );
    final color2 = softenGlow(
      g2,
      maxAlpha: g.frozen ? 0.24 : 0.14,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: AscentAtmospherePainter(glow1: color1, glow2: color2),
            ),
          ),
        ),
        // Theme signature: soft stardust, brighter at night.
        Positioned.fill(
          child: IgnorePointer(
            child: RepaintBoundary(
              child: CustomPaint(
                painter: AscentStardustPainter(
                  color: isDark ? Colors.white : g.amber,
                  isDark: isDark,
                  faint: g.frozen,
                ),
              ),
            ),
          ),
        ),
        Positioned.fill(child: child),
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
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.2, size.width, size.height * 0.65),
      paint2,
    );

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
    canvas.drawRect(
      Rect.fromLTWH(0, size.height * 0.6, size.width, size.height * 0.4),
      paint3,
    );
  }

  @override
  bool shouldRepaint(covariant AscentAtmospherePainter oldDelegate) =>
      oldDelegate.glow1 != glow1 || oldDelegate.glow2 != glow2;
}

/// Deterministic micro stardust so stars never flicker or move on rebuild.
class AscentStardustPainter extends CustomPainter {
  final Color color;
  final bool isDark;
  final bool faint;

  const AscentStardustPainter({
    required this.color,
    required this.isDark,
    this.faint = false,
  });

  static const _stars = [
    Offset(0.12, 0.08), Offset(0.28, 0.14), Offset(0.45, 0.06),
    Offset(0.72, 0.11), Offset(0.88, 0.09), Offset(0.18, 0.22),
    Offset(0.62, 0.25), Offset(0.82, 0.28), Offset(0.08, 0.35),
    Offset(0.38, 0.38), Offset(0.76, 0.42), Offset(0.92, 0.46),
    Offset(0.15, 0.52), Offset(0.52, 0.56), Offset(0.85, 0.60),
    Offset(0.22, 0.68), Offset(0.68, 0.72), Offset(0.10, 0.76),
    Offset(0.40, 0.78), Offset(0.80, 0.75), Offset(0.25, 0.62),
    Offset(0.55, 0.48), Offset(0.90, 0.65), Offset(0.33, 0.45),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final scale = faint ? 0.5 : 1.0;
    for (var i = 0; i < _stars.length; i++) {
      final s = _stars[i];
      final radius = (i % 3 == 0) ? 1.4 : (i % 2 == 0 ? 1.0 : 0.7);
      final alpha = isDark
          ? ((i % 4 == 0) ? 0.38 : (i % 2 == 0 ? 0.22 : 0.14))
          : ((i % 4 == 0) ? 0.20 : 0.10);
      paint.color = color.withValues(alpha: alpha * scale);
      canvas.drawCircle(
        Offset(s.dx * size.width, s.dy * size.height),
        radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant AscentStardustPainter old) =>
      old.color != color || old.isDark != isDark || old.faint != faint;
}
