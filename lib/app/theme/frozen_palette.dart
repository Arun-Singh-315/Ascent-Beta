import 'package:flutter/material.dart';

/// "Clear Sky": A blue-and-white design system for Ascent.
/// - White-forward surfaces: crisp, airy, translucent, with thin blue-tinted borders.
/// - One confident blue (action) for everything interactive.
/// - One warm spark (sunny amber) for streaks, wins, and celebration.
/// - Green only for "success", never as a brand color.
class FrozenPalette {
  FrozenPalette._();

  // ── Light Mode ("Clear Sky") ──────────────────────────────────────────────
  /// Canvas: Scaffold background
  static const canvas = Color(0xFFEEF4F9);

  /// Surface: Cards, bottom nav, containers
  static const surface = Color(0xFFF7FAFD);

  /// Elevated: Sheets, dialogs, modals
  static const elevated = Color(0xFFE1ECF5);

  /// Line: 1px border on surfaces and containers
  static const line = Color(0xFFBFD4E6);

  /// Action: Buttons, active nav, FAB, selected tab, interactive icons
  static const action = Color(0xFF1D64B4);

  /// Action Bright: Top of gradient, hover/press highlight
  static const actionBright = Color(0xFF2F7FD8);

  /// Action Pressed: Pressed state
  static const actionPressed = Color(0xFF174F8F);

  /// Tint: Active nav pill, chips, tonal button background
  static const tint = Color(0xFFD8E8F5);

  /// Ink: Primary text (12.8:1 contrast on canvas)
  static const ink = Color(0xFF1E293B);

  /// Secondary Ink: Secondary text, subtitles (6.8:1 contrast on canvas)
  static const secondaryInk = Color(0xFF475569);

  /// Muted Ink: Captions, helper text, inactive icons (WCAG AA 4.5+:1 on canvas & tint)
  static const mutedInk = Color(0xFF58687E);

  /// Muted Ink Raw token (#64748B) from spec
  static const mutedInkToken = Color(0xFF64748B);

  /// Spark: Warm sunny amber strictly for streak flame, achievements, win celebration
  static const spark = Color(0xFFF5A524);

  /// Spark Tint: Streak container highlight
  static const sparkTint = Color(0xFFFFF3D6);

  /// Success: Status only
  static const success = Color(0xFF2E7D5B);

  /// Warning: Status only
  static const warning = Color(0xFFB7791F);

  /// Danger: Status only
  static const danger = Color(0xFFC0392B);

  // ── Dark Mode ("Clear Sky Dark") ──────────────────────────────────────────
  static const darkCanvas = Color(0xFF0F1A2B);
  static const darkSurface = Color(0xFF162338);
  static const darkElevated = Color(0xFF1C2C45);
  static const darkLine = Color(0xFF2A3F5E);
  static const darkAction = Color(0xFF5EA0F0);
  static const darkActionBright = Color(0xFF7DB4F5);
  static const darkActionPressed = Color(0xFF4A8BDD);
  static const darkTint = Color(0xFF1F3555);
  static const darkInk = Color(0xFFE6EEF8);
  static const darkSecondaryInk = Color(0xFFA9BBD3);
  static const darkMutedInk = Color(0xFF8296B0);
  static const darkSpark = Color(0xFFFFB84D);
  static const darkSparkTint = Color(0xFF3A2F14);
  static const darkSuccess = Color(0xFF3EA378);
  static const darkWarning = Color(0xFFDCA045);
  static const darkDanger = Color(0xFFE56A5E);

  // ── Backward-compatible Aliases ───────────────────────────────────────────
  /// Replaces dark slate with action as the single interactive color everywhere
  static const accent = action;
  static const secondary = action;
  static const mint = tint;
  static const lavender = tint;
  static const aqua = tint;
  static const frost = actionBright;
  static const mist = tint;
}
