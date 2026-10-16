import 'package:flutter/material.dart';
import 'color_tokens.dart';
import 'dimension_tokens.dart';
import 'glass_theme.dart';
import 'frozen_palette.dart';

enum AppSurfaceRole {
  card,
  pill,
  tag,
  avatar,
  primary,
  divider,
  progressTrack,
  progressFill,
  indicator,
}

/// Semantic surfaces. Only this layer resolves day versus glass presentation.
class AppSurfaces extends ThemeExtension<AppSurfaces> {
  const AppSurfaces({
    required this.outlined,
    required this.ink,
    required this.mutedText,
    required this.accent,
    required this.greenAction,
    required this.cardFill,
    required this.cardBorderColor,
    required this.pillBorderColor,
    required this.dividerColor,
    required this.tintFill,
    required this.tintBorder,
    required this.onAccent,
    required this.cardBorderWidth,
    required this.pillBorderWidth,
    required this.shadow,
    required this.blur,
  });
  final bool outlined;
  final Color ink,
      mutedText,
      accent,
      greenAction,
      cardFill,
      cardBorderColor,
      pillBorderColor,
      dividerColor,
      tintFill,
      tintBorder,
      onAccent,
      shadow;
  final double cardBorderWidth, pillBorderWidth, blur;
  Color get playerBackdrop =>
      outlined ? AscentGlass.light.bg : Colors.transparent;

  double get dividerWidth => 1;
  double get cardRadius => AscentDimensions.radiusXxl;
  double get pillRadius => AscentDimensions.radiusFull;
  double get tagRadius => AscentDimensions.radiusSm;
  double get spacing => AscentDimensions.spaceSm;
  double get padding => AscentDimensions.spaceLg;
  double get minTapTarget => AscentDimensions.minTouchTarget;
  static const day = AppSurfaces(
    outlined: true,
    ink: Color(0xFF2A1F1C),
    mutedText: Color(0xFF6E625E),
    accent: Color(0xFFB8634D),
    greenAction: AscentColors.accentPrimary,
    cardFill: Colors.transparent,
    cardBorderColor: Color(0xFF2A1F1C),
    pillBorderColor: Color(0xFF2A1F1C),
    dividerColor: Color(0x332A1F1C),
    tintFill: Color(0x24B8634D),
    tintBorder: Color(0x4DB8634D),
    onAccent: Colors.white,
    cardBorderWidth: 1.5,
    pillBorderWidth: 1,
    shadow: Colors.transparent,
    blur: 0,
  );

  /// Preserve the pre-migration light decorations at existing call sites.
  static final legacyLight = night.copyWith(
    ink: AscentGlass.light.ink,
    mutedText: AscentGlass.light.inkMuted,
    accent: AscentGlass.light.clay,
    greenAction: AscentColors.accentPrimary,
    cardFill: AscentGlass.light.fill,
    cardBorderColor: AscentGlass.light.edge,
    pillBorderColor: AscentGlass.light.edge,
    dividerColor: AscentGlass.light.line,
    tintFill: AscentGlass.light.claySoft,
    tintBorder: AscentGlass.light.clay.withValues(alpha: .25),
    shadow: AscentGlass.light.shadow,
  );

  static const nordicSky = AppSurfaces(
    outlined: true,
    ink: FrozenPalette.ink,
    mutedText: FrozenPalette.mutedInk,
    accent: FrozenPalette.accent,
    greenAction: FrozenPalette.success,
    cardFill: Colors.transparent,
    cardBorderColor: FrozenPalette.line,
    pillBorderColor: FrozenPalette.line,
    dividerColor: Color(0x33465B64),
    tintFill: FrozenPalette.aqua,
    tintBorder: Color(0x4D465B64),
    onAccent: Colors.white,
    cardBorderWidth: 1.5,
    pillBorderWidth: 1,
    shadow: Colors.transparent,
    blur: 0,
  );

  static final legacyNordicSky = night.copyWith(
    ink: AscentGlass.nordicSky.ink,
    mutedText: AscentGlass.nordicSky.inkMuted,
    accent: AscentGlass.nordicSky.slate,
    greenAction: FrozenPalette.success,
    cardFill: AscentGlass.nordicSky.fill,
    cardBorderColor: AscentGlass.nordicSky.edge,
    pillBorderColor: AscentGlass.nordicSky.edge,
    dividerColor: AscentGlass.nordicSky.line,
    tintFill: AscentGlass.nordicSky.slateSoft,
    tintBorder: AscentGlass.nordicSky.slate.withValues(alpha: .25),
    shadow: AscentGlass.nordicSky.shadow,
    blur: 12,
  );

  static final night = AppSurfaces(
    outlined: false,
    ink: AscentGlass.dark.ink,
    mutedText: AscentGlass.dark.inkMuted,
    accent: AscentGlass.dark.clay,
    greenAction: AscentColors.accentPrimaryDark,
    cardFill: AscentGlass.dark.fill,
    cardBorderColor: AscentGlass.dark.edge,
    pillBorderColor: AscentGlass.dark.edge,
    dividerColor: AscentGlass.dark.line,
    tintFill: AscentGlass.dark.claySoft,
    tintBorder: AscentGlass.dark.clay.withValues(alpha: .25),
    onAccent: Colors.white,
    cardBorderWidth: .9,
    pillBorderWidth: 1,
    shadow: AscentGlass.dark.shadow,
    blur: 22,
  );

  Color? contentForeground(bool selected, Color? previous) =>
      outlined && selected ? onAccent : previous;

  Color pillForeground(bool selected, Color glassColor) =>
      outlined ? (selected ? onAccent : ink) : glassColor;

  Border get cardBorder =>
      Border.all(color: cardBorderColor, width: cardBorderWidth);
  Border get pillBorder =>
      Border.all(color: pillBorderColor, width: pillBorderWidth);

  BoxDecoration decoration(
    AppSurfaceRole role, {
    BoxDecoration? night,
    bool selected = false,
    BorderRadiusGeometry? radius,
  }) {
    if (!outlined && night != null) return night;
    final r =
        radius ??
        (role == AppSurfaceRole.pill
            ? BorderRadius.circular(pillRadius)
            : role == AppSurfaceRole.tag
            ? BorderRadius.circular(tagRadius)
            : night?.borderRadius ?? BorderRadius.circular(cardRadius));
    if (role == AppSurfaceRole.progressTrack ||
        role == AppSurfaceRole.progressFill ||
        role == AppSurfaceRole.indicator) {
      return BoxDecoration(
        color: selected
            ? accent
            : role == AppSurfaceRole.progressTrack
            ? ink.withValues(alpha: .1)
            : night?.color ?? accent,
        borderRadius: night?.shape == BoxShape.circle ? null : r,
        shape: night?.shape ?? BoxShape.rectangle,
      );
    }
    if (role == AppSurfaceRole.divider) {
      return BoxDecoration(color: dividerColor);
    }
    if (role == AppSurfaceRole.avatar ||
        (role == AppSurfaceRole.tag && night?.shape == BoxShape.circle)) {
      return BoxDecoration(
        color: tintFill,
        shape: night?.shape ?? BoxShape.circle,
      );
    }
    final primary = selected || role == AppSurfaceRole.primary;
    return BoxDecoration(
      color: primary
          ? accent
          : role == AppSurfaceRole.tag
          ? tintFill
          : cardFill,
      borderRadius: night?.shape == BoxShape.circle ? null : r,
      shape: night?.shape ?? BoxShape.rectangle,
      border: primary
          ? null
          : role == AppSurfaceRole.tag
          ? Border.all(color: tintBorder, width: pillBorderWidth)
          : role == AppSurfaceRole.pill
          ? pillBorder
          : cardBorder,
    );
  }

  ButtonStyle buttonStyle(
    ButtonStyle original, {
    bool filled = false,
    bool icon = false,
  }) {
    if (!outlined) return original;
    return original.copyWith(
      backgroundColor: WidgetStatePropertyAll(filled ? accent : cardFill),
      foregroundColor: WidgetStatePropertyAll(filled ? onAccent : ink),
      side: WidgetStatePropertyAll(
        filled
            ? BorderSide.none
            : BorderSide(color: pillBorderColor, width: pillBorderWidth),
      ),
      shape: WidgetStatePropertyAll(
        icon
            ? const CircleBorder()
            : RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(pillRadius),
              ),
      ),
      shadowColor: const WidgetStatePropertyAll(Colors.transparent),
      elevation: const WidgetStatePropertyAll(0),
      minimumSize: WidgetStatePropertyAll(Size(minTapTarget, minTapTarget)),
      tapTargetSize: MaterialTapTargetSize.padded,
    );
  }

  @override
  AppSurfaces copyWith({
    bool? outlined,
    Color? ink,
    Color? mutedText,
    Color? accent,
    Color? greenAction,
    Color? cardFill,
    Color? cardBorderColor,
    Color? pillBorderColor,
    Color? dividerColor,
    Color? tintFill,
    Color? tintBorder,
    Color? onAccent,
    double? cardBorderWidth,
    double? pillBorderWidth,
    Color? shadow,
    double? blur,
  }) => AppSurfaces(
    outlined: outlined ?? this.outlined,
    ink: ink ?? this.ink,
    mutedText: mutedText ?? this.mutedText,
    accent: accent ?? this.accent,
    greenAction: greenAction ?? this.greenAction,
    cardFill: cardFill ?? this.cardFill,
    cardBorderColor: cardBorderColor ?? this.cardBorderColor,
    pillBorderColor: pillBorderColor ?? this.pillBorderColor,
    dividerColor: dividerColor ?? this.dividerColor,
    tintFill: tintFill ?? this.tintFill,
    tintBorder: tintBorder ?? this.tintBorder,
    onAccent: onAccent ?? this.onAccent,
    cardBorderWidth: cardBorderWidth ?? this.cardBorderWidth,
    pillBorderWidth: pillBorderWidth ?? this.pillBorderWidth,
    shadow: shadow ?? this.shadow,
    blur: blur ?? this.blur,
  );
  @override
  AppSurfaces lerp(covariant AppSurfaces? other, double t) {
    if (other == null) return this;
    Color mix(Color a, Color b) => Color.lerp(a, b, t)!;
    return AppSurfaces(
      outlined: t < .5 ? outlined : other.outlined,
      ink: mix(ink, other.ink),
      mutedText: mix(mutedText, other.mutedText),
      accent: mix(accent, other.accent),
      greenAction: mix(greenAction, other.greenAction),
      cardFill: mix(cardFill, other.cardFill),
      cardBorderColor: mix(cardBorderColor, other.cardBorderColor),
      pillBorderColor: mix(pillBorderColor, other.pillBorderColor),
      dividerColor: mix(dividerColor, other.dividerColor),
      tintFill: mix(tintFill, other.tintFill),
      tintBorder: mix(tintBorder, other.tintBorder),
      onAccent: mix(onAccent, other.onAccent),
      shadow: mix(shadow, other.shadow),
      cardBorderWidth:
          cardBorderWidth + (other.cardBorderWidth - cardBorderWidth) * t,
      pillBorderWidth:
          pillBorderWidth + (other.pillBorderWidth - pillBorderWidth) * t,
      blur: blur + (other.blur - blur) * t,
    );
  }
}

extension AppSurfacesContext on BuildContext {
  AppSurfaces get surfaces =>
      Theme.of(this).extension<AppSurfaces>() ??
      (Theme.of(this).brightness == Brightness.dark
          ? AppSurfaces.night
          : AppSurfaces.legacyLight);
}

/// Existing night geometry and palette, shared by all presentation roles.
class AppPalette {
  static const green = Colors.green;
  static const deepOrange = Colors.deepOrange;
  static const deepOrangeAccent = Colors.deepOrangeAccent;
  static const amberAccent = Colors.amberAccent;
  static const white10 = Colors.white10;
  static const white12 = Colors.white12;
  static const amber = Colors.amber;
  static const orange = Colors.orange;
  static const black26 = Colors.black26;
  static const white70 = Colors.white70;
  static const white60 = Colors.white60;
  static const white54 = Colors.white54;
  static const grey = Colors.grey;
  static const black = Colors.black;
  static const red = Colors.red;
  static const white = Colors.white;
  static const redAccent = Colors.redAccent;
  static const transparent = Colors.transparent;
  AppPalette._();
  static const colorFF201A14 = Color(0XFF201A14);
  static const colorFFF7F6F2 = Color(0XFFF7F6F2);
  static const colorFF4E9B6B = Color(0XFF4E9B6B);
  static const colorFFD99A37 = Color(0XFFD99A37);
  static const colorFFCA5C54 = Color(0XFFCA5C54);
  static const colorFFFBF0D9 = Color(0XFFFBF0D9);
  static const colorFF2C2523 = Color(0XFF2C2523);
  static const colorFFD6C8AC = Color(0XFFD6C8AC);
  static const colorFF121212 = Color(0XFF121212);
  static const colorFFE2E8F0 = Color(0XFFE2E8F0);
  static const colorFF2A2A2A = Color(0XFF2A2A2A);
  static const colorFFFFFFFF = Color(0XFFFFFFFF);
  static const colorFF1A1A1A = Color(0XFF1A1A1A);
  static const colorFFE5E7EB = Color(0XFFE5E7EB);
  static const colorFF162019 = Color(0XFF162019);
  static const colorFFD1E7DD = Color(0XFFD1E7DD);
  static const colorFF26382C = Color(0XFF26382C);
  static const colorFFF9AB67 = Color(0XFFF9AB67);
  static const colorFF6B3A1C = Color(0XFF6B3A1C);
  static const colorFFE28B57 = Color(0XFFE28B57);
  static const colorFF322922 = Color(0XFF322922);
  static const colorFF160F09 = Color(0XFF160F09);
  static const colorFF2A1C0F = Color(0XFF2A1C0F);
  static const colorFFF8FAFC = Color(0XFFF8FAFC);
  static const colorFFEFF6FF = Color(0XFFEFF6FF);
  static const colorFF6E8565 = Color(0XFF6E8565);
  static const colorFF10B981 = Color(0XFF10B981);
  static const colorFFF89238 = Color(0XFFF89238);
  static const colorFF22C55E = Color(0XFF22C55E);
  static const colorFFD97706 = Color(0XFFD97706);
  static const colorFF34D399 = Color(0XFF34D399);
  static const colorFF059669 = Color(0XFF059669);
  static const colorFF1D1610 = Color(0XFF1D1610);
  static const colorFFB46824 = Color(0XFFB46824);
  static const colorFF8B6A4F = Color(0XFF8B6A4F);
  static const colorFF16A34A = Color(0XFF16A34A);
  static const colorFFEA580C = Color(0XFFEA580C);
  static const colorFFEC8C38 = Color(0XFFEC8C38);
  static const colorFFE79D5C = Color(0XFFE79D5C);
  static const colorFF26201A = Color(0XFF26201A);
  static const colorFF1E1914 = Color(0XFF1E1914);
  static const colorFF221D18 = Color(0XFF221D18);
  static const colorFFF59E0B = Color(0XFFF59E0B);
  static const colorFF3B2C1E = Color(0XFF3B2C1E);
  static const colorFF5FA070 = Color(0XFF5FA070);
  static const colorFF2D251E = Color(0XFF2D251E);
  static const colorFF372D25 = Color(0XFF372D25);
  static const colorFFEFEDE9 = Color(0XFFEFEDE9);
  static const colorFF45392E = Color(0XFF45392E);
  static const colorFFFBF9F6 = Color(0XFFFBF9F6);
}

class AppGeometry {
  AppGeometry._();
  static Radius bubbleTail(bool tail) => tail ? radiusr4 : radiusr18;
  static const radiusr2 = Radius.circular(2);
  static const roundedr2 = BorderRadius.all(radiusr2);
  static const radiusr3 = Radius.circular(3);
  static const roundedr3 = BorderRadius.all(radiusr3);
  static const radiusr4 = Radius.circular(4);
  static const roundedr4 = BorderRadius.all(radiusr4);
  static const radiusr5 = Radius.circular(5);
  static const roundedr5 = BorderRadius.all(radiusr5);
  static const radiusr6 = Radius.circular(6);
  static const roundedr6 = BorderRadius.all(radiusr6);
  static const radiusr7 = Radius.circular(7);
  static const roundedr7 = BorderRadius.all(radiusr7);
  static const radiusr8 = Radius.circular(8);
  static const roundedr8 = BorderRadius.all(radiusr8);
  static const radiusr9 = Radius.circular(9);
  static const roundedr9 = BorderRadius.all(radiusr9);
  static const radiusr10 = Radius.circular(10);
  static const roundedr10 = BorderRadius.all(radiusr10);
  static const radiusr11 = Radius.circular(11);
  static const roundedr11 = BorderRadius.all(radiusr11);
  static const radiusr12 = Radius.circular(12);
  static const roundedr12 = BorderRadius.all(radiusr12);
  static const radiusr14 = Radius.circular(14);
  static const roundedr14 = BorderRadius.all(radiusr14);
  static const radiusr16 = Radius.circular(16);
  static const roundedr16 = BorderRadius.all(radiusr16);
  static const radiusr18 = Radius.circular(18);
  static const roundedr18 = BorderRadius.all(radiusr18);
  static const radiusr20 = Radius.circular(20);
  static const roundedr20 = BorderRadius.all(radiusr20);
  static const radiusr22 = Radius.circular(22);
  static const roundedr22 = BorderRadius.all(radiusr22);
  static const radiusr24 = Radius.circular(24);
  static const roundedr24 = BorderRadius.all(radiusr24);
  static const radiusr26 = Radius.circular(26);
  static const roundedr26 = BorderRadius.all(radiusr26);
  static const radiusr28 = Radius.circular(28);
  static const roundedr28 = BorderRadius.all(radiusr28);
  static const radiusr30 = Radius.circular(30);
  static const roundedr30 = BorderRadius.all(radiusr30);
  static const radiusr40 = Radius.circular(40);
  static const roundedr40 = BorderRadius.all(radiusr40);
  static const radiusr99 = Radius.circular(99);
  static const roundedr99 = BorderRadius.all(radiusr99);
}

class AppBorderScale {
  AppBorderScale._();
  static const double w0point6 = 0.6;
  static const double w0point8 = 0.8;
  static const double w0point9 = 0.9;
  static const double w1point0 = 1.0;
  static const double w1 = 1;
  static const double w1point1 = 1.1;
  static const double w1point2 = 1.2;
  static const double w1point5 = 1.5;
  static const double w1point75 = 1.75;
  static const double w1point8 = 1.8;
  static const double w2 = 2;
  static const double w2point5 = 2.5;
}

class AppSpace {
  AppSpace._();
  static const double s0 = 0;
  static const double s1 = 1;
  static const double s1point5 = 1.5;
  static const double s2 = 2;
  static const double s2point5 = 2.5;
  static const double s3 = 3;
  static const double s3point5 = 3.5;
  static const double s4point0 = 4.0;
  static const double s4 = 4;
  static const double s5 = 5;
  static const double s6 = 6;
  static const double s7 = 7;
  static const double s8 = 8;
  static const double s8point0 = 8.0;
  static const double s9 = 9;
  static const double s10 = 10;
  static const double s11 = 11;
  static const double s12 = 12;
  static const double s13 = 13;
  static const double s14 = 14;
  static const double s16point0 = 16.0;
  static const double s16 = 16;
  static const double s18 = 18;
  static const double s20 = 20;
  static const double s22 = 22;
  static const double s24point0 = 24.0;
  static const double s24 = 24;
  static const double s26 = 26;
  static const double s28 = 28;
  static const double s32 = 32;
  static const double s36 = 36;
  static const double s38point0 = 38.0;
  static const double s40 = 40;
  static const double s60 = 60;
  static const double s68 = 68;
  static const double s74 = 74;
  static const double s80 = 80;
  static const double s90 = 90;
  static const double s96 = 96;
  static const double s250 = 250;
}
