import 'package:flutter/material.dart';

/// "Royal Aurora": A signature calm, cool, and royal design system for Ascent.
/// - Cool-toned matte surfaces: velvet twilight slate, misty porcelain, satin glass.
/// - Dual royal accents: Royal Indigo (#4F46E5 / #818CF8) and Aurora Cyan (#06B6D4 / #38BDF8).
/// - 1px illuminated outlines with subtle dual-depth ambient glow.
/// - Designed to give the app a cohesive, deeply focused, and captivating aesthetic.
class AuroraPalette {
  AuroraPalette._();

  // ── Light Mode ("Royal Aurora Mist") ──────────────────────────────────────
  /// Canvas: Scaffold background — cool misty slate with subtle luminous air
  static const canvas = Color(0xFFF1F5F9);

  /// Surface: Cards, bottom nav, containers — crisp matte porcelain
  static const surface = Color(0xFFFCFDFF);

  /// Elevated: Sheets, dialogs, modals — soft elevated mist
  static const elevated = Color(0xFFE8EEF5);

  /// Line: 1px border on surfaces and containers
  static const line = Color(0xFFCBD5E1);

  /// Action: Buttons, active nav, FAB, selected tab — Royal Indigo
  static const action = Color(0xFF4F46E5);

  /// Royal Indigo alias
  static const royalIndigo = action;

  /// Action Cyan: Complementary aurora cyan for secondary actions and highlights
  static const actionCyan = Color(0xFF06B6D4);

  /// Aurora Cyan alias
  static const auroraCyan = actionCyan;

  /// Secondary accent
  static const secondary = Color(0xFF334155);

  /// Shadow color
  static const shadowColor = Color(0xFF0F172A);

  /// Action Bright: Top of gradient, hover/press highlight
  static const actionBright = Color(0xFF6366F1);

  /// Action Pressed: Pressed state
  static const actionPressed = Color(0xFF4338CA);

  /// Tint: Active nav pill, chips, tonal button background
  static const tint = Color(0xFFEEF2FF);

  /// Cyan Tint: Tonal background for secondary badges
  static const cyanTint = Color(0xFFECFEFF);

  /// Ink: Primary text (13:1 contrast on canvas)
  static const ink = Color(0xFF0F172A);

  /// Secondary Ink: Secondary text, subtitles (7:1 contrast on canvas)
  static const secondaryInk = Color(0xFF334155);

  /// Muted Ink: Captions, helper text, inactive icons
  static const mutedInk = Color(0xFF64748B);

  /// Spark: Warm amber strictly for streak flame, achievements, win celebration
  static const spark = Color(0xFFF59E0B);

  /// Spark Tint: Streak container highlight
  static const sparkTint = Color(0xFFFEF3C7);

  /// Success: Status only
  static const success = Color(0xFF10B981);

  /// Warning: Status only
  static const warning = Color(0xFFF59E0B);

  /// Danger: Status only
  static const danger = Color(0xFFEF4444);

  // ── Dark Mode ("Royal Aurora Twilight") ───────────────────────────────────
  /// Dark Canvas: Deep velvet twilight slate — comfortable, calm, not harsh pitch black
  static const darkCanvas = Color(0xFF0B0F19);

  /// Dark Surface: Matte royal slate for cards and containers
  static const darkSurface = Color(0xFF131B2E);

  /// Dark Elevated: Elevated matte slate for modals and sheets
  static const darkElevated = Color(0xFF1E293B);

  /// Dark Line: 1px subtle indigo-slate border
  static const darkLine = Color(0xFF27354E);

  /// Dark Action: Luminous Royal Periwinkle
  static const darkAction = Color(0xFF818CF8);

  /// Dark Action Cyan: Electric Aurora Cyan
  static const darkActionCyan = Color(0xFF38BDF8);

  /// Dark Action Bright: Top of gradient
  static const darkActionBright = Color(0xFFA5B4FC);

  /// Dark Action Pressed: Pressed state
  static const darkActionPressed = Color(0xFF6366F1);

  /// Dark Tint: Deep royal satin tint
  static const darkTint = Color(0xFF1E1B4B);

  /// Dark Cyan Tint: Deep cyan tint
  static const darkCyanTint = Color(0xFF083344);

  /// Dark Ink: Crisp diamond slate text
  static const darkInk = Color(0xFFF1F5F9);

  /// Dark Secondary Ink: Soft silver slate text
  static const darkSecondaryInk = Color(0xFFCBD5E1);

  /// Dark Muted Ink: Cool mist muted text
  static const darkMutedInk = Color(0xFF94A3B8);

  /// Dark Spark: Warm amber sun
  static const darkSpark = Color(0xFFFBBF24);

  /// Dark Spark Tint: Amber ember glow
  static const darkSparkTint = Color(0xFF2E2208);

  /// Dark Success: Vibrant mint
  static const darkSuccess = Color(0xFF34D399);

  /// Dark Warning: Warm gold
  static const darkWarning = Color(0xFFFBBF24);

  /// Dark Danger: Soft coral red
  static const darkDanger = Color(0xFFF87171);
}
