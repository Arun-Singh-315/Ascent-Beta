import 'package:flutter/material.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../app/theme/surface_tokens.dart';
import 'home_day_design.dart';

/// Home's approved neutral working canvas; the selected theme on other routes
/// and the person's explicit day/night choice remain independently owned.
class HomeTheme {
  static ThemeData from(ThemeData parent) {
    final dark = parent.brightness == Brightness.dark;
    final ink = HomeDayDesign.ink(dark);
    final secondary = HomeDayDesign.secondary(dark);
    final line = HomeDayDesign.line(dark);
    final surface = dark ? const Color(0xFF1E2530) : Colors.white;
    final glass =
        (parent.extension<AscentGlass>() ??
                (dark ? AscentGlass.dark : AscentGlass.light))
            .copyWith(
              bg: HomeDayDesign.canvas(dark),
              fill: surface,
              ink: ink,
              inkSecondary: secondary,
              inkMuted: secondary,
              edge: line,
              line: line,
              clay: dark
                  ? SharedControlColors.actionBlueDark
                  : SharedControlColors.actionBlue,
              claySoft: SharedControlColors.actionBlue.withValues(alpha: .08),
            );
    final surfaces =
        parent.extension<AppSurfaces>() ??
        (dark ? AppSurfaces.night : AppSurfaces.day);
    return parent.copyWith(
      scaffoldBackgroundColor: HomeDayDesign.canvas(dark),
      colorScheme: parent.colorScheme.copyWith(
        surface: surface,
        onSurface: ink,
      ),
      extensions: [
        ...parent.extensions.values.where(
          (extension) => extension is! AscentGlass && extension is! AppSurfaces,
        ),
        glass,
        surfaces.copyWith(
          cardFill: surface,
          cardBorderColor: line,
          pillBorderColor: line,
          dividerColor: line,
          ink: ink,
          mutedText: secondary,
          blur: 0,
          shadow: Colors.black.withValues(alpha: dark ? .16 : .025),
        ),
      ],
    );
  }
}
