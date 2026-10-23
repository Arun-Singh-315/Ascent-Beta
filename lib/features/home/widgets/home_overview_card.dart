import '../../../shared/widgets/glass_chip.dart';
import '../../../shared/widgets/glass_surface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';

class HomeOverviewCard extends ConsumerWidget {
  const HomeOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(todayActivitiesProvider);
    final reminders = ref.watch(allRemindersProvider);
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final pending = activities.value
        ?.where((a) => a.status != TodayActivityStatus.done)
        .length;
    final done = activities.value
        ?.where((a) => a.status == TodayActivityStatus.done)
        .length;
    final due = reminders.value
        ?.where((r) => r.isActive && r.scheduledAt.isBefore(tomorrow))
        .length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassSurface(
        key: const ValueKey('home_overview'),
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Your day at a glance',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                GlassChip(
                  icon: Icons.checklist_rounded,
                  label: pending == null
                      ? 'Loading…'
                      : pending == 0
                      ? 'All clear'
                      : '$pending to do',
                  onTap: () => context.push('/today'),
                ),
                GlassChip(
                  icon: Icons.notifications_none_rounded,
                  label: due == null
                      ? 'Loading…'
                      : due == 0
                      ? 'No reminders'
                      : '$due due',
                  onTap: () => context.push('/reminders'),
                ),
                GlassChip(
                  icon: Icons.check_circle_outline,
                  label: done == null ? 'Loading…' : '$done done',
                  success: done != null && done > 0,
                  onTap: () => context.push('/today'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
