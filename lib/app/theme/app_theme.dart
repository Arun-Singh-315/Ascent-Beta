import 'package:flutter/cupertino.dart'
    show CupertinoPageTransitionsBuilder, CupertinoThemeData;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';
import 'calm_blue_palette.dart';
import 'day_glass_material.dart';
import 'dimension_tokens.dart';
import 'glass_theme.dart';
import 'shared_control_tokens.dart';
import 'surface_tokens.dart';
import 'text_styles.dart';

/// Light and dark [ThemeData] for Ascent: one Calm Blue palette, mirrored.
///
/// ```dart
/// MaterialApp(
///   theme: AscentTheme.light(),
///   darkTheme: AscentTheme.dark(),
/// )
/// ```
class AscentTheme {
  AscentTheme._();

  static ThemeData light({
    GlassTranslucencyPreset translucency =
        GlassTranslucencyPreset.balancedLiquid,
  }) {
    final base = _build(Brightness.light);
    final glass = base.extension<AscentGlass>()!;
    final material = DayGlassMaterial.from(glass, translucency);
    final surface = base.extension<AppSurfaces>()!.copyWith(
      cardFill: glass.fill.withValues(alpha: material.topOpacity),
      cardBorderColor: Colors.white.withValues(alpha: .70),
      blur: material.blur,
      shadow: material.shadow,
    );
    return base.copyWith(
      cardTheme: base.cardTheme.copyWith(
        color: surface.cardFill,
        shadowColor: material.shadow,
      ),
      colorScheme: base.colorScheme.copyWith(
        surfaceContainer: surface.cardFill,
      ),
      extensions: [
        material,
        surface,
        glass.copyWith(
          fill: surface.cardFill,
          nav: surface.cardFill,
          edge: surface.cardBorderColor,
          shadow: material.shadow,
        ),
        AppColors.light,
      ],
    );
  }

  static ThemeData dark() => _build(Brightness.dark);

  /// Assistant routes share the app theme.
  static ThemeData assistant(ThemeData parent) => parent;

  /// JetBrains Mono for timers and code (CLAUDE.md §3.2).
  static TextStyle monoStyle(TextStyle base) =>
      GoogleFonts.jetBrainsMono(textStyle: base);

  static ThemeData _build(Brightness brightness) {
    final isDark = brightness == Brightness.dark;
    final glass = isDark ? AscentGlass.dark : AscentGlass.light;
    final canvas = glass.bg;
    final surface = glass.surface;
    final elevated = glass.elevated;
    final recessed = glass.recessed;
    final separator = glass.line;
    final label = glass.ink;
    final secondary = glass.inkSecondary;
    final tertiary = glass.inkMuted;
    final action = glass.actionInk;
    final actionFill = glass.primaryButtonBg;
    final danger = glass.coral;

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: action,
      onPrimary: CalmBluePalette.onAction,
      primaryContainer: glass.tonalBg,
      onPrimaryContainer: glass.tonalFg,
      secondary: glass.tonalFg,
      onSecondary: CalmBluePalette.onAction,
      secondaryContainer: glass.tonalBg,
      onSecondaryContainer: glass.tonalFg,
      tertiary: glass.amber,
      onTertiary: CalmBluePalette.onAction,
      tertiaryContainer: glass.amberSoft,
      onTertiaryContainer: label,
      error: danger,
      onError: CalmBluePalette.onAction,
      errorContainer: glass.coralSoft,
      onErrorContainer: label,
      surface: surface,
      onSurface: label,
      surfaceContainerHighest: elevated,
      onSurfaceVariant: tertiary,
      outline: separator,
      outlineVariant: separator,
      shadow: glass.shadow,
      scrim: const Color(0x66000000), // black @ 40% (CLAUDE.md §3.4)
      inverseSurface: isDark
          ? CalmBluePalette.label
          : CalmBluePalette.darkLabel,
      onInverseSurface: isDark
          ? CalmBluePalette.darkLabel
          : CalmBluePalette.label,
      inversePrimary: isDark
          ? CalmBluePalette.action
          : CalmBluePalette.darkAction,
    );

    TextStyle ink(TextStyle s) => s.copyWith(color: label);
    final textTheme = TextTheme(
      displayLarge: ink(AscentTextStyles.displayLarge),
      displayMedium: ink(AscentTextStyles.displayMedium),
      displaySmall: ink(AscentTextStyles.displaySmall),
      headlineLarge: ink(AscentTextStyles.displayLarge),
      headlineMedium: ink(AscentTextStyles.displayMedium),
      headlineSmall: ink(AscentTextStyles.displaySmall),
      titleLarge: ink(AscentTextStyles.labelLarge),
      titleMedium: ink(AscentTextStyles.bodyMediumMedium),
      titleSmall: ink(AscentTextStyles.labelSmall),
      bodyLarge: ink(AscentTextStyles.bodyLarge),
      bodyMedium: ink(AscentTextStyles.bodyMedium),
      bodySmall: AscentTextStyles.bodySmall.copyWith(color: secondary),
      labelLarge: ink(AscentTextStyles.labelLarge),
      labelMedium: AscentTextStyles.bodyMediumMedium.copyWith(color: secondary),
      labelSmall: AscentTextStyles.labelSmall.copyWith(color: secondary),
    );

    const controlRadius = BorderRadius.all(Radius.circular(12));
    final buttonShape = const WidgetStatePropertyAll(
      RoundedRectangleBorder(borderRadius: controlRadius),
    );
    OutlineInputBorder inputBorder(Color c, [double w = 1]) =>
        OutlineInputBorder(
          borderRadius: controlRadius,
          borderSide: BorderSide(color: c, width: w),
        );

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: canvas,
      canvasColor: canvas,
      fontFamily: GoogleFonts.dmSans().fontFamily,
      textTheme: textTheme,
      cupertinoOverrideTheme: CupertinoThemeData(
        primaryColor: action,
        brightness: brightness,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: action,
        selectionColor: action.withValues(alpha: .25),
        selectionHandleColor: action,
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: canvas,
        foregroundColor: label,
        elevation: 0,
        scrolledUnderElevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: false,
        titleTextStyle: AscentTextStyles.displaySmall.copyWith(color: label),
        iconTheme: IconThemeData(color: label),
        actionsIconTheme: IconThemeData(color: secondary),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(20)),
          side: isDark ? BorderSide(color: separator) : BorderSide.none,
        ),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: action,
        unselectedItemColor: tertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
        selectedLabelStyle: AscentTextStyles.labelSmall,
        unselectedLabelStyle: AscentTextStyles.labelSmall,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: recessed,
        border: inputBorder(Colors.transparent),
        enabledBorder: inputBorder(Colors.transparent),
        focusedBorder: inputBorder(action),
        errorBorder: inputBorder(danger),
        focusedErrorBorder: inputBorder(danger),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        hintStyle: AscentTextStyles.body.copyWith(color: tertiary),
        labelStyle: AscentTextStyles.body.copyWith(color: secondary),
        floatingLabelStyle: AscentTextStyles.caption.copyWith(color: action),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: actionFill,
          foregroundColor: CalmBluePalette.onAction,
          minimumSize: const Size(48, 44),
          elevation: 0,
          shape: const RoundedRectangleBorder(borderRadius: controlRadius),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? glass.disabledBg
                : actionFill,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (s) => s.contains(WidgetState.disabled)
                ? glass.disabledFg
                : CalmBluePalette.onAction,
          ),
          overlayColor: WidgetStatePropertyAll(
            CalmBluePalette.onAction.withValues(alpha: .12),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: buttonShape,
          minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
          textStyle: WidgetStatePropertyAll(AscentTextStyles.labelMedium),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(action),
          overlayColor: WidgetStatePropertyAll(action.withValues(alpha: .08)),
          textStyle: WidgetStatePropertyAll(AscentTextStyles.labelMedium),
          shape: buttonShape,
          minimumSize: const WidgetStatePropertyAll(Size(44, 44)),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(action),
          overlayColor: WidgetStatePropertyAll(action.withValues(alpha: .08)),
          side: WidgetStatePropertyAll(BorderSide(color: separator)),
          shape: buttonShape,
          minimumSize: const WidgetStatePropertyAll(Size(64, 44)),
          textStyle: WidgetStatePropertyAll(AscentTextStyles.labelMedium),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          ),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        style: ButtonStyle(
          minimumSize: WidgetStatePropertyAll(
            Size.square(AscentDimensions.minTouchTarget),
          ),
          tapTargetSize: MaterialTapTargetSize.padded,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.disabled)
              ? glass.disabledFg
              : SharedControlColors.switchThumb,
        ),
        trackColor: WidgetStateProperty.resolveWith((s) {
          if (s.contains(WidgetState.disabled)) return glass.disabledBg;
          if (s.contains(WidgetState.selected)) return glass.switchTrackOn;
          return glass.switchTrackOff;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      dividerTheme: DividerThemeData(color: separator, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: elevated,
        contentTextStyle: AscentTextStyles.bodyMedium.copyWith(
          color: label,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: separator),
        ),
        behavior: SnackBarBehavior.floating,
        actionTextColor: action,
        elevation: 6,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: elevated,
        modalBackgroundColor: elevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        modalElevation: 0,
        elevation: 0,
        dragHandleColor: separator,
        dragHandleSize: const Size(40, 4),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
        },
      ),
      iconTheme: IconThemeData(color: label, size: 24),
      primaryIconTheme: IconThemeData(color: action, size: 24),
      chipTheme: ChipThemeData(
        backgroundColor: recessed,
        selectedColor: glass.tonalBg,
        labelStyle: AscentTextStyles.labelSmall.copyWith(color: label),
        secondaryLabelStyle: AscentTextStyles.labelSmall.copyWith(
          color: glass.tonalFg,
          fontWeight: FontWeight.w600,
        ),
        checkmarkColor: glass.tonalFg,
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: elevated,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: AscentTextStyles.cardTitle.copyWith(color: label),
        contentTextStyle: AscentTextStyles.supportingText.copyWith(
          color: secondary,
        ),
        elevation: 0,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: elevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: separator),
        ),
        elevation: 4,
        shadowColor: Color.fromRGBO(0, 0, 0, isDark ? .30 : .10),
        surfaceTintColor: Colors.transparent,
        menuPadding: const EdgeInsets.symmetric(vertical: 4),
        textStyle: AscentTextStyles.body.copyWith(
          color: label,
          fontWeight: FontWeight.w500,
        ),
        labelTextStyle: WidgetStatePropertyAll(
          AscentTextStyles.body.copyWith(
            color: label,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: action,
        inactiveTrackColor: separator,
        trackHeight: 4,
        thumbColor: action,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: action,
        linearTrackColor: glass.track,
        linearMinHeight: 4,
        borderRadius: BorderRadius.circular(4),
      ),
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(tertiary.withValues(alpha: .45)),
        radius: const Radius.circular(4),
        thickness: const WidgetStatePropertyAll(4),
        interactive: true,
      ),
      extensions: [
        isDark ? AppColors.dark : AppColors.light,
        glass,
        isDark ? AppSurfaces.night : AppSurfaces.legacyLight,
      ],
    );
  }
}
