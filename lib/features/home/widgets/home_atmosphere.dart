import 'package:flutter/material.dart';

import '../../../app/theme/glass_theme.dart';

/// Paints the soothing atmosphere glows behind the Home scroll view.
/// - Clay glow at top-left
/// - Slate blue glow at mid-right
/// - Soft clay glow at bottom-left
/// Painted once with CustomPaint, staying static while content scrolls smoothly.
class HomeAtmosphereBackground extends StatelessWidget {
  final Widget child;

  const HomeAtmosphereBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return Stack(
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: CustomPaint(
              painter: HomeAtmospherePainter(
                glow1: g.glow1,
                glow2: g.glow2,
              ),
            ),
          ),
        ),
        child,
      ],
    );
  }
}

class HomeAtmospherePainter extends CustomPainter {
  final Color glow1;
  final Color glow2;

  const HomeAtmospherePainter({required this.glow1, required this.glow2});

  @override
  void paint(Canvas canvas, Size size) {
    // 1. Glow 1 top left: radial-gradient(440px 380px at 0% 0%, glow1, transparent 70%)
    final rect1 = Rect.fromCenter(
      center: Offset(0, 0),
      width: size.width * 1.5,
      height: size.height * 0.7,
    );
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [glow1, glow1.withValues(alpha: 0.0)],
        stops: const [0.0, 0.75],
      ).createShader(rect1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.5), paint1);

    // 2. Glow 2 mid right: radial-gradient(460px 420px at 105% 52%, glow2, transparent 70%)
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

    // 3. Glow 3 bottom left: radial-gradient(420px 320px at -5% 96%, glow1, transparent 70%)
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
  bool shouldRepaint(covariant HomeAtmospherePainter oldDelegate) =>
      oldDelegate.glow1 != glow1 || oldDelegate.glow2 != glow2;
}
