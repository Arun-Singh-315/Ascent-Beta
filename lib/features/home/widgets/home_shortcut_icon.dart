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
        isDark ? const Color(0xFFB8A6E0) : const Color(0xFF5E4B9E),
      'learning' || 'momentum' || 'promises' => design.learningInk,
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
    final tintColor = identity != null ? design.tintFor(identity!) : Colors.transparent;
    final tintWithOpacity = Color.alphaBlend(
      tintColor.withValues(alpha: isDark ? 0.0 : 0.0),
      tintColor,
    );

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
                : (isDark ? tintColor.withValues(alpha: 0.28) : tintColor)),
        shape: BoxShape.circle,
        border: !framed
            ? null
            : Border.all(
                color: selected
                    ? (isDark
                          ? SharedControlColors.actionBlueDark
                          : SharedControlColors.actionBlue)
                    : (identity != null
                        ? accentInk.withValues(alpha: isDark ? 0.42 : 0.25)
                        : design.separator),
                width: selected ? 1.5 : 1.0,
              ),
        boxShadow: identity == null || isDark
            ? null
            : [
                BoxShadow(
                  color: accentInk.withValues(alpha: 0.08),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Icon(
        icon,
        size: size * .46,
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
