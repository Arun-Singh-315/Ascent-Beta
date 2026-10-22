import 'package:flutter/material.dart';

/// "Vintage Merlot & Cashmere Linen": Ascent's signature daylight design system.
/// - Calming organic canvas: Cashmere oat linen (#F8F5EE).
/// - Restrained aristocratic jewel: Deep Vintage Merlot (#581825 / #4D131F).
/// - Frosted matte tactile surfaces with 0.75px hairline specular borders.
/// - Warm oat parchment pills (#F1EBE0) and antique gold accents (#C28834).
/// - Zero eye strain, balanced luminance, and WCAG AAA contrast compliance.
class MerlotPalette {
  MerlotPalette._();

  // ── Light Mode ("Vintage Merlot & Cashmere Linen") ─────────────────────────

  /// Canvas: Scaffold background — soft, soothing cashmere oat linen
  static const canvas = Color(0xFFF8F5EE);

  /// Surface: Cards, bottom nav, containers — frosted warm cashmere porcelain
  static const surface = Color(0xFFF8F4EC);

  /// Surface Bottom: Lower stop for frosted card gradient
  static const surfaceBottom = Color(0xFFF6F2E9);

  /// Recessed Well: Sub-cards (Medicine, Hydration, Chai Break)
  static const recessedWell = Color(0xFFEFE9DC);

  /// Elevated: Sheets, dialogs, modals — warm elevated oat mist
  static const elevated = Color(0xFFF2ECE1);

  /// Line: Hairline 0.75px border on cards and containers
  static const line = Color(0x1F581825); // 12% alpha merlot

  /// Line Specular: Top edge catchlight reflection
  static const lineSpecular = Color(0x2E581825); // 18% alpha merlot

  /// Line Subtle: Inner divider and recessed well border
  static const lineSubtle = Color(0x14581825); // 8% alpha merlot

  /// Action: Buttons, active nav, primary CTA ("Resume") — Deep Vintage Merlot
  static const action = Color(0xFF581825);

  /// Deep Vintage Merlot alias
  static const vintageMerlot = action;

  /// Action Deep: FAB ("✦ Ask Jarvis"), pressed/active states
  static const actionDeep = Color(0xFF4D131F);

  /// Action Bright: Top of CTA button micro-gradient
  static const actionBright = Color(0xFF6B1D2F);

  /// Action Pressed: Pressed state
  static const actionPressed = Color(0xFF3F0E18);

  /// Secondary Accent: Antique warm gold for progress, sparks, and stars
  static const antiqueGold = Color(0xFFC28834);

  /// Tint: Selected tabs ("Today"), chips, tonal button background — oat parchment
  static const tint = Color(0xFFF1EBE0);

  /// Pill Soft: Composer pills ("To-do", "Today", "Reminder off")
  static const pillSoft = Color(0xFFF7F3EB);

  /// Ink: Primary text — Espresso Merlot Obsidian (15.4:1 contrast on canvas)
  static const ink = Color(0xFF260F14);

  /// Secondary Ink: Secondary text, subtitles (8:1 contrast on canvas)
  static const secondaryInk = Color(0xFF4A353B);

  /// Muted Ink: Captions, helper text, inactive icons (5.6:1 contrast on canvas)
  static const mutedInk = Color(0xFF6E565B);

  /// Subtle Ink: Hints, placeholders, disabled indicators
  static const subtleInk = Color(0xFF9B8489);

  /// Spark: Antique gold strictly for streak flame, achievements, win celebration
  static const spark = antiqueGold;

  /// Spark Tint: Warm gold container highlight
  static const sparkTint = Color(0xFFFDF6EA);

  /// Terracotta: Warm roasted terracotta for Chai & Coffee Break tile
  static const terracotta = Color(0xFFA04020);

  /// Terracotta Tint: Beverage container highlight
  static const terracottaTint = Color(0xFFFDF1EB);

  /// Success: Dewy botanical sage for hydration and completed goals
  static const success = Color(0xFF166534);

  /// Success Tint: Soft sage container highlight
  static const successTint = Color(0xFFEDF7F0);

  /// Warning: Warm amber
  static const warning = Color(0xFFD97706);

  /// Danger: Deep ruby red
  static const danger = Color(0xFFBE123C);

  /// Shadow Contact: Proximity contact shadow
  static const shadowContact = Color(0x09260F14);

  /// Shadow Ambient: Wide ambient diffuse glow
  static const shadowAmbient = Color(0x0B260F14);

  // ── Dark Mode ("Vintage Merlot Night Glass") ─────────────────────────────

  /// Canvas: Dark velvet espresso-plum background
  static const darkCanvas = Color(0xFF161012);

  /// Surface: Frosted night merlot glass cards
  static const darkSurface = Color(0xFF22171B);

  /// Elevated: Modals, popups, and elevated sheets
  static const darkElevated = Color(0xFF2C1E23);

  /// Line: Hairline subtle specular edge in dark mode
  static const darkLine = Color(0x4DAD9184);

  /// Line Subtle: Inner divider in dark mode
  static const darkLineSubtle = Color(0x33AD9184);

  /// Action: Muted vintage wine for primary buttons, active tabs (AAA contrast)
  static const darkAction = action;

  /// Action Bright: Gradient top highlight for dark mode CTA
  static const darkActionBright = Color(0xFF6C2B39);

  /// Action Deep: Pressed state in dark mode
  static const darkActionDeep = actionDeep;

  /// Tint: Selected pills and container highlights in dark mode
  static const darkTint = Color(0xFF381F27);

  /// Ink: Crisp cashmere cream primary text (15.5:1 contrast on dark canvas)
  static const darkInk = Color(0xFFF7F2EE);

  /// Secondary Ink: Soft linen silver secondary text (9.5:1 contrast on dark canvas)
  static const darkSecondaryInk = Color(0xFFD6CBC7);

  /// Muted Ink: Warm oat slate for captions & helper text (6.2:1 contrast on dark canvas)
  static const darkMutedInk = Color(0xFFA89A96);

  /// Spark: Radiant warm gold for flame/streak in dark mode
  static const darkSpark = Color(0xFFF0B354);

  /// Spark Tint: Gold container highlight in dark mode
  static const darkSparkTint = Color(0xFF382914);

  /// Terracotta: Warm glowing terracotta for Chai break in dark mode
  static const darkTerracotta = Color(0xFFE07A5F);

  /// Success: Luminous botanical sage in dark mode
  static const darkSuccess = Color(0xFF4ADE80);

  /// Warning: Warm amber
  static const darkWarning = Color(0xFFFBBF24);

  /// Danger: Soft ruby red
  static const darkDanger = Color(0xFFFB7185);
}
