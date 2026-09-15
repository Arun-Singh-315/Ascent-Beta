import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ascent type system.
///
/// All styles are color-free — apply color at the call site via color tokens:
/// ```dart
/// Text('Hello', style: AscentTextStyles.displayLarge.copyWith(color: context.textPrimary))
/// ```
///
/// Font mapping:
/// - **Display** → Plus Jakarta Sans (SemiBold / Bold)
/// - **Body / Label** → Inter (Regular / Medium)
/// - **Stat** → JetBrains Mono (Medium)
class AscentTextStyles {
  AscentTextStyles._();

  // ── Display (Plus Jakarta Sans) ───────────────────────────────────────────

  /// 28 px · Bold · h 1.2 · ls −0.5  — hero numbers, screen titles
  static TextStyle get displayLarge => GoogleFonts.plusJakartaSans(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.5,
      );

  /// 22 px · SemiBold · h 1.25 · ls −0.3  — section headers
  static TextStyle get displayMedium => GoogleFonts.plusJakartaSans(
        fontSize: 22,
        fontWeight: FontWeight.w600,
        height: 1.25,
        letterSpacing: -0.3,
      );

  /// 18 px · SemiBold · h 1.3  — card titles, dialog headings
  static TextStyle get displaySmall => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  // ── Body (Inter) ──────────────────────────────────────────────────────────

  /// 16 px · Regular · h 1.5
  static TextStyle get bodyLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  /// 14 px · Regular · h 1.5
  static TextStyle get bodyMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.5,
      );

  /// 12 px · Regular · h 1.4
  static TextStyle get bodySmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
      );

  /// 14 px · Medium (w500) · h 1.5  — slightly emphasised body copy
  static TextStyle get bodyMediumMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.5,
      );

  // ── Labels (Inter Medium) ─────────────────────────────────────────────────

  /// 16 px · Medium · h 1.3 · ls +0.1  — button labels, tab labels
  static TextStyle get labelLarge => GoogleFonts.inter(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.1,
      );

  /// 12 px · Medium · h 1.3 · ls +0.4  — chips, badges, metadata
  static TextStyle get labelSmall => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.4,
      );

  /// 14 px · Medium · h 1.3 · ls +0.2 — form labels, card subtitles
  static TextStyle get labelMedium => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.2,
      );

  /// 12 px · Medium · h 1.3 · ls +0.3 — captions, pills
  static TextStyle get captionMedium => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.3,
        letterSpacing: 0.3,
      );

  /// Alias for captionMedium
  static TextStyle get caption => captionMedium;

  /// 18 px · SemiBold · h 1.3 — card titles and section headings
  static TextStyle get headlineMedium => GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        height: 1.3,
      );

  // ── Stats / Numbers (JetBrains Mono) ─────────────────────────────────────

  /// 14 px · Medium · h 1.2 — code snippets, mono badges
  static TextStyle get monoCode => GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        height: 1.2,
      );

  /// 28 px · Medium · h 1.1  — hero stat figures
  static TextStyle get statLarge => GoogleFonts.jetBrainsMono(
        fontSize: 28,
        fontWeight: FontWeight.w500,
        height: 1.1,
      );

  /// 22 px · Medium · h 1.1  — dashboard counters
  static TextStyle get statMedium => GoogleFonts.jetBrainsMono(
        fontSize: 22,
        fontWeight: FontWeight.w500,
        height: 1.1,
      );

  /// 16 px · Medium · h 1.1  — inline numbers, percentage tags
  static TextStyle get statSmall => GoogleFonts.jetBrainsMono(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        height: 1.1,
      );
}

