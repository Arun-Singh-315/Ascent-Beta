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
/// - **Body / Label** → DM Sans (Regular / Medium)
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

  // ── Body (DM Sans) ──────────────────────────────────────────────────────────

  /// 16 px · Regular · h 1.45 · ls −0.15
  static TextStyle get bodyLarge => GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: -0.15,
  );

  /// 14 px · Regular · h 1.45 · ls −0.12
  static TextStyle get bodyMedium => GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: -0.12,
  );

  /// 12 px · Regular · h 1.4 · ls −0.05
  static TextStyle get bodySmall => GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: -0.05,
  );

  /// 14 px · Medium (w500) · h 1.45 · ls −0.12 — slightly emphasised body copy
  static TextStyle get bodyMediumMedium => GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
    letterSpacing: -0.12,
  );

  // ── Labels (DM Sans Medium) ─────────────────────────────────────────────────

  /// 16 px · Medium · h 1.3 · ls +0.05  — button labels, tab labels
  static TextStyle get labelLarge => GoogleFonts.dmSans(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.05,
  );

  /// 12 px · Medium · h 1.3 · ls +0.35  — chips, badges, metadata
  static TextStyle get labelSmall => GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.35,
  );

  /// 14 px · Medium · h 1.3 · ls +0.1 — form labels, card subtitles
  static TextStyle get labelMedium => GoogleFonts.dmSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.1,
  );

  /// 12 px · Medium · h 1.3 · ls +0.25 — captions, pills
  static TextStyle get captionMedium => GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.3,
    letterSpacing: 0.25,
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

  // ── Home Redesign Type Scale (Tokens) ────────────────────────────────────

  /// Display 34 / 40 · 600 (Bricolage Grotesque)
  static TextStyle get homeDisplay => GoogleFonts.bricolageGrotesque(
    fontSize: 34,
    fontWeight: FontWeight.w600,
    height: 40 / 34,
    letterSpacing: -0.5,
  );

  /// Title 22 / 28 · 600 (Bricolage Grotesque)
  static TextStyle get homeTitle => GoogleFonts.bricolageGrotesque(
    fontSize: 22,
    fontWeight: FontWeight.w600,
    height: 28 / 22,
    letterSpacing: -0.3,
  );

  /// Headline 17 / 24 · 600 (DM Sans)
  static TextStyle get homeHeadline => GoogleFonts.dmSans(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    height: 24 / 17,
  );

  /// Body 15 / 22 · 400 (DM Sans) · ls −0.12
  static TextStyle get homeBody => GoogleFonts.dmSans(
    fontSize: 15,
    fontWeight: FontWeight.w400,
    height: 1.45,
    letterSpacing: -0.12,
  );

  /// Secondary 13 / 18 · 400 (DM Sans) · ls −0.08
  static TextStyle get homeSecondary => GoogleFonts.dmSans(
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: -0.08,
  );

  /// Caption 11 / 16 · 500 (DM Sans) · ls +0.35
  static TextStyle get homeCaption => GoogleFonts.dmSans(
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.35,
    letterSpacing: 0.35,
  );
}

/// Central font catalog, retaining the established glass type scale.
/// Repeated styles share a definition; screens supply semantic colors only.
/// Legacy inter* accessor names remain compatible but render DM Sans body copy.
class AppTypography {
  AppTypography._();

  /// Dedicated typography for thought reflections and notes: crisp, readable,
  /// breathable line-height, and gentle letter-spacing.
  static TextStyle thoughtContent({
    Color? color,
    TextDecoration? decoration,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: 14.5,
    fontWeight: FontWeight.w500,
    height: 1.5,
    letterSpacing: 0.1,
    color: color,
    decoration: decoration,
  );

  static TextStyle inter13Regular1({FontWeight? fontWeight, Color? color}) =>
      GoogleFonts.dmSans(fontSize: 13, fontWeight: fontWeight, color: color);
  static TextStyle jetBrainsMono11W7002({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle inter11W7003({Color? color}) => GoogleFonts.dmSans(
    fontSize: 11,
    fontWeight: FontWeight.w700,
    color: color,
  );
  static TextStyle plusJakartaSans18W6004({
    Color? color,
    TextDecoration? decoration,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w600,
    height: 1.35,
    color: color,
    decoration: decoration,
  );
  static TextStyle inter14Regular5({Color? color}) =>
      GoogleFonts.dmSans(fontSize: 14, height: 1.4, color: color);
  static TextStyle inter13Regular6({Color? color}) =>
      GoogleFonts.dmSans(fontSize: 13, color: color);
  static TextStyle plusJakartaSans14W7007({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle jetBrainsMono10Regular8({Color? color}) =>
      GoogleFonts.jetBrainsMono(fontSize: 10, color: color);
  static TextStyle jetBrainsMono115W7009({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle plusJakartaSans105W60010({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: color,
      );
  static TextStyle jetBrainsMono11W60011({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: color,
      );
  static TextStyle plusJakartaSans16W70012({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle merriweather20W80013({Color? color}) =>
      GoogleFonts.merriweather(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        height: 1.3,
        color: color,
      );
  static TextStyle sourceSerif415Regular14({Color? color}) =>
      GoogleFonts.sourceSerif4(fontSize: 15, height: 1.6, color: color);
  static TextStyle plusJakartaSans125Regular15({
    FontWeight? fontWeight,
    Color? color,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: 12.5,
    fontWeight: fontWeight,
    color: color,
  );
  static TextStyle plusJakartaSans13W70016({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.4,
        color: color,
      );
  static TextStyle plusJakartaSans14Regular17({
    FontWeight? fontWeight,
    Color? color,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: fontWeight,
    color: color,
  );
  static TextStyle plusJakartaSans13Regular18({Color? color}) =>
      GoogleFonts.plusJakartaSans(fontSize: 13, color: color);
  static TextStyle jetBrainsMono48W70019({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        color: color,
      );
  static TextStyle plusJakartaSans12W50020({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: color,
      );
  static TextStyle plusJakartaSans14W70021({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: 14,
        color: color,
      );
  static TextStyle plusJakartaSans14Regular22({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontStyle: FontStyle.italic,
        height: 1.35,
        color: color,
      );
  static TextStyle plusJakartaSans11W80023({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.6,
        color: color,
      );
  static TextStyle plusJakartaSans44W80024({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 44,
        fontWeight: FontWeight.w800,
        letterSpacing: -1.5,
        color: color,
      );
  static TextStyle plusJakartaSans105W80025({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 10.5,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.5,
        color: color,
      );
  static TextStyle jetBrainsMono13W60026({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      );
  static TextStyle plusJakartaSans95W70027({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: color,
      );
  static TextStyle jetBrainsMono15W70028({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle plusJakartaSans95W50029({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 9.5,
        fontWeight: FontWeight.w500,
        color: color,
      );
  static TextStyle plusJakartaSans155W70030({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle plusJakartaSans13W70031() =>
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13);
  static TextStyle plusJakartaSans13W60032() =>
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w600, fontSize: 13);
  static TextStyle jetBrainsMono12W60033({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
      );
  static TextStyle jetBrainsMono105W70034({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle plusJakartaSans15W70035({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle jetBrainsMono11Regular36({Color? color}) =>
      GoogleFonts.jetBrainsMono(fontSize: 11, color: color);
  static TextStyle plusJakartaSans125W60037({
    Color? color,
    TextDecoration? decoration,
    Color? decorationColor,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: 12.5,
    fontWeight: FontWeight.w600,
    color: color,
    decoration: decoration,
    decorationColor: decorationColor,
  );
  static TextStyle jetBrainsMono105Regular38({Color? color}) =>
      GoogleFonts.jetBrainsMono(fontSize: 10.5, color: color);
  static TextStyle jetBrainsMono115W60039({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 11.5,
        fontWeight: FontWeight.w600,
        color: color,
      );
  static TextStyle plusJakartaSans13Regular40({
    FontWeight? fontWeight,
    Color? color,
    TextDecoration? decoration,
    Color? decorationColor,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: 13,
    height: 1.25,
    fontWeight: fontWeight,
    color: color,
    decoration: decoration,
    decorationColor: decorationColor,
  );
  static TextStyle jetBrainsMono105W60041({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 10.5,
        fontWeight: FontWeight.w600,
        color: color,
      );
  static TextStyle plusJakartaSans115Regular42({
    FontWeight? fontWeight,
    Color? color,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: 11.5,
    fontWeight: fontWeight,
    color: color,
  );
  static TextStyle plusJakartaSans125Regular43({Color? color}) =>
      GoogleFonts.plusJakartaSans(fontSize: 12.5, height: 1.4, color: color);
  static TextStyle plusJakartaSans13W70044({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle plusJakartaSans18W70045({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle jetBrainsMono11W80046({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
        color: color,
      );
  static TextStyle plusJakartaSans135W70047({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle jetBrainsMono95W70048({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 9.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: color,
      );
  static TextStyle jetBrainsMono95W60049({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 9.5,
        fontWeight: FontWeight.w600,
        color: color,
      );
  static TextStyle plusJakartaSans16W70050({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.25,
        color: color,
      );
  static TextStyle jetBrainsMono12W80051({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w800,
        color: color,
      );
  static TextStyle jetBrainsMono11W60052({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        color: color,
      );
  static TextStyle plusJakartaSans18W70053({
    Color? color,
    TextDecoration? decoration,
    Color? decorationColor,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: 18,
    fontWeight: FontWeight.w700,
    height: 1.25,
    color: color,
    decoration: decoration,
    decorationColor: decorationColor,
  );
  static TextStyle jetBrainsMono32W80054({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        letterSpacing: -1,
        color: color,
      );
  static TextStyle jetBrainsMono11W70055({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.2,
        color: color,
      );
  static TextStyle plusJakartaSans135W60056({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        color: color,
      );
  static TextStyle plusJakartaSans12Regular57({Color? color}) =>
      GoogleFonts.plusJakartaSans(fontSize: 12, color: color);
  static TextStyle plusJakartaSans11Regular58({Color? color}) =>
      GoogleFonts.plusJakartaSans(fontSize: 11, color: color);
  static TextStyle plusJakartaSans125Regular59({
    FontWeight? fontWeight,
    Color? color,
    TextDecoration? decoration,
    Color? decorationColor,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: 12.5,
    fontWeight: fontWeight,
    color: color,
    decoration: decoration,
    decorationColor: decorationColor,
  );
  static TextStyle jetBrainsMono11Regular60({
    Color? color,
    FontWeight? fontWeight,
  }) => GoogleFonts.jetBrainsMono(
    fontSize: 11,
    color: color,
    fontWeight: fontWeight,
  );
  static TextStyle interInheritedRegular61({
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
  }) => GoogleFonts.dmSans(
    fontSize: fontSize,
    fontWeight: fontWeight,
    color: color,
  );
  static TextStyle inter12W50062({Color? color}) => GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w500,
    color: color,
  );
  static TextStyle jetBrainsMono12W70063({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle plusJakartaSans20W80064({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        color: color,
      );
  static TextStyle plusJakartaSans125Regular65({Color? color}) =>
      GoogleFonts.plusJakartaSans(fontSize: 12.5, height: 1.35, color: color);
  static TextStyle jetBrainsMono13W70066({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontWeight: FontWeight.w700,
        fontSize: 13,
        color: color,
      );
  static TextStyle jetBrainsMono11W80067({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontWeight: FontWeight.w800,
        fontSize: 11,
        color: color,
      );
  static TextStyle jetBrainsMono105W70068({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 10.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: color,
      );
  static TextStyle jetBrainsMono14W70069({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle jetBrainsMono13W80070({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w800,
        color: color,
      );
  static TextStyle plusJakartaSans14W60071({
    Color? color,
    TextDecoration? decoration,
  }) => GoogleFonts.plusJakartaSans(
    fontWeight: FontWeight.w500,
    height: 1.45,
    fontSize: 14,
    letterSpacing: -0.12,
    color: color,
    decoration: decoration,
  );
  static TextStyle jetBrainsMonoInheritedRegular72({TextStyle? textStyle}) =>
      GoogleFonts.jetBrainsMono(textStyle: textStyle);
  static TextStyle plusJakartaSans12W60073({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: color,
      );
  static TextStyle jetBrainsMono52W40074({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 52,
        fontWeight: FontWeight.w400,
        letterSpacing: -1.5,
        color: color,
      );
  static TextStyle jetBrainsMono10W70075({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 10,
        letterSpacing: 1.5,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle plusJakartaSans17W70076({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle plusJakartaSans115Regular77({
    Color? color,
    FontWeight? fontWeight,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: 11.5,
    color: color,
    fontWeight: fontWeight,
  );
  static TextStyle plusJakartaSans125W70078() =>
      GoogleFonts.plusJakartaSans(fontSize: 12.5, fontWeight: FontWeight.w700);
  static TextStyle jetBrainsMono10W70079({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: color,
      );
  static TextStyle plusJakartaSans14W60080({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: color,
      );
  static TextStyle plusJakartaSans115Regular81({Color? color}) =>
      GoogleFonts.plusJakartaSans(fontSize: 11.5, color: color);
  static TextStyle jetBrainsMono10W70082({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 10,
        letterSpacing: 1.1,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle plusJakartaSans13W60083({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13,
        fontWeight: FontWeight.w600,
        color: color,
      );
  static TextStyle jetBrainsMono13W70084({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 13,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle jetBrainsMono11W70085({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: color,
      );
  static TextStyle plusJakartaSans14W70086() =>
      GoogleFonts.plusJakartaSans(fontSize: 14, fontWeight: FontWeight.w700);
  static TextStyle jetBrainsMono11W70087({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.1,
        color: color,
      );
  static TextStyle plusJakartaSans20W70088({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle plusJakartaSans14Regular89({Color? color}) =>
      GoogleFonts.plusJakartaSans(fontSize: 14, height: 1.4, color: color);
  static TextStyle jetBrainsMono42W70090({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 42,
        fontWeight: FontWeight.w700,
        letterSpacing: -1,
        color: color,
      );
  static TextStyle plusJakartaSansInheritedW70091() =>
      GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700);
  static TextStyle plusJakartaSans13Regular92({
    FontWeight? fontWeight,
    Color? color,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: 13,
    fontWeight: fontWeight,
    color: color,
  );
  static TextStyle plusJakartaSans125W70093({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w700,
        height: 1.2,
        color: color,
      );
  static TextStyle plusJakartaSans135W60094({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 13.5,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
        color: color,
      );
  static TextStyle plusJakartaSans16W70095({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        height: 1.3,
        color: color,
      );
  static TextStyle jetBrainsMono10W70096({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.0,
        color: color,
      );
  static TextStyle plusJakartaSans12W60097() =>
      GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600);
  static TextStyle plusJakartaSans13W70098() =>
      GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700);
  static TextStyle bricolageGrotesque15W70099({Color? color}) =>
      GoogleFonts.bricolageGrotesque(
        fontWeight: FontWeight.w700,
        fontSize: 15,
        color: color,
      );
  static TextStyle bricolageGrotesque20W700100({Color? color}) =>
      GoogleFonts.bricolageGrotesque(
        fontWeight: FontWeight.w700,
        fontSize: 20,
        color: color,
      );
  static TextStyle bricolageGrotesque18W700101({Color? color}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: color,
      );
  static TextStyle dmSans13Regular102({Color? color}) =>
      GoogleFonts.dmSans(fontSize: 13, color: color);
  static TextStyle dmSansInheritedW600103() =>
      GoogleFonts.dmSans(fontWeight: FontWeight.w600);
  static TextStyle bricolageGrotesqueInheritedW700104({
    double? fontSize,
    Color? color,
  }) => GoogleFonts.bricolageGrotesque(
    fontWeight: FontWeight.w700,
    fontSize: fontSize,
    color: color,
  );
  static TextStyle dmSans13Regular105({Color? color}) =>
      GoogleFonts.dmSans(fontSize: 13, height: 1.4, color: color);
  static TextStyle dmSans14W600106() =>
      GoogleFonts.dmSans(fontSize: 14, fontWeight: FontWeight.w600);
  static TextStyle bricolageGrotesque17W600107({Color? color}) =>
      GoogleFonts.bricolageGrotesque(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: color,
      );
  static TextStyle dmSans11W400108({Color? color}) => GoogleFonts.dmSans(
    fontSize: 11,
    fontWeight: FontWeight.w400,
    color: color,
  );
  static TextStyle jetBrainsMono12W600109({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontWeight: FontWeight.w600,
        fontSize: 12,
        color: color,
      );
  static TextStyle jetBrainsMono12W500110({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontWeight: FontWeight.w500,
        fontSize: 12,
        color: color,
      );
  static TextStyle inter12W600111({Color? color}) => GoogleFonts.dmSans(
    fontSize: 12,
    fontWeight: FontWeight.w600,
    color: color,
  );
  static TextStyle plusJakartaSans20W800112({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 20,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.5,
        color: color,
      );
  static TextStyle plusJakartaSans32W800113({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 32,
        fontWeight: FontWeight.w800,
        color: color,
      );
  static TextStyle plusJakartaSans12W700114({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: color,
      );
  static TextStyle plusJakartaSans15W700115() =>
      GoogleFonts.plusJakartaSans(fontSize: 15, fontWeight: FontWeight.w700);
  static TextStyle plusJakartaSans14W600116({
    Color? color,
    TextDecoration? decoration,
  }) => GoogleFonts.plusJakartaSans(
    fontSize: 14,
    fontWeight: FontWeight.w500,
    height: 1.45,
    letterSpacing: -0.12,
    color: color,
    decoration: decoration,
  );
  static TextStyle jetBrainsMono10W700117({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 10,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.8,
        color: color,
      );
  static TextStyle plusJakartaSans155W700118({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 15.5,
        fontWeight: FontWeight.w700,
        letterSpacing: -0.2,
        color: color,
      );
  static TextStyle plusJakartaSans125W600119({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontSize: 12.5,
        fontWeight: FontWeight.w600,
        color: color,
      );
  static TextStyle jetBrainsMono105W500120({Color? color}) =>
      GoogleFonts.jetBrainsMono(
        fontSize: 10.5,
        fontWeight: FontWeight.w500,
        color: color,
      );
  static TextStyle plusJakartaSans18W700121({Color? color}) =>
      GoogleFonts.plusJakartaSans(
        fontWeight: FontWeight.w700,
        fontSize: 18,
        color: color,
      );
}

/// Shared typography overrides used with the central text theme.
class AppTypeRoles {
  AppTypeRoles._();
  static const typeRole1 = TextStyle(fontSize: AppTypeScale.type18);
  static const typeRole2 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightW700,
  );
  static const typeRole3 = TextStyle(
    fontSize: AppTypeScale.type10,
    fontWeight: AppTypeScale.typeFontWeightW700,
  );
  static const typeRole4 = TextStyle(fontSize: AppTypeScale.type11);
  static const typeRole5 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightBold,
    fontSize: AppTypeScale.type18,
  );
  static const typeRole6 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightBold,
    fontSize: AppTypeScale.type17,
  );
  static const typeRole7 = TextStyle(
    fontSize: AppTypeScale.type12,
    fontWeight: AppTypeScale.typeFontWeightBold,
  );
  static const typeRole8 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightW600,
  );
  static const typeRole9 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightBold,
  );
  static const typeRole10 = TextStyle(fontSize: AppTypeScale.type16);
  static const typeRole11 = TextStyle(
    fontSize: AppTypeScale.type22,
    fontWeight: AppTypeScale.typeFontWeightW700,
  );
  static const typeRole12 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightBold,
    fontSize: AppTypeScale.type11,
  );
  static const typeRole13 = TextStyle(fontSize: AppTypeScale.type17);
  static const typeRole14 = TextStyle(
    fontSize: AppTypeScale.type12,
    fontWeight: AppTypeScale.typeFontWeightW700,
  );
  static const typeRole15 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightW500,
  );
  static const typeRole16 = TextStyle(
    fontSize: AppTypeScale.type11,
    fontWeight: AppTypeScale.typeFontWeightW500,
  );
  static const typeRole17 = TextStyle(
    fontSize: AppTypeScale.type12,
    fontWeight: AppTypeScale.typeFontWeightW600,
  );
  static const typeRole18 = TextStyle(fontSize: AppTypeScale.type10);
  static const typeRole19 = TextStyle(
    fontSize: AppTypeScale.type10,
    fontWeight: AppTypeScale.typeFontWeightBold,
  );
  static const typeRole20 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightW800,
  );
  static const typeRole21 = TextStyle(
    fontSize: AppTypeScale.type18,
    fontWeight: AppTypeScale.typeFontWeightBold,
  );
  static const typeRole22 = TextStyle(
    fontSize: AppTypeScale.type11,
    fontWeight: AppTypeScale.typeFontWeightW700,
  );
  static const typeRole23 = TextStyle(fontSize: AppTypeScale.type115);
  static const typeRole24 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightBold,
    fontSize: AppTypeScale.type12,
  );
  static const typeRole25 = TextStyle(
    fontSize: AppTypeScale.type26,
    fontWeight: AppTypeScale.typeFontWeightW700,
  );
  static const typeRole26 = TextStyle(
    fontSize: AppTypeScale.type13,
    fontWeight: AppTypeScale.typeFontWeightW400,
  );
  static const typeRole27 = TextStyle(fontSize: AppTypeScale.type12);
  static const typeRole28 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightBold,
    fontSize: AppTypeScale.type16,
  );
  static const typeRole29 = TextStyle(fontSize: AppTypeScale.type22);
  static const typeRole30 = TextStyle(
    fontSize: AppTypeScale.type16,
    fontWeight: AppTypeScale.typeFontWeightBold,
  );
  static const typeRole31 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightW700,
    fontSize: AppTypeScale.type11,
  );
  static const typeRole32 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightW600,
    fontSize: AppTypeScale.type14,
  );
  static const typeRole33 = TextStyle(
    fontSize: AppTypeScale.type11,
    fontWeight: AppTypeScale.typeFontWeightW600,
  );
  static const typeRole34 = TextStyle(
    fontSize: AppTypeScale.type11,
    fontWeight: AppTypeScale.typeFontWeightBold,
  );
  static const typeRole35 = TextStyle(
    fontSize: AppTypeScale.type24,
    fontWeight: AppTypeScale.typeFontWeightW700,
  );
  static const typeRole36 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightW600,
    fontSize: AppTypeScale.type11,
  );
  static const typeRole37 = TextStyle(
    fontSize: AppTypeScale.type17,
    fontWeight: AppTypeScale.typeFontWeightBold,
  );
  static const typeRole38 = TextStyle(
    fontSize: AppTypeScale.type125,
    fontWeight: AppTypeScale.typeFontWeightW700,
  );
  static const typeRole39 = TextStyle(
    fontSize: AppTypeScale.type135,
    fontWeight: AppTypeScale.typeFontWeightW700,
  );
  static const typeRole40 = TextStyle(fontSize: AppTypeScale.type125);
  static const typeRole41 = TextStyle(fontSize: AppTypeScale.type15);
  static const typeRole42 = TextStyle(
    fontSize: AppTypeScale.type125,
    fontWeight: AppTypeScale.typeFontWeightW600,
  );
  static const typeRole43 = TextStyle(
    fontSize: AppTypeScale.type125,
    fontWeight: AppTypeScale.typeFontWeightW500,
  );
  static const typeRole44 = TextStyle(
    fontSize: AppTypeScale.type10,
    fontWeight: AppTypeScale.typeFontWeightW500,
  );
  static const typeRole45 = TextStyle(
    fontSize: AppTypeScale.type32,
    fontWeight: AppTypeScale.typeFontWeightW800,
  );
  static const typeRole46 = TextStyle(
    fontSize: AppTypeScale.type26,
    fontWeight: AppTypeScale.typeFontWeightBold,
  );
  static const typeRole47 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightW600,
    fontSize: AppTypeScale.type13,
  );
  static const typeRole48 = TextStyle(
    fontSize: AppTypeScale.type24,
    fontWeight: AppTypeScale.typeFontWeightBold,
  );
  static const typeRole49 = TextStyle(
    fontSize: AppTypeScale.type16,
    fontWeight: AppTypeScale.typeFontWeightW700,
  );
  static const typeRole50 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightW700,
    fontSize: AppTypeScale.type15,
  );
  static const typeRole51 = TextStyle(
    fontSize: AppTypeScale.type10,
    fontWeight: AppTypeScale.typeFontWeightW600,
  );
  static const typeRole52 = TextStyle(
    fontSize: AppTypeScale.type13,
    fontWeight: AppTypeScale.typeFontWeightW600,
  );
  static const typeRole53 = TextStyle(
    fontSize: AppTypeScale.type18,
    fontWeight: AppTypeScale.typeFontWeightW700,
  );
  static const typeRole54 = TextStyle(fontSize: AppTypeScale.type105);
  static const typeRole55 = TextStyle(
    fontSize: AppTypeScale.type9,
    fontWeight: AppTypeScale.typeFontWeightBold,
  );
  static const typeRole56 = TextStyle(
    fontSize: AppTypeScale.type85,
    fontWeight: AppTypeScale.typeFontWeightBold,
  );
  static const typeRole57 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightW700,
    fontSize: AppTypeScale.type16,
  );
  static const typeRole58 = TextStyle(fontSize: AppTypeScale.type13);
  static const typeRole59 = TextStyle(fontSize: AppTypeScale.type14);
  static const typeRole60 = TextStyle(
    fontSize: AppTypeScale.type15,
    fontWeight: AppTypeScale.typeFontWeightBold,
  );
  static const typeRole61 = TextStyle(
    fontSize: AppTypeScale.type14,
    fontWeight: AppTypeScale.typeFontWeightW600,
  );
  static const typeRole62 = TextStyle(
    fontSize: AppTypeScale.type95,
    fontWeight: AppTypeScale.typeFontWeightW700,
  );
  static const typeRole63 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightW600,
    fontSize: AppTypeScale.type12,
  );
  static const typeRole64 = TextStyle(fontSize: AppTypeScale.type44);
  static const typeRole65 = TextStyle(
    fontSize: AppTypeScale.type9,
    fontWeight: AppTypeScale.typeFontWeightW800,
  );
  static const typeRole66 = TextStyle(
    fontSize: AppTypeScale.type105,
    fontWeight: AppTypeScale.typeFontWeightW600,
  );
  static const typeRole67 = TextStyle(
    fontSize: AppTypeScale.type155,
    fontWeight: AppTypeScale.typeFontWeightW700,
  );
  static const typeRole68 = TextStyle(
    fontSize: AppTypeScale.type15,
    fontWeight: AppTypeScale.typeFontWeightW600,
  );
  static const typeRole69 = TextStyle(
    fontSize: AppTypeScale.type17,
    fontWeight: AppTypeScale.typeFontWeightW700,
  );
  static const typeRole70 = TextStyle(
    fontSize: AppTypeScale.type17,
    fontWeight: AppTypeScale.typeFontWeightW600,
  );
  static const typeRole71 = TextStyle(
    fontSize: AppTypeScale.type13,
    fontWeight: AppTypeScale.typeFontWeightBold,
  );
  static const typeRole72 = TextStyle(
    fontSize: AppTypeScale.type105,
    fontWeight: AppTypeScale.typeFontWeightW500,
  );
  static const typeRole73 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightBold,
    fontSize: AppTypeScale.type22,
  );
  static const typeRole74 = TextStyle(
    fontWeight: AppTypeScale.typeFontWeightBold,
    fontSize: AppTypeScale.type14,
  );
  static const typeRole75 = TextStyle(fontSize: AppTypeScale.type9);
  static const typeRole76 = TextStyle(
    fontSize: AppTypeScale.type12,
    fontWeight: AppTypeScale.typeFontWeightW500,
  );
}

/// State-dependent type recipes preserve existing emphasis without inline fonts.
class AppStateTypography {
  AppStateTypography._();
  static TextStyle stateType1({required bool state0}) =>
      TextStyle(fontWeight: state0 ? FontWeight.w600 : FontWeight.w500);
  static TextStyle stateType2({required bool state0, Color? color}) =>
      AppTypography.inter13Regular1(
        fontWeight: state0 ? FontWeight.w600 : FontWeight.w500,
        color: color,
      );
  static TextStyle stateType3({required bool state0}) => TextStyle(
    fontSize: AppTypeScale.type11,
    fontWeight: state0 ? FontWeight.w600 : FontWeight.w400,
  );
  static const stateType4 = TextStyle(fontSize: AppTypeScale.type10);
  static TextStyle stateType5({required bool state0}) => TextStyle(
    fontWeight: state0 ? FontWeight.bold : FontWeight.normal,
    fontSize: AppTypeScale.type11,
  );
  static TextStyle stateType6({required bool state0}) =>
      TextStyle(fontWeight: state0 ? FontWeight.w600 : FontWeight.w400);
  static TextStyle stateType7({required bool state0}) => TextStyle(
    fontWeight: state0 ? FontWeight.w600 : FontWeight.normal,
    fontSize: AppTypeScale.type12,
  );
  static TextStyle stateType8({required bool state0, Color? color}) =>
      AppTypography.plusJakartaSans125Regular15(
        fontWeight: state0 ? FontWeight.w700 : FontWeight.w500,
        color: color,
      );
  static TextStyle stateType9({required bool state0, Color? color}) =>
      AppTypography.plusJakartaSans14Regular17(
        fontWeight: state0 ? FontWeight.w700 : FontWeight.w500,
        color: color,
      );
  static TextStyle stateType10({required bool state0}) => TextStyle(
    fontWeight: state0 ? FontWeight.w600 : FontWeight.w400,
    fontSize: AppTypeScale.type12,
  );
  static TextStyle stateType11({
    required bool state0,
    Color? color,
    TextDecoration? decoration,
    Color? decorationColor,
  }) => AppTypography.plusJakartaSans13Regular40(
    fontWeight: state0 ? FontWeight.w700 : FontWeight.w600,
    color: color,
    decoration: decoration,
    decorationColor: decorationColor,
  );
  static TextStyle stateType12({required bool state0, Color? color}) =>
      AppTypography.plusJakartaSans115Regular42(
        fontWeight: state0 ? FontWeight.w700 : FontWeight.w600,
        color: color,
      );
  static TextStyle stateType13({required bool state0}) => TextStyle(
    fontSize: AppTypeScale.type115,
    fontWeight: state0 ? FontWeight.w600 : FontWeight.normal,
  );
  static const stateType14 = TextStyle(fontSize: AppTypeScale.type11);
  static TextStyle stateType15({required bool state0}) => TextStyle(
    fontSize: state0 ? 18 : 23,
    fontWeight: AppTypeScale.typeFontWeightW700,
  );
  static TextStyle stateType16({
    required bool state0,
    Color? color,
    TextDecoration? decoration,
    Color? decorationColor,
  }) => AppTypography.plusJakartaSans125Regular59(
    fontWeight: state0 ? FontWeight.w700 : FontWeight.w500,
    color: color,
    decoration: decoration,
    decorationColor: decorationColor,
  );
  static TextStyle stateType17({required bool state0, Color? color}) =>
      AppTypography.jetBrainsMono11Regular60(
        fontWeight: state0 ? FontWeight.w700 : FontWeight.w500,
        color: color,
      );
  static TextStyle stateType18({
    required bool state0,
    required bool state1,
    Color? color,
  }) => AppTypography.interInheritedRegular61(
    fontSize: state0 ? 10.5 : 11,
    fontWeight: state1 ? FontWeight.w700 : FontWeight.w500,
    color: color,
  );
  static TextStyle stateType19({required bool state0}) => TextStyle(
    fontSize: AppTypeScale.type12,
    fontWeight: state0 ? FontWeight.w600 : FontWeight.w500,
  );
  static TextStyle stateType20({required bool state0}) => TextStyle(
    fontWeight: state0 ? FontWeight.w600 : FontWeight.w400,
    fontSize: AppTypeScale.type11,
  );
  static const stateType21 = TextStyle(
    fontSize: AppTypeScale.type11,
    fontWeight: AppTypeScale.typeFontWeightBold,
  );
  static TextStyle stateType22({required bool state0}) => TextStyle(
    fontSize: AppTypeScale.type105,
    fontWeight: state0 ? FontWeight.w600 : FontWeight.w400,
  );
  static TextStyle stateType23({required bool state0, Color? color}) =>
      AppTypography.plusJakartaSans115Regular77(
        fontWeight: state0 ? FontWeight.w600 : FontWeight.normal,
        color: color,
      );
  static TextStyle stateType24({required bool state0, Color? color}) =>
      AppTypography.plusJakartaSans13Regular92(
        fontWeight: state0 ? FontWeight.w700 : FontWeight.w500,
        color: color,
      );
  static TextStyle stateType25({required bool state0, Color? color}) =>
      AppTypography.bricolageGrotesqueInheritedW700104(
        fontSize: state0 ? 22 : 20,
        color: color,
      );
  static TextStyle stateType26({required bool state0}) => TextStyle(
    fontSize: AppTypeScale.type10,
    fontWeight: state0 ? FontWeight.w700 : FontWeight.w500,
  );
}

class AppTypeScale {
  AppTypeScale._();
  static const double type18 = 18;
  static const double type10 = 10;
  static const double type11 = 11;
  static const typeFontWeightW700 = FontWeight.w700;
  static const double type17 = 17;
  static const double type12 = 12;
  static const double type16 = 16;
  static const typeFontWeightBold = FontWeight.bold;
  static const typeFontWeightW600 = FontWeight.w600;
  static const double type22 = 22;
  static const typeFontWeightW500 = FontWeight.w500;
  static const typeFontWeightW800 = FontWeight.w800;
  static const double type115 = 11.5;
  static const double type26 = 26;
  static const double type13 = 13;
  static const typeFontWeightW400 = FontWeight.w400;
  static const double type14 = 14;
  static const double type24 = 24;
  static const double type125 = 12.5;
  static const double type135 = 13.5;
  static const double type15 = 15;
  static const double type32 = 32;
  static const double type105 = 10.5;
  static const double type9 = 9;
  static const double type85 = 8.5;
  static const double type95 = 9.5;
  static const double type44 = 44;
  static const double type155 = 15.5;
}
