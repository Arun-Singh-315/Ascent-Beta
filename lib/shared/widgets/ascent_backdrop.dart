import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/calm_blue_palette.dart';
import '../../app/theme/glass_theme.dart';

/// The soft Apple-blue backdrop behind screens: a gentle top-to-bottom
/// gradient with two faint colour clouds, and optionally a WhatsApp-style
/// doodle of small, faint glyphs. Still (no animation), so it costs nothing
/// while scrolling and never distracts from text.
class AscentBackdrop extends StatelessWidget {
  const AscentBackdrop({super.key, required this.child, this.doodle = false});
  final Widget child;

  /// Draw the faint doodle pattern (Mindspace and Riya).
  final bool doodle;

  @override
  Widget build(BuildContext context) {
    final dark = context.glass.isDark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? CalmBluePalette.backdropDark
              : CalmBluePalette.backdropLight,
        ),
      ),
      child: CustomPaint(
        painter: _BackdropPainter(dark: dark, doodle: doodle),
        child: child,
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.dark, required this.doodle});
  final bool dark;
  final bool doodle;

  static const _glyphs = [
    Icons.lightbulb_outline_rounded,
    Icons.favorite_border_rounded,
    Icons.star_border_rounded,
    Icons.edit_outlined,
    Icons.chat_bubble_outline_rounded,
    Icons.local_florist_outlined,
    Icons.music_note_outlined,
    Icons.wb_sunny_outlined,
    Icons.coffee_outlined,
    Icons.auto_awesome_outlined,
    Icons.bookmark_border_rounded,
    Icons.cloud_outlined,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    void cloud(Color c, Offset center, double r, double a) {
      final rect = Rect.fromCircle(center: center, radius: r);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [c.withValues(alpha: a), c.withValues(alpha: 0)],
          ).createShader(rect),
      );
    }

    final w = size.width, h = size.height;
    final a = dark ? .10 : .28;
    cloud(CalmBluePalette.cloudBlue, Offset(w * .9, h * .12), w * .8, a);
    cloud(CalmBluePalette.cloudLilac, Offset(w * .05, h * .55), w * .7, a * .8);

    if (!doodle) return;
    final ink = dark ? CalmBluePalette.doodleDark : CalmBluePalette.doodleLight;
    const cell = 64.0;
    var i = 0;
    for (var y = 18.0; y < h; y += cell) {
      final row = (y / cell).round();
      for (var x = (row.isOdd ? cell / 2 : 0) + 14.0; x < w; x += cell) {
        final glyph = _glyphs[(i * 7 + row) % _glyphs.length];
        final tp = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(glyph.codePoint),
            style: TextStyle(
              fontFamily: glyph.fontFamily,
              package: glyph.fontPackage,
              fontSize: 20,
              color: ink,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(((i % 5) - 2) * math.pi / 18);
        tp.paint(canvas, Offset(-tp.width / 2, -tp.height / 2));
        canvas.restore();
        i++;
      }
    }
  }

  @override
  bool shouldRepaint(_BackdropPainter old) =>
      old.dark != dark || old.doodle != doodle;
}
