import 'package:flutter/material.dart';

import '../../core/home/home_zone.dart';
import 'calm_blue_palette.dart';

export '../../core/home/home_zone.dart';

/// The one set of colour roles for the Day Page (CLAUDE.md §3.1).
///
/// Light and dark are each designed on their own: Calm Blue by day,
/// charcoal by night. Read it with `context.tokens`, which never fails: if a
/// theme somehow lacks the extension, it falls back to the matching preset,
/// so a theme switch can't show an error screen.
@immutable
class AscentTokens extends ThemeExtension<AscentTokens> {
  const AscentTokens({
    required this.canvas,
    required this.surface,
    required this.raised,
    required this.recessed,
    required this.separator,
    required this.label,
    required this.labelSecondary,
    required this.labelTertiary,
    required this.action,
    required this.actionFill,
    required this.onAction,
    required this.actionTint,
    required this.success,
    required this.warning,
    required this.danger,
    required this.star,
    required this.think,
    required this.commit,
    required this.care,
    required this.water,
    required this.money,
    required this.zones,
  });

  /// Page background.
  final Color canvas;

  /// Cards and typing boxes.
  final Color surface;

  /// Raised surfaces: the Now card, full-screen pages, menus, dialogs.
  final Color raised;

  /// Segmented tracks and empty-state tiles.
  final Color recessed;

  /// 1 px hairlines and outlines.
  final Color separator;

  final Color label;
  final Color labelSecondary;
  final Color labelTertiary;

  /// Links, active icons, focus, selection.
  final Color action;

  /// Filled primary buttons (white label).
  final Color actionFill;
  final Color onAction;

  /// Tonal buttons and selected chips.
  final Color actionTint;

  final Color success;
  final Color warning;
  final Color danger;
  final Color star;

  /// Thoughts and Mind (teal).
  final Color think;

  /// Promises, focus streaks (amber).
  final Color commit;

  /// Medicine and body (rose).
  final Color care;
  final Color water;
  final Color money;

  /// Background tint for each Home zone, before it is mixed into [canvas].
  final Map<HomeZone, Color> zones;

  /// A zone's background at [strength] (0–1) over the canvas.
  Color zone(HomeZone z, {double strength = 0.7}) =>
      Color.lerp(canvas, zones[z]!, strength.clamp(0.0, 1.0))!;

  static const light = AscentTokens(
    canvas: CalmBluePalette.canvas,
    surface: CalmBluePalette.surface,
    raised: CalmBluePalette.elevated,
    recessed: CalmBluePalette.recessed,
    separator: CalmBluePalette.separator,
    label: CalmBluePalette.label,
    labelSecondary: CalmBluePalette.labelSecondary,
    labelTertiary: CalmBluePalette.labelTertiary,
    action: CalmBluePalette.action,
    actionFill: CalmBluePalette.action,
    onAction: CalmBluePalette.onAction,
    actionTint: CalmBluePalette.actionTint,
    success: CalmBluePalette.success,
    warning: CalmBluePalette.warning,
    danger: CalmBluePalette.danger,
    star: CalmBluePalette.star,
    think: CalmBluePalette.think,
    commit: CalmBluePalette.commit,
    care: CalmBluePalette.care,
    water: CalmBluePalette.water,
    money: CalmBluePalette.money,
    zones: {
      HomeZone.now: CalmBluePalette.zoneNow,
      HomeZone.plan: CalmBluePalette.zonePlan,
      HomeZone.keep: CalmBluePalette.zoneKeep,
      HomeZone.mind: CalmBluePalette.zoneMind,
      HomeZone.care: CalmBluePalette.zoneCare,
      HomeZone.money: CalmBluePalette.zoneMoney,
      HomeZone.more: CalmBluePalette.zoneMore,
    },
  );

  static const dark = AscentTokens(
    canvas: CalmBluePalette.darkCanvas,
    surface: CalmBluePalette.darkSurface,
    raised: CalmBluePalette.darkElevated,
    recessed: CalmBluePalette.darkRecessed,
    separator: CalmBluePalette.darkSeparator,
    label: CalmBluePalette.darkLabel,
    labelSecondary: CalmBluePalette.darkLabelSecondary,
    labelTertiary: CalmBluePalette.darkLabelTertiary,
    action: CalmBluePalette.darkAction,
    actionFill: CalmBluePalette.darkActionFill,
    onAction: CalmBluePalette.onAction,
    actionTint: CalmBluePalette.darkActionTint,
    success: CalmBluePalette.darkSuccess,
    warning: CalmBluePalette.darkWarning,
    danger: CalmBluePalette.darkDanger,
    star: CalmBluePalette.darkStar,
    think: CalmBluePalette.darkThink,
    commit: CalmBluePalette.darkCommit,
    care: CalmBluePalette.darkCare,
    water: CalmBluePalette.darkWater,
    money: CalmBluePalette.darkMoney,
    zones: {
      HomeZone.now: CalmBluePalette.darkZoneNow,
      HomeZone.plan: CalmBluePalette.darkZonePlan,
      HomeZone.keep: CalmBluePalette.darkZoneKeep,
      HomeZone.mind: CalmBluePalette.darkZoneMind,
      HomeZone.care: CalmBluePalette.darkZoneCare,
      HomeZone.money: CalmBluePalette.darkZoneMoney,
      HomeZone.more: CalmBluePalette.darkZoneMore,
    },
  );

  @override
  AscentTokens copyWith({Color? canvas, Color? surface, Color? raised}) =>
      AscentTokens(
        canvas: canvas ?? this.canvas,
        surface: surface ?? this.surface,
        raised: raised ?? this.raised,
        recessed: recessed,
        separator: separator,
        label: label,
        labelSecondary: labelSecondary,
        labelTertiary: labelTertiary,
        action: action,
        actionFill: actionFill,
        onAction: onAction,
        actionTint: actionTint,
        success: success,
        warning: warning,
        danger: danger,
        star: star,
        think: think,
        commit: commit,
        care: care,
        water: water,
        money: money,
        zones: zones,
      );

  /// Every colour fades smoothly; nothing snaps halfway through a theme
  /// switch.
  @override
  AscentTokens lerp(covariant ThemeExtension<AscentTokens>? other, double t) {
    if (other is! AscentTokens) return this;
    Color c(Color a, Color b) => Color.lerp(a, b, t)!;
    return AscentTokens(
      canvas: c(canvas, other.canvas),
      surface: c(surface, other.surface),
      raised: c(raised, other.raised),
      recessed: c(recessed, other.recessed),
      separator: c(separator, other.separator),
      label: c(label, other.label),
      labelSecondary: c(labelSecondary, other.labelSecondary),
      labelTertiary: c(labelTertiary, other.labelTertiary),
      action: c(action, other.action),
      actionFill: c(actionFill, other.actionFill),
      onAction: c(onAction, other.onAction),
      actionTint: c(actionTint, other.actionTint),
      success: c(success, other.success),
      warning: c(warning, other.warning),
      danger: c(danger, other.danger),
      star: c(star, other.star),
      think: c(think, other.think),
      commit: c(commit, other.commit),
      care: c(care, other.care),
      water: c(water, other.water),
      money: c(money, other.money),
      zones: {
        for (final z in HomeZone.values) z: c(zones[z]!, other.zones[z]!),
      },
    );
  }
}

extension AscentTokensContext on BuildContext {
  /// The Day Page colour roles for the current theme.
  AscentTokens get tokens {
    final theme = Theme.of(this);
    return theme.extension<AscentTokens>() ??
        (theme.brightness == Brightness.dark
            ? AscentTokens.dark
            : AscentTokens.light);
  }
}
