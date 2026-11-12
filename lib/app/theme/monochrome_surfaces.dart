import 'package:flutter/material.dart';

/// Opt-in neutral surfaces. Semantic action colours remain in SharedControlColors.
/// Interpolating the appearance keeps light/dark theme changes continuous.
class MonochromeSurfaces extends ThemeExtension<MonochromeSurfaces> {
  const MonochromeSurfaces.light() : darkness = 0;
  const MonochromeSurfaces.dark() : darkness = 1;

  /// Allows a scoped palette to reuse shared controls and their interpolation.
  const MonochromeSurfaces.level(this.darkness);
  const MonochromeSurfaces._(this.darkness);

  final double darkness;
  static MonochromeSurfaces of(BuildContext context) =>
      Theme.of(context).extension<MonochromeSurfaces>() ??
      (Theme.of(context).brightness == Brightness.dark
          ? const MonochromeSurfaces.dark()
          : const MonochromeSurfaces.light());

  Color _pair(int light, int dark) =>
      Color.lerp(Color(light), Color(dark), darkness)!;
  Color get canvas => _pair(0xFFF4F5F8, 0xFF000000);
  Color get surface => _pair(0xFFFFFFFF, 0xFF1C1C1E);
  Color get elevated => _pair(0xFFFFFFFF, 0xFF2C2C2E);
  Color get groupedFill => _pair(0xFFEFEFF1, 0xFF252527);
  Color get primaryText => _pair(0xFF0F172A, 0xFFF5F5F7);
  Color get secondaryText => _pair(0xFF5B6475, 0xFFAEAEB2);
  Color get tertiaryText => _pair(0xFF6C6C70, 0xFF98989D);
  Color get separator => _pair(0xFFE6E8EE, 0xFF38383A);
  Color get controlOutline => _pair(0xFF76767A, 0xFF8E8E93);
  Color get neutralSelection => _pair(0xFFE9E9ED, 0xFF38383A);
  Color get pressedFill => _pair(0xFFE5E5EA, 0xFF3A3A3C);
  Color get disabledText => _pair(0xFF8E8E93, 0xFF757579);

  @override
  MonochromeSurfaces copyWith({double? darkness}) =>
      MonochromeSurfaces._(darkness ?? this.darkness);

  @override
  MonochromeSurfaces lerp(MonochromeSurfaces? other, double t) => other == null
      ? this
      : MonochromeSurfaces._(darkness + (other.darkness - darkness) * t);
}
