import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'color_tokens.dart';
import 'text_styles.dart';

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

  static ThemeData light() => _build(brightness: Brightness.light);

  // ── Dark ───────────────────────────────────────────────────────────────────

  static ThemeData dark() => _build(brightness: Brightness.dark);

  // ── Utility ────────────────────────────────────────────────────────────────

  /// Overlays JetBrains Mono onto any [TextStyle] for use in numeric/stat
  /// contexts that fall outside the standard type scale.
  static TextStyle monoStyle(TextStyle base) =>
      GoogleFonts.jetBrainsMono(textStyle: base);

  // ── Internal builder ───────────────────────────────────────────────────────

  static ThemeData _build({required Brightness brightness}) {
    final isDark = brightness == Brightness.dark;

    // Resolve semantic tokens for this brightness.
    final bgBase =
        isDark ? AscentColors.bgBaseDark : AscentColors.bgBase;
    final bgSurface =
        isDark ? AscentColors.bgSurfaceDark : AscentColors.bgSurface;
    final bgSurfaceElevated = isDark
        ? AscentColors.bgSurfaceElevatedDark
        : AscentColors.bgSurfaceElevated;
    final accentPrimary =
        isDark ? AscentColors.accentPrimaryDark : AscentColors.accentPrimary;
    final accentSecondary = isDark
        ? AscentColors.accentSecondaryDark
        : AscentColors.accentSecondary;
    final accentInfo =
        isDark ? AscentColors.accentInfoDark : AscentColors.accentInfo;
    final stateDanger =
        isDark ? AscentColors.stateDangerDark : AscentColors.stateDanger;
    final textPrimary =
        isDark ? AscentColors.textPrimaryDark : AscentColors.textPrimary;
    final textMuted =
        isDark ? AscentColors.textMutedDark : AscentColors.textMuted;
    final textOnPrimary = isDark
        ? AscentColors.textOnPrimaryDark
        : AscentColors.textOnPrimary;
    final divider =
        isDark ? AscentColors.dividerDark : AscentColors.divider;

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
      displayLarge: AscentTextStyles.displayLarge
          .copyWith(color: textPrimary),
      displayMedium: AscentTextStyles.displayMedium
          .copyWith(color: textPrimary),
      displaySmall: AscentTextStyles.displaySmall
          .copyWith(color: textPrimary),
      headlineLarge: AscentTextStyles.displayLarge
          .copyWith(color: textPrimary),
      headlineMedium: AscentTextStyles.displayMedium
          .copyWith(color: textPrimary),
      headlineSmall: AscentTextStyles.displaySmall
          .copyWith(color: textPrimary),
      titleLarge: AscentTextStyles.labelLarge
          .copyWith(color: textPrimary),
      titleMedium: AscentTextStyles.bodyMediumMedium
          .copyWith(color: textPrimary),
      titleSmall: AscentTextStyles.labelSmall
          .copyWith(color: textPrimary),
      bodyLarge: AscentTextStyles.bodyLarge.copyWith(color: textPrimary),
      bodyMedium: AscentTextStyles.bodyMedium.copyWith(color: textPrimary),
      bodySmall: AscentTextStyles.bodySmall.copyWith(color: textMuted),
      labelLarge: AscentTextStyles.labelLarge.copyWith(color: textPrimary),
      labelMedium: AscentTextStyles.bodyMediumMedium
          .copyWith(color: textMuted),
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
        scrolledUnderElevation: 0.5,
        shadowColor: (isDark ? AscentColors.shadowDark : AscentColors.shadow)
            .withValues(alpha: 0.08),
        centerTitle: false,
        titleTextStyle: AscentTextStyles.displaySmall
            .copyWith(color: textPrimary),
        iconTheme: IconThemeData(color: textPrimary),
        actionsIconTheme: IconThemeData(color: textMuted),
      ),

      // ── Card ────────────────────────────────────────────────────────────────
      cardTheme: CardThemeData(
        color: bgSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(cardRadius),
          side: BorderSide(color: divider, width: 0.8),
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
        fillColor: bgSurface,
        border: OutlineInputBorder(
          borderRadius: const BorderRadius.all(inputRadius),
          borderSide: BorderSide(color: divider, width: 1.0),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: const BorderRadius.all(inputRadius),
          borderSide: BorderSide(color: divider, width: 1.0),
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
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        hintStyle: AscentTextStyles.bodyMedium.copyWith(color: textMuted),
        labelStyle: AscentTextStyles.bodyMedium.copyWith(color: textMuted),
        floatingLabelStyle:
            AscentTextStyles.labelSmall.copyWith(color: accentPrimary),
      ),

      // ── Elevated button ─────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStatePropertyAll(accentPrimary),
          foregroundColor: WidgetStatePropertyAll(textOnPrimary),
          overlayColor:
              WidgetStatePropertyAll(textOnPrimary.withValues(alpha: 0.12)),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(buttonRadius),
            ),
          ),
          minimumSize:
              const WidgetStatePropertyAll(Size(double.infinity, 42)),
          textStyle: WidgetStatePropertyAll(AscentTextStyles.labelMedium),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
        ),
      ),

      // ── Text button ─────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(accentPrimary),
          overlayColor:
              WidgetStatePropertyAll(accentPrimary.withValues(alpha: 0.08)),
          textStyle: WidgetStatePropertyAll(AscentTextStyles.labelMedium),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(buttonRadius),
            ),
          ),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 14, vertical: 8)),
        ),
      ),

      // ── Outlined button ─────────────────────────────────────────────────────
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(accentPrimary),
          overlayColor:
              WidgetStatePropertyAll(accentPrimary.withValues(alpha: 0.08)),
          side: WidgetStatePropertyAll(
            BorderSide(color: divider, width: 1.0),
          ),
          shape: const WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(buttonRadius),
            ),
          ),
          minimumSize:
              const WidgetStatePropertyAll(Size(double.infinity, 42)),
          textStyle: WidgetStatePropertyAll(AscentTextStyles.labelMedium),
          padding: const WidgetStatePropertyAll(
              EdgeInsets.symmetric(horizontal: 18, vertical: 10)),
        ),
      ),

      // ── Divider ─────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: divider,
        thickness: 1,
        space: 1,
      ),

      // ── Snack bar ────────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: AscentTextStyles.bodyMedium
            .copyWith(color: Colors.white),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(12)),
        ),
        behavior: SnackBarBehavior.floating,
        width: 340,
        actionTextColor: accentPrimary,
        elevation: 4,
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
        backgroundColor: bgSurfaceElevated,
        labelStyle: AscentTextStyles.labelSmall.copyWith(color: textPrimary),
        side: BorderSide.none,
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Dialog ───────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: bgSurface,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
        ),
        titleTextStyle: AscentTextStyles.displaySmall
            .copyWith(color: textPrimary),
        contentTextStyle:
            AscentTextStyles.bodyMedium.copyWith(color: textMuted),
        elevation: 0,
      ),
    );
  }
}
