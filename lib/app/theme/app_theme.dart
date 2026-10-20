import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'color_tokens.dart';
import 'frozen_palette.dart';
import 'merlot_palette.dart';
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
    DayThemePreset preset = DayThemePreset.merlotLinen,
  }) => _build(brightness: Brightness.light, preset: preset);

  // ── Dark ───────────────────────────────────────────────────────────────────

  static ThemeData dark({DayThemePreset preset = DayThemePreset.classicClay}) =>
      _build(brightness: Brightness.dark, preset: preset);

  static ThemeData assistant(ThemeData parent) {
    if (parent.brightness == Brightness.dark) return parent;
    final parentGlass = parent.extension<AscentGlass>() ?? AscentGlass.light;
    final isNordic = parentGlass.frozen;
    final isClay = parentGlass.clay == AscentColors.accentPrimary;
    final preset = isNordic
        ? DayThemePreset.nordicSky
        : (isClay ? DayThemePreset.classicClay : DayThemePreset.merlotLinen);
    final original = _build(
      brightness: Brightness.light,
      preset: preset,
      outlinedDay: false,
    );
    final glass = isNordic
        ? AscentGlass.nordicSky
        : (isClay ? AscentGlass.light : AscentGlass.merlotLinenLight);
    final surfaces = isNordic
        ? AppSurfaces.legacyNordicSky
        : (isClay ? AppSurfaces.legacyLight : AppSurfaces.legacyMerlotLinen);
    return original.copyWith(
      extensions: [glass, surfaces],
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
    DayThemePreset preset = DayThemePreset.merlotLinen,
    bool outlinedDay = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final isNordicSky = preset == DayThemePreset.nordicSky;
    final isMerlotLinen = preset == DayThemePreset.merlotLinen;
    final day = !isDark && outlinedDay;

    // Resolve semantic tokens for this brightness.
    final bgBase = isMerlotLinen
        ? (isDark ? MerlotPalette.darkCanvas : MerlotPalette.canvas)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkCanvas : FrozenPalette.canvas)
        : (isDark ? AscentColors.bgBaseDark : AscentColors.bgBase);
    final bgSurface = isMerlotLinen
        ? (isDark ? MerlotPalette.darkSurface : MerlotPalette.surface)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkSurface : FrozenPalette.surface)
        : (isDark ? AscentColors.bgSurfaceDark : AscentColors.bgSurface);
    final bgSurfaceElevated = isMerlotLinen
        ? (isDark ? MerlotPalette.darkElevated : MerlotPalette.elevated)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkElevated : FrozenPalette.elevated)
        : (isDark
              ? AscentColors.bgSurfaceElevatedDark
              : AscentColors.bgSurfaceElevated);
    final accentPrimary = isMerlotLinen
        ? (isDark ? MerlotPalette.darkAction : MerlotPalette.action)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkAction : FrozenPalette.action)
        : (isDark
              ? AscentColors.accentPrimaryDark
              : AscentColors.accentPrimary);
    final accentSecondary = isMerlotLinen
        ? (isDark ? MerlotPalette.darkSpark : MerlotPalette.antiqueGold)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkAction : FrozenPalette.action)
        : (isDark
              ? AscentColors.accentSecondaryDark
              : AscentColors.accentSecondary);
    final accentInfo = isMerlotLinen
        ? (isDark ? MerlotPalette.darkWarning : MerlotPalette.warning)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkWarning : FrozenPalette.warning)
        : (isDark ? AscentColors.accentInfoDark : AscentColors.accentInfo);
    final stateDanger = isMerlotLinen
        ? (isDark ? MerlotPalette.darkDanger : MerlotPalette.danger)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkDanger : FrozenPalette.danger)
        : (isDark ? AscentColors.stateDangerDark : AscentColors.stateDanger);
    final textPrimary = day
        ? (isMerlotLinen
              ? AppSurfaces.merlotLinen.ink
              : isNordicSky
              ? AppSurfaces.nordicSky.ink
              : AppSurfaces.day.ink)
        : isMerlotLinen
        ? (isDark ? MerlotPalette.darkInk : MerlotPalette.ink)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkInk : FrozenPalette.ink)
        : (isDark ? AscentColors.textPrimaryDark : AscentColors.textPrimary);
    final textMuted = day
        ? (isMerlotLinen
              ? AppSurfaces.merlotLinen.mutedText
              : isNordicSky
              ? AppSurfaces.nordicSky.mutedText
              : AppSurfaces.day.mutedText)
        : isMerlotLinen
        ? (isDark ? MerlotPalette.darkMutedInk : MerlotPalette.mutedInk)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkMutedInk : FrozenPalette.mutedInk)
        : (isDark ? AscentColors.textMutedDark : AscentColors.textMuted);
    final textOnPrimary = isDark
        ? (isMerlotLinen ? Colors.white : AscentColors.textOnPrimaryDark)
        : AscentColors.textOnPrimary;
    final divider = day
        ? (isMerlotLinen
              ? AppSurfaces.merlotLinen.dividerColor
              : isNordicSky
              ? AppSurfaces.nordicSky.dividerColor
              : AppSurfaces.day.dividerColor)
        : isMerlotLinen
        ? (isDark ? MerlotPalette.darkLineSubtle : MerlotPalette.lineSubtle)
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

    final cardRadius = Radius.circular(
      isMerlotLinen ? 20 : (isNordicSky ? 16 : 14),
    );
    final inputRadius = Radius.circular(
      isMerlotLinen ? 16 : (isNordicSky ? 12 : 10),
    );
    final buttonRadius = Radius.circular(
      isMerlotLinen ? 20 : (isNordicSky ? 24 : 10),
    );
    final sheetRadius = Radius.circular(
      isMerlotLinen ? 24 : (isNordicSky ? 24 : 20),
    );

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
            ? (isMerlotLinen
                ? AppSurfaces.merlotLinen.cardFill
                : isNordicSky
                    ? AppSurfaces.nordicSky.cardFill
                    : AppSurfaces.day.cardFill)
            : (isMerlotLinen
                  ? (isDark
                        ? AscentColors.bgSurfaceDark
                        : MerlotPalette.surface.withValues(alpha: 0.96))
                  : isNordicSky
                      ? (isDark
                            ? FrozenPalette.darkSurface.withValues(alpha: 0.94)
                            : FrozenPalette.surface.withValues(alpha: 0.94))
                      : bgSurface),
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(cardRadius),
          side: day
              ? BorderSide(
                  color: isMerlotLinen
                      ? AppSurfaces.merlotLinen.cardBorderColor
                      : isNordicSky
                          ? AppSurfaces.nordicSky.cardBorderColor
                          : AppSurfaces.day.cardBorderColor,
                  width: isMerlotLinen
                      ? AppSurfaces.merlotLinen.cardBorderWidth
                      : AppSurfaces.day.cardBorderWidth,
                )
              : BorderSide(
                  color: isMerlotLinen
                      ? (isDark ? AscentColors.dividerDark : MerlotPalette.line)
                      : divider,
                  width: (isNordicSky || isMerlotLinen) ? 1.0 : 0.8,
                ),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      // ── Bottom navigation bar ───────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isMerlotLinen
            ? (isDark
                  ? AscentColors.bgSurfaceElevatedDark
                  : MerlotPalette.elevated.withValues(alpha: 0.96))
            : isNordicSky
                ? (isDark
                      ? FrozenPalette.darkSurface.withValues(alpha: 0.96)
                      : FrozenPalette.surface.withValues(alpha: 0.96))
                : bgBase,
        selectedItemColor: accentPrimary,
        unselectedItemColor: isMerlotLinen
            ? (isDark ? AscentColors.textMutedDark : MerlotPalette.mutedInk)
            : isNordicSky
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
            ? (isMerlotLinen
                ? AppSurfaces.merlotLinen.cardFill
                : isNordicSky
                    ? AppSurfaces.nordicSky.cardFill
                    : AppSurfaces.day.cardFill)
            : (isMerlotLinen
                  ? (isDark ? AscentColors.bgSurfaceDark : MerlotPalette.surface)
                  : isNordicSky
                      ? (isDark
                            ? FrozenPalette.darkSurface
                            : FrozenPalette.surface)
                      : bgSurface),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(inputRadius),
          borderSide: BorderSide(
            color: day
                ? (isMerlotLinen
                    ? AppSurfaces.merlotLinen.cardBorderColor
                    : isNordicSky
                        ? AppSurfaces.nordicSky.cardBorderColor
                        : AppSurfaces.day.ink)
                : (isMerlotLinen
                      ? (isDark ? AscentColors.dividerDark : MerlotPalette.line)
                      : isNordicSky
                          ? (isDark
                                ? FrozenPalette.darkLine
                                : FrozenPalette.line)
                          : divider),
            width: day
                ? (isMerlotLinen
                    ? AppSurfaces.merlotLinen.cardBorderWidth
                    : AppSurfaces.day.cardBorderWidth)
                : 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(inputRadius),
          borderSide: BorderSide(
            color: day
                ? (isMerlotLinen
                    ? AppSurfaces.merlotLinen.cardBorderColor
                    : isNordicSky
                        ? AppSurfaces.nordicSky.cardBorderColor
                        : AppSurfaces.day.ink)
                : (isMerlotLinen
                      ? (isDark ? AscentColors.dividerDark : MerlotPalette.line)
                      : isNordicSky
                          ? (isDark
                                ? FrozenPalette.darkLine
                                : FrozenPalette.line)
                          : divider),
            width: day
                ? (isMerlotLinen
                    ? AppSurfaces.merlotLinen.cardBorderWidth
                    : AppSurfaces.day.cardBorderWidth)
                : 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(inputRadius),
          borderSide: BorderSide(
            color: accentPrimary,
            width: (isNordicSky || isMerlotLinen) ? 2.0 : 1.3,
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
              if (isMerlotLinen) {
                return isDark
                    ? AscentColors.bgSurfaceElevatedDark
                    : MerlotPalette.tint;
              }
              return isNordicSky
                  ? (isDark ? FrozenPalette.darkTint : FrozenPalette.tint)
                  : bgSurfaceElevated.withValues(alpha: 0.4);
            }
            return accentPrimary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              if (isMerlotLinen) {
                return isDark
                    ? AscentColors.textMutedDark
                    : MerlotPalette.mutedInk;
              }
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
              (isNordicSky || isMerlotLinen)
                  ? 48
                  : (day ? AppSurfaces.day.minTapTarget : 42),
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
                  ? (isMerlotLinen
                      ? AppSurfaces.merlotLinen.cardBorderColor
                      : isNordicSky
                          ? AppSurfaces.nordicSky.cardBorderColor
                          : AppSurfaces.day.ink)
                  : (isMerlotLinen
                        ? (isDark ? AscentColors.dividerDark : MerlotPalette.line)
                        : isNordicSky
                            ? (isDark
                                  ? FrozenPalette.darkLine
                                  : FrozenPalette.line)
                            : divider),
              width: day
                  ? (isMerlotLinen
                      ? AppSurfaces.merlotLinen.cardBorderWidth
                      : AppSurfaces.day.cardBorderWidth)
                  : 1.0,
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
              (isNordicSky || isMerlotLinen)
                  ? 48
                  : (day ? AppSurfaces.day.minTapTarget : 42),
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
            if (isMerlotLinen) {
              return Colors.white;
            }
            if (isNordicSky) return const Color(0xFFFFFFFF);
            return isDark ? accentPrimary : const Color(0xFFC07360);
          }
          if (isMerlotLinen) {
            return isDark
                ? AscentColors.textMutedDark
                : MerlotPalette.secondaryInk;
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
            if (isMerlotLinen) {
              return MerlotPalette.action;
            }
            if (isNordicSky) {
              return isDark ? FrozenPalette.darkAction : FrozenPalette.action;
            }
            return isDark
                ? accentPrimary.withValues(alpha: 0.38)
                : const Color(0xFFC07360).withValues(alpha: 0.28);
          }
          if (isMerlotLinen) {
            return isDark ? AscentColors.dividerDark : MerlotPalette.lineSubtle;
          }
          if (isNordicSky) {
            return isDark ? FrozenPalette.darkLine : FrozenPalette.line;
          }
          return isDark ? const Color(0xFF3B2C1E) : const Color(0xFFEFE8E2);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (isMerlotLinen) {
            return states.contains(WidgetState.selected)
                ? MerlotPalette.action
                : MerlotPalette.lineSubtle;
          }
          return Colors.transparent;
        }),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),

      // ── Divider ─────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: day
            ? (isMerlotLinen
                ? AppSurfaces.merlotLinen.dividerColor
                : isNordicSky
                    ? AppSurfaces.nordicSky.dividerColor
                    : AppSurfaces.day.dividerColor)
            : divider,
        thickness: 1,
        space: 1,
      ),

      // ── Snack bar ────────────────────────────────────────────────────────────
      snackBarTheme: SnackBarThemeData(
        backgroundColor: isDark
            ? (isMerlotLinen
                ? AscentColors.bgSurfaceElevatedDark
                : isNordicSky
                    ? FrozenPalette.darkInk
                    : const Color(0xFF2D251E))
            : (isMerlotLinen
                ? MerlotPalette.ink
                : isNordicSky
                    ? FrozenPalette.ink
                    : const Color(0xFF2B221B)),
        contentTextStyle: AscentTextStyles.bodyMedium.copyWith(
          color: const Color(0xFFF1F5F9),
          fontWeight: FontWeight.w500,
        ),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: Color(0x33FFFFFF), width: 0.9),
        ),
        behavior: SnackBarBehavior.floating,
        actionTextColor: isMerlotLinen
            ? MerlotPalette.antiqueGold
            : isNordicSky
                ? (isDark ? FrozenPalette.darkTint : FrozenPalette.tint)
                : accentPrimary,
        elevation: day ? 0 : 6,
      ),

      // ── Bottom sheet ─────────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isMerlotLinen
            ? (isDark
                  ? AscentColors.bgSurfaceElevatedDark
                  : MerlotPalette.elevated)
            : isNordicSky
                ? (isDark ? FrozenPalette.darkElevated : FrozenPalette.elevated)
                : bgSurface,
        modalBackgroundColor: isMerlotLinen
            ? (isDark
                  ? AscentColors.bgSurfaceElevatedDark
                  : MerlotPalette.elevated)
            : isNordicSky
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
        dragHandleColor: isMerlotLinen
            ? (isDark ? AscentColors.dividerDark : MerlotPalette.lineSubtle)
            : isNordicSky
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
        backgroundColor: isMerlotLinen
            ? (isDark
                  ? AscentColors.bgSurfaceElevatedDark
                  : MerlotPalette.pillSoft)
            : isNordicSky
                ? (isDark ? FrozenPalette.darkTint : FrozenPalette.tint)
                : (day ? AppSurfaces.day.cardFill : bgSurfaceElevated),
        selectedColor: isMerlotLinen
            ? accentPrimary
            : isNordicSky
                ? accentPrimary
                : (day ? AppSurfaces.day.accent : null),
        labelStyle: AscentTextStyles.labelSmall.copyWith(
          color: (isMerlotLinen || isNordicSky) ? accentPrimary : textPrimary,
        ),
        secondaryLabelStyle: AscentTextStyles.labelSmall.copyWith(
          color: (isMerlotLinen || isNordicSky)
              ? (isDark
                    ? (isMerlotLinen
                          ? AscentColors.bgBaseDark
                          : FrozenPalette.darkCanvas)
                    : Colors.white)
              : textOnPrimary,
          fontWeight: FontWeight.w600,
        ),
        checkmarkColor: (isMerlotLinen || isNordicSky)
            ? (isDark
                  ? (isMerlotLinen
                        ? AscentColors.bgBaseDark
                        : FrozenPalette.darkCanvas)
                  : Colors.white)
            : textOnPrimary,
        side: isMerlotLinen
            ? BorderSide(
                color: isDark
                    ? AscentColors.dividerDark
                    : MerlotPalette.lineSubtle,
                width: 0.75,
              )
            : isNordicSky
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
        backgroundColor: isMerlotLinen
            ? (isDark
                  ? AscentColors.bgSurfaceElevatedDark
                  : MerlotPalette.elevated)
            : isNordicSky
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

      // ── Popup Menu ────────────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: day
            ? (isMerlotLinen
                ? AppSurfaces.merlotLinen.cardFill
                : isNordicSky
                    ? AppSurfaces.nordicSky.cardFill
                    : AppSurfaces.day.cardFill)
            : (isMerlotLinen
                  ? (isDark
                        ? AscentColors.bgSurfaceElevatedDark
                        : MerlotPalette.surface)
                  : isNordicSky
                      ? (isDark
                            ? FrozenPalette.darkElevated
                            : FrozenPalette.elevated)
                      : bgSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: day
                ? (isMerlotLinen
                    ? AppSurfaces.merlotLinen.cardBorderColor
                    : isNordicSky
                        ? AppSurfaces.nordicSky.cardBorderColor
                        : AppSurfaces.day.cardBorderColor)
                : (isMerlotLinen
                      ? (isDark ? AscentColors.dividerDark : MerlotPalette.line)
                      : isNordicSky
                          ? (isDark
                                ? FrozenPalette.darkLine
                                : FrozenPalette.line)
                          : divider),
            width: isMerlotLinen ? 0.75 : 1.0,
          ),
        ),
        elevation: 8,
        shadowColor: (isDark ? Colors.black : Colors.black54).withValues(
          alpha: 0.18,
        ),
        surfaceTintColor: Colors.transparent,
        menuPadding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
        textStyle: AscentTextStyles.bodyMedium.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w500,
        ),
        labelTextStyle: WidgetStateProperty.all(
          AscentTextStyles.bodyMedium.copyWith(
            color: textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      extensions: [
        isDark
            ? (isMerlotLinen
                ? AscentGlass.merlotLinenDark
                : isNordicSky
                ? AscentGlass.nordicSkyDark
                : AscentGlass.dark)
            : isMerlotLinen
                ? (!day
                    ? AscentGlass.merlotLinenLight
                    : AscentGlass.merlotLinenLight.copyWith(
                        fill: AppSurfaces.merlotLinen.cardFill,
                        line: AppSurfaces.merlotLinen.dividerColor,
                        clay: AppSurfaces.merlotLinen.accent,
                        claySoft: AppSurfaces.merlotLinen.tintFill,
                        ink: AppSurfaces.merlotLinen.ink,
                        inkMuted: AppSurfaces.merlotLinen.mutedText,
                        glow1: const Color(0x29C28834),
                        glow2: const Color(0x1F581825),
                        shadow: MerlotPalette.shadowAmbient,
                      ))
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
            ? (isMerlotLinen
                ? AppSurfaces.legacyMerlotLinenDark
                : AppSurfaces.night)
            : isMerlotLinen
                ? (day ? AppSurfaces.merlotLinen : AppSurfaces.legacyMerlotLinen)
                : isNordicSky
                    ? (day
                          ? AppSurfaces.nordicSky
                          : AppSurfaces.legacyNordicSky)
                    : (day ? AppSurfaces.day : AppSurfaces.legacyLight),
      ],
    );
  }
}
