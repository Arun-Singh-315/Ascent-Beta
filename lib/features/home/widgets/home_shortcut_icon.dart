import 'package:flutter/material.dart';
import '../../../app/theme/shared_control_tokens.dart';
import 'home_day_design.dart';

/// The same transparent outlined icon treatment in the hub and its editor.
class HomeShortcutIcon extends StatelessWidget {
  const HomeShortcutIcon({
    super.key,
    required this.icon,
    this.selected = false,
    this.size = 44,
  });
  final IconData icon;
  final bool selected;
  final double size;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = HomeDayDesign.ink(dark);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.transparent,
        shape: BoxShape.circle,
        border: Border.all(
          color: selected
              ? (dark
                    ? SharedControlColors.actionBlueDark
                    : SharedControlColors.actionBlue)
              : ink.withValues(alpha: .36),
          width: selected ? 1.4 : .85,
        ),
      ),
      child: Icon(
        icon,
        size: size * .49,
        color: selected
            ? (dark
                  ? SharedControlColors.actionBlueDark
                  : SharedControlColors.actionBlue)
            : ink,
      ),
    );
  }
}
