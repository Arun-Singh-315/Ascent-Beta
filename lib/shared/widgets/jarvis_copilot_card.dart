import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/providers/database_provider.dart';

/// Living JARVIS AI Companion Card
/// Features an animated pulsing aura, time-of-day cognitive awareness,
/// real-time synthesis of all life pillars (water, spend, walk, tasks),
/// and proactive personalized guidance.
class JarvisCopilotCard extends ConsumerStatefulWidget {
  const JarvisCopilotCard({super.key});

  @override
  ConsumerState<JarvisCopilotCard> createState() => _JarvisCopilotCardState();
}

class _JarvisCopilotCardState extends ConsumerState<JarvisCopilotCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.85, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOutSine),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  String _generateJarvisInsight({
    required int hour,
    required double todaySpend,
    required double? dailyBudget,
    required double walkMeters,
    required double walkTargetMeters,
    required int waterMl,
    required int waterTargetMl,
    required int pendingTasks,
    required int streak,
  }) {
    final walkKm = (walkMeters / 1000.0).toStringAsFixed(1);
    final targetKm = (walkTargetMeters / 1000.0).toStringAsFixed(1);

    if (hour >= 5 && hour < 12) {
      // Morning
      if (waterMl < 500) {
        return 'Good morning, sir. I recommend kickstarting your metabolism with 500 mL water. You have $pendingTasks tasks scheduled and your $streak-day momentum is active.';
      }
      return 'Morning focus mode active. All systems primed. $pendingTasks key tasks ahead, and $walkKm / $targetKm km walked.';
    } else if (hour >= 12 && hour < 17) {
      // Afternoon
      if (dailyBudget != null && todaySpend > dailyBudget * 0.75) {
        return 'Afternoon status, sir: You have used ₹${todaySpend.toStringAsFixed(0)} of your ₹${dailyBudget.toStringAsFixed(0)} daily target. I advise pacing remaining discretionary expenses.';
      }
      if (waterMl < waterTargetMl * 0.5) {
        return 'Midday check-in: Hydration is at $waterMl mL. Grab a glass of water before your next study session.';
      }
      return 'Solid midday rhythm. Pacing on budget (₹${todaySpend.toStringAsFixed(0)} spent) and $pendingTasks tasks remaining in your study pipeline.';
    } else if (hour >= 17 && hour < 22) {
      // Evening
      if (walkMeters < walkTargetMeters * 0.6) {
        final remainingMeters = (walkTargetMeters - walkMeters).clamp(0.0, 10000.0);
        final remainingMinutes = ((remainingMeters / 1000.0) * 12).round();
        return 'Evening debrief: You are at $walkKm km walked today. A brisk $remainingMinutes-minute outdoor walk will complete your $targetKm km goal.';
      }
      return 'Evening wellness on track! Great job maintaining your routines today. Ready to review your Thought Wall before wrapping up?';
    } else {
      // Night
      return 'Night wrap-up, sir: $streak-day continuous streak secured. Rest well so your memory consolidation and energy peak tomorrow.';
    }
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final hour = now.hour;

    final spendAsync = ref.watch(todaySpendingStreamProvider);
    final budgetAsync = ref.watch(overallBudgetStreamProvider);
    final walkAsync = ref.watch(todayWalkDistanceStreamProvider);
    final walkGoalAsync = ref.watch(activityGoalStreamProvider);
    final waterAsync = ref.watch(todayWaterMlStreamProvider);
    final waterGoalAsync = ref.watch(dailyWaterGoalStreamProvider);
    final tasksAsync = ref.watch(todayTasksStreamProvider);
    final streakAsync = ref.watch(currentStreakStreamProvider);

    final todaySpend = spendAsync.value ?? 0.0;
    final dailyBudget = budgetAsync.value?.dailyLimit ?? 500.0;
    final walkMeters = walkAsync.value ?? 0.0;
    final walkTargetMeters = walkGoalAsync.value?.targetDistanceMeters ?? 5000.0;
    final waterMl = waterAsync.value ?? 0;
    final waterTargetMl = waterGoalAsync.value ?? 2500;
    final pendingTasks = (tasksAsync.value ?? []).where((t) => t.actualCompletedDate == null).length;
    final streak = streakAsync.value ?? 1;

    final speech = _generateJarvisInsight(
      hour: hour,
      todaySpend: todaySpend,
      dailyBudget: dailyBudget,
      walkMeters: walkMeters,
      walkTargetMeters: walkTargetMeters,
      waterMl: waterMl,
      waterTargetMl: waterTargetMl,
      pendingTasks: pendingTasks,
      streak: streak,
    );

    return Container(
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF0096C7).withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0096C7).withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: JARVIS Identity & Breathing Aura
          Row(
            children: [
              // Pulsing JARVIS Orb
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      Container(
                        width: 32 * _pulseAnimation.value,
                        height: 32 * _pulseAnimation.value,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0096C7).withValues(alpha: 0.2),
                        ),
                      ),
                      Container(
                        width: 22,
                        height: 22,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [Color(0xFF48CAE4), Color(0xFF0077B6)],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Color(0xFF00B4D8),
                              blurRadius: 8,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.blur_on_rounded,
                          color: Colors.white,
                          size: 14,
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'JARVIS',
                        style: AscentTextStyles.labelMedium.copyWith(
                          color: const Color(0xFF00B4D8),
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.4,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: Color(0xFF5FA070),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ACTIVE COPILOT',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: const Color(0xFF5FA070),
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Real-time Life Intelligence',
                    style: AscentTextStyles.bodySmall.copyWith(
                      color: context.textMuted,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Talk with Jarvis shortcut
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/ai-assistant');
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0096C7).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: const Color(0xFF0096C7).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.chat_bubble_outline_rounded, size: 12, color: Color(0xFF00B4D8)),
                      const SizedBox(width: 4),
                      Text(
                        'Open Chat',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: const Color(0xFF00B4D8),
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Speech Bubble
          Container(
            padding: const EdgeInsets.all(13),
            decoration: BoxDecoration(
              color: context.bgBase,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.divider.withValues(alpha: 0.6)),
            ),
            child: Text(
              speech,
              style: AscentTextStyles.bodyMedium.copyWith(
                color: context.textPrimary,
                height: 1.45,
                fontSize: 13.5,
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Dynamic JARVIS Action Suggestions
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _JarvisPromptChip(
                  label: 'Plan My Day 🎯',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/ai-assistant');
                  },
                ),
                const SizedBox(width: 8),
                _JarvisPromptChip(
                  label: 'Rebalance Tasks ⚖️',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/today');
                  },
                ),
                const SizedBox(width: 8),
                _JarvisPromptChip(
                  label: 'Mind Reflection 🪞',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/thought-wall');
                  },
                ),
                const SizedBox(width: 8),
                _JarvisPromptChip(
                  label: 'Hydrate +250ml 💧',
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    await ref.read(waterDaoProvider).addWater(250);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('JARVIS logged +250 mL water!')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _JarvisPromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _JarvisPromptChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: context.bgSurface,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: context.divider),
        ),
        child: Text(
          label,
          style: AscentTextStyles.labelSmall.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
