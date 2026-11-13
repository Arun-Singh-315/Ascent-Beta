import 'dart:math' as math;
import 'package:flutter/material.dart';

/// A time-aware landscape painted at device resolution behind the greeting.
/// The left side stays quiet so names and accessibility text can wrap freely.
class HomeHeaderLandscape extends CustomPainter {
  const HomeHeaderLandscape({
    required this.now,
    required this.dark,
    this.opacity = 1,
  });
  final DateTime now;
  final bool dark;
  final double opacity;

  static String periodAt(DateTime time) => switch (time.hour) {
    >= 5 && < 12 => 'morning',
    >= 12 && < 17 => 'afternoon',
    >= 17 && < 21 => 'evening',
    _ => 'night',
  };

  @override
  void paint(Canvas canvas, Size size) {
    canvas.saveLayer(
      Offset.zero & size,
      Paint()..color = Colors.white.withValues(alpha: opacity),
    );
    final period = periodAt(now);
    final night = period == 'night';
    final evening = period == 'evening';
    final morning = period == 'morning';
    final skyInk = night
        ? (dark ? const Color(0xFF9DAFE5) : const Color(0xFF6375A4))
        : evening
        ? const Color(0xFFBF8D9D)
        : const Color(0xFF85B8CB);
    final center = Offset(
      size.width * .84,
      size.height * (morning ? .57 : .43),
    );
    final radius = night ? 21.0 : 27.0;
    canvas.drawCircle(
      center,
      radius * 2.5,
      Paint()
        ..shader = RadialGradient(
          colors: [
            skyInk.withValues(alpha: dark ? .15 : .12),
            skyInk.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius * 2.5)),
    );
    if (night) {
      // A crescent with a transparent cutout, rather than a sun at night.
      final moon = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
        Path()..addOval(
          Rect.fromCircle(
            center: center + const Offset(10, -7),
            radius: radius - 1,
          ),
        ),
      );
      canvas.drawPath(moon, Paint()..color = skyInk.withValues(alpha: .72));
      for (final star in const [
        Offset(.65, .32),
        Offset(.93, .29),
        Offset(.74, .52),
        Offset(.95, .64),
        Offset(.79, .22),
      ]) {
        final point = Offset(size.width * star.dx, size.height * star.dy);
        final paint = Paint()
          ..color = skyInk.withValues(alpha: .65)
          ..strokeWidth = 1.2;
        canvas.drawLine(
          point - const Offset(3, 0),
          point + const Offset(3, 0),
          paint,
        );
        canvas.drawLine(
          point - const Offset(0, 3),
          point + const Offset(0, 3),
          paint,
        );
      }
    } else {
      final sunColor = dark ? const Color(0xFFD6AE7C) : const Color(0xFFDFA96B);
      canvas.drawCircle(
        center,
        radius,
        Paint()..color = sunColor.withValues(alpha: .6),
      );
      if (!evening) {
        final rays = Paint()
          ..color = sunColor.withValues(alpha: .45)
          ..strokeWidth = 1.5
          ..strokeCap = StrokeCap.round;
        for (var i = 0; i < 8; i++) {
          final angle = i * math.pi / 4;
          final direction = Offset(math.cos(angle), math.sin(angle));
          canvas.drawLine(
            center + direction * 34,
            center + direction * 39,
            rays,
          );
        }
      }
      if (period == 'afternoon') {
        final cloud = Paint()
          ..color = (dark ? Colors.white : const Color(0xFFFAFEFF)).withValues(
            alpha: dark ? .10 : .8,
          );
        for (final offset in const [
          Offset(-29, 18),
          Offset(-10, 12),
          Offset(9, 19),
        ]) {
          canvas.drawOval(
            Rect.fromCenter(center: center + offset, width: 44, height: 17),
            cloud,
          );
        }
      }
    }
    // Layered hills are strongest on the right and fade beneath the copy.
    for (var layer = 0; layer < 3; layer++) {
      final y = size.height * (.72 + layer * .085);
      final path = Path()
        ..moveTo(size.width * .38, size.height)
        ..cubicTo(
          size.width * .57,
          y + 25,
          size.width * .67,
          y - 32,
          size.width * .82,
          y,
        )
        ..quadraticBezierTo(size.width * .94, y + 20, size.width * 1.08, y - 24)
        ..lineTo(size.width, size.height)
        ..close();
      canvas.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(
            colors: [
              skyInk.withValues(alpha: 0),
              skyInk.withValues(alpha: .08 + layer * .055),
            ],
          ).createShader(Offset.zero & size),
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(HomeHeaderLandscape oldDelegate) =>
      periodAt(oldDelegate.now) != periodAt(now) ||
      oldDelegate.dark != dark ||
      oldDelegate.opacity != opacity;
}
