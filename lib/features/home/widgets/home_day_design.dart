import 'package:flutter/material.dart';
import '../../../app/theme/monochrome_surfaces.dart';
import '../../../app/theme/home_design.dart';

/// Shared atmosphere for Home's header, working surface and quieter lower area.
class HomeDayDesign {
  const HomeDayDesign(
    this.greeting,
    this.cue,
    this.sky,
    this.light,
    this.sunHeight,
  );
  final String greeting, cue;
  final Color sky, light;
  final double sunHeight;

  static HomeDayDesign at(DateTime now, {bool dark = false}) {
    final design = switch (now.hour) {
      >= 5 && < 12 => const HomeDayDesign(
        'Good morning,',
        'A little space to begin.',
        Color(0xFFADDDF8),
        Color(0xFFFFE8B5),
        .58,
      ),
      >= 12 && < 17 => const HomeDayDesign(
        'Good afternoon,',
        'Make room for a little reset.',
        Color(0xFF9EDBF3),
        Color(0xFFFFF0C7),
        .85,
      ),
      >= 17 && < 21 => const HomeDayDesign(
        'Good evening,',
        'Close the day at your pace.',
        Color(0xFFC8B5F1),
        Color(0xFFFFCDB5),
        .14,
      ),
      _ => const HomeDayDesign(
        'Good night,',
        'Keep a little room for tomorrow.',
        Color(0xFFB7C7EE),
        Color(0xFFD9CEF5),
        .05,
      ),
    };
    if (!dark) return design;
    final (sky, light) = switch (now.hour) {
      >= 5 && < 12 => (const Color(0xFF284F75), const Color(0xFF65533F)),
      >= 12 && < 17 => (const Color(0xFF215B79), const Color(0xFF476477)),
      >= 17 && < 21 => (const Color(0xFF55416F), const Color(0xFF79534E)),
      _ => (const Color(0xFF304B78), const Color(0xFF524876)),
    };
    return HomeDayDesign(
      design.greeting,
      design.cue,
      sky,
      light,
      design.sunHeight,
    );
  }

  static MonochromeSurfaces _neutral(bool dark) =>
      dark ? const MonochromeSurfaces.dark() : const MonochromeSurfaces.light();
  static Color canvas(bool dark) => dark ? _neutral(dark).canvas : Colors.white;
  static Color ink(bool dark) => _neutral(dark).primaryText;
  static Color secondary(bool dark) => _neutral(dark).secondaryText;
  static Color line(bool dark) => _neutral(dark).separator;
}

class HomeDayBackground extends StatelessWidget {
  const HomeDayBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(color: HomeDesign.of(context).canvas),
      child: child,
    );
  }
}
