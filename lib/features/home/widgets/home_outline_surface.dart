import 'package:flutter/material.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/day_glass_material.dart';
import '../../../shared/widgets/glass_surface.dart';

/// Transparent Home shell framed by a continuous, softly illuminated rim.
class HomeOutlineSurface extends StatelessWidget {
  const HomeOutlineSurface({
    super.key,
    required this.child,
    this.surfaceKey,
    this.radius = 22,
    this.padding = const EdgeInsets.all(16),
    this.showOutline = true,
  });

  final Widget child;
  final Key? surfaceKey;
  final double radius;
  final EdgeInsetsGeometry padding;
  final bool showOutline;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (Theme.of(context).extension<DayGlassMaterial>() != null) {
      return GlassSurface(
        key: surfaceKey,
        radius: radius,
        padding: padding,
        child: child,
      );
    }
    // Warm wine and champagne on cream; linen reflections on the night palette.
    final edge = dark
        ? Color.lerp(g.clay, g.ink, .4)!
        : g.merlot
        ? const Color(0xFF88545E)
        : Color.lerp(g.clay, g.ink, .25)!;
    final rim = edge.withValues(alpha: dark ? .58 : .48);
    return CustomPaint(
      painter: showOutline
          ? _HomeRim(radius: radius, edge: edge, dark: dark, glow: true)
          : null,
      foregroundPainter: showOutline
          ? _HomeRim(radius: radius, edge: edge, dark: dark)
          : null,
      child: GlassSurface(
        key: surfaceKey,
        radius: radius,
        enableBlur: Theme.of(context).brightness == Brightness.light,
        customBorder: showOutline
            ? Border.all(color: rim, width: 1.2)
            : const Border.fromBorderSide(BorderSide.none),
        padding: padding,
        child: child,
      ),
    );
  }
}

class _HomeRim extends CustomPainter {
  const _HomeRim({
    required this.radius,
    required this.edge,
    required this.dark,
    this.glow = false,
  });
  final double radius;
  final Color edge;
  final bool dark;
  final bool glow;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final bounds = (Offset.zero & size).deflate(.6);
    final outline = RRect.fromRectAndRadius(
      bounds,
      Radius.circular(radius - .6),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = glow ? 2 : 1.2;
    if (glow) {
      // Only the perimeter glows: the middle remains truly transparent.
      paint
        ..color = edge.withValues(alpha: dark ? .18 : .10)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3);
    } else {
      paint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color.lerp(
            edge,
            const Color(0xFFF8EBD7),
            dark ? .45 : .30,
          )!.withValues(alpha: .85),
          edge.withValues(alpha: dark ? .50 : .62),
          Color.lerp(
            edge,
            const Color(0xFFC6A77C),
            .38,
          )!.withValues(alpha: .78),
          edge.withValues(alpha: dark ? .65 : .80),
        ],
        stops: const [0, .35, .65, 1],
      ).createShader(bounds);
    }
    canvas.drawRRect(outline, paint);
  }

  @override
  bool shouldRepaint(_HomeRim oldDelegate) =>
      radius != oldDelegate.radius ||
      edge != oldDelegate.edge ||
      dark != oldDelegate.dark ||
      glow != oldDelegate.glow;
}
