import 'package:flutter/cupertino.dart' show CupertinoThemeData;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'color_tokens.dart';
import 'dimension_tokens.dart';
import 'frozen_palette.dart';
import 'merlot_palette.dart';
import 'glass_theme.dart';
import 'day_glass_material.dart';
import 'text_styles.dart';
import 'surface_tokens.dart';
import 'shared_control_tokens.dart';
import '../../core/providers/settings_provider.dart';
import '../../core/theme/app_colors.dart';

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
    GlassTranslucencyPreset translucency =
        GlassTranslucencyPreset.balancedLiquid,
  }) {
    final base = _build(brightness: Brightness.light, preset: preset);
    final glass = base.extension<AscentGlass>()!;
    final material = DayGlassMaterial.from(glass, translucency);
    final muted = glass.frozen
        ? glass.inkMuted
        : Color.lerp(glass.inkMuted, glass.ink, .16)!;
    final surface = base.extension<AppSurfaces>()!.copyWith(
      mutedText: muted,
      cardFill: glass.fill.withValues(alpha: material.topOpacity),
      cardBorderColor: material.rim.top.color,
      blur: material.blur,
      shadow: material.shadow,
    );
    return base.copyWith(
      scaffoldBackgroundColor: material.canvas,
      appBarTheme: base.appBarTheme.copyWith(backgroundColor: material.canvas),
      colorScheme: base.colorScheme.copyWith(
        surfaceContainer: surface.cardFill,
        onSurfaceVariant: muted,
      ),
      textTheme: base.textTheme.copyWith(
        bodySmall: base.textTheme.bodySmall?.copyWith(color: muted),
        labelMedium: base.textTheme.labelMedium?.copyWith(color: muted),
        labelSmall: base.textTheme.labelSmall?.copyWith(color: muted),
      ),
      cardTheme: base.cardTheme.copyWith(
        color: surface.cardFill,
        shadowColor: material.shadow,
      ),
      extensions: [
        material,
        surface,
        glass.copyWith(
          bg: material.canvas,
          inkMuted: muted,
          fill: surface.cardFill,
          nav: surface.cardFill,
          edge: surface.cardBorderColor,
          highlight: Colors.white.withValues(alpha: .90),
          shadow: material.shadow,
        ),
        AppColors.light,
      ],
    );
  }

  // ── Dark ───────────────────────────────────────────────────────────────────

  static ThemeData dark({DayThemePreset preset = DayThemePreset.classicClay}) =>
      _build(brightness: Brightness.dark, preset: preset);

  // Assistant routes share the current palette and translucency preference.
  static ThemeData assistant(ThemeData parent) => parent;

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
    final accentPrimary = isDark
        ? SharedControlColors.actionBlueDark
        : SharedControlColors.actionBlue;
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
        ? (isMerlotLinen
              ? MerlotPalette.darkCanvas
              : AscentColors.textOnPrimaryDark)
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
      primary: isDark ? const Color(0xFFF08A5D) : const Color(0xFFD2643A),
      onPrimary: isDark ? const Color(0xFF2B1408) : const Color(0xFFFFFFFF),
      primaryContainer:
          isDark ? const Color(0xFF4A2A1B) : const Color(0xFFFCE5D8),
      onPrimaryContainer:
          isDark ? const Color(0xFFFFD9C6) : const Color(0xFF6E2E15),
      secondary: isDark ? const Color(0xFFE27A93) : const Color(0xFFC4506A),
      onSecondary: isDark ? const Color(0xFF2B1408) : const Color(0xFFFFFFFF),
      secondaryContainer:
          isDark ? const Color(0xFF4A222E) : const Color(0xFFF8E1E6),
      onSecondaryContainer:
          isDark ? const Color(0xFFF8E1E6) : const Color(0xFF5A1C29),
      tertiary: isDark ? const Color(0xFFE8B65A) : const Color(0xFFD6A23E),
      onTertiary: isDark ? const Color(0xFF2B1408) : const Color(0xFFFFFFFF),
      tertiaryContainer:
          isDark ? const Color(0xFF45351C) : const Color(0xFFF8EDD0),
      onTertiaryContainer:
          isDark ? const Color(0xFFF8EDD0) : const Color(0xFF5A4108),
      error: isDark ? const Color(0xFFE06D65) : const Color(0xFFB8433B),
      onError: isDark ? const Color(0xFF2B1408) : const Color(0xFFFFFFFF),
      errorContainer:
          isDark ? const Color(0xFF4A1E1C) : const Color(0xFFFBEBEA),
      onErrorContainer:
          isDark ? const Color(0xFFE06D65) : const Color(0xFFB8433B),
      surface: isDark ? const Color(0xFF2A2420) : const Color(0xFFFFFDF9),
      onSurface: isDark ? const Color(0xFFF3EBE2) : const Color(0xFF2B2622),
      surfaceContainerHighest:
          isDark ? const Color(0xFF332C27) : const Color(0xFFF1E9DD),
      onSurfaceVariant:
          isDark ? const Color(0xFFB9AC9F) : const Color(0xFF6F665C),
      outline: isDark ? const Color(0xFF3D342E) : const Color(0xFFE6DCCD),
      outlineVariant:
          isDark ? const Color(0xFF3D342E) : const Color(0xFFE6DCCD),
      shadow: isDark ? const Color(0x331B1714) : const Color(0x0A5C4A3E),
      scrim: const Color(0x73000000), // black@45% for overlays
      inverseSurface:
          isDark ? const Color(0xFFFAF6F0) : const Color(0xFF2A2420),
      onInverseSurface:
          isDark ? const Color(0xFF2B2622) : const Color(0xFFF3EBE2),
      inversePrimary:
          isDark ? const Color(0xFFD2643A) : const Color(0xFFF08A5D),
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

    final cardRadius = const Radius.circular(16);
    final inputRadius = const Radius.circular(12);
    final buttonRadius = const Radius.circular(12);
    final dialogRadius = const Radius.circular(20);
    final sheetRadius = const Radius.circular(28);

    return ThemeData(
      useMaterial3: true,
      cupertinoOverrideTheme: CupertinoThemeData(
        primaryColor: accentPrimary,
        brightness: brightness,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: isDark ? const Color(0xFFF08A5D) : const Color(0xFFD2643A),
        selectionColor: (isDark ? const Color(0xFFF08A5D) : const Color(0xFFD2643A))
            .withValues(alpha: 0.30),
        selectionHandleColor:
            isDark ? const Color(0xFFF08A5D) : const Color(0xFFD2643A),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: SharedControlColors.actionBlue,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 36),
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
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
      brightness: brightness,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: bgBase,
      fontFamily: GoogleFonts.dmSans().fontFamily,
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
                        ? MerlotPalette.darkSurface
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
                      ? (isDark ? MerlotPalette.darkLine : MerlotPalette.line)
                      : isNordicSky
                      ? (isDark ? FrozenPalette.darkLine : FrozenPalette.line)
                      : divider,
                  width: (isNordicSky || isMerlotLinen) ? 0.75 : 0.8,
                ),
        ),
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
      ),

      // ── Bottom navigation bar ───────────────────────────────────────────────
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: isMerlotLinen
            ? (isDark
                  ? MerlotPalette.darkElevated
                  : MerlotPalette.elevated.withValues(alpha: 0.96))
            : isNordicSky
            ? (isDark
                  ? FrozenPalette.darkSurface.withValues(alpha: 0.96)
                  : FrozenPalette.surface.withValues(alpha: 0.96))
            : bgBase,
        selectedItemColor: isMerlotLinen && isDark
            ? MerlotPalette.darkInk
            : accentPrimary,
        unselectedItemColor: isMerlotLinen
            ? (isDark ? MerlotPalette.darkMutedInk : MerlotPalette.mutedInk)
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
        fillColor: isNordicSky
            ? (isDark ? FrozenPalette.darkRecessed : FrozenPalette.recessed)
            : (isMerlotLinen
                  ? (isDark
                        ? MerlotPalette.darkCanvas
                        : MerlotPalette.recessedWell)
                  : (isDark ? AscentColors.bgBaseDark : AscentColors.bgBase)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.all(inputRadius),
          borderSide: BorderSide(
            color: isNordicSky
                ? (isDark
                      ? FrozenPalette.darkControlOutline
                      : FrozenPalette.controlOutline)
                : (isMerlotLinen
                      ? (isDark ? MerlotPalette.darkLine : MerlotPalette.line)
                      : (isDark
                            ? AscentColors.dividerDark
                            : AscentColors.outlineDay)),
            width: 1.0,
          ),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(inputRadius),
          borderSide: BorderSide(
            color: isNordicSky
                ? (isDark
                      ? FrozenPalette.darkControlOutline
                      : FrozenPalette.controlOutline)
                : (isMerlotLinen
                      ? (isDark ? MerlotPalette.darkLine : MerlotPalette.line)
                      : (isDark
                            ? AscentColors.dividerDark
                            : AscentColors.outlineDay)),
            width: 1.0,
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(inputRadius),
          borderSide: BorderSide(color: accentPrimary, width: 2.0),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(inputRadius),
          borderSide: BorderSide(color: stateDanger, width: 1.0),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.all(inputRadius),
          borderSide: BorderSide(color: stateDanger, width: 2.0),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 14,
        ),
        hintStyle: AscentTextStyles.body.copyWith(color: textMuted),
        labelStyle: AscentTextStyles.body.copyWith(color: textMuted),
        floatingLabelStyle: AscentTextStyles.caption.copyWith(
          color: isMerlotLinen && isDark
              ? MerlotPalette.darkSecondaryInk
              : accentPrimary,
        ),
      ),

      // ── Elevated button ─────────────────────────────────────────────────────
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              if (isMerlotLinen) {
                return isDark ? MerlotPalette.darkElevated : MerlotPalette.tint;
              }
              return isNordicSky
                  ? (isDark ? FrozenPalette.darkTint : FrozenPalette.tint)
                  : bgSurfaceElevated.withValues(alpha: 0.4);
            }
            if (isNordicSky) {
              return FrozenPalette.action.withValues(alpha: .94);
            }
            return accentPrimary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              if (isMerlotLinen) {
                return isDark
                    ? MerlotPalette.darkMutedInk
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
          minimumSize: const WidgetStatePropertyAll(Size(64, 36)),
          textStyle: WidgetStatePropertyAll(AscentTextStyles.labelMedium),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          ),
        ),
      ),

      // ── Text button ─────────────────────────────────────────────────────────
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStatePropertyAll(
            isMerlotLinen && isDark
                ? MerlotPalette.darkSecondaryInk
                : accentPrimary,
          ),
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
          foregroundColor: WidgetStatePropertyAll(
            isMerlotLinen && isDark
                ? MerlotPalette.darkSecondaryInk
                : accentPrimary,
          ),
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
                        ? (isDark ? MerlotPalette.darkLine : MerlotPalette.line)
                        : isNordicSky
                        ? (isDark ? FrozenPalette.darkLine : FrozenPalette.line)
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
          minimumSize: WidgetStatePropertyAll(Size(64, 36)),
          textStyle: WidgetStatePropertyAll(AscentTextStyles.labelMedium),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(horizontal: 14, vertical: 7),
          ),
        ),
      ),

      // ── Switch ──────────────────────────────────────────────────────────────
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return isDark
                ? SharedControlColors.disabledFgDark
                : SharedControlColors.disabledFgLight;
          }
          return SharedControlColors.switchThumb;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) {
            return isDark
                ? SharedControlColors.disabledBgDark
                : SharedControlColors.disabledBgLight;
          }
          if (states.contains(WidgetState.selected)) {
            return SharedControlColors.switchTrackOn;
          }
          return isDark
              ? SharedControlColors.switchTrackOffDark
              : SharedControlColors.switchTrackOffLight;
        }),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
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
                  ? MerlotPalette.darkElevated
                  : isNordicSky
                  ? FrozenPalette.darkElevated
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
        actionTextColor: const Color(0xFFF0D5A8),
        elevation: day ? 0 : 6,
      ),

      // ── Bottom sheet ─────────────────────────────────────────────────────────
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: isMerlotLinen
            ? (isDark ? MerlotPalette.darkElevated : MerlotPalette.elevated)
            : isNordicSky
            ? (isDark ? FrozenPalette.darkElevated : FrozenPalette.elevated)
            : bgSurface,
        modalBackgroundColor: isMerlotLinen
            ? (isDark ? MerlotPalette.darkElevated : MerlotPalette.elevated)
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
            ? (isDark ? MerlotPalette.darkLine : MerlotPalette.lineSubtle)
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
      primaryIconTheme: IconThemeData(
        color: isMerlotLinen && isDark
            ? MerlotPalette.darkSecondaryInk
            : accentPrimary,
        size: 24,
      ),

      // ── Chip ─────────────────────────────────────────────────────────────────
      chipTheme: ChipThemeData(
        backgroundColor: isMerlotLinen
            ? (isDark ? MerlotPalette.darkElevated : MerlotPalette.pillSoft)
            : isNordicSky
            ? (isDark ? FrozenPalette.darkTint : FrozenPalette.tint)
            : (day ? AppSurfaces.day.cardFill : bgSurfaceElevated),
        selectedColor: isMerlotLinen
            ? accentPrimary
            : isNordicSky
            ? accentPrimary
            : (day ? AppSurfaces.day.accent : null),
        labelStyle: AscentTextStyles.labelSmall.copyWith(
          color: isMerlotLinen && isDark
              ? MerlotPalette.darkSecondaryInk
              : (isMerlotLinen || isNordicSky)
              ? accentPrimary
              : textPrimary,
        ),
        secondaryLabelStyle: AscentTextStyles.labelSmall.copyWith(
          color: textOnPrimary,
          fontWeight: FontWeight.w600,
        ),
        checkmarkColor: textOnPrimary,
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
        backgroundColor: bgSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(dialogRadius),
        ),
        titleTextStyle: AscentTextStyles.cardTitle.copyWith(color: textPrimary),
        contentTextStyle: AscentTextStyles.supportingText.copyWith(
          color: textMuted,
        ),
        elevation: 0,
      ),

      // ── Popup Menu ────────────────────────────────────────────────────────────
      popupMenuTheme: PopupMenuThemeData(
        color: bgSurfaceElevated,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: divider, width: 1.0),
        ),
        elevation: 4,
        shadowColor: Color.fromRGBO(0, 0, 0, isDark ? 0.20 : 0.10),
        surfaceTintColor: Colors.transparent,
        menuPadding: const EdgeInsets.symmetric(vertical: 4),
        textStyle: AscentTextStyles.body.copyWith(
          color: textPrimary,
          fontWeight: FontWeight.w500,
        ),
        labelTextStyle: WidgetStatePropertyAll(
          AscentTextStyles.body.copyWith(
            color: textPrimary,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),

      // ── Slider ───────────────────────────────────────────────────────────────
      sliderTheme: SliderThemeData(
        activeTrackColor: accentPrimary,
        inactiveTrackColor: isNordicSky
            ? (isDark
                  ? FrozenPalette.darkControlOutline
                  : FrozenPalette.controlOutline)
            : (isMerlotLinen
                  ? (isDark ? MerlotPalette.darkLine : MerlotPalette.line)
                  : (isDark
                        ? AscentColors.dividerDark
                        : AscentColors.outlineDay)),
        trackHeight: 4.0,
        thumbColor: accentPrimary,
        thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10.0),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 24.0),
      ),

      // ── Progress indicator ───────────────────────────────────────────────────
      progressIndicatorTheme: ProgressIndicatorThemeData(
        color: isMerlotLinen
            ? (isDark ? MerlotPalette.darkAction : MerlotPalette.action)
            : (isNordicSky
                  ? (isDark ? FrozenPalette.darkAction : FrozenPalette.action)
                  : accentPrimary),
        linearTrackColor: isMerlotLinen
            ? (isDark
                  ? const Color(0x1FFFFFFF)
                  : const Color.fromRGBO(88, 24, 37, 0.12))
            : (isNordicSky
                  ? (isDark
                        ? const Color(0x1FFFFFFF)
                        : const Color.fromRGBO(29, 100, 180, 0.12))
                  : (isDark
                        ? const Color(0x1FFFFFFF)
                        : const Color.fromRGBO(15, 23, 42, 0.12))),
        linearMinHeight: 4,
        borderRadius: BorderRadius.circular(4),
      ),

      // ── Scrollbar ────────────────────────────────────────────────────────────
      scrollbarTheme: ScrollbarThemeData(
        thumbColor: WidgetStatePropertyAll(
          isDark
              ? Colors.white.withValues(alpha: 0.28)
              : Colors.black.withValues(alpha: 0.22),
        ),
        trackColor: WidgetStatePropertyAll(
          isDark
              ? Colors.white.withValues(alpha: 0.05)
              : Colors.black.withValues(alpha: 0.04),
        ),
        radius: const Radius.circular(4),
        thickness: const WidgetStatePropertyAll(4.0),
        thumbVisibility: const WidgetStatePropertyAll(true),
        interactive: true,
      ),
      extensions: [
        isDark ? AppColors.dark : AppColors.light,
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
                  : (isNordicSky
                        ? AppSurfaces.legacyNordicSkyDark
                        : AppSurfaces.night))
            : isMerlotLinen
            ? (day ? AppSurfaces.merlotLinen : AppSurfaces.legacyMerlotLinen)
            : isNordicSky
            ? (day ? AppSurfaces.nordicSky : AppSurfaces.legacyNordicSky)
            : (day ? AppSurfaces.day : AppSurfaces.legacyLight),
      ],
    );
  }
}
