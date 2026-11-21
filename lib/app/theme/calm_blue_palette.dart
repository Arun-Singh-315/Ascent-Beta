import 'package:flutter/painting.dart';

/// Calm Blue: Ascent's one colour palette (CLAUDE.md §3.1).
///
/// Soft, low-glare blues and a white/graphite base. Light and dark mirror
/// each other role for role. Every colour role in the app resolves here;
/// there are no alternative presets.
///
/// Rules this palette follows:
/// - No pure white text on black and no #007AFF-bright fills: text is a deep
///   navy ink by day and a soft off-white by night, so long reading is easy.
/// - Body text ≥ 7:1, secondary ≥ 4.5:1 on its surface; hints ≥ 4.5:1.
/// - Action blue is a calm, slightly desaturated blue. In dark mode links use
///   a soft periwinkle ink and filled buttons use a deeper blue so white
///   labels stay readable.
abstract final class CalmBluePalette {
  // ── Light ──────────────────────────────────────────────────────────────────
  static const canvas = Color(0xFFF2F5F9);
  static const surface = Color(0xFFFFFFFF);
  static const elevated = Color(0xFFFFFFFF);
  static const recessed = Color(0xFFE8EDF3);
  static const separator = Color(0xFFD6DEE8);
  static const label = Color(0xFF1A2332);
  static const labelSecondary = Color(0xFF4A5668);
  static const labelTertiary = Color(0xFF5B677C);
  static const action = Color(0xFF2F68C8);
  static const actionPressed = Color(0xFF2756A8);
  static const actionTint = Color(0xFFE6EEF9);
  static const actionTintInk = Color(0xFF24559F);
  static const onAction = Color(0xFFFFFFFF);
  static const success = Color(0xFF2E8B57);
  static const successTint = Color(0xFFE5F2EA);
  static const warning = Color(0xFFB7731F);
  static const warningTint = Color(0xFFF8EEDD);
  static const danger = Color(0xFFC6443A);
  static const dangerTint = Color(0xFFF8E6E4);
  static const star = Color(0xFFD9A514);
  static const track = Color(0x1A1A2332);
  static const shadow = Color(0x0D1A2332);

  // ── Dark (mirror) ──────────────────────────────────────────────────────────
  static const darkCanvas = Color(0xFF0B0E13);
  static const darkSurface = Color(0xFF161B23);
  static const darkElevated = Color(0xFF1E242E);
  static const darkRecessed = Color(0xFF1E242E);
  static const darkSeparator = Color(0xFF2B323D);
  static const darkLabel = Color(0xFFE4E9F0);
  static const darkLabelSecondary = Color(0xFFA9B4C2);
  static const darkLabelTertiary = Color(0xFF8995A6);
  static const darkAction = Color(0xFF8EB1EC);
  static const darkActionFill = Color(0xFF3A66B8);
  static const darkActionPressed = Color(0xFF30579E);
  static const darkActionTint = Color(0xFF1B2A42);
  static const darkActionTintInk = Color(0xFFA9C4F2);
  static const darkSuccess = Color(0xFF5DBB84);
  static const darkSuccessTint = Color(0xFF16291F);
  static const darkWarning = Color(0xFFE0A458);
  static const darkWarningTint = Color(0xFF2D2416);
  static const darkDanger = Color(0xFFE8776D);
  static const darkDangerTint = Color(0xFF34191A);
  static const darkStar = Color(0xFFE6C35A);
  static const darkTrack = Color(0x1FE4E9F0);
  static const darkShadow = Color(0x80000000);

  // ── Home sky (time of day): muted, low-glare pairs of (sky, light) ────────
  static const skyMorning = Color(0xFFCFE2F3);
  static const skyMorningLight = Color(0xFFF3E6D8);
  static const skyAfternoon = Color(0xFFC9E0F1);
  static const skyAfternoonLight = Color(0xFFE6EFF7);
  static const skyEvening = Color(0xFFD5D3EC);
  static const skyEveningLight = Color(0xFFEFE0D9);
  static const skyNight = Color(0xFFC8D2E8);
  static const skyNightLight = Color(0xFFDAD8EC);
  static const darkSkyMorning = Color(0xFF1D3450);
  static const darkSkyMorningLight = Color(0xFF39332E);
  static const darkSkyAfternoon = Color(0xFF1B3850);
  static const darkSkyAfternoonLight = Color(0xFF243649);
  static const darkSkyEvening = Color(0xFF2C2946);
  static const darkSkyEveningLight = Color(0xFF3B2E34);
  static const darkSkyNight = Color(0xFF192440);
  static const darkSkyNightLight = Color(0xFF272542);
}
