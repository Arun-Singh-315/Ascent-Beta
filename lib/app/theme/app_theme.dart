import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'color_tokens.dart';
import 'glass_theme.dart';
import 'text_styles.dart';
import 'surface_tokens.dart';
import '../../core/providers/settings_provider.dart';

/// Provides the light and dark [ThemeData] for the Ascent app.
///
/// Usage:
/// ```dart
/// MaterialApp(
///   theme: AscentTheme.light(),
///   darkTheme: AscentTheme.dark(),
/// )
/// ```
class AscentTheme {
  AscentTheme._();

  // ── Light ──────────────────────────────────────────────────────────────────

  static ThemeData light({DayThemePreset preset = DayThemePreset.classicClay}) =>
      _build(brightness: Brightness.light, preset: preset);

  // ── Dark ───────────────────────────────────────────────────────────────────

  static ThemeData dark() => _build(brightness: Brightness.dark);

  static ThemeData assistant(ThemeData parent) {
    if (parent.brightness == Brightness.dark) return parent;
    final parentGlass = parent.extension<AscentGlass>() ?? AscentGlass.light;
    final isNordic = parentGlass.clay == const Color(0xFFC05621) ||
        parentGlass.slate == const Color(0xFF0284C7) ||
        parentGlass.bg == const Color(0xFFF0F4F9);
    final original = _build(
      brightness: Brightness.light,
      preset: isNordic ? DayThemePreset.nordicSky : DayThemePreset.classicClay,
      outlinedDay: false,
    );
    return original.copyWith(
      extensions: [
        isNordic ? AscentGlass.nordicSky : AscentGlass.light,
        isNordic ? AppSurfaces.legacyNordicSky : AppSurfaces.legacyLight,
      ],
    );
  }

  // ── Utility ────────────────────────────────────────────────────────────────

  /// Overlays JetBrains Mono onto any [TextStyle] for use in numeric/stat
  /// contexts that fall outside the standard type scale.
  static TextStyle monoStyle(TextStyle base) =>
      GoogleFonts.jetBrainsMono(textStyle: base);

  // ── Internal builder ───────────────────────────────────────────────────────

  static ThemeData _build({
    required Brightness brightness,
    DayThemePreset preset = DayThemePreset.classicClay,
    bool outlinedDay = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final isNordicSky = !isDark && preset == DayThemePreset.nordicSky;
    final day = !isDark && outlinedDay;

    // Resolve semantic tokens for this brightness.
    final bgBase = isDark
        ? AscentColors.bgBaseDark
        : (isNordicSky ? const Color(0xFFF0F4F9) : AscentColors.bgBase);
    final bgSurface = isDark
        ? AscentColors.bgSurfaceDark
        : AscentColors.bgSurface;
    final bgSurfaceElevated = isDark
        ? AscentColors.bgSurfaceElevatedDark
        : (isNordicSky ? const Color(0xFFE8EEF5) : AscentColors.bgSurfaceElevated);
    final accentPrimary = isDark
        ? AscentColors.accentPrimaryDark
        : (isNordicSky ? const Color(0xFF0284C7) : AscentColors.accentPrimary);
    final accentSecondary = isDark
        ? AscentColors.accentSecondaryDark
        : (isNordicSky ? const Color(0xFF0369A1) : AscentColors.accentSecondary);
    final accentInfo = isDark
        ? AscentColors.accentInfoDark
        : (isNordicSky ? const Color(0xFFD97706) : AscentColors.accentInfo);
    final stateDanger = isDark
        ? AscentColors.stateDangerDark
        : (isNordicSky ? const Color(0xFFDC2626) : AscentColors.stateDanger);
    final textPrimary = day
        ? (isNordicSky ? AppSurfaces.nordicSky.ink : AppSurfaces.day.ink)
        : isDark
        ? AscentColors.textPrimaryDark
        : (isNordicSky ? const Color(0xFF0F172A) : AscentColors.textPrimary);
    final textMuted = day
        ? (isNordicSky ? AppSurfaces.nordicSky.mutedText : AppSurfaces.day.mutedText)
        : isDark
        ? AscentColors.textMutedDark
        : (isNordicSky ? const Color(0xFF64748B) : AscentColors.textMuted);
    final textOnPrimary = isDark
        ? AscentColors.textOnPrimaryDark
        : AscentColors.textOnPrimary;
    final divider = day
        ? (isNordicSky ? AppSurfaces.nordicSky.dividerColor : AppSurfaces.day.dividerColor)
        : isDark
        ? AscentColors.dividerDark
        : (isNordicSky ? const Color(0xFFE2E8F0) : AscentColors.divider);

    final colorScheme = ColorScheme(
      brightness: brightness,
      primary: accentPrimary,
      onPrimary: textOnPrimary,
      primaryContainer: bgSurfaceElevated,
      onPrimaryContainer: textPrimary,
      secondary: accentSecondary,
      onSecondary: textOnPrimary,
      secondaryContainer: bgSurfaceElevated,
      onSecondaryContainer: textPrimary,
      tertiary: accentInfo,
      onTertiary: textOnPrimary,
      tertiaryContainer: bgSurfaceElevated,
      onTertiaryContainer: textPrimary,
      error: stateDanger,
      onError: textOnPrimary,
      errorContainer: bgSurfaceElevated,
      onErrorContainer: stateDanger,
      surface: bgSurface,
      onSurface: textPrimary,
      surfaceContainerHighest: bgSurfaceElevated,
      onSurfaceVariant: textMuted,
      outline: divider,
      outlineVariant: divider,
      shadow: isDark ? AscentColors.shadowDark : AscentColors.shadow,
      scrim: isDark ? AscentColors.shadowDark : AscentColors.shadow,
      inverseSurface: textPrimary,
      onInverseSurface: bgBase,
      inversePrimary: accentPrimary,
    );

    final baseTextTheme = TextTheme(
      displayLarge: AscentTextStyles.displayLarge.copyWith(color: textPrimary),
      displayMedium: AscentTextStyles.displayMedium.copyWith(
        color: textPrimary,
      ),
      displaySmall: AscentTextStyles.displaySmall.copyWith(color: textPrimary),
      headlineLarge: AscentTextStyles.displayLarge.copyWith(color: textPrimary),
      headlineMedium: AscentTextStyles.displayMedium.copyWith(
        color: textPrimary,
      ),
      headlineSmall: AscentTextStyles.displaySmall.copyWith(color: textPrimary),
      titleLarge: AscentTextStyles.labelLarge.copyWith(color: textPrimary),
      titleMedium: AscentTextStyles.bodyMediumMedium.copyWith(
        color: textPrimary,
      ),
      titleSmall: AscentTextStyles.labelSmall.copyWith(color: textPrimary),
      bodyLarge: AscentTextStyles.bodyLarge.copyWith(color: textPrimary),
      bodyMedium: AscentTextStyles.bodyMedium.copyWith(color: textPrimary),
      bodySmall: AscentTextStyles.bodySmall.copyWith(color: textMuted),
      labelLarge: AscentTextStyles.labelLarge.copyWith(color: textPrimary),
      labelMedium: AscentTextStyles.bodyMediumMedium.copyWith(color: textMuted),
      labelSmall: AscentTextStyles.labelSmall.copyWith(color: textMuted),
    );

    const cardRadius = Radius.circular(14);
    const inputRadius = Radius.circular(10);
    const buttonRadius = Radius.circular(10);
    const sheetRadius = Radius.circular(20);

    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgBase,
      fontFamily: GoogleFonts.inter().fontFamily,
      textTheme: baseTextTheme,

      // ── App bar ─────────────────────────────────────────────────────────────
      appBarTheme: AppBarTheme(
        backgroundColor: bgBase,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: day ? 0 : 0.5,
        shadowColor: (isDark ? AscentColors.shadowDark : AscentColors.shadow)
            .withValues(alpha: 0.08),
        centerTitle: false,
        titleTextStyle: AscentTextStyles.displaySmall.copyWith(
          color: textPrimary,
        ),
        iconTheme: IconThemeData(color: textPrimary),
        actionsIconTheme: IconThemeData(color: textMuted),
      ),

      // ── Card ────────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: day ? AppSurfaces.day.cardFill : bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(cardRadius),
          side: day
              ? BorderSide(
                  color: AppSurfaces.day.cardBorderColor,
                  width: AppSurfaces.day.cardBorderWidth,
                )
              : BorderSide(color: divider, width: 0.8),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      // ── Bottom navigation bar ───────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: bgBase,
        selectedItemColor: accentPrimary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
        selectedLabelStyle: AscentTextStyles.labelSmall,
        unselectedLabelStyle: AscentTextStyles.labelSmall,
      ),

      // ── Input decoration ────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: day ? AppSurfaces.day.cardFill : bgSurface,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(inputRadius),
          borderSide: BorderSide(
            color: day ? AppSurfaces.day.ink : divider,
            width: day ? AppSurfaces.day.cardBorderWidth : 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(inputRadius),
          borderSide: BorderSide(
            color: day ? AppSurfaces.day.ink : divider,
            width: day ? AppSurfaces.day.cardBorderWidth : 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(inputRadius),
          borderSide: BorderSide(color: accentPrimary, width: 1.3),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(inputRadius),
          borderSide: BorderSide(color: stateDanger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(inputRadius),
          borderSide: BorderSide(color: stateDanger, width: 1.3),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 12,
        ),
        hintStyle: AscentTextStyles.bodyMedium.copyWith(color: textMuted),
        labelStyle: AscentTextStyles.bodyMedium.copyWith(color: textMuted),
        floatingLabelStyle: AscentTextStyles.labelSmall.copyWith(
          color: accentPrimary,
        ),
      ),

      // ── Elevated button ─────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(accentPrimary),
          foregroundColor: WidgetStatePropertyAll(textOnPrimary),
          overlayColor: WidgetStatePropertyAll(
            textOnPrimary.withValues(alpha: 0.12),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(buttonRadius),
            ),
          ),
          minimumSize: WidgetStatePropertyAll(
            Size(64, day ? AppSurfaces.day.minTapTarget : 42),
          ),
          textStyle: WidgetStatePropertyAll(AscentTextStyles.labelMedium),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
        ),
      ),

      // ── Text button ─────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(
            isNordicSky ? const Color(0xFF0369A1) : accentPrimary,
          ),
          overlayColor: WidgetStatePropertyAll(
            (isNordicSky ? const Color(0xFF0369A1) : accentPrimary)
                .withValues(alpha: 0.08),
          ),
          textStyle: WidgetStatePropertyAll(AscentTextStyles.labelMedium),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(buttonRadius),
            ),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          ),
        ),
      ),

      // ── Outlined button ─────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(
            isNordicSky ? const Color(0xFF0F172A) : accentPrimary,
          ),
          overlayColor: WidgetStatePropertyAll(
            accentPrimary.withValues(alpha: 0.08),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(
              color: day
                  ? AppSurfaces.day.ink
                  : (isNordicSky ? const Color(0xFFCBD5E1) : divider),
              width: day ? AppSurfaces.day.cardBorderWidth : 1.0,
            ),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(buttonRadius),
            ),
          ),
          minimumSize: WidgetStatePropertyAll(
            Size(64, day ? AppSurfaces.day.minTapTarget : 42),
          ),
          textStyle: WidgetStatePropertyAll(AscentTextStyles.labelMedium),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
        ),
      ),

      // ── Switch ──────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            if (isNordicSky) return const Color(0xFFFFFFFF);
            return isDark ? accentPrimary : const Color(0xFFC07360);
          }
          if (isNordicSky) return const Color(0xFF475569);
          return isDark ? const Color(0xFFB8A594) : const Color(0xFFD4C8BC);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            if (isNordicSky) return const Color(0xFF0284C7);
            return isDark
                ? accentPrimary.withValues(alpha: 0.38)
                : const Color(0xFFC07360).withValues(alpha: 0.28);
          }
          if (isNordicSky) return const Color(0xFFCBD5E1);
          return isDark ? const Color(0xFF3B2C1E) : const Color(0xFFEFE8E2);
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),

      // ── Divider ─────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: day ? AppSurfaces.day.dividerColor : divider,
        thickness: 1,
        space: 1,
      ),

      // ── Snack bar ────────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? const Color(0xFF2D251E)
            : const Color(0xFF2B221B),
        contentTextStyle: AscentTextStyles.bodyMedium.copyWith(
          color: const Color(0xFFF1F5F9),
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          side: BorderSide(
            color: isDark ? const Color(0x33FFFFFF) : const Color(0x1F000000),
            width: 0.9,
          ),
        ),
        behavior: SnackBarBehavior.floating,
        actionTextColor: accentPrimary,
        elevation: day ? 0 : 6,
      ),

      // ── Bottom sheet ─────────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: bgSurface,
        modalBackgroundColor: bgSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: sheetRadius,
            topRight: sheetRadius,
          ),
        ),
        modalElevation: 0,
        elevation: 0,
        dragHandleColor: divider,
        dragHandleSize: const Size(40, 4),
      ),

      // ── Page transitions ─────────────────────────────────────────────────────
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: ZoomPageTransitionsBuilder(),
          TargetPlatform.iOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.linux: ZoomPageTransitionsBuilder(),
          TargetPlatform.macOS: ZoomPageTransitionsBuilder(),
          TargetPlatform.windows: ZoomPageTransitionsBuilder(),
          TargetPlatform.fuchsia: ZoomPageTransitionsBuilder(),
        },
      ),

      // ── Icon theme ───────────────────────────────────────────────────────────
      iconTheme: IconThemeData(color: textPrimary, size: 24),
      primaryIconTheme: IconThemeData(color: accentPrimary, size: 24),

      // ── Chip ─────────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: day ? AppSurfaces.day.cardFill : bgSurfaceElevated,
        selectedColor: day ? AppSurfaces.day.accent : null,
        labelStyle: AscentTextStyles.labelSmall.copyWith(color: textPrimary),
        side: day
            ? BorderSide(
                color: AppSurfaces.day.pillBorderColor,
                width: AppSurfaces.day.pillBorderWidth,
              )
            : BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Dialog ───────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: bgSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: AscentTextStyles.displaySmall.copyWith(
          color: textPrimary,
        ),
        contentTextStyle: AscentTextStyles.bodyMedium.copyWith(
          color: textMuted,
        ),
        elevation: 0,
      ),
      extensions: [
        isDark
            ? AscentGlass.dark
            : isNordicSky
            ? (!day
                ? AscentGlass.nordicSky
                : AscentGlass.nordicSky.copyWith(
                    fill: AppSurfaces.nordicSky.cardFill,
                    line: AppSurfaces.nordicSky.dividerColor,
                    clay: AppSurfaces.nordicSky.accent,
                    claySoft: AppSurfaces.nordicSky.tintFill,
                    ink: AppSurfaces.nordicSky.ink,
                    inkMuted: AppSurfaces.nordicSky.mutedText,
                    glow1: Colors.transparent,
                    glow2: Colors.transparent,
                    shadow: Colors.transparent,
                  ))
            : !day
            ? AscentGlass.light
            : AscentGlass.light.copyWith(
                fill: AppSurfaces.day.cardFill,
                line: AppSurfaces.day.dividerColor,
                clay: AppSurfaces.day.accent,
                claySoft: AppSurfaces.day.tintFill,
                ink: AppSurfaces.day.ink,
                inkMuted: AppSurfaces.day.mutedText,
                glow1: Colors.transparent,
                glow2: Colors.transparent,
                shadow: Colors.transparent,
              ),
        isDark
            ? AppSurfaces.night
            : isNordicSky
            ? (day ? AppSurfaces.nordicSky : AppSurfaces.legacyNordicSky)
            : (day ? AppSurfaces.day : AppSurfaces.legacyLight),
      ],
    );
  }
}
