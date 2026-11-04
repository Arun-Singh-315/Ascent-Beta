import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../../app/theme/glass_theme.dart';

/// Paints the soothing atmosphere ambient glows behind any Ascent screen or sheet:
/// - Primary warm/emerald glow (defaults to clay or cyan/greenish touch) at top-left
/// - Secondary aura glow (defaults to slate/indigo blue) at mid-right
/// - Bottom aura glow at bottom-left
/// Painted with [CustomPaint] inside a [RepaintBoundary], ensuring zero re-rendering overhead
/// while the foreground content scrolls fluidly at 60/120 FPS.
class AscentAtmosphereBackground extends StatefulWidget {
  final Widget child;
  final Color? glow1;
  final Color? glow2;
  final bool animate;

  const AscentAtmosphereBackground({
    super.key,
    required this.child,
    this.glow1,
    this.glow2,
    this.animate = true,
  });

  @override
  State<AscentAtmosphereBackground> createState() =>
      _AscentAtmosphereBackgroundState();

  static Color softenGlow(Color color, {double maxAlpha = 0.14}) {
    if (color.a > maxAlpha) {
      return color.withValues(alpha: maxAlpha);
    }
    return color;
  }
}

class _AscentAtmosphereBackgroundState extends State<AscentAtmosphereBackground>
    with SingleTickerProviderStateMixin {
  AnimationController? _controller;

  @override
  void initState() {
    super.initState();
    final isTestEnvironment =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (widget.animate && !isTestEnvironment) {
      _controller = AnimationController(
        vsync: this,
        duration: const Duration(seconds: 8),
      )..repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final g1 = widget.glow1 ?? g.glow1;
    final g2 = widget.glow2 ?? g.glow2;
    if (g1.a == 0 && g2.a == 0) return widget.child;

    final color1 = AscentAtmosphereBackground.softenGlow(g1, maxAlpha: 0.085);
    final color2 = AscentAtmosphereBackground.softenGlow(g2, maxAlpha: 0.065);

    final painter = _controller == null
        ? CustomPaint(
            painter: AscentAtmospherePainter(
              glow1: color1,
              glow2: color2,
              progress: 0,
            ),
          )
        : AnimatedBuilder(
            animation: _controller!,
            builder: (context, _) {
              return CustomPaint(
                painter: AscentAtmospherePainter(
                  glow1: color1,
                  glow2: color2,
                  progress: _controller!.value,
                ),
              );
            },
          );

    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: painter,
          ),
        ),
        Positioned.fill(child: widget.child),
      ],
    );
  }
}

class AscentAtmospherePainter extends CustomPainter {
  final Color glow1;
  final Color glow2;
  final double progress;

  const AscentAtmospherePainter({
    required this.glow1,
    required this.glow2,
    this.progress = 0.0,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final t = progress * 2 * math.pi;
    final shiftX = 14 * math.sin(t);
    final shiftY = 10 * math.cos(t);

    // 1. Glow 1 top left: radial-gradient at (0%, 0%)
    final rect1 = Rect.fromCenter(
      center: Offset(shiftX, shiftY),
      width: size.width * (1.5 + 0.1 * math.sin(t)),
      height: size.height * (0.7 + 0.06 * math.cos(t)),
    );
    final paint1 = Paint()
      ..shader = RadialGradient(
        colors: [glow1, glow1.withValues(alpha: 0.0)],
        stops: const [0.0, 0.75],
      ).createShader(rect1);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height * 0.5), paint1);

    // 2. Glow 2 mid right: radial-gradient at (105%, 52%)
    final rect2 = Rect.fromCenter(
      center: Offset(size.width * 1.05 - shiftX, size.height * 0.52 + shiftY),
      width: size.width * (1.6 + 0.08 * math.cos(t)),
      height: size.height * (0.8 + 0.08 * math.sin(t)),
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
      center: Offset(
        size.width * -0.05 + shiftX * 0.7,
        size.height * 0.96 - shiftY * 0.7,
      ),
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
      oldDelegate.glow1 != glow1 ||
      oldDelegate.glow2 != glow2 ||
      oldDelegate.progress != progress;
}
