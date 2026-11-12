import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'home_day_design.dart';
import '../../../app/theme/home_design.dart';

/// A native sky surface, composed around the greeting rather than a photograph.
class HomeHeaderScene extends StatelessWidget {
  const HomeHeaderScene({
    super.key,
    required this.now,
    required this.child,
    this.flat = false,
  });
  final DateTime now;
  final Widget child;
  final bool flat;

  static String periodAt(DateTime time) => switch (time.hour) {
    >= 5 && < 12 => 'morning',
    >= 12 && < 17 => 'afternoon',
    >= 17 && < 21 => 'evening',
    _ => 'night',
  };

  static Color inkAt(DateTime time, {required bool dark}) =>
      dark || periodAt(time) == 'night'
      ? const Color(0xFFF9FBFF)
      : const Color(0xFF172A42);

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final period = periodAt(now);
    if (flat) {
      return DecoratedBox(
        key: ValueKey('home_header_scene_$period'),
        decoration: BoxDecoration(gradient: HomeDesign.of(context).atmosphere),
        child: child,
      );
    }
    final day = HomeDayDesign.at(now, dark: dark);
    final night = period == 'night';
    final sky = night ? const Color(0xFF243D70) : day.sky;
    final light = night ? const Color(0xFF60669D) : day.light;
    return AnimatedContainer(
      key: ValueKey('home_header_scene_$period'),
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 800,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [sky, Color.lerp(sky, light, .45)!, light],
          stops: const [0, .55, 1],
        ),
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(.85, -.1),
                  radius: .95,
                  colors: [
                    (night ? const Color(0xFFB9C9FF) : const Color(0xFFFFEDC8))
                        .withValues(alpha: dark || night ? .13 : .48),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// One quiet celestial focal point, with no scenery behind the text.
class HomeCelestialMark extends StatelessWidget {
  const HomeCelestialMark({super.key, required this.now});
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final period = HomeHeaderScene.periodAt(now);
    return ExcludeSemantics(
      child: AnimatedSwitcher(
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 600,
        ),
        child: CustomPaint(
          key: ValueKey('home_celestial_$period'),
          size: const Size(88, 88),
          painter: _CelestialPainter(period, HomeDesign.of(context)),
        ),
      ),
    );
  }
}

class _CelestialPainter extends CustomPainter {
  const _CelestialPainter(this.period, this.design);
  final String period;
  final HomeDesign design;
  bool get dark => design.darkness > .5;

  @override
  void paint(Canvas canvas, Size size) {
    final night = period == 'night';
    final morning = period == 'morning';
    final evening = period == 'evening';
    final center = Offset(
      size.width * .5,
      size.height * (morning || evening ? .55 : .48),
    );
    const radius = 22.0;
    final glow = night ? design.moonGlow : design.solarGlow;
    canvas.drawCircle(
      center,
      43,
      Paint()
        ..shader = RadialGradient(
          colors: [
            glow.withValues(alpha: dark || night ? .24 : .5),
            glow.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: 43)),
    );
    final discPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: night
            ? [design.moonStart, design.moonEnd]
            : evening
            ? [design.sunsetStart, design.sunsetEnd]
            : [design.solarStart, design.solarEnd],
      ).createShader(Rect.fromCircle(center: center, radius: radius));
    if (night) {
      final crescent = Path.combine(
        PathOperation.difference,
        Path()..addOval(Rect.fromCircle(center: center, radius: radius)),
        Path()..addOval(
          Rect.fromCircle(center: center + const Offset(10, -8), radius: 21),
        ),
      );
      canvas.drawPath(crescent, discPaint);
      for (final star in const [
        Offset(70, 19),
        Offset(21, 21),
        Offset(69, 65),
      ]) {
        final paint = Paint()
          ..color = design.stars.withValues(alpha: .8)
          ..strokeWidth = 1.3
          ..strokeCap = StrokeCap.round;
        canvas.drawLine(
          star - const Offset(2.5, 0),
          star + const Offset(2.5, 0),
          paint,
        );
        canvas.drawLine(
          star - const Offset(0, 2.5),
          star + const Offset(0, 2.5),
          paint,
        );
      }
      return;
    }
    final horizon = center.dy + 7;
    canvas.save();
    if (morning || evening) {
      canvas.clipRect(Rect.fromLTRB(0, 0, size.width, horizon));
    }
    canvas.drawCircle(center, radius, discPaint);
    final rayPaint = Paint()
      ..color = design.solarRay.withValues(alpha: .65)
      ..strokeWidth = 1.3
      ..strokeCap = StrokeCap.round;
    for (var i = 0; i < 12; i++) {
      final angle = i * math.pi / 6;
      final direction = Offset(math.cos(angle), math.sin(angle));
      canvas.drawLine(
        center + direction * 29,
        center + direction * 33,
        rayPaint,
      );
    }
    canvas.restore();
    if (morning || evening) {
      final linePaint = Paint()
        ..color = design.horizon.withValues(alpha: .5)
        ..strokeWidth = 1.1
        ..strokeCap = StrokeCap.round;
      canvas.drawLine(Offset(13, horizon), Offset(75, horizon), linePaint);
      canvas.drawLine(
        Offset(25, horizon + 7),
        Offset(63, horizon + 7),
        linePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_CelestialPainter oldDelegate) =>
      oldDelegate.period != period ||
      oldDelegate.design.darkness != design.darkness;
}
