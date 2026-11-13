import 'package:flutter/material.dart';
import '../../../app/theme/home_design.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/monochrome_surfaces.dart';

/// Home's approved neutral working canvas; the selected theme on other routes
/// and the person's explicit day/night choice remain independently owned.
class HomeTheme {
  static ThemeData from(ThemeData parent) {
    final dark = parent.brightness == Brightness.dark;
    final design = dark ? const HomeDesign.night() : const HomeDesign.day();
    final neutral = HomeControlSurfaces(design);
    final ink = design.primaryText;
    final secondary = design.secondaryText;
    final line = design.separator;
    final canvas = design.canvas;
    final surface = design.surface;
    final glass =
        (parent.extension<AscentGlass>() ??
                (dark ? AscentGlass.dark : AscentGlass.light))
            .copyWith(
              monochrome: neutral,
              bg: canvas,
              highlight: design.surface,
              glow1: Colors.transparent,
              glow2: Colors.transparent,
              slate: secondary,
              slateSoft: design.groupedFill,
              sage: design.wellnessInk,
              sageSoft: design.groupedFill,
              amber: design.learningInk,
              amberSoft: design.groupedFill,
              coral: dark
                  ? SharedControlColors.dueRedDark
                  : SharedControlColors.dueRed,
              coralSoft: SharedControlColors.errorSoftBg(dark),
              track: design.groupedFill,
              nav: design.elevated,
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
      scaffoldBackgroundColor: canvas,
      canvasColor: design.elevated,
      dialogTheme: parent.dialogTheme.copyWith(
        backgroundColor: design.elevated,
        surfaceTintColor: Colors.transparent,
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(design.elevated),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
        ),
      ),
      textTheme: parent.textTheme.copyWith(
        displaySmall: AscentTextStyles.interfaceDisplay.copyWith(color: ink),
        titleLarge: AscentTextStyles.interfaceSection.copyWith(color: ink),
        titleMedium: AscentTextStyles.interfaceTitle.copyWith(color: ink),
        bodyLarge: AscentTextStyles.interfaceBody.copyWith(color: ink),
        bodyMedium: AscentTextStyles.interfaceBody.copyWith(color: ink),
        bodySmall: AscentTextStyles.interfaceSupporting.copyWith(
          color: secondary,
        ),
        labelLarge: AscentTextStyles.interfaceNavigation.copyWith(color: ink),
      ),
      appBarTheme: parent.appBarTheme.copyWith(
        backgroundColor: canvas,
        foregroundColor: ink,
        iconTheme: IconThemeData(color: ink),
        actionsIconTheme: IconThemeData(color: ink),
      ),
      bottomSheetTheme: parent.bottomSheetTheme.copyWith(
        backgroundColor: design.elevated,
        modalBackgroundColor: design.elevated,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: parent.popupMenuTheme.copyWith(
        color: design.elevated,
        surfaceTintColor: Colors.transparent,
        textStyle: AscentTextStyles.interfaceBody.copyWith(color: ink),
      ),
      iconTheme: parent.iconTheme.copyWith(color: ink),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          foregroundColor: ink,
          minimumSize: const Size(48, 48),
        ),
      ),
      colorScheme: parent.colorScheme.copyWith(
        surface: surface,
        onSurface: ink,
        surfaceContainer: design.elevated,
        onSurfaceVariant: secondary,
        outline: design.controlOutline,
        outlineVariant: line,
      ),
      extensions: [
        ...parent.extensions.values.where(
          (extension) =>
              extension is! AscentGlass &&
              extension is! AppSurfaces &&
              extension is! MonochromeSurfaces &&
              extension is! HomeDesign,
        ),
        neutral,
        design,
        glass,
        surfaces.copyWith(
          cardFill: surface,
          tintFill: design.groupedFill,
          tintBorder: line,
          cardBorderColor: line,
          pillBorderColor: line,
          dividerColor: line,
          ink: ink,
          mutedText: secondary,
          blur: 0,
          shadow: design.shadow,
        ),
      ],
    );
  }
}
