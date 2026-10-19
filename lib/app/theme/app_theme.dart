import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'color_tokens.dart';
import 'frozen_palette.dart';
import 'aurora_palette.dart';
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
    DayThemePreset preset = DayThemePreset.auroraCalm,
  }) => _build(brightness: Brightness.light, preset: preset);

  // ── Dark ───────────────────────────────────────────────────────────────────

  static ThemeData dark({DayThemePreset preset = DayThemePreset.auroraCalm}) =>
      _build(brightness: Brightness.dark, preset: preset);

  static ThemeData assistant(ThemeData parent) {
    if (parent.brightness == Brightness.dark) return parent;
    final parentGlass = parent.extension<AscentGlass>() ?? AscentGlass.auroraCalmLight;
    final isNordic = parentGlass.frozen;
    final isClay = parentGlass.clay == AscentColors.accentPrimary;
    final preset = isNordic
        ? DayThemePreset.nordicSky
        : (isClay ? DayThemePreset.classicClay : DayThemePreset.auroraCalm);
    final original = _build(
      brightness: Brightness.light,
      preset: preset,
      outlinedDay: false,
    );
    final glass = isNordic
        ? AscentGlass.nordicSky
        : (isClay ? AscentGlass.light : AscentGlass.auroraCalmLight);
    final surfaces = isNordic
        ? AppSurfaces.legacyNordicSky
        : (isClay ? AppSurfaces.legacyLight : AppSurfaces.legacyAuroraCalm);
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
    DayThemePreset preset = DayThemePreset.auroraCalm,
    bool outlinedDay = false,
  }) {
    final isDark = brightness == Brightness.dark;
    final isNordicSky = preset == DayThemePreset.nordicSky;
    final isAuroraCalm = preset == DayThemePreset.auroraCalm;
    final day = !isDark && outlinedDay;

    // Resolve semantic tokens for this brightness.
    final bgBase = isAuroraCalm
        ? (isDark ? AuroraPalette.darkCanvas : AuroraPalette.canvas)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkCanvas : FrozenPalette.canvas)
        : (isDark ? AscentColors.bgBaseDark : AscentColors.bgBase);
    final bgSurface = isAuroraCalm
        ? (isDark ? AuroraPalette.darkSurface : AuroraPalette.surface)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkSurface : FrozenPalette.surface)
        : (isDark ? AscentColors.bgSurfaceDark : AscentColors.bgSurface);
    final bgSurfaceElevated = isAuroraCalm
        ? (isDark ? AuroraPalette.darkElevated : AuroraPalette.elevated)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkElevated : FrozenPalette.elevated)
        : (isDark
              ? AscentColors.bgSurfaceElevatedDark
              : AscentColors.bgSurfaceElevated);
    final accentPrimary = isAuroraCalm
        ? (isDark ? AuroraPalette.darkAction : AuroraPalette.action)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkAction : FrozenPalette.action)
        : (isDark
              ? AscentColors.accentPrimaryDark
              : AscentColors.accentPrimary);
    final accentSecondary = isAuroraCalm
        ? (isDark ? AuroraPalette.darkActionCyan : AuroraPalette.actionCyan)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkAction : FrozenPalette.action)
        : (isDark
              ? AscentColors.accentSecondaryDark
              : AscentColors.accentSecondary);
    final accentInfo = isAuroraCalm
        ? (isDark ? AuroraPalette.darkWarning : AuroraPalette.warning)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkWarning : FrozenPalette.warning)
        : (isDark ? AscentColors.accentInfoDark : AscentColors.accentInfo);
    final stateDanger = isAuroraCalm
        ? (isDark ? AuroraPalette.darkDanger : AuroraPalette.danger)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkDanger : FrozenPalette.danger)
        : (isDark ? AscentColors.stateDangerDark : AscentColors.stateDanger);
    final textPrimary = day
        ? (isAuroraCalm
              ? AppSurfaces.auroraCalm.ink
              : isNordicSky
              ? AppSurfaces.nordicSky.ink
              : AppSurfaces.day.ink)
        : isAuroraCalm
        ? (isDark ? AuroraPalette.darkInk : AuroraPalette.ink)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkInk : FrozenPalette.ink)
        : (isDark ? AscentColors.textPrimaryDark : AscentColors.textPrimary);
    final textMuted = day
        ? (isAuroraCalm
              ? AppSurfaces.auroraCalm.mutedText
              : isNordicSky
              ? AppSurfaces.nordicSky.mutedText
              : AppSurfaces.day.mutedText)
        : isAuroraCalm
        ? (isDark ? AuroraPalette.darkMutedInk : AuroraPalette.mutedInk)
        : isNordicSky
        ? (isDark ? FrozenPalette.darkMutedInk : FrozenPalette.mutedInk)
        : (isDark ? AscentColors.textMutedDark : AscentColors.textMuted);
    final textOnPrimary = isDark
        ? AscentColors.textOnPrimaryDark
        : AscentColors.textOnPrimary;
    final divider = day
        ? (isAuroraCalm
              ? AppSurfaces.auroraCalm.dividerColor
              : isNordicSky
              ? AppSurfaces.nordicSky.dividerColor
              : AppSurfaces.day.dividerColor)
        : isAuroraCalm
        ? (isDark ? AuroraPalette.darkLine : AuroraPalette.line)
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
      isAuroraCalm ? 18 : (isNordicSky ? 16 : 14),
    );
    final inputRadius = Radius.circular(
      isAuroraCalm ? 14 : (isNordicSky ? 12 : 10),
    );
    final buttonRadius = Radius.circular(
      isAuroraCalm ? 20 : (isNordicSky ? 24 : 10),
    );
    final sheetRadius = Radius.circular(
      isAuroraCalm ? 24 : (isNordicSky ? 24 : 20),
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
            ? (isAuroraCalm
                ? AppSurfaces.auroraCalm.cardFill
                : isNordicSky
                    ? AppSurfaces.nordicSky.cardFill
                    : AppSurfaces.day.cardFill)
            : (isAuroraCalm
                  ? (isDark
                        ? AuroraPalette.darkSurface.withValues(alpha: 0.95)
                        : AuroraPalette.surface.withValues(alpha: 0.95))
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
                  color: isAuroraCalm
                      ? AppSurfaces.auroraCalm.cardBorderColor
                      : isNordicSky
                          ? AppSurfaces.nordicSky.cardBorderColor
                          : AppSurfaces.day.cardBorderColor,
                  width: isAuroraCalm
                      ? AppSurfaces.auroraCalm.cardBorderWidth
                      : AppSurfaces.day.cardBorderWidth,
                )
              : BorderSide(
                  color: isAuroraCalm
                      ? (isDark ? AuroraPalette.darkLine : AuroraPalette.line)
                      : divider,
                  width: (isNordicSky || isAuroraCalm) ? 1.0 : 0.8,
                ),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      // ── Bottom navigation bar ───────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isAuroraCalm
            ? (isDark
                  ? AuroraPalette.darkElevated.withValues(alpha: 0.96)
                  : AuroraPalette.elevated.withValues(alpha: 0.96))
            : isNordicSky
                ? (isDark
                      ? FrozenPalette.darkSurface.withValues(alpha: 0.96)
                      : FrozenPalette.surface.withValues(alpha: 0.96))
                : bgBase,
        selectedItemColor: accentPrimary,
        unselectedItemColor: isAuroraCalm
            ? (isDark ? AuroraPalette.darkMutedInk : AuroraPalette.mutedInk)
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
            ? (isAuroraCalm
                ? AppSurfaces.auroraCalm.cardFill
                : isNordicSky
                    ? AppSurfaces.nordicSky.cardFill
                    : AppSurfaces.day.cardFill)
            : (isAuroraCalm
                  ? (isDark ? AuroraPalette.darkSurface : AuroraPalette.surface)
                  : isNordicSky
                      ? (isDark
                            ? FrozenPalette.darkSurface
                            : FrozenPalette.surface)
                      : bgSurface),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(inputRadius),
          borderSide: BorderSide(
            color: day
                ? (isAuroraCalm
                    ? AppSurfaces.auroraCalm.cardBorderColor
                    : isNordicSky
                        ? AppSurfaces.nordicSky.cardBorderColor
                        : AppSurfaces.day.ink)
                : (isAuroraCalm
                      ? (isDark ? AuroraPalette.darkLine : AuroraPalette.line)
                      : isNordicSky
                          ? (isDark
                                ? FrozenPalette.darkLine
                                : FrozenPalette.line)
                          : divider),
            width: day
                ? (isAuroraCalm
                    ? AppSurfaces.auroraCalm.cardBorderWidth
                    : AppSurfaces.day.cardBorderWidth)
                : 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(inputRadius),
          borderSide: BorderSide(
            color: day
                ? (isAuroraCalm
                    ? AppSurfaces.auroraCalm.cardBorderColor
                    : isNordicSky
                        ? AppSurfaces.nordicSky.cardBorderColor
                        : AppSurfaces.day.ink)
                : (isAuroraCalm
                      ? (isDark ? AuroraPalette.darkLine : AuroraPalette.line)
                      : isNordicSky
                          ? (isDark
                                ? FrozenPalette.darkLine
                                : FrozenPalette.line)
                          : divider),
            width: day
                ? (isAuroraCalm
                    ? AppSurfaces.auroraCalm.cardBorderWidth
                    : AppSurfaces.day.cardBorderWidth)
                : 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(inputRadius),
          borderSide: BorderSide(
            color: accentPrimary,
            width: (isNordicSky || isAuroraCalm) ? 2.0 : 1.3,
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
              if (isAuroraCalm) {
                return isDark ? AuroraPalette.darkTint : AuroraPalette.tint;
              }
              return isNordicSky
                  ? (isDark ? FrozenPalette.darkTint : FrozenPalette.tint)
                  : bgSurfaceElevated.withValues(alpha: 0.4);
            }
            return accentPrimary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              if (isAuroraCalm) {
                return isDark
                    ? AuroraPalette.darkMutedInk
                    : AuroraPalette.mutedInk;
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
              (isNordicSky || isAuroraCalm)
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
                  ? (isAuroraCalm
                      ? AppSurfaces.auroraCalm.cardBorderColor
                      : isNordicSky
                          ? AppSurfaces.nordicSky.cardBorderColor
                          : AppSurfaces.day.ink)
                  : (isAuroraCalm
                        ? (isDark ? AuroraPalette.darkLine : AuroraPalette.line)
                        : isNordicSky
                            ? (isDark
                                  ? FrozenPalette.darkLine
                                  : FrozenPalette.line)
                            : divider),
              width: day
                  ? (isAuroraCalm
                      ? AppSurfaces.auroraCalm.cardBorderWidth
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
              (isNordicSky || isAuroraCalm)
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
            if (isAuroraCalm) {
              return isDark ? AuroraPalette.darkActionCyan : Colors.white;
            }
            if (isNordicSky) return const Color(0xFFFFFFFF);
            return isDark ? accentPrimary : const Color(0xFFC07360);
          }
          if (isAuroraCalm) {
            return isDark
                ? AuroraPalette.darkMutedInk
                : AuroraPalette.secondaryInk;
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
            if (isAuroraCalm) {
              return isDark ? AuroraPalette.darkAction : AuroraPalette.action;
            }
            if (isNordicSky) {
              return isDark ? FrozenPalette.darkAction : FrozenPalette.action;
            }
            return isDark
                ? accentPrimary.withValues(alpha: 0.38)
                : const Color(0xFFC07360).withValues(alpha: 0.28);
          }
          if (isAuroraCalm) {
            return isDark ? AuroraPalette.darkLine : AuroraPalette.line;
          }
          if (isNordicSky) {
            return isDark ? FrozenPalette.darkLine : FrozenPalette.line;
          }
          return isDark ? const Color(0xFF3B2C1E) : const Color(0xFFEFE8E2);
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (isAuroraCalm) {
            return states.contains(WidgetState.selected)
                ? (isDark ? AuroraPalette.darkAction : AuroraPalette.action)
                : (isDark ? AuroraPalette.darkLine : AuroraPalette.line);
          }
          return Colors.transparent;
        }),
        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),

      // ── Divider ─────────────────────────────────────────────────────────────
      dividerTheme: DividerThemeData(
        color: day
            ? (isAuroraCalm
                ? AppSurfaces.auroraCalm.dividerColor
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
            ? (isAuroraCalm
                ? AuroraPalette.darkElevated
                : isNordicSky
                    ? FrozenPalette.darkInk
                    : const Color(0xFF2D251E))
            : (isAuroraCalm
                ? AuroraPalette.ink
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
        actionTextColor: isAuroraCalm
            ? (isDark ? AuroraPalette.darkActionCyan : AuroraPalette.actionCyan)
            : isNordicSky
                ? (isDark ? FrozenPalette.darkTint : FrozenPalette.tint)
                : accentPrimary,
        elevation: day ? 0 : 6,
      ),

      // ── Bottom sheet ─────────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isAuroraCalm
            ? (isDark ? AuroraPalette.darkElevated : AuroraPalette.elevated)
            : isNordicSky
                ? (isDark ? FrozenPalette.darkElevated : FrozenPalette.elevated)
                : bgSurface,
        modalBackgroundColor: isAuroraCalm
            ? (isDark ? AuroraPalette.darkElevated : AuroraPalette.elevated)
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
        dragHandleColor: isAuroraCalm
            ? (isDark ? AuroraPalette.darkLine : AuroraPalette.line)
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
        backgroundColor: isAuroraCalm
            ? (isDark ? AuroraPalette.darkTint : AuroraPalette.tint)
            : isNordicSky
                ? (isDark ? FrozenPalette.darkTint : FrozenPalette.tint)
                : (day ? AppSurfaces.day.cardFill : bgSurfaceElevated),
        selectedColor: isAuroraCalm
            ? accentPrimary
            : isNordicSky
                ? accentPrimary
                : (day ? AppSurfaces.day.accent : null),
        labelStyle: AscentTextStyles.labelSmall.copyWith(
          color: (isAuroraCalm || isNordicSky) ? accentPrimary : textPrimary,
        ),
        secondaryLabelStyle: AscentTextStyles.labelSmall.copyWith(
          color: (isAuroraCalm || isNordicSky)
              ? (isDark
                    ? (isAuroraCalm
                          ? AuroraPalette.darkCanvas
                          : FrozenPalette.darkCanvas)
                    : Colors.white)
              : textOnPrimary,
          fontWeight: FontWeight.w600,
        ),
        checkmarkColor: (isAuroraCalm || isNordicSky)
            ? (isDark
                  ? (isAuroraCalm
                        ? AuroraPalette.darkCanvas
                        : FrozenPalette.darkCanvas)
                  : Colors.white)
            : textOnPrimary,
        side: isAuroraCalm
            ? BorderSide(
                color: isDark ? AuroraPalette.darkLine : AuroraPalette.line,
                width: 1.0,
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
        backgroundColor: isAuroraCalm
            ? (isDark ? AuroraPalette.darkElevated : AuroraPalette.elevated)
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
            ? (isAuroraCalm
                ? AppSurfaces.auroraCalm.cardFill
                : isNordicSky
                    ? AppSurfaces.nordicSky.cardFill
                    : AppSurfaces.day.cardFill)
            : (isAuroraCalm
                  ? (isDark
                        ? AuroraPalette.darkElevated
                        : AuroraPalette.elevated)
                  : isNordicSky
                      ? (isDark
                            ? FrozenPalette.darkElevated
                            : FrozenPalette.elevated)
                      : bgSurface),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: day
                ? (isAuroraCalm
                    ? AppSurfaces.auroraCalm.cardBorderColor
                    : isNordicSky
                        ? AppSurfaces.nordicSky.cardBorderColor
                        : AppSurfaces.day.cardBorderColor)
                : (isAuroraCalm
                      ? (isDark ? AuroraPalette.darkLine : AuroraPalette.line)
                      : isNordicSky
                          ? (isDark
                                ? FrozenPalette.darkLine
                                : FrozenPalette.line)
                          : divider),
            width: 1.0,
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
            ? (isAuroraCalm
                ? AscentGlass.auroraCalmDark
                : isNordicSky
                    ? AscentGlass.nordicSkyDark
                    : AscentGlass.dark)
            : isAuroraCalm
                ? (!day
                    ? AscentGlass.auroraCalmLight
                    : AscentGlass.auroraCalmLight.copyWith(
                        fill: AppSurfaces.auroraCalm.cardFill,
                        line: AppSurfaces.auroraCalm.dividerColor,
                        clay: AppSurfaces.auroraCalm.accent,
                        claySoft: AppSurfaces.auroraCalm.tintFill,
                        ink: AppSurfaces.auroraCalm.ink,
                        inkMuted: AppSurfaces.auroraCalm.mutedText,
                        glow1: AuroraPalette.royalIndigo.withValues(
                          alpha: 0.08,
                        ),
                        glow2: AuroraPalette.auroraCyan.withValues(alpha: 0.08),
                        shadow: AuroraPalette.shadowColor.withValues(
                          alpha: 0.05,
                        ),
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
            ? AppSurfaces.night
            : isAuroraCalm
                ? (day ? AppSurfaces.auroraCalm : AppSurfaces.legacyAuroraCalm)
                : isNordicSky
                    ? (day
                          ? AppSurfaces.nordicSky
                          : AppSurfaces.legacyNordicSky)
                    : (day ? AppSurfaces.day : AppSurfaces.legacyLight),
      ],
    );
  }
}
