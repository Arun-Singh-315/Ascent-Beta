import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';

/// Lightweight AI Companion Card for the home screen.
/// Replaced the continuous pulse animation with a static indicator to reduce
/// main-thread overhead. Watches only 3 providers instead of 8.
class JarvisCopilotCard extends ConsumerWidget {
  const JarvisCopilotCard({super.key});

  String _generateInsight({
    required String name,
    required int hour,
    required double todaySpend,
    required int waterMl,
    required int pendingTasks,
  }) {
    if (hour >= 5 && hour < 12) {
      if (waterMl < 300) {
        return '$name, good morning! Start with a glass of water — you have $pendingTasks tasks ahead today.';
      }
      return 'Good morning! $pendingTasks tasks are lined up. I\'ll track your progress throughout the day.';
    } else if (hour >= 12 && hour < 17) {
      if (waterMl < 1000) {
        return 'Midday check-in: ${waterMl}ml hydrated so far. Grab a glass before your next focus session.';
      }
      return 'Solid midday pace. ₹${todaySpend.toStringAsFixed(0)} spent today, $pendingTasks tasks remaining.';
    } else if (hour >= 17 && hour < 22) {
      return 'Evening: $pendingTasks tasks left. Great time to wrap them up or plan tomorrow.';
    } else {
      return 'Time to wind down. Rest well — tomorrow\'s plan is ready when you are.';
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(assistantNameProvider);
    final hour = DateTime.now().hour;

    // Only 3 providers instead of 8 — reduces SQLite stream overhead
    final spendAsync = ref.watch(todaySpendingStreamProvider);
    final waterAsync = ref.watch(todayWaterMlStreamProvider);
    final tasksAsync = ref.watch(todayTasksStreamProvider);

    final todaySpend = spendAsync.value ?? 0.0;
    final waterMl = waterAsync.value ?? 0;
    final pendingTasks = (tasksAsync.value ?? [])
        .where((t) => t.actualCompletedDate == null)
        .length;

    final speech = _generateInsight(
      name: name,
      hour: hour,
      todaySpend: todaySpend,
      waterMl: waterMl,
      pendingTasks: pendingTasks,
    );

    final accentColor = const Color(0xFF4A90E2);

    return Container(
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.25),
          width: 1.0,
        ),
      ),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row — static indicator, no continuous animation
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.12),
                ),
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: accentColor,
                  size: 15,
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        name.toUpperCase(),
                        style: AscentTextStyles.labelMedium.copyWith(
                          color: accentColor,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: context.stateSuccess,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'ACTIVE',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: context.stateSuccess,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Your AI life assistant',
                    style: AscentTextStyles.bodySmall.copyWith(
                      color: context.textMuted,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Single, clear chat entry point
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/ai-assistant');
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.25),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 12, color: accentColor),
                      const SizedBox(width: 4),
                      Text(
                        'Chat',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: accentColor,
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

          const SizedBox(height: 10),

          // Insight text
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: context.bgBase,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: context.divider.withValues(alpha: 0.5)),
            ),
            child: Text(
              speech,
              style: AscentTextStyles.bodyMedium.copyWith(
                color: context.textPrimary,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),

          const SizedBox(height: 10),

          // Compact prompt chips — scroll horizontally
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _RiyaPromptChip(
                  label: 'Plan Day',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/ai-assistant');
                  },
                ),
                const SizedBox(width: 8),
                _RiyaPromptChip(
                  label: 'Log water',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/ai-assistant');
                  },
                ),
                const SizedBox(width: 8),
                _RiyaPromptChip(
                  label: 'Log expense',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/ai-assistant');
                  },
                ),
                const SizedBox(width: 8),
                _RiyaPromptChip(
                  label: 'My progress',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/ai-assistant');
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

class _RiyaPromptChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RiyaPromptChip({
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
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
            fontSize: 11.5,
          ),
        ),
      ),
    );
  }
}
