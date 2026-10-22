import '../../../app/theme/color_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../shared/widgets/app_surfaces.dart';

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
    return AppCard(
      key: const ValueKey('home_overview'),
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      nightDecoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.glass.line),
      ),
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
              TextButton.icon(
                onPressed: () => context.push('/today'),
                icon: const Icon(Icons.checklist_rounded, size: 18),
                label: Text('${pending ?? '—'} to do'),
              ),
              TextButton.icon(
                onPressed: () => context.push('/reminders'),
                icon: const Icon(Icons.notifications_none_rounded, size: 18),
                label: Text('${due ?? '—'} reminders due'),
              ),
              TextButton.icon(
                onPressed: () => context.push('/today'),
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text('${done ?? '—'} done'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
