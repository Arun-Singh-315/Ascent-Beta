import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'color_tokens.dart';
import 'frozen_palette.dart';
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

  static ThemeData light({
    DayThemePreset preset = DayThemePreset.classicClay,
  }) => _build(brightness: Brightness.light, preset: preset);

  // ── Dark ───────────────────────────────────────────────────────────────────

  static ThemeData dark({DayThemePreset preset = DayThemePreset.classicClay}) =>
      _build(brightness: Brightness.dark, preset: preset);

  static ThemeData assistant(ThemeData parent) {
    if (parent.brightness == Brightness.dark) return parent;
    final parentGlass = parent.extension<AscentGlass>() ?? AscentGlass.light;
    final isNordic = parentGlass.frozen;
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
    final isNordicSky = preset == DayThemePreset.nordicSky;
    final day = !isDark && outlinedDay;

    // Resolve semantic tokens for this brightness.
    final bgBase = isNordicSky
        ? (isDark ? FrozenPalette.darkCanvas : FrozenPalette.canvas)
        : (isDark ? AscentColors.bgBaseDark : AscentColors.bgBase);
    final bgSurface = isNordicSky
        ? (isDark ? FrozenPalette.darkSurface : FrozenPalette.surface)
        : (isDark ? AscentColors.bgSurfaceDark : AscentColors.bgSurface);
    final bgSurfaceElevated = isNordicSky
        ? (isDark ? FrozenPalette.darkElevated : FrozenPalette.elevated)
        : (isDark
              ? AscentColors.bgSurfaceElevatedDark
              : AscentColors.bgSurfaceElevated);
    final accentPrimary = isNordicSky
        ? (isDark ? FrozenPalette.darkAction : FrozenPalette.action)
        : (isDark
              ? AscentColors.accentPrimaryDark
              : AscentColors.accentPrimary);
    final accentSecondary = isNordicSky
        ? (isDark ? FrozenPalette.darkAction : FrozenPalette.action)
        : (isDark
              ? AscentColors.accentSecondaryDark
              : AscentColors.accentSecondary);
    final accentInfo = isNordicSky
        ? (isDark ? FrozenPalette.darkWarning : FrozenPalette.warning)
        : (isDark ? AscentColors.accentInfoDark : AscentColors.accentInfo);
    final stateDanger = isNordicSky
        ? (isDark ? FrozenPalette.darkDanger : FrozenPalette.danger)
        : (isDark ? AscentColors.stateDangerDark : AscentColors.stateDanger);
    final textPrimary = day
        ? (isNordicSky ? AppSurfaces.nordicSky.ink : AppSurfaces.day.ink)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkInk : FrozenPalette.ink)
        : (isDark ? AscentColors.textPrimaryDark : AscentColors.textPrimary);
    final textMuted = day
        ? (isNordicSky
              ? AppSurfaces.nordicSky.mutedText
              : AppSurfaces.day.mutedText)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkMutedInk : FrozenPalette.mutedInk)
        : (isDark ? AscentColors.textMutedDark : AscentColors.textMuted);
    final textOnPrimary = isDark
        ? AscentColors.textOnPrimaryDark
        : AscentColors.textOnPrimary;
    final divider = day
        ? (isNordicSky
              ? AppSurfaces.nordicSky.dividerColor
              : AppSurfaces.day.dividerColor)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkLine : FrozenPalette.line)
        : (isDark ? AscentColors.dividerDark : AscentColors.divider);

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

    final cardRadius = Radius.circular(isNordicSky ? 16 : 14);
    final inputRadius = Radius.circular(isNordicSky ? 12 : 10);
    final buttonRadius = Radius.circular(isNordicSky ? 24 : 10);
    final sheetRadius = Radius.circular(isNordicSky ? 24 : 20);

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
        color: day
            ? AppSurfaces.day.cardFill
            : (isNordicSky
                  ? (isDark
                        ? FrozenPalette.darkSurface.withValues(alpha: 0.94)
                        : FrozenPalette.surface.withValues(alpha: 0.94))
                  : bgSurface),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(cardRadius),
          side: day
              ? BorderSide(
                  color: AppSurfaces.day.cardBorderColor,
                  width: AppSurfaces.day.cardBorderWidth,
                )
              : BorderSide(color: divider, width: isNordicSky ? 1.0 : 0.8),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      // ── Bottom navigation bar ───────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isNordicSky
            ? (isDark
                  ? FrozenPalette.darkSurface.withValues(alpha: 0.96)
                  : FrozenPalette.surface.withValues(alpha: 0.96))
            : bgBase,
        selectedItemColor: accentPrimary,
        unselectedItemColor: isNordicSky
            ? (isDark ? FrozenPalette.darkMutedInk : FrozenPalette.mutedInk)
            : textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
        showUnselectedLabels: true,
        selectedLabelStyle: AscentTextStyles.labelSmall,
        unselectedLabelStyle: AscentTextStyles.labelSmall,
      ),

      // ── Input decoration ────────────────────────────────────────────────────
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: day
            ? AppSurfaces.day.cardFill
            : (isNordicSky
                  ? (isDark ? FrozenPalette.darkSurface : FrozenPalette.surface)
                  : bgSurface),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(inputRadius),
          borderSide: BorderSide(
            color: day
                ? AppSurfaces.day.ink
                : (isNordicSky
                      ? (isDark ? FrozenPalette.darkLine : FrozenPalette.line)
                      : divider),
            width: day ? AppSurfaces.day.cardBorderWidth : 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(inputRadius),
          borderSide: BorderSide(
            color: day
                ? AppSurfaces.day.ink
                : (isNordicSky
                      ? (isDark ? FrozenPalette.darkLine : FrozenPalette.line)
                      : divider),
            width: day ? AppSurfaces.day.cardBorderWidth : 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(inputRadius),
          borderSide: BorderSide(
            color: accentPrimary,
            width: isNordicSky ? 2.0 : 1.3,
          ),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(inputRadius),
          borderSide: BorderSide(color: stateDanger, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(inputRadius),
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
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return isNordicSky
                  ? (isDark ? FrozenPalette.darkTint : FrozenPalette.tint)
                  : bgSurfaceElevated.withValues(alpha: 0.4);
            }
            return accentPrimary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return isNordicSky
                  ? (isDark
                        ? FrozenPalette.darkMutedInk
                        : FrozenPalette.mutedInk)
                  : textPrimary.withValues(alpha: 0.4);
            }
            return textOnPrimary;
          }),
          overlayColor: WidgetStatePropertyAll(
            textOnPrimary.withValues(alpha: 0.12),
          ),
          elevation: const WidgetStatePropertyAll(0),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(buttonRadius),
            ),
          ),
          minimumSize: WidgetStatePropertyAll(
            Size(
              64,
              isNordicSky ? 48 : (day ? AppSurfaces.day.minTapTarget : 42),
            ),
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
          foregroundColor: WidgetStatePropertyAll(accentPrimary),
          overlayColor: WidgetStatePropertyAll(
            accentPrimary.withValues(alpha: 0.08),
          ),
          textStyle: WidgetStatePropertyAll(AscentTextStyles.labelMedium),
          shape: WidgetStatePropertyAll(
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
          foregroundColor: WidgetStatePropertyAll(accentPrimary),
          overlayColor: WidgetStatePropertyAll(
            accentPrimary.withValues(alpha: 0.08),
          ),
          side: WidgetStatePropertyAll(
            BorderSide(
              color: day
                  ? AppSurfaces.day.ink
                  : (isNordicSky
                        ? (isDark ? FrozenPalette.darkLine : FrozenPalette.line)
                        : divider),
              width: day ? AppSurfaces.day.cardBorderWidth : 1.0,
            ),
          ),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.all(buttonRadius),
            ),
          ),
          minimumSize: WidgetStatePropertyAll(
            Size(
              64,
              isNordicSky ? 48 : (day ? AppSurfaces.day.minTapTarget : 42),
            ),
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
          if (isNordicSky) {
            return isDark
                ? FrozenPalette.darkSecondaryInk
                : FrozenPalette.secondaryInk;
          }
          return isDark ? const Color(0xFFB8A594) : const Color(0xFFD4C8BC);
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            if (isNordicSky) {
              return isDark ? FrozenPalette.darkAction : FrozenPalette.action;
            }
            return isDark
                ? accentPrimary.withValues(alpha: 0.38)
                : const Color(0xFFC07360).withValues(alpha: 0.28);
          }
          if (isNordicSky) {
            return isDark ? FrozenPalette.darkLine : FrozenPalette.line;
          }
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
            ? (isNordicSky ? FrozenPalette.darkInk : const Color(0xFF2D251E))
            : (isNordicSky ? FrozenPalette.ink : const Color(0xFF2B221B)),
        contentTextStyle: AscentTextStyles.bodyMedium.copyWith(
          color: const Color(0xFFF1F5F9),
          fontWeight: FontWeight.w500,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: Color(0x33FFFFFF), width: 0.9),
        ),
        behavior: SnackBarBehavior.floating,
        actionTextColor: isNordicSky
            ? (isDark ? FrozenPalette.darkTint : FrozenPalette.tint)
            : accentPrimary,
        elevation: day ? 0 : 6,
      ),

      // ── Bottom sheet ─────────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isNordicSky
            ? (isDark ? FrozenPalette.darkElevated : FrozenPalette.elevated)
            : bgSurface,
        modalBackgroundColor: isNordicSky
            ? (isDark ? FrozenPalette.darkElevated : FrozenPalette.elevated)
            : bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.only(
            topLeft: sheetRadius,
            topRight: sheetRadius,
          ),
        ),
        modalElevation: 0,
        elevation: 0,
        dragHandleColor: isNordicSky
            ? (isDark ? FrozenPalette.darkLine : FrozenPalette.line)
            : divider,
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
        backgroundColor: isNordicSky
            ? (isDark ? FrozenPalette.darkTint : FrozenPalette.tint)
            : (day ? AppSurfaces.day.cardFill : bgSurfaceElevated),
        selectedColor: isNordicSky
            ? accentPrimary
            : (day ? AppSurfaces.day.accent : null),
        labelStyle: WidgetStateTextStyle.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return AscentTextStyles.labelSmall.copyWith(
              color: isNordicSky
                  ? (isDark ? FrozenPalette.darkCanvas : Colors.white)
                  : textOnPrimary,
              fontWeight: FontWeight.w600,
            );
          }
          return AscentTextStyles.labelSmall.copyWith(
            color: isNordicSky ? accentPrimary : textPrimary,
          );
        }),
        secondaryLabelStyle: AscentTextStyles.labelSmall.copyWith(
          color: isNordicSky
              ? (isDark ? FrozenPalette.darkCanvas : Colors.white)
              : textOnPrimary,
          fontWeight: FontWeight.w600,
        ),
        checkmarkColor: isNordicSky
            ? (isDark ? FrozenPalette.darkCanvas : Colors.white)
            : textOnPrimary,
        side: isNordicSky
            ? BorderSide(
                color: isDark ? FrozenPalette.darkLine : FrozenPalette.line,
                width: 1.0,
              )
            : (day
                  ? BorderSide(
                      color: AppSurfaces.day.pillBorderColor,
                      width: AppSurfaces.day.pillBorderWidth,
                    )
                  : BorderSide.none),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),

      // ── Dialog ───────────────────────────────────────────────────────────────
      dialogTheme: DialogThemeData(
        backgroundColor: isNordicSky
            ? (isDark ? FrozenPalette.darkElevated : FrozenPalette.elevated)
            : bgSurface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(sheetRadius),
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
            ? (isNordicSky ? AscentGlass.nordicSkyDark : AscentGlass.dark)
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
