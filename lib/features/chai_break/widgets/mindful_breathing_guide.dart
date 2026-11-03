import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import 'package:flutter/material.dart';

import '../chai_break_provider.dart';

class MindfulBreathingGuide extends StatelessWidget {
  final BreathPhase phase;
  final bool isRunning;
  final Color? accentColor;

  const MindfulBreathingGuide({
    super.key,
    required this.phase,
    required this.isRunning,
    this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final accent = accentColor ?? g.clay;
    double targetScale = 1.0;
    Color ringColor = accent.withValues(alpha: 0.4);

    switch (phase) {
      case BreathPhase.inhale:
        targetScale = 1.18;
        ringColor = accent.withValues(alpha: 0.85);
        break;
      case BreathPhase.hold:
        targetScale = 1.18;
        ringColor = g.amber;
        break;
      case BreathPhase.exhale:
        targetScale = 0.92;
        ringColor = accent.withValues(alpha: 0.45);
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedContainer(
          duration: const Duration(milliseconds: 1800),
          curve: Curves.easeInOutCubic,
          width: 44 * targetScale,
          height: 44 * targetScale,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: ringColor.withValues(alpha: 0.15),
            border: Border.all(
              color: ringColor,
              width: 1.8,
            ),
            boxShadow: [
              BoxShadow(
                color: ringColor.withValues(alpha: 0.2),
                blurRadius: 14,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Center(
            child: Icon(
              phase == BreathPhase.hold
                  ? Icons.pause_circle_outline_rounded
                  : phase == BreathPhase.inhale
                  ? Icons.arrow_upward_rounded
                  : Icons.arrow_downward_rounded,
              size: 20,
              color: ringColor,
            ),
          ),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            isRunning ? phase.label : 'Paused — Breathe at your own pace',
            key: ValueKey(phase.label),
            style: AscentTextStyles.bodyMedium.copyWith(
              color: g.ink,
              fontWeight: FontWeight.w600,
              fontSize: 13.5,
            ),
          ),
        ),
      ],
    );
  }
}
