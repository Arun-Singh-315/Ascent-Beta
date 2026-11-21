import 'package:flutter/material.dart';

import 'glass_theme.dart';

/// Shared daylight card material: solid white cards on the plain canvas.
/// Text and action colours come from [AscentGlass] (Calm Blue).
class DayGlassMaterial extends ThemeExtension<DayGlassMaterial> {
  const DayGlassMaterial({
    required this.canvas,
    required this.topOpacity,
    required this.bottomOpacity,
    required this.blur,
    required this.shadow,
  });

  /// Light-mode cards are solid white with a soft shadow (CLAUDE.md §3.3).
  /// Translucent "frosted" cards were removed: glass is for persistent
  /// chrome only (§3.4), and frosted panes read grey and glossy.
  factory DayGlassMaterial.from(AscentGlass glass) => DayGlassMaterial(
    canvas: glass.bg,
    topOpacity: 1,
    bottomOpacity: 1,
    blur: 0,
    shadow: Colors.black.withValues(alpha: .05),
  );

  final Color canvas;
  final double topOpacity, bottomOpacity, blur;
  final Color shadow;

  LinearGradient gradient(Color tint, {double minimumOpacity = 0}) =>
      LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          tint.withValues(alpha: topOpacity.clamp(minimumOpacity, 1)),
          tint.withValues(alpha: bottomOpacity.clamp(minimumOpacity, 1)),
        ],
      );

  /// No rim: light cards have no outline (§3.3).
  Border get rim => Border.all(color: Colors.transparent, width: 0);

  /// Soft card shadow: y 2, blur 12, black at 5% (§3.3).
  List<BoxShadow> get shadows => [
    BoxShadow(color: shadow, blurRadius: 12, offset: const Offset(0, 2)),
  ];

  @override
  DayGlassMaterial copyWith({
    Color? canvas,
    double? topOpacity,
    double? bottomOpacity,
    double? blur,
    Color? shadow,
  }) => DayGlassMaterial(
    canvas: canvas ?? this.canvas,
    topOpacity: topOpacity ?? this.topOpacity,
    bottomOpacity: bottomOpacity ?? this.bottomOpacity,
    blur: blur ?? this.blur,
    shadow: shadow ?? this.shadow,
  );

  @override
  DayGlassMaterial lerp(covariant DayGlassMaterial? other, double t) {
    if (other == null) return this;
    return DayGlassMaterial(
      canvas: Color.lerp(canvas, other.canvas, t)!,
      topOpacity: topOpacity + (other.topOpacity - topOpacity) * t,
      bottomOpacity: bottomOpacity + (other.bottomOpacity - bottomOpacity) * t,
      blur: blur + (other.blur - blur) * t,
      shadow: Color.lerp(shadow, other.shadow, t)!,
    );
  }
}
