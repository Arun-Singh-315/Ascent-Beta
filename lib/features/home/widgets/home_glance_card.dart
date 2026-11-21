import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_navigation.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../core/streak/study_streak_provider.dart';

/// "Your day" at a glance: one big card, six live tiles in a bento grid.
/// Every tile is real data and opens its screen; empty values show "–"
/// with a one-word start instead of a zero (CLAUDE.md §1, §2.6).
class HomeGlanceCard extends ConsumerWidget {
  const HomeGlanceCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final things = ref.watch(todayActivitiesProvider).value ?? const [];
    final doneThings = things
        .where((a) => a.status == TodayActivityStatus.done)
        .length;
    final water = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final goal = ref.watch(dailyWaterGoalStreamProvider).value ?? 2000;
    final focus = ref.watch(studyStreakProvider).todaySeconds ~/ 60;
    final thoughts = ref.watch(todayThoughtsCountStreamProvider).value ?? 0;
    final doses = ref.watch(todayMedicineLogsStreamProvider).value ?? const [];
    final taken = doses.where((d) => d.isTaken).length;
    final spent = ref.watch(todaySpendingStreamProvider).value ?? 0;

    final tiles = [
      _Tile(
        id: 'things',
        icon: Icons.checklist_rounded,
        tint: g.actionInk,
        label: 'Things',
        value: things.isEmpty ? '–' : '$doneThings/${things.length}',
        detail: things.isEmpty
            ? 'Plan your day'
            : doneThings == things.length
            ? 'All done'
            : '${things.length - doneThings} left',
        progress: things.isEmpty ? null : doneThings / things.length,
        route: '/things',
      ),
      _Tile(
        id: 'water',
        icon: Icons.water_drop_outlined,
        tint: g.slate,
        label: 'Water',
        value: water == 0 ? '–' : '${(water / 1000).toStringAsFixed(1)} L',
        detail: water == 0
            ? 'First glass'
            : 'of ${(goal / 1000).toStringAsFixed(1)} L',
        progress: water <= 0 || goal <= 0
            ? null
            : (water / goal).clamp(0, 1).toDouble(),
        route: '/hydration',
      ),
      _Tile(
        id: 'focus',
        icon: Icons.timer_outlined,
        tint: g.amber,
        label: 'Focus',
        value: focus == 0
            ? '–'
            : focus >= 60
            ? '${focus ~/ 60}h ${focus % 60}m'
            : '${focus}m',
        detail: focus == 0 ? 'Start a session' : 'focused today',
        route: '/focus',
      ),
      _Tile(
        id: 'mind',
        icon: Icons.bubble_chart_outlined,
        tint: g.clay,
        label: 'Mind',
        value: thoughts == 0 ? '–' : '$thoughts',
        detail: thoughts == 0
            ? 'Jot a thought'
            : thoughts == 1
            ? 'thought today'
            : 'thoughts today',
        route: '/thought-wall',
      ),
      _Tile(
        id: 'medicine',
        icon: Icons.medication_outlined,
        tint: g.coral,
        label: 'Medicine',
        value: doses.isEmpty ? '–' : '$taken/${doses.length}',
        detail: doses.isEmpty
            ? 'Nothing due'
            : taken == doses.length
            ? 'All taken'
            : 'doses taken',
        progress: doses.isEmpty ? null : taken / doses.length,
        route: '/medicine',
      ),
      _Tile(
        id: 'money',
        icon: Icons.account_balance_wallet_outlined,
        tint: g.sage,
        label: 'Spent',
        value: spent == 0 ? '–' : '₹${NumberFormat.compact().format(spent)}',
        detail: spent == 0 ? 'Nothing yet' : 'today',
        route: '/money',
      ),
    ];

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s8,
        AppSpace.s16,
        AppSpace.s16,
      ),
      child: Container(
        key: const ValueKey('home_glance_card'),
        padding: const EdgeInsets.all(AppSpace.s16),
        decoration: BoxDecoration(
          color: g.surface,
          borderRadius: BorderRadius.circular(24),
          border: g.isDark ? Border.all(color: g.line) : null,
          boxShadow: g.isDark
              ? null
              : [
                  BoxShadow(
                    color: g.shadow.withValues(alpha: .08),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpace.s8,
              children: [
                Text(
                  'Your day',
                  style: AscentTextStyles.homeTitle.copyWith(color: g.ink),
                ),
                Text(
                  DateFormat('EEE d MMM').format(DateTime.now()),
                  style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s12),
            LayoutBuilder(
              builder: (context, box) {
                // Three columns on phones, two when text is very large.
                final cols = MediaQuery.textScalerOf(context).scale(14) > 22
                    ? 2
                    : 3;
                const gap = AppSpace.s8;
                final w = (box.maxWidth - gap * (cols - 1)) / cols;
                return Wrap(
                  spacing: gap,
                  runSpacing: gap,
                  children: [
                    for (final t in tiles) SizedBox(width: w, child: t),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({
    required this.id,
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    required this.detail,
    required this.route,
    this.progress,
  });
  final String id;
  final IconData icon;
  final Color tint;
  final String label;
  final String value;
  final String detail;
  final String route;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      button: true,
      label: '$label: $value, $detail',
      child: InkWell(
        key: ValueKey('home_glance_$id'),
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          HapticFeedback.selectionClick();
          context.open(route);
        },
        child: Container(
          constraints: const BoxConstraints(minHeight: 104),
          padding: const EdgeInsets.all(AppSpace.s12),
          decoration: BoxDecoration(
            color: tint.withValues(alpha: g.isDark ? .14 : .08),
            borderRadius: BorderRadius.circular(16),
          ),
          child: ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(icon, size: 18, color: tint),
                    const SizedBox(width: AppSpace.s4),
                    Flexible(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AscentTextStyles.caption.copyWith(
                          color: g.inkSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    value,
                    style: AscentTextStyles.interfaceTitle.copyWith(
                      color: g.ink,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
                Text(
                  detail,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
                ),
                if (progress != null) ...[
                  const SizedBox(height: AppSpace.s8),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 4,
                      color: tint,
                      backgroundColor: tint.withValues(alpha: .15),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
