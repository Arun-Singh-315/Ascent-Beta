import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Small, resolution-independent scenes give each ritual its own character.
class HomeRhythmArtwork extends CustomPainter {
  const HomeRhythmArtwork({
    required this.id,
    required this.dark,
    required this.tint,
  });
  final String id;
  final bool dark;
  final Color tint;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 112, size.height / 112);
    final ink = Color.lerp(
      tint,
      dark ? Colors.white : Colors.black,
      dark ? .32 : .12,
    )!;
    Paint fill(double opacity) =>
        Paint()..color = ink.withValues(alpha: opacity);
    Paint line(double opacity, [double width = 1.6]) => Paint()
      ..color = ink.withValues(alpha: opacity)
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    canvas.drawCircle(const Offset(58, 55), 46, fill(.08));
    canvas.drawArc(
      const Rect.fromLTWH(4, 4, 104, 104),
      -.8,
      2.5,
      false,
      line(.20),
    );
    canvas.drawCircle(const Offset(97, 22), 4, fill(.55));
    switch (id) {
      case 'hydration':
        final drop = Path()
          ..moveTo(56, 17)
          ..cubicTo(47, 34, 28, 49, 28, 66)
          ..cubicTo(28, 101, 84, 101, 84, 66)
          ..cubicTo(84, 49, 65, 34, 56, 17)
          ..close();
        canvas.drawPath(drop, fill(.15));
        canvas.save();
        canvas.clipPath(drop);
        for (var i = 0; i < 3; i++) {
          canvas.drawPath(
            Path()
              ..moveTo(20, 62 + i * 8)
              ..cubicTo(42, 48 + i * 8, 65, 81 + i * 8, 94, 58 + i * 8)
              ..lineTo(94, 105)
              ..lineTo(20, 105)
              ..close(),
            fill(.20 + .12 * i),
          );
        }
        canvas.restore();
        canvas.drawPath(drop, line(.85, 1.8));
        canvas.drawPath(
          Path()
            ..moveTo(39, 64)
            ..quadraticBezierTo(34, 75, 44, 81),
          line(.6, 2.6),
        );
        canvas.drawCircle(const Offset(88, 42), 3, fill(.45));
      case 'walk':
        canvas.drawCircle(const Offset(78, 31), 11, fill(.6));
        canvas.drawPath(
          Path()
            ..moveTo(10, 81)
            ..quadraticBezierTo(39, 36, 60, 68)
            ..quadraticBezierTo(77, 92, 106, 60)
            ..lineTo(106, 101)
            ..lineTo(10, 101)
            ..close(),
          fill(.18),
        );
        canvas.drawPath(
          Path()
            ..moveTo(52, 102)
            ..cubicTo(23, 81, 92, 81, 65, 54),
          line(.85, 3),
        );
        for (var i = 0; i < 4; i++) {
          canvas.drawCircle(Offset(27 + i * 6, 48 - i * 4), 1.8, fill(.6));
        }
      case 'chai-break':
        canvas.drawPath(
          Path()
            ..moveTo(54, 94)
            ..cubicTo(45, 64, 61, 42, 65, 21),
          line(.8, 2),
        );
        for (var i = 0; i < 3; i++) {
          final y = 78.0 - i * 19;
          canvas.drawPath(
            Path()
              ..moveTo(54, y)
              ..quadraticBezierTo(22, y + 2, 25, y - 20)
              ..quadraticBezierTo(49, y - 27, 54, y)
              ..close(),
            fill(.3 + i * .12),
          );
          canvas.drawPath(
            Path()
              ..moveTo(57, y - 8)
              ..quadraticBezierTo(86, y - 3, 89, y - 30)
              ..quadraticBezierTo(64, y - 36, 57, y - 8)
              ..close(),
            fill(.22 + i * .12),
          );
        }
      case 'medicine':
        final heart = Path()
          ..moveTo(56, 88)
          ..cubicTo(43, 76, 22, 61, 22, 43)
          ..cubicTo(22, 22, 47, 20, 56, 38)
          ..cubicTo(65, 20, 90, 22, 90, 43)
          ..cubicTo(90, 61, 69, 76, 56, 88)
          ..close();
        canvas.drawPath(heart, fill(.25));
        canvas.drawPath(heart, line(.7, 2));
        canvas.drawPath(
          Path()
            ..moveTo(29, 58)
            ..lineTo(44, 58)
            ..lineTo(50, 46)
            ..lineTo(59, 68)
            ..lineTo(65, 55)
            ..lineTo(82, 55),
          line(.9, 2.4),
        );
      default:
        canvas.drawPath(
          Path()
            ..moveTo(9, 99)
            ..lineTo(43, 51)
            ..lineTo(64, 75)
            ..lineTo(78, 56)
            ..lineTo(108, 99)
            ..close(),
          fill(.25),
        );
        canvas.drawPath(
          Path()
            ..moveTo(27, 99)
            ..lineTo(62, 47)
            ..lineTo(99, 99)
            ..close(),
          fill(.35),
        );
        canvas.drawLine(
          const Offset(62, 48),
          const Offset(62, 18),
          line(.9, 2),
        );
        canvas.drawPath(
          Path()
            ..moveTo(63, 18)
            ..quadraticBezierTo(75, 12, 87, 22)
            ..lineTo(85, 39)
            ..quadraticBezierTo(75, 29, 63, 35)
            ..close(),
          fill(.8),
        );
        for (var i = 0; i < 3; i++) {
          final a = i * math.pi / 3;
          final c = const Offset(29, 27);
          canvas.drawLine(
            c + Offset(math.cos(a), math.sin(a)) * 4,
            c - Offset(math.cos(a), math.sin(a)) * 4,
            line(.6),
          );
        }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(HomeRhythmArtwork oldDelegate) =>
      oldDelegate.id != id ||
      oldDelegate.dark != dark ||
      oldDelegate.tint != tint;
}
