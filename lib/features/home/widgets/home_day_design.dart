import 'package:flutter/material.dart';

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
        Color(0xFFDDEDF8),
        Color(0xFFFFF2DE),
        .58,
      ),
      >= 12 && < 17 => const HomeDayDesign(
        'Good afternoon,',
        'Make room for a little reset.',
        Color(0xFFE5F0F5),
        Color(0xFFF8F0DF),
        .85,
      ),
      >= 17 && < 21 => const HomeDayDesign(
        'Good evening,',
        'Close the day at your pace.',
        Color(0xFFE6E1F3),
        Color(0xFFFBE7DF),
        .14,
      ),
      _ => const HomeDayDesign(
        'Good night,',
        'Keep a little room for tomorrow.',
        Color(0xFFE3E7F1),
        Color(0xFFF1ECF7),
        .05,
      ),
    };
    if (!dark) return design;
    return HomeDayDesign(
      design.greeting,
      design.cue,
      Color.lerp(const Color(0xFF141A24), design.sky, .10)!,
      Color.lerp(const Color(0xFF1B202B), design.light, .07)!,
      design.sunHeight,
    );
  }

  static Color canvas(bool dark) =>
      dark ? const Color(0xFF171C24) : const Color(0xFFFFFCF8);
  static Color ink(bool dark) =>
      dark ? const Color(0xFFF1F3F7) : const Color(0xFF20232A);
  static Color secondary(bool dark) =>
      dark ? const Color(0xFFBCC4D0) : const Color(0xFF5D626A);
  static Color line(bool dark) => ink(dark).withValues(alpha: dark ? .18 : .16);
}

class HomeDayBackground extends StatelessWidget {
  const HomeDayBackground({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: dark
              ? [HomeDayDesign.canvas(true), const Color(0xFF1C222B)]
              : [
                  HomeDayDesign.canvas(false),
                  const Color(0xFFF8F6F1),
                  const Color(0xFFF2F6F3),
                ],
        ),
      ),
      child: child,
    );
  }
}
