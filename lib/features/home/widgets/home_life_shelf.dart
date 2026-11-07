import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/home_layout_provider.dart';
import '../../challenge/challenge_providers.dart';

/// A horizontally browsable set of independent routines. No empty telemetry.
class HomeLifeShelf extends ConsumerWidget {
  const HomeLifeShelf({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final layout = ref.watch(homeLayoutProvider);
    final g = context.glass;
    final water = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final goal = ref.watch(dailyWaterGoalStreamProvider).value ?? 2500;
    final walk = ref.watch(todayWalkDistanceStreamProvider).value ?? 0;
    final doses = ref.watch(todayMedicineLogsStreamProvider).value ?? [];
    final taken = doses.where((dose) => dose.isTaken).length;
    final challenge = ref.watch(activeChallengeProvider).value;
    final cards = <Widget>[
      if (layout.tools.contains('hydration'))
        _RoutineTile(
          id: 'hydration',
          title: 'Water',
          icon: Icons.water_drop_outlined,
          tint: SharedControlColors.actionBlue,
          value: water > 0
              ? '${(water / 1000).toStringAsFixed(1)} L'
              : 'Stay refreshed',
          detail: water > 0
              ? 'of ${(goal / 1000).toStringAsFixed(1)} L today'
              : 'Make room for a sip',
          progress: water > 0 && goal > 0 ? water / goal : null,
        ),
      if (layout.tools.contains('medicine') && doses.isNotEmpty)
        _RoutineTile(
          id: 'medicine',
          title: 'Medicine',
          icon: Icons.medication_outlined,
          tint: g.inkSecondary,
          value: '$taken of ${doses.length}',
          detail: taken == doses.length
              ? 'Today’s doses taken'
              : 'Doses taken today',
          progress: taken > 0 ? taken / doses.length : null,
        ),
      if (layout.tools.contains('walk'))
        _RoutineTile(
          id: 'walk',
          title: 'Movement',
          icon: Icons.directions_walk_rounded,
          tint: context.isDark
              ? const Color(0xFF98BFA8)
              : const Color(0xFF466D58),
          value: walk > 0
              ? '${(walk / 1000).toStringAsFixed(1)} km'
              : 'Step outside',
          detail: walk > 0 ? 'Walked today' : 'A change of scenery',
        ),
      if (layout.tools.contains('chai-break'))
        _RoutineTile(
          id: 'chai-break',
          title: 'A little pause',
          icon: Icons.coffee_outlined,
          tint: context.isDark
              ? const Color(0xFFD5B69A)
              : const Color(0xFF8B6046),
          value: 'Breathe. Reset.',
          detail: 'Your break, your pace',
        ),
      if (layout.tools.contains('momentum') && challenge != null)
        _RoutineTile(
          id: 'momentum',
          title: 'Challenge',
          icon: Icons.flag_outlined,
          tint: g.inkSecondary,
          value: challenge.title,
          detail: 'Keep your momentum',
        ),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Life & Health',
                style: AscentTextStyles.homeTitle.copyWith(
                  color: g.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'All life tools',
              onPressed: () => context.push('/more'),
              icon: Icon(Icons.arrow_forward_rounded, size: 20, color: g.ink),
            ),
          ],
        ),
        const SizedBox(height: 8),
        SingleChildScrollView(
          key: const ValueKey('home_life_shelf'),
          scrollDirection: Axis.horizontal,
          clipBehavior: Clip.hardEdge,
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < cards.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  SizedBox(
                    width: MediaQuery.textScalerOf(context).scale(16) > 22
                        ? 220
                        : 172,
                    child: cards[i],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 28),
      ],
    );
  }
}

class _RoutineTile extends StatelessWidget {
  const _RoutineTile({
    required this.id,
    required this.title,
    required this.icon,
    required this.tint,
    required this.value,
    required this.detail,
    this.progress,
  });
  final String id, title, value, detail;
  final IconData icon;
  final Color tint;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Material(
      color: Color.alphaBlend(
        tint.withValues(alpha: context.isDark ? .12 : .055),
        g.bg,
      ),
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        key: ValueKey('home_routine_$id'),
        onTap: () => context.push('/$id'),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: tint, size: 26),
              const SizedBox(height: 18),
              Text(
                title,
                style: AscentTextStyles.labelMedium.copyWith(
                  color: g.inkSecondary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                value,
                style: AscentTextStyles.cardTitle.copyWith(
                  color: g.ink,
                  fontSize: 19,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                detail,
                style: AscentTextStyles.labelSmall.copyWith(
                  color: g.inkSecondary,
                  height: 1.4,
                ),
              ),
              if (progress != null) ...[
                const SizedBox(height: 14),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress!.clamp(0, 1),
                    minHeight: 3,
                    color: SharedControlColors.actionBlue,
                    backgroundColor: g.ink.withValues(alpha: .08),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
