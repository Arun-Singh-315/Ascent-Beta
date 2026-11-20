import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/surface_tokens.dart';
import 'app_chip.dart';

/// One suggested next step after an action ("Remind me at 6", "Make these
/// to-dos"). Shown right where the user's thumb already is.
class NextStep {
  const NextStep({
    required this.id,
    required this.label,
    required this.icon,
    required this.onTap,
  });
  final String id;
  final String label;
  final IconData icon;
  final VoidCallback onTap;
}

/// A short row of suggested next steps (CLAUDE.md §1: never "later").
/// Fades and rises in; renders nothing when [steps] is empty.
class NextStepChips extends StatelessWidget {
  const NextStepChips({super.key, required this.steps});
  final List<NextStep> steps;

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return AnimatedSwitcher(
      duration: reduceMotion
          ? Duration.zero
          : const Duration(milliseconds: 220),
      transitionBuilder: (child, anim) => FadeTransition(
        opacity: anim,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, .25),
            end: Offset.zero,
          ).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic)),
          child: child,
        ),
      ),
      child: steps.isEmpty
          ? const SizedBox.shrink(key: ValueKey('next_steps_empty'))
          : Wrap(
              key: ValueKey('next_steps_${steps.map((s) => s.id).join('_')}'),
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final s in steps)
                  AppChip(
                    key: ValueKey('next_step_${s.id}'),
                    label: s.label,
                    icon: s.icon,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      s.onTap();
                    },
                  ),
              ],
            ),
    );
  }
}
