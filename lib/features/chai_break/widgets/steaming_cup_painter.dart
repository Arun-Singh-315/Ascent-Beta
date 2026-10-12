import 'dart:math' as math;
import 'package:flutter/material.dart';

class SteamingCupWidget extends StatefulWidget {
  final bool isRunning;
  final Color accentColor;

  const SteamingCupWidget({
    super.key,
    required this.isRunning,
    this.accentColor = const Color(0xFF6B3A1C),
  });

  @override
  State<SteamingCupWidget> createState() => _SteamingCupWidgetState();
}

class _SteamingCupWidgetState extends State<SteamingCupWidget>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
      _controller.value = 0;
    } else if (!_controller.isAnimating) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: const Size(180, 160),
          painter: _SteamingCupPainter(
            animationValue: _controller.value,
            accentColor: widget.accentColor,
            isRunning: widget.isRunning,
          ),
          child: const SizedBox(width: 180, height: 160),
        );
      },
    );
  }
}

class _SteamingCupPainter extends CustomPainter {
  final double animationValue;
  final Color accentColor;
  final bool isRunning;

  _SteamingCupPainter({
    required this.animationValue,
    required this.accentColor,
    required this.isRunning,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height * 0.65;

    // 1. Warm breathing radial glow behind cup
    final glowRadius = 55.0 + math.sin(animationValue * 2 * math.pi) * 6.0;
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              accentColor.withValues(alpha: 0.28),
              accentColor.withValues(alpha: 0.08),
              Colors.transparent,
            ],
            stops: const [0.0, 0.55, 1.0],
          ).createShader(
            Rect.fromCircle(center: Offset(cx, cy), radius: glowRadius),
          );
    canvas.drawCircle(Offset(cx, cy), glowRadius, glowPaint);

    // 2. Rising steam wisps (3 separate sine-wave paths)
    {
      final steamPaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 2.4;

      final wispOffsets = [-18.0, 0.0, 18.0];
      final phaseOffsets = [0.0, 0.33, 0.66];

      for (int i = 0; i < 3; i++) {
        final localX = cx + wispOffsets[i];
        final phase = (animationValue + phaseOffsets[i]) % 1.0;
        final alpha = (math.sin(phase * math.pi) * 0.7).clamp(0.0, 0.85);

        steamPaint.color = Colors.white.withValues(
          alpha: alpha * (isRunning ? 1 : 0.35),
        );

        final path = Path();
        final startY = cy - 26;
        final endY = cy - 78;
        path.moveTo(localX, startY);

        for (double t = 0.0; t <= 1.0; t += 0.1) {
          final y = startY - (startY - endY) * t;
          final waveX = localX + math.sin((t + phase) * 2 * math.pi) * 6.5;
          path.lineTo(waveX, y);
        }

        canvas.drawPath(path, steamPaint);
      }
    }

    // 3. Saucer / Plate at base
    final saucerPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.18)
      ..style = PaintingStyle.fill;
    final saucerRect = Rect.fromCenter(
      center: Offset(cx, cy + 28),
      width: 76,
      height: 10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(saucerRect, const Radius.circular(5)),
      saucerPaint,
    );

    // 4. Mug Body
    final cupPath = Path();
    final topWidth = 28.0;
    final bottomWidth = 22.0;
    final topY = cy - 24;
    final bottomY = cy + 24;

    cupPath.moveTo(cx - topWidth, topY);
    cupPath.lineTo(cx - bottomWidth, bottomY);
    cupPath.quadraticBezierTo(cx, bottomY + 5, cx + bottomWidth, bottomY);
    cupPath.lineTo(cx + topWidth, topY);
    cupPath.close();

    final cupPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              accentColor.withValues(alpha: 0.95),
              accentColor.withValues(alpha: 0.75),
            ],
          ).createShader(
            Rect.fromLTWH(cx - topWidth, topY, topWidth * 2, bottomY - topY),
          );
    canvas.drawPath(cupPath, cupPaint);

    // Mug rim border
    final rimPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.35)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2;
    canvas.drawPath(cupPath, rimPaint);

    // 5. Mug Handle
    final handlePaint = Paint()
      ..color = accentColor.withValues(alpha: 0.9)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.6
      ..strokeCap = StrokeCap.round;
    final handlePath = Path();
    handlePath.moveTo(cx + topWidth - 3, topY + 6);
    handlePath.cubicTo(
      cx + topWidth + 16,
      topY + 6,
      cx + topWidth + 16,
      bottomY - 6,
      cx + bottomWidth - 2,
      bottomY - 4,
    );
    canvas.drawPath(handlePath, handlePaint);

    // 6. Tea/Coffee warm liquid rim
    final liquidPaint = Paint()
      ..color = const Color(0xFF6B3A1C)
      ..style = PaintingStyle.fill;
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(cx, topY),
        width: topWidth * 1.85,
        height: 8,
      ),
      liquidPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _SteamingCupPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue ||
        oldDelegate.isRunning != isRunning ||
        oldDelegate.accentColor != accentColor;
  }
}
