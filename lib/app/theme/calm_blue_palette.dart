import 'package:flutter/painting.dart';

/// Calm Blue, Harbor edition: Ascent's one colour palette (CLAUDE.md §3.1).
/// A light blue-tinted page with a navy theme; red, green and amber are used
/// only where they mean something (overdue, done, due soon).
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
  static const canvas = Color(0xFFF1F5FB);
  static const surface = Color(0xFFFFFFFF);
  static const elevated = Color(0xFFFFFFFF);
  static const recessed = Color(0xFFE5ECF6);
  static const separator = Color(0xFFDCE4F0);
  static const label = Color(0xFF0F1D30);
  static const labelSecondary = Color(0xFF45556B);
  static const labelTertiary = Color(0xFF56657C);
  static const action = Color(0xFF13325C);
  static const actionPressed = Color(0xFF0E2747);
  static const actionTint = Color(0xFFDDE6F3);
  static const actionTintInk = Color(0xFF13325C);
  static const onAction = Color(0xFFFFFFFF);
  static const success = Color(0xFF24744B);
  static const successTint = Color(0xFFE2F2E9);
  static const warning = Color(0xFF94590F);
  static const warningTint = Color(0xFFF8ECD8);
  static const danger = Color(0xFFB23A32);
  static const dangerTint = Color(0xFFFBE8E6);
  static const star = Color(0xFFD9A514);
  static const track = Color(0x1A1A2332);
  static const shadow = Color(0x0D1A2332);

  // ── Dark: charcoal, designed on its own (not inverted navy) ──────────────────────────────────────────────────────────
  static const darkCanvas = Color(0xFF0A0F17);
  static const darkSurface = Color(0xFF131A24);
  static const darkElevated = Color(0xFF1A2230);
  static const darkRecessed = Color(0xFF1A2230);
  static const darkSeparator = Color(0xFF232D3C);
  static const darkLabel = Color(0xFFE6ECF5);
  static const darkLabelSecondary = Color(0xFFA6B3C6);
  static const darkLabelTertiary = Color(0xFF8796AD);
  static const darkAction = Color(0xFFA9C3E8);
  static const darkActionFill = Color(0xFF3C5F96);
  static const darkActionPressed = Color(0xFF334F7E);
  static const darkActionTint = Color(0xFF14213A);
  static const darkActionTintInk = Color(0xFFA9C3E8);
  static const darkSuccess = Color(0xFF6CCB98);
  static const darkSuccessTint = Color(0xFF14291E);
  static const darkWarning = Color(0xFFE8AE5C);
  static const darkWarningTint = Color(0xFF2E2314);
  static const darkDanger = Color(0xFFF08A80);
  static const darkDangerTint = Color(0xFF3A1D1C);
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

  // ── Backdrops (top → bottom), one identity per screen ────────────────
  // Home: soft Apple blue.
  static const backdropLight = [
    Color(0xFFDDE9FB),
    Color(0xFFEDF3FD),
    Color(0xFFF7F9FD),
  ];
  static const backdropDark = [
    Color(0xFF161B23),
    Color(0xFF13161B),
    Color(0xFF111317),
  ];
  static const cloudBlue = Color(0xFF8DB7F5);
  static const cloudLilac = Color(0xFFC7B8F2);

  // Mindspace: soft teal-blue mist by day, deep sea by night (no purple).
  static const mindLight = [
    Color(0xFFE3F1F1),
    Color(0xFFEEF6F7),
    Color(0xFFF8FBFC),
  ];
  static const mindDark = [
    Color(0xFF0C1C1F),
    Color(0xFF0B1518),
    Color(0xFF080D10),
  ];
  static const mindCloudA = Color(0xFF8FD3CC);
  static const mindCloudB = Color(0xFF9CC3EE);
  static const mindDoodleLight = Color(0x1A2F8F8A);
  static const mindDoodleDark = Color(0x1A6CCBC3);

  // Riya: indigo to rose by day, indigo night after dark.
  static const riyaLight = [
    Color(0xFFE9EBFC),
    Color(0xFFF3EFFB),
    Color(0xFFFCF6F8),
  ];
  static const riyaDark = [
    Color(0xFF111735),
    Color(0xFF16122E),
    Color(0xFF0E0B19),
  ];
  static const riyaCloudA = Color(0xFF9C9AF0);
  static const riyaCloudB = Color(0xFFF0A9C0);
  static const riyaDoodleLight = Color(0x175E5CE6);
  static const riyaDoodleDark = Color(0x1AA9A7FF);

  /// Doodle ink for the Home tone (unused by default).
  static const doodleLight = Color(0x142F68C8);
  static const doodleDark = Color(0x14A9C4F2);

  // ── iOS glass cards ───────────────────────────────────────────────────────
  static const glassFillLight = Color(0xB8FFFFFF);
  static const glassFillDark = Color(0x8C1A2234);
  static const glassRimLight = Color(0xCCFFFFFF);
  static const glassRimDark = Color(0x1FFFFFFF);
  static const glassShadow = Color(0x142F4F86);

  // ── Pillar kinds (text and icons on canvas or surface, ≥ 4.5:1) ─────────
  static const think = Color(0xFF3F5BC4);
  static const darkThink = Color(0xFF94A8F2);
  static const commit = Color(0xFF94590F);
  static const darkCommit = Color(0xFFE8AE5C);
  static const care = Color(0xFFA93A5D);
  static const darkCare = Color(0xFFEE93B1);
  static const water = Color(0xFF16698F);
  static const darkWater = Color(0xFF6EC0EA);
  static const money = Color(0xFF24744B);
  static const darkMoney = Color(0xFF6CCB98);

  // ── Home colour zones (background tints, mixed into the canvas) ─────────
  static const zoneNow = Color(0xFFD6E6F8);
  static const zonePlan = Color(0xFFDCE8FA);
  static const zoneKeep = Color(0xFFFBE4D2);
  static const zoneMind = Color(0xFFD5EEEA);
  static const zoneCare = Color(0xFFF8DBE4);
  static const zoneMoney = Color(0xFFD6EEDF);
  static const zoneMore = Color(0xFFE3E7EE);
  static const darkZoneNow = Color(0xFF18273D);
  static const darkZonePlan = Color(0xFF15233A);
  static const darkZoneKeep = Color(0xFF2C2118);
  static const darkZoneMind = Color(0xFF10292A);
  static const darkZoneCare = Color(0xFF2E1A23);
  static const darkZoneMoney = Color(0xFF12291E);
  static const darkZoneMore = Color(0xFF1B1F26);

  // Focus (indigo-blue), used for focus sessions and their charts.
  static const focus = Color(0xFF3F5BC4);
  static const darkFocus = Color(0xFF94A8F2);
}
