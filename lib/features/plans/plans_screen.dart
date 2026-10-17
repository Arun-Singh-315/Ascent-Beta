import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../app/theme/frozen_palette.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/app_surfaces.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import 'widgets/plan_detail_sheet.dart';

final allPlansStreamProvider = StreamProvider<List<PlanDefinition>>(
  (ref) => ref.watch(databaseProvider).planDao.watchAllPlans(),
);

class PlansScreen extends ConsumerStatefulWidget {
  const PlansScreen({super.key, this.initialPlanId});
  final String? initialPlanId;

  @override
  ConsumerState<PlansScreen> createState() => _PlansScreenState();
}

class _PlansScreenState extends ConsumerState<PlansScreen> {
  int _selectedTab = 0; // 0 = Active, 1 = Paused, 2 = Ended
  bool _handledInitialPlan = false;

  void _checkInitialPlan(List<PlanDefinition> plans) {
    if (_handledInitialPlan || widget.initialPlanId == null) return;
    _handledInitialPlan = true;
    final target = plans.where((p) => p.id == widget.initialPlanId).firstOrNull;
    if (target != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) showPlanDetailSheet(context, target);
      });
    }
  }

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

  String _scheduleSummary(PlanDefinition plan) {
    final rule = plan.recurrenceRule == 'daily'
        ? 'Every day'
        : plan.recurrenceRule == 'weekdays'
            ? 'Weekdays'
            : plan.recurrenceRule == 'custom_days'
                ? 'Selected days'
                : 'One-time';
    return '$rule · ${_formatTime(plan.localTime)} · Until ${plan.endDate}';
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plansAsync = ref.watch(allPlansStreamProvider);

    return AscentScaffold(
      title: 'Plans & Routines',
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (err, _) => Center(child: Text('Could not load plans: $err')),
        data: (allPlans) {
          _checkInitialPlan(allPlans);

          final activePlans =
              allPlans.where((p) => p.status == 'active').toList();
          final pausedPlans =
              allPlans.where((p) => p.status == 'paused').toList();
          final endedPlans =
              allPlans.where((p) => p.status == 'ended').toList();

          final currentList = _selectedTab == 0
              ? activePlans
              : _selectedTab == 1
                  ? pausedPlans
                  : endedPlans;

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    _tabButton(0, 'Active (${activePlans.length})'),
                    const SizedBox(width: 8),
                    _tabButton(1, 'Paused (${pausedPlans.length})'),
                    const SizedBox(width: 8),
                    _tabButton(2, 'Ended (${endedPlans.length})'),
                  ],
                ),
              ),
              Expanded(
                child: currentList.isEmpty
                    ? EmptyState(
                        icon: Icons.event_repeat_rounded,
                        title: _selectedTab == 0
                            ? 'No active routines'
                            : _selectedTab == 1
                                ? 'No paused routines'
                                : 'No ended routines',
                        subtitle: _selectedTab == 0
                            ? 'Create a routine from thought capture, Today card, or Riya.'
                            : 'Paused routines will appear here.',
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 12,
                        ),
                        itemCount: currentList.length,
                        itemBuilder: (context, index) {
                          final plan = currentList[index];
                          return AppCard(
                            margin: const EdgeInsets.only(bottom: 12),
                            padding: const EdgeInsets.all(16),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {
                                HapticFeedback.lightImpact();
                                showPlanDetailSheet(context, plan);
                              },
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? FrozenPalette.darkAction
                                                  .withValues(alpha: 0.15)
                                              : FrozenPalette.action
                                                  .withValues(alpha: 0.12),
                                          borderRadius:
                                              BorderRadius.circular(10),
                                        ),
                                        child: Icon(
                                          Icons.event_repeat_rounded,
                                          size: 18,
                                          color: isDark
                                              ? FrozenPalette.darkActionBright
                                              : FrozenPalette.action,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: Text(
                                          plan.title,
                                          style: Theme.of(context)
                                              .textTheme
                                              .titleMedium
                                              ?.copyWith(
                                                fontWeight: FontWeight.w600,
                                              ),
                                        ),
                                      ),
                                      Icon(
                                        Icons.chevron_right_rounded,
                                        color: g.inkMuted,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    _scheduleSummary(plan),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: g.inkSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tabButton(int index, String label) {
    final isSelected = _selectedTab == index;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final g = context.glass;

    return Expanded(
      child: GestureDetector(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() => _selectedTab = index);
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isSelected
                ? (isDark
                    ? FrozenPalette.darkAction.withValues(alpha: 0.25)
                    : FrozenPalette.action.withValues(alpha: 0.15))
                : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isSelected
                  ? (isDark ? FrozenPalette.darkAction : FrozenPalette.action)
                  : g.edge,
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
              color: isSelected
                  ? (isDark ? FrozenPalette.darkActionBright : FrozenPalette.action)
                  : g.inkSecondary,
            ),
          ),
        ),
      ),
    );
  }
}
