import 'package:flutter/material.dart';

import '../../core/providers/settings_provider.dart';
import 'glass_theme.dart';

/// Shared daylight material: a smoked canvas beneath bright, frosted panes.
/// Text and action colors continue to come from the selected brand palette.
class DayGlassMaterial extends ThemeExtension<DayGlassMaterial> {
  const DayGlassMaterial({
    required this.canvas,
    required this.topOpacity,
    required this.bottomOpacity,
    required this.blur,
    required this.shadow,
  });

  factory DayGlassMaterial.from(
    AscentGlass glass,
    GlassTranslucencyPreset preset,
  ) {
    final (top, bottom, blur) = switch (preset) {
      GlassTranslucencyPreset.subtleFrosted => (.62, .38, 24.0),
      GlassTranslucencyPreset.balancedLiquid => (.76, .50, 20.0),
      GlassTranslucencyPreset.highContrast => (.96, .90, 16.0),
    };
    return DayGlassMaterial(
      canvas: Color.alphaBlend(glass.ink.withValues(alpha: .025), glass.bg),
      topOpacity: top,
      bottomOpacity: bottom,
      blur: blur,
      shadow: glass.shadow.withValues(alpha: .13),
    );
  }

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

  Border get rim => Border.all(color: Colors.white.withValues(alpha: .70));

  List<BoxShadow> get shadows => [
    BoxShadow(color: shadow, blurRadius: 26, offset: const Offset(0, 9)),
    BoxShadow(
      color: shadow.withValues(alpha: .04),
      blurRadius: 3,
      offset: const Offset(0, 1),
    ),
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
