import 'package:flutter/material.dart';

/// Nordic Sky (Blue preset): Apple-inspired design system tokens for Ascent.
/// Specified in Section 3.1 of the Ascent visual upgrade handoff.
class FrozenPalette {
  FrozenPalette._();

  // ── Light Mode ("Nordic Sky / Clear Sky") ──────────────────────────────────
  /// Page canvas: #F5F5F7
  static const canvas = Color(0xFFF5F5F7);

  /// Content/card surface: #FFFFFF
  static const surface = Color(0xFFFFFFFF);

  /// Elevated surface (sheet/dialog/menu): #FFFFFF
  static const elevated = Color(0xFFFFFFFF);

  /// Recessed surface (inputs/segment track): #ECEEF2
  static const recessed = Color(0xFFECEEF2);
  static const pillSoft = Color(0xFFECEEF2);

  /// Primary text: #1D1D1F
  static const ink = Color(0xFF1D1D1F);

  /// Secondary text: #51545C
  static const secondaryInk = Color(0xFF51545C);

  /// Helper/placeholder text: #626670
  static const mutedInk = Color(0xFF626670);
  static const mutedInkToken = Color(0xFF626670);

  /// Decorative separator: #D8DBE2
  static const line = Color(0xFFD8DBE2);
  static const lineSubtle = Color(0xFFD8DBE2);

  /// Required control outline: #747985
  static const controlOutline = Color(0xFF747985);

  /// Action ink (links/active icons/focus): #1D64B4
  static const action = Color(0xFF1D64B4);
  static const actionBright = Color(0xFF1D64B4);
  static const actionPressed = Color(0xFF174F8F);

  /// Filled primary button background: #1D64B4
  static const primaryButtonBg = Color(0xFF1D64B4);
  /// Filled primary button foreground: #FFFFFF
  static const primaryButtonFg = Color(0xFFFFFFFF);
  /// Filled primary button pressed background: #174F8F
  static const primaryButtonPressed = Color(0xFF174F8F);

  /// Tonal/selection background: #DFEAF8
  static const tint = Color(0xFFDFEAF8);
  /// Tonal/selection foreground: #174F8F
  static const tintForeground = Color(0xFF174F8F);

  /// Focus ring: #1D64B4
  static const focusRing = Color(0xFF1D64B4);

  /// Atmospheric drop shadow
  static const shadowAmbient = Color.fromRGBO(0, 0, 0, 0.05);

  /// Domain accents (preserved)
  static const spark = Color(0xFFF5A524);
  static const sparkTint = Color(0xFFFFF3D6);
  static const success = Color(0xFF166534);
  static const warning = Color(0xFF854D0E);
  static const danger = Color(0xFFB42318);

  // ── Dark Mode ("Nordic Sky Dark") ──────────────────────────────────────────
  /// Page canvas: #171819
  static const darkCanvas = Color(0xFF171819);

  /// Content/card surface: #202224
  static const darkSurface = Color(0xFF202224);

  /// Elevated surface: #292B2D
  static const darkElevated = Color(0xFF292B2D);

  /// Recessed surface: #171819
  static const darkRecessed = Color(0xFF171819);

  /// Primary text: #F3F4F6
  static const darkInk = Color(0xFFF3F4F6);

  /// Secondary text: #C5C8CE
  static const darkSecondaryInk = Color(0xFFC5C8CE);

  /// Helper/placeholder text: #A7ABB3
  static const darkMutedInk = Color(0xFFA7ABB3);

  /// Decorative separator: #41454D
  static const darkLine = Color(0xFF41454D);
  static const darkLineSubtle = Color(0xFF41454D);

  /// Required control outline: #8D939F
  static const darkControlOutline = Color(0xFF8D939F);

  /// Action ink: #5EA0F0
  static const darkAction = Color(0xFF5EA0F0);
  static const darkActionBright = Color(0xFF5EA0F0);
  static const darkActionPressed = Color(0xFF174F8F);

  /// Filled primary background in dark: #1D64B4
  static const darkPrimaryButtonBg = Color(0xFF1D64B4);
  /// Filled primary foreground in dark: #FFFFFF
  static const darkPrimaryButtonFg = Color(0xFFFFFFFF);
  /// Filled primary pressed background in dark: #174F8F
  static const darkPrimaryButtonPressed = Color(0xFF174F8F);

  /// Tonal/selection background: #203853
  static const darkTint = Color(0xFF203853);
  /// Tonal/selection foreground: #A8D0FF
  static const darkTintForeground = Color(0xFFA8D0FF);

  /// Focus ring in dark: #5EA0F0
  static const darkFocusRing = Color(0xFF5EA0F0);

  /// Domain accents (preserved)
  static const darkSpark = Color(0xFFFFB84D);
  static const darkSparkTint = Color(0xFF3A2F14);
  static const darkSuccess = Color(0xFF86EFAC);
  static const darkWarning = Color(0xFFFDE68A);
  static const darkDanger = Color(0xFFFFB4AB);

  // ── Backward-compatible Aliases ───────────────────────────────────────────
  static const accent = action;
  static const secondary = action;
  static const mint = tint;
  static const lavender = tint;
  static const aqua = tint;
  static const frost = actionBright;
  static const mist = tint;
}
