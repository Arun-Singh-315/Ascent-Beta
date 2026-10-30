import 'package:flutter/material.dart';

import '../../../core/providers/island_preferences_provider.dart';
import '../../../shared/widgets/glass_surface.dart';

class IslandPalette {
  const IslandPalette(
    this.top,
    this.bottom,
    this.ink,
    this.secondary,
    this.accent,
  );
  final Color top, bottom, ink, secondary, accent;

  static IslandPalette resolve(IslandFinish finish, bool dark) {
    if (finish == IslandFinish.midnight || dark) {
      return const IslandPalette(
        Color(0xF0232326),
        Color(0xF00F0F12),
        Color(0xFFF5F5F7),
        Color(0xFFAEAEB2),
        Color(0xFF64ACFF),
      );
    }
    return finish == IslandFinish.frost
        ? const IslandPalette(
            Color(0xF5FFFFFF),
            Color(0xF0F2F2F7),
            Color(0xFF1C1C1E),
            Color(0xFF636366),
            Color(0xFF006FE6),
          )
        : const IslandPalette(
            Color(0xF5FFFFFF),
            Color(0xF0EBF2FF),
            Color(0xFF1C1C1E),
            Color(0xFF636366),
            Color(0xFF006FE6),
          );
  }

  bool get isDark => ink.computeLuminance() > .5;
  Color get tile => Color.alphaBlend(
    accent.withValues(alpha: .08),
    bottom.withValues(alpha: 1),
  );
}

/// Shared by the real island and its inert customization preview.
class IslandSurface extends StatelessWidget {
  const IslandSurface({
    super.key,
    required this.palette,
    required this.child,
    this.radius = 28,
  });
  final IslandPalette palette;
  final Widget child;
  final double radius;

  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: palette.isDark ? .15 : .045),
          blurRadius: 24,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: GlassSurface(
      radius: radius,
      padding: EdgeInsets.zero,
      enableBlur: true,
      hasShadow: false,
      customBorder: Border.all(
        color: palette.ink.withValues(alpha: .09),
        width: .8,
      ),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        stops: const [0, .24, 1],
        colors: [
          Color.alphaBlend(
            Colors.white.withValues(alpha: palette.isDark ? .08 : .35),
            palette.top,
          ),
          palette.top,
          palette.bottom,
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Stack(
          children: [
            child,
            Positioned(
              key: const ValueKey('island_specular_shine'),
              top: 0,
              left: 16,
              right: 16,
              height: 1.5,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      (palette.isDark ? Colors.white : palette.accent)
                          .withValues(alpha: palette.isDark ? 0.40 : 0.50),
                      Colors.transparent,
                    ],
                    stops: const [0.0, 0.5, 1.0],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
