import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/frozen_palette.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/ascent_button.dart';

Future<void> showPlanDetailSheet(
  BuildContext context, [
  dynamic planOrId,
]) async {
  PlanDefinition? target;
  if (planOrId is PlanDefinition) {
    target = planOrId;
  } else if (planOrId is String) {
    final container = ProviderScope.containerOf(context, listen: false);
    target = await container.read(planDaoProvider).getPlanById(planOrId);
  }
  if (target == null || !context.mounted) return;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => PlanDetailSheet(plan: target!),
  );
}

class PlanDetailSheet extends ConsumerStatefulWidget {
  const PlanDetailSheet({super.key, required this.plan});
  final PlanDefinition plan;

  @override
  ConsumerState<PlanDetailSheet> createState() => _PlanDetailSheetState();
}

class _PlanDetailSheetState extends ConsumerState<PlanDetailSheet> {
  bool _busy = false;

  String _formatTime(String time24) {
    try {
      final parts = time24.split(':');
      final h = int.parse(parts[0]);
      final m = int.parse(parts[1]);
      final dt = DateTime(2026, 1, 1, h, m);
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return time24;
    }
  }

  String _recurrenceLabel(String rule) {
    switch (rule) {
      case 'daily':
        return 'Every day';
      case 'weekdays':
        return 'Weekdays (Mon–Fri)';
      case 'custom_days':
        return 'Selected days';
      case 'once':
      default:
        return 'One-time plan';
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plan = widget.plan;
    final planService = ref.watch(planServiceProvider);
    final db = ref.watch(databaseProvider);

    return FutureBuilder<List<PlanOccurrence>>(
      future: db.planDao.getOccurrencesForPlan(plan.id),
      builder: (_, snapshot) {
        final occurrences = snapshot.data ?? [];
        final totalSessions = occurrences.length;
        final doneSessions =
            occurrences.where((o) => o.outcome == 'done').length;
        final skippedSessions =
            occurrences.where((o) => o.outcome == 'skipped').length;
        final notConfirmedSessions =
            occurrences.where((o) => o.outcome == 'not_confirmed').length;
        final scheduledSessions =
            occurrences.where((o) => o.outcome == 'scheduled').length;

        final isPaused = plan.status == 'paused';
        final isEnded = plan.status == 'ended';
        final isActive = plan.status == 'active';

        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 20,
            bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top Bar with Status Badge
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isEnded
                            ? g.inkMuted.withValues(alpha: 0.15)
                            : isPaused
                                ? Colors.orange.withValues(alpha: 0.15)
                                : isDark
                                    ? FrozenPalette.darkAction
                                        .withValues(alpha: 0.2)
                                    : FrozenPalette.action
                                        .withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isEnded
                            ? 'Ended'
                            : isPaused
                                ? 'Paused'
                                : 'Active Routine',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isEnded
                              ? g.inkMuted
                              : isPaused
                                  ? Colors.orange
                                  : isDark
                                      ? FrozenPalette.darkActionBright
                                      : FrozenPalette.action,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                // Title
                Text(
                  plan.title,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: g.ink,
                      ),
                ),
                const SizedBox(height: 6),

                // Plain-language schedule summary
                Text(
                  '${_recurrenceLabel(plan.recurrenceRule)} · ${_formatTime(plan.localTime)} · ${plan.startDate} to ${plan.endDate}',
                  style: TextStyle(
                    fontSize: 14,
                    color: g.inkSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Statistics Grid
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isDark ? g.fill : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: g.edge),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Session Progress',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: g.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _StatItem(label: 'Total', value: '$totalSessions'),
                          _StatItem(label: 'Done', value: '$doneSessions'),
                          _StatItem(label: 'Skipped', value: '$skippedSessions'),
                          if (notConfirmedSessions > 0)
                            _StatItem(
                              label: 'Unconfirmed',
                              value: '$notConfirmedSessions',
                            ),
                          _StatItem(
                            label: 'Upcoming',
                            value: '$scheduledSessions',
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Details list
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.notifications_outlined, size: 22),
                  title: const Text('Start reminder'),
                  subtitle: Text(
                    plan.reminderPolicy == 'at_start'
                        ? 'At ${_formatTime(plan.localTime)} on each scheduled day'
                        : 'Off',
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.chat_bubble_outline, size: 22),
                  title: const Text('Check-in follow-up'),
                  subtitle: Text(
                    plan.checkInPolicy == 'gentle'
                        ? 'Gentle (First check-in, +30m and +90m retries if unanswered)'
                        : plan.checkInPolicy == 'once'
                            ? 'Once after scheduled session'
                            : 'Off',
                  ),
                ),
                if (plan.expectedDurationMinutes != null)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.timer_outlined, size: 22),
                    title: const Text('Expected duration'),
                    subtitle:
                        Text('${plan.expectedDurationMinutes} minutes'),
                  ),

                const SizedBox(height: 20),

                // Management Actions
                if (isActive)
                  SizedBox(
                    width: double.infinity,
                    child: AscentButton.ghost(
                      label: 'Pause routine',
                      onPressed: _busy
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              setState(() => _busy = true);
                              try {
                                await planService.pausePlan(plan.id);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Routine paused. Pending alerts stopped.'),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                    ),
                  ),
                if (isPaused)
                  SizedBox(
                    width: double.infinity,
                    child: AscentButton.tonal(
                      label: 'Resume routine',
                      onPressed: _busy
                          ? null
                          : () async {
                              HapticFeedback.lightImpact();
                              setState(() => _busy = true);
                              try {
                                await planService.resumePlan(plan.id);
                                if (context.mounted) {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text('Routine resumed.'),
                                    ),
                                  );
                                }
                              } finally {
                                if (mounted) setState(() => _busy = false);
                              }
                            },
                    ),
                  ),
                if (!isEnded) ...[
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: Theme.of(context).colorScheme.error,
                      ),
                      onPressed: _busy
                          ? null
                          : () async {
                              HapticFeedback.mediumImpact();
                              final confirmed = await showDialog<bool>(
                                context: context,
                                builder: (dialogContext) => AlertDialog(
                                  title: const Text('End routine?'),
                                  content: Text(
                                    'This will end "${plan.title}" and cancel all pending alerts. Past session history will be retained.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext, true),
                                      style: TextButton.styleFrom(
                                        foregroundColor:
                                            Theme.of(dialogContext).colorScheme.error,
                                      ),
                                      child: const Text('End routine'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirmed == true && mounted) {
                                setState(() => _busy = true);
                                try {
                                  await planService.endPlan(plan.id);
                                  if (context.mounted) {
                                    Navigator.pop(context);
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                        content: Text('Routine ended.'),
                                      ),
                                    );
                                  }
                                } finally {
                                  if (mounted) setState(() => _busy = false);
                                }
                              }
                            },
                      child: const Text('End routine'),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

class _StatItem extends StatelessWidget {
  const _StatItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
