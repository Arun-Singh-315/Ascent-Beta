import 'package:flutter/material.dart';
import '../../../app/theme/home_design.dart';
import '../../../app/theme/shared_control_tokens.dart';

/// The same transparent outlined icon treatment in the hub and its editor.
class HomeShortcutIcon extends StatelessWidget {
  const HomeShortcutIcon({
    super.key,
    required this.icon,
    this.selected = false,
    this.size = 44,
    this.framed = true,
    this.identity,
  });
  final IconData icon;
  final bool selected;
  final bool framed;
  final String? identity;
  final double size;

  /// Returns the vivid ink color associated with a shortcut identity.
  static Color inkFor(String id, BuildContext context) {
    final design = HomeDesign.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return switch (id) {
      'hydration' || 'walk' || 'medicine' || 'chai-break' => design.wellnessInk,
      'assistant' || 'thought-wall' || 'mind' =>
        isDark ? const Color(0xFFC084FC) : const Color(0xFF7C3AED),
      'learning' || 'momentum' || 'promises' => design.learningInk,
      'vault' => isDark ? const Color(0xFF94A3B8) : const Color(0xFF1E293B),
      _ => isDark ? SharedControlColors.actionBlueDark : SharedControlColors.actionBlue,
    };
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final design = HomeDesign.of(context);
    final accentInk = identity != null
        ? inkFor(identity!, context)
        : HomeShortcutStyle.ink(context);

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: identity == null
            ? Colors.transparent
            : (selected
                ? (isDark
                    ? SharedControlColors.actionBlueDark.withValues(alpha: 0.22)
                    : SharedControlColors.actionBlue.withValues(alpha: 0.14))
                : (isDark
                    ? const Color(0xFF1E293B).withValues(alpha: 0.5)
                    : Colors.white.withValues(alpha: 0.85))),
        shape: BoxShape.circle,
        border: !framed
            ? null
            : Border.all(
                color: selected
                    ? (isDark
                          ? SharedControlColors.actionBlueDark
                          : SharedControlColors.actionBlue)
                    : (identity != null
                        ? accentInk.withValues(alpha: isDark ? 0.55 : 0.4)
                        : design.separator),
                width: selected ? 1.5 : 1.1,
              ),
        boxShadow: identity == null || isDark
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.03),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Icon(
        icon,
        size: size * .44,
        color: selected
            ? (isDark
                  ? SharedControlColors.actionBlueDark
                  : SharedControlColors.actionBlue)
            : accentInk,
      ),
    );
  }
}

/// The shortcut enclosure, glyphs and values share a neutral, high-contrast treatment.
abstract final class HomeShortcutStyle {
  static Color ink(BuildContext context) => HomeDesign.of(context).primaryText;
  static Color border(BuildContext context) => HomeDesign.of(context).separator;
  static Color badgeFill(BuildContext context) =>
      HomeDesign.of(context).elevated;
}
