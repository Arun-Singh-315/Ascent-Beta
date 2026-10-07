import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';

class TopReminderAlertBanner extends ConsumerWidget {
  const TopReminderAlertBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final nextReminderAsync = ref.watch(nextUpcomingReminderProvider);
    final reminder = nextReminderAsync.value;

    if (reminder == null) return const SizedBox.shrink();

    final dueTime = DateFormat('h:mm a').format(reminder.scheduledAt);

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: context.accentSecondary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: context.accentSecondary.withValues(alpha: 0.35),
          width: 1.0,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () {
            HapticFeedback.lightImpact();
            context.push('/reminders');
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: context.accentSecondary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    size: 16,
                    color: context.accentSecondary,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Text(
                            'UPCOMING REMINDER',
                            style: AscentTextStyles.captionMedium.copyWith(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: context.accentSecondary,
                              letterSpacing: 0.8,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            '· $dueTime',
                            style: AscentTextStyles.captionMedium.copyWith(
                              fontSize: 10.5,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        reminder.title,
                        style: AscentTextStyles.bodyMedium.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 12,
                  color: context.textMuted.withValues(alpha: 0.7),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class WelcomeBackBanner extends ConsumerWidget {
  final int days;
  const WelcomeBackBanner({super.key, required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: context.accentSecondary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.accentSecondary.withValues(alpha: 0.25), width: 0.8),
      ),
      child: Row(
        children: [
          Icon(Icons.wb_sunny_outlined, color: context.accentSecondary, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back! You were away $days days.',
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  'Consistency starts with one focused block. Let\'s build momentum today!',
                  style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
