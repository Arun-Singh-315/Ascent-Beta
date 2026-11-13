import 'package:flutter/material.dart';
import 'shared_control_tokens.dart';
import 'text_styles.dart';
import 'monochrome_surfaces.dart';

/// Home's mineral/day and ink/night art direction. Accent washes identify a
/// module; blue and red retain their shared interaction and semantic meanings.
class HomeDesign extends ThemeExtension<HomeDesign> {
  const HomeDesign.day() : darkness = 0;
  const HomeDesign.night() : darkness = 1;
  const HomeDesign._(this.darkness);
  final double darkness;

  static HomeDesign of(BuildContext context) =>
      Theme.of(context).extension<HomeDesign>() ??
      (Theme.of(context).brightness == Brightness.dark
          ? const HomeDesign.night()
          : const HomeDesign.day());

  Color _tone(int day, int night) =>
      Color.lerp(Color(day), Color(night), darkness)!;
  Color get canvas => _tone(0xFFFFFFFF, 0xFF111418);
  Color get surface => _tone(0xFFFFFFFF, 0xFF111418);
  Color get elevated => _tone(0xFFFFFFFF, 0xFF1C2027);
  Color get primaryText => _tone(0xFF101318, 0xFFF1F3F7);
  Color get secondaryText => _tone(0xFF657080, 0xFFA9B1BF);
  Color get tertiaryText => _tone(0xFF6B7B8B, 0xFF8CA0B5);
  Color get separator => _tone(0xFFD9E1E8, 0xFF34465A);
  Color get controlOutline => _tone(0xFF7A8998, 0xFF829AB2);
  Color get groupedFill => _tone(0xFFE8EDF2, 0xFF26384B);
  Color get heroStart => canvas;
  Color get heroEnd => canvas;
  Color get workTint => _tone(0xFFEAF2FD, 0xFF203A53);
  Color get workEdge => _tone(0xFFB7CEE8, 0xFF3A5878);
  Color get mindTint => _tone(0xFFEEEBF7, 0xFF28283E);
  Color get mindEdge => _tone(0xFFBEB6D8, 0xFF665C86);
  Color get wellnessTint => _tone(0xFFE3F1EF, 0xFF193638);
  Color get wellnessEnd => _tone(0xFFF1F7F3, 0xFF172C34);
  Color get wellnessInk => _tone(0xFF356B68, 0xFF9CCFC6);
  Color get wellnessEdge => _tone(0xFFB2D5CE, 0xFF3D6665);
  Color get learningTint => _tone(0xFFF5EDDF, 0xFF352F29);
  Color get learningInk => _tone(0xFF86643D, 0xFFD5B68A);
  Color get mindInk => _tone(0xFF7050B6, 0xFFC2A5F5);
  Color get strongSurface => _tone(0xFF101318, 0xFFF1F3F7);
  Color get onStrong => _tone(0xFFFFFFFF, 0xFF111418);
  Color get shadow => _tone(0x0A1B344D, 0x24000000);
  Color get moonStart => _tone(0xFF627FA9, 0xFFF2F6FF);
  Color get moonEnd => _tone(0xFF9AB3D2, 0xFFB7D2F4);
  Color get moonGlow => _tone(0xFFB0C5E0, 0xFF9FBEEA);
  Color get stars => _tone(0xFF718CB1, 0xFFC2D7F2);
  Color get solarGlow => _tone(0xFFFFCE78, 0xFFE9BC86);
  Color get solarStart => _tone(0xFFFFF4CF, 0xFFFFE9BC);
  Color get solarEnd => _tone(0xFFF1B350, 0xFFE4AE6C);
  Color get sunsetStart => _tone(0xFFFFDAA0, 0xFFFFD0A0);
  Color get sunsetEnd => _tone(0xFFEE916B, 0xFFDA976E);
  Color get solarRay => _tone(0xFFB17B32, 0xFFFFD99B);
  Color get horizon => _tone(0xFF9F795A, 0xFFFFE1BB);
  Color get action => Color.lerp(
    SharedControlColors.actionBlueInkLight,
    SharedControlColors.actionBlueDark,
    darkness,
  )!;

  Color tintFor(String id) => switch (id) {
    'hydration' || 'walk' || 'medicine' || 'chai-break' => wellnessTint,
    'assistant' || 'thought-wall' || 'mind' => mindTint,
    'learning' || 'momentum' || 'promises' => learningTint,
    _ => workTint,
  };

  LinearGradient get atmosphere => LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [heroStart, heroEnd, canvas],
    stops: const [0, .45, 1],
  );
  LinearGradient get wellness => LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [wellnessTint, wellnessEnd],
  );

  @override
  HomeDesign copyWith({double? darkness}) =>
      HomeDesign._(darkness ?? this.darkness);
  @override
  HomeDesign lerp(HomeDesign? other, double t) => other == null
      ? this
      : HomeDesign._(darkness + (other.darkness - darkness) * t);
}

/// Adapts Home's materials to existing shared buttons, date cells and controls.
/// Other app themes keep their existing neutral recipes.
class HomeControlSurfaces extends MonochromeSurfaces {
  HomeControlSurfaces(this.design) : super.level(design.darkness);
  final HomeDesign design;
  @override
  Color get canvas => design.canvas;
  @override
  Color get surface => design.surface;
  @override
  Color get elevated => design.elevated;
  @override
  Color get groupedFill => design.groupedFill;
  @override
  Color get primaryText => design.primaryText;
  @override
  Color get secondaryText => design.secondaryText;
  @override
  Color get tertiaryText => design.tertiaryText;
  @override
  Color get separator => design.separator;
  @override
  Color get controlOutline => design.controlOutline;
  @override
  Color get neutralSelection => design.workTint;
  @override
  Color get pressedFill => design.groupedFill;
  @override
  Color get disabledText => design.tertiaryText;
  @override
  HomeControlSurfaces copyWith({double? darkness}) =>
      HomeControlSurfaces(design.copyWith(darkness: darkness));
  @override
  MonochromeSurfaces lerp(MonochromeSurfaces? other, double t) =>
      other is HomeControlSurfaces
      ? HomeControlSurfaces(design.lerp(other.design, t))
      : super.lerp(other, t);
}

abstract final class HomeType {
  static TextStyle get greeting =>
      AscentTextStyles.interfaceSupporting.copyWith(fontSize: 14);
  static TextStyle get title => AscentTextStyles.homeTitle.copyWith(
    fontSize: 28,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: -.8,
  );
  static TextStyle get section => AscentTextStyles.interfaceTitle.copyWith(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    letterSpacing: -.4,
  );
  static TextStyle get metric => AscentTextStyles.interfaceDisplay.copyWith(
    fontSize: 44,
    fontWeight: FontWeight.w500,
    letterSpacing: -1.5,
    fontFeatures: const [FontFeature.tabularFigures()],
  );
  static TextStyle get label => AscentTextStyles.interfaceLabel.copyWith(
    fontSize: 11,
    fontWeight: FontWeight.w600,
    letterSpacing: 1.2,
  );
  static TextStyle get supporting =>
      AscentTextStyles.interfaceSupporting.copyWith(fontSize: 13, height: 1.45);
}
