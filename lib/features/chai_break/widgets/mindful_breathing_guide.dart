import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../chai_break_provider.dart';

class MindfulBreathingGuide extends StatelessWidget {
  final BreathPhase phase;
  final bool isRunning;
  final Color accentColor;

  const MindfulBreathingGuide({
    super.key,
    required this.phase,
    required this.isRunning,
    this.accentColor = const Color(0xFFE28B57),
  });

  @override
  Widget build(BuildContext context) {
    double targetScale = 1.0;
    Color ringColor = accentColor.withValues(alpha: 0.4);

    switch (phase) {
      case BreathPhase.inhale:
        targetScale = 1.18;
        ringColor = accentColor.withValues(alpha: 0.85);
        break;
      case BreathPhase.hold:
        targetScale = 1.18;
        ringColor = const Color(0xFFF59E0B);
        break;
      case BreathPhase.exhale:
        targetScale = 0.92;
        ringColor = accentColor.withValues(alpha: 0.45);
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
                color: ringColor.withValues(alpha: 0.25),
                blurRadius: 16,
                spreadRadius: 2,
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
            style: GoogleFonts.plusJakartaSans(
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white70
                  : const Color(0xFF1E293B),
              letterSpacing: 0.2,
            ),
          ),
        ),
      ],
    );
  }
}
