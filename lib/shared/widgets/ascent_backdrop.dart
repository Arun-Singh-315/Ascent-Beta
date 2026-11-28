import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/calm_blue_palette.dart';
import '../../app/theme/glass_theme.dart';

/// Which screen a backdrop belongs to. Each has its own colours and doodle.
enum BackdropTone { home, mind, riya }

/// A soft gradient backdrop with two faint colour clouds and, for Mindspace
/// and Riya, a chat-wallpaper doodle of small faint glyphs. Still (no
/// animation), so it costs nothing while scrolling and never sits behind
/// text loudly.
class AscentBackdrop extends StatelessWidget {
  const AscentBackdrop({
    super.key,
    required this.child,
    this.tone = BackdropTone.home,
  });
  final Widget child;
  final BackdropTone tone;

  /// Whether this tone draws the doodle pattern.
  bool get doodle => tone != BackdropTone.home;

  /// The colour at the bottom edge of [tone]'s backdrop, so a docked input
  /// can fade into the screen instead of sitting on a slab of its own.
  static Color bottomOf(BuildContext context, BackdropTone tone) =>
      _colors(tone, context.glass.isDark).last;

  static List<Color> _colors(BackdropTone tone, bool dark) => switch (tone) {
    BackdropTone.home =>
      dark ? CalmBluePalette.backdropDark : CalmBluePalette.backdropLight,
    BackdropTone.mind =>
      dark ? CalmBluePalette.mindDark : CalmBluePalette.mindLight,
    BackdropTone.riya =>
      dark ? CalmBluePalette.riyaDark : CalmBluePalette.riyaLight,
  };

  @override
  Widget build(BuildContext context) {
    final dark = context.glass.isDark;
    final colors = _colors(tone, dark);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: colors,
        ),
      ),
      child: CustomPaint(
        painter: _BackdropPainter(dark: dark, tone: tone),
        child: child,
      ),
    );
  }
}

class _BackdropPainter extends CustomPainter {
  _BackdropPainter({required this.dark, required this.tone});
  final bool dark;
  final BackdropTone tone;

  static const _mindGlyphs = [
    Icons.lightbulb_outline_rounded,
    Icons.edit_outlined,
    Icons.favorite_border_rounded,
    Icons.star_border_rounded,
    Icons.cloud_outlined,
    Icons.local_florist_outlined,
    Icons.bookmark_border_rounded,
    Icons.music_note_outlined,
    Icons.push_pin_outlined,
    Icons.wb_sunny_outlined,
  ];
  static const _riyaGlyphs = [
    Icons.auto_awesome_outlined,
    Icons.chat_bubble_outline_rounded,
    Icons.star_border_rounded,
    Icons.nightlight_outlined,
    Icons.favorite_border_rounded,
    Icons.bolt_outlined,
    Icons.question_answer_outlined,
    Icons.emoji_objects_outlined,
  ];

  @override
  void paint(Canvas canvas, Size size) {
    // Home is a calm, plain gradient (Home v7): no clouds, no doodle.
    if (tone == BackdropTone.home) return;
    void cloud(Color c, Offset center, double r, double a) {
      final rect = Rect.fromCircle(center: center, radius: r);
      canvas.drawCircle(
        center,
        r,
        Paint()
          ..shader = RadialGradient(
            colors: [
              c.withValues(alpha: a),
              c.withValues(alpha: 0),
            ],
          ).createShader(rect),
      );
    }

    final w = size.width, h = size.height;
    final a = dark ? .10 : .26;
    final (cloudA, cloudB) = switch (tone) {
      BackdropTone.home => (
        CalmBluePalette.cloudBlue,
        CalmBluePalette.cloudLilac,
      ),
      BackdropTone.mind => (
        CalmBluePalette.mindCloudA,
        CalmBluePalette.mindCloudB,
      ),
      BackdropTone.riya => (
        CalmBluePalette.riyaCloudA,
        CalmBluePalette.riyaCloudB,
      ),
    };
    cloud(cloudA, Offset(w * .9, h * .1), w * .8, a);
    cloud(cloudB, Offset(w * .05, h * .6), w * .7, a * .8);

    if (tone == BackdropTone.home) return;
    final ink = switch (tone) {
      BackdropTone.mind =>
        dark ? CalmBluePalette.mindDoodleDark : CalmBluePalette.mindDoodleLight,
      _ =>
        dark ? CalmBluePalette.riyaDoodleDark : CalmBluePalette.riyaDoodleLight,
    };
    final glyphs = tone == BackdropTone.mind ? _mindGlyphs : _riyaGlyphs;
    const cell = 64.0;
    var i = 0;
    for (var y = 18.0; y < h; y += cell) {
      final row = (y / cell).round();
      for (var x = (row.isOdd ? cell / 2 : 0) + 14.0; x < w; x += cell) {
        final glyph = glyphs[(i * 7 + row) % glyphs.length];
        final tp = TextPainter(
          text: TextSpan(
            text: String.fromCharCode(glyph.codePoint),
            style: TextStyle(
              fontFamily: glyph.fontFamily,
              package: glyph.fontPackage,
              fontSize: 19,
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
      old.dark != dark || old.tone != tone;
}
