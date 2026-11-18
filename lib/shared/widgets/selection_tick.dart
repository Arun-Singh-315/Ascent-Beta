import 'package:flutter/material.dart';

import '../../app/theme/glass_theme.dart';

/// Round select indicator for multi-select lists.
///
/// Fills with the accent and draws the check in with a small scale-and-fade
/// instead of swapping icons, so selecting feels smooth. Motion is skipped when
/// the system asks for reduced motion.
class SelectionTick extends StatelessWidget {
  const SelectionTick({
    super.key,
    required this.selected,
    this.size = 22,
    this.color,
    this.idleColor,
  });

  final bool selected;
  final double size;

  /// Accent used for the filled state. Defaults to the glass accent.
  final Color? color;

  /// Outline color while unselected. Defaults to the muted ink.
  final Color? idleColor;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final accent = color ?? g.clay;
    final idle = idleColor ?? g.inkMuted;
    final onAccent = Theme.of(context).colorScheme.surface;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = Duration(milliseconds: reduce ? 0 : 220);

    return Semantics(
      checked: selected,
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: duration,
          curve: Curves.easeOutCubic,
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? accent : Colors.transparent,
            border: Border.all(
              color: selected ? accent : idle.withValues(alpha: .7),
              width: 1.5,
            ),
          ),
          child: AnimatedScale(
            scale: selected ? 1 : 0.4,
            duration: duration,
            curve: Curves.easeOutBack,
            child: AnimatedOpacity(
              opacity: selected ? 1 : 0,
              duration: duration,
              curve: Curves.easeOutCubic,
              child: Icon(
                Icons.check_rounded,
                size: size * .68,
                color: onAccent,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
