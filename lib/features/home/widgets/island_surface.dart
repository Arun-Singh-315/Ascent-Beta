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
    if (finish == IslandFinish.midnight) {
      return const IslandPalette(
        Color(0xF0263C58),
        Color(0xF20B1427),
        Color(0xFFF1F7FF),
        Color(0xFFB8CAE4),
        Color(0xFF95CDFF),
      );
    }
    if (finish == IslandFinish.frost) {
      return dark
          ? const IslandPalette(
              Color(0xEE34434C),
              Color(0xF01B252E),
              Color(0xFFF2F8FA),
              Color(0xFFBACFD8),
              Color(0xFFADE7E5),
            )
          : const IslandPalette(
              Color(0xEEFAFFFF),
              Color(0xE6DFECEE),
              Color(0xFF173D45),
              Color(0xFF47666D),
              Color(0xFF246873),
            );
    }
    return dark
        ? const IslandPalette(
            Color(0xEB214B70),
            Color(0xF0102238),
            Color(0xFFF1F7FF),
            Color(0xFFB6CDE4),
            Color(0xFF8DCCFF),
          )
        : const IslandPalette(
            Color(0xEEF0F8FF),
            Color(0xE6CBE2F6),
            Color(0xFF102F50),
            Color(0xFF426482),
            Color(0xFF1364AC),
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
          color: palette.accent.withValues(alpha: palette.isDark ? .10 : .07),
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
        color: palette.accent.withValues(alpha: .28),
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
                          .withValues(
                        alpha: palette.isDark ? 0.40 : 0.50,
                      ),
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
