import '../../../shared/widgets/ascent_snack_bar.dart';
import 'home_shortcut_summary.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/home_layout_provider.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../challenge/challenge_providers.dart';

class _RhythmTool {
  const _RhythmTool(
    this.id,
    this.title,
    this.icon,
    this.detail,
    this.action,
    this.tint,
    this.route,
  );
  final String id, title, detail, action, route;
  final IconData icon;
  final Color tint;
}

/// Tools stay within Home's width. Details expand into the same page scroll.
class HomeLifeShelf extends ConsumerStatefulWidget {
  const HomeLifeShelf({super.key});
  @override
  ConsumerState<HomeLifeShelf> createState() => _HomeLifeShelfState();
}

class _HomeLifeShelfState extends ConsumerState<HomeLifeShelf> {
  String? _expanded;
  int _amount = 250;
  bool _saving = false;
  String? _error;

  Future<void> _logWater() async {
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final amount = _amount;
      final dao = ref.read(waterDaoProvider);
      final id = await dao.addWater(amount);
      if (mounted) {
        HapticFeedback.lightImpact();
        AscentSnackBar.show(
          context,
          message: '$amount ml water logged',
          actionLabel: 'Undo',
          onAction: () async {
            try {
              await dao.deleteWater(id);
            } catch (_) {
              if (mounted) {
                AscentSnackBar.error(
                  context,
                  message: 'Could not undo water log. Please retry.',
                );
              }
            }
          },
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not log water. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final layout = ref.watch(homeLayoutProvider);
    final g = context.glass;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final waterState = ref.watch(todayWaterMlStreamProvider);
    final goalState = ref.watch(dailyWaterGoalStreamProvider);
    final water = waterState.hasError ? null : waterState.value;
    final goal = goalState.hasError ? null : goalState.value;
    final doseState = ref.watch(todayMedicineLogsStreamProvider);
    final doses = doseState.value ?? [];
    final challenge = ref.watch(activeChallengeProvider).value;

    final tools = [
      if (layout.tools.contains('hydration'))
        _RhythmTool(
          'hydration',
          'Water',
          Icons.water_drop_rounded,
          'Choose an amount to log',
          'Choose an amount',
          const Color(0xFF0284C7),
          '/hydration',
        ),
      if (layout.tools.contains('walk'))
        _RhythmTool(
          'walk',
          'Move',
          Icons.directions_walk_rounded,
          'Keep your walking distance together, one walk at a time.',
          'Start a walk',
          const Color(0xFF10B981),
          '/walk',
        ),
      if (layout.tools.contains('chai-break'))
        const _RhythmTool(
          'chai-break',
          'Pause',
          Icons.spa_rounded,
          'Take a breather',
          'Take a minute',
          Color(0xFFF59E0B),
          '/chai-break',
        ),
      if (layout.tools.contains('medicine'))
        _RhythmTool(
          'medicine',
          'Care',
          Icons.favorite_rounded,
          doseState.hasError
              ? 'Could not load your doses.'
              : doseState.isLoading
              ? 'Loading your doses…'
              : doses.isEmpty
              ? 'No doses scheduled today.'
              : 'Follow your saved medicine routine.',
          !doseState.isLoading && !doseState.hasError && doses.isEmpty
              ? 'Set up a routine'
              : 'View your doses',
          const Color(0xFFEC4899),
          '/medicine',
        ),
      if (layout.tools.contains('momentum'))
        _RhythmTool(
          'momentum',
          'Momentum',
          Icons.flag_rounded,
          challenge?.title ?? 'Choose a challenge to build a little momentum.',
          'View challenge',
          const Color(0xFF8B5CF6),
          '/momentum',
        ),
    ];

    if (tools.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: AnimatedSize(
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 300,
        ),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: Container(
          key: const ValueKey('home_life_shelf_enclosure'),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Daily rhythm',
                          style: AscentTextStyles.homeTitle.copyWith(
                            color: g.ink,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Today',
                          style: AscentTextStyles.bodySmall.copyWith(
                            color: g.inkSecondary,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: g.clay.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: g.clay.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      '${tools.length} active',
                      style: TextStyle(
                        color: g.clay,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Column(
                key: const ValueKey('home_life_shelf'),
                children: [
                  for (final tool in tools)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: SizedBox(
                        key: ValueKey('rhythm_card_${tool.id}'),
                        width: double.infinity,
                        child: _tile(tool, dark, g, water, goal),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggle(String id) {
    if (_saving) return;
    HapticFeedback.selectionClick();
    setState(() {
      _expanded = _expanded == id ? null : id;
      _error = null;
    });
  }

  Widget _tile(
    _RhythmTool tool,
    bool dark,
    AscentGlass g,
    int? water,
    int? goal,
  ) {
    final selected = tool.id == _expanded;
    final blue = dark
        ? SharedControlColors.actionBlueDark
        : SharedControlColors.actionBlue;

    double? progress;
    if (tool.id == 'hydration' && goal != null && goal > 0 && water != null && water > 0) {
      progress = (water / goal).clamp(0.0, 1.0);
    }

    final summary = ref
        .watch(homeShortcutSummaryProvider(tool.id))
        .replaceFirst(RegExp(r' today$'), '');

    return Container(
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected
              ? (dark ? blue : tool.tint)
              : g.line.withValues(alpha: 0.75),
          width: selected ? 1.4 : 1.0,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Semantics(
            button: true,
            expanded: selected,
            child: InkWell(
              key: ValueKey('home_routine_${tool.id}'),
              onTap: _saving ? null : () => _toggle(tool.id),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: tool.tint.withValues(alpha: dark ? 0.20 : 0.12),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: tool.tint.withValues(alpha: 0.35),
                              width: 1.0,
                            ),
                          ),
                          child: Center(
                            child: Icon(
                              tool.icon,
                              size: 22,
                              color: tool.tint,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Wrap(
                                crossAxisAlignment: WrapCrossAlignment.center,
                                spacing: 6,
                                children: [
                                  Text(
                                    tool.title,
                                    style: TextStyle(
                                      color: g.inkSecondary,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.2,
                                    ),
                                  ),
                                  if (tool.id == 'hydration' && goal != null && goal > 0)
                                    Text(
                                      '· Goal $goal ml',
                                      style: TextStyle(
                                        color: g.inkMuted,
                                        fontSize: 11,
                                      ),
                                    ),
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                summary,
                                key: ValueKey('rhythm_summary_${tool.id}'),
                                style: AscentTextStyles.cardTitle.copyWith(
                                  color: g.ink,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: -0.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (selected)
                          IconButton(
                            tooltip: 'Close details',
                            onPressed: _saving ? null : () => _toggle(tool.id),
                            icon: Icon(
                              Icons.keyboard_arrow_up_rounded,
                              size: 22,
                              color: blue,
                            ),
                          )
                        else
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 22,
                            color: g.inkSecondary,
                          ),
                      ],
                    ),
                    if (progress != null && !selected) ...[
                      const SizedBox(height: 12),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: LinearProgressIndicator(
                          value: progress,
                          minHeight: 4,
                          backgroundColor: g.line.withValues(alpha: 0.25),
                          valueColor: AlwaysStoppedAnimation<Color>(tool.tint),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          if (selected)
            Padding(
              key: ValueKey('rhythm_detail_${tool.id}'),
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Divider(height: 1, color: g.line),
                  const SizedBox(height: 14),
                  if (ref.watch(homeShortcutSummaryProvider(tool.id)) ==
                      'Unavailable')
                    TextButton.icon(
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Retry'),
                      onPressed: () {
                        switch (tool.id) {
                          case 'hydration':
                            ref.invalidate(todayWaterMlStreamProvider);
                            ref.invalidate(dailyWaterGoalStreamProvider);
                          case 'walk':
                            ref.invalidate(todayWalkDistanceStreamProvider);
                          case 'medicine':
                            ref.invalidate(todayMedicineLogsStreamProvider);
                          case 'chai-break':
                            ref.invalidate(todayPauseCountProvider);
                          case 'momentum':
                            ref.invalidate(activeChallengeProvider);
                        }
                      },
                    ),
                  if (tool.id == 'hydration') ...[
                    if (goal != null && goal > 0 && water != null) ...[
                      Text(
                        'Daily goal · $goal ml',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: g.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: (water / goal).clamp(0, 1),
                          minHeight: 4,
                          color: blue,
                          backgroundColor: g.line,
                          semanticsLabel:
                              'Daily water goal, $water of $goal millilitres',
                        ),
                      ),
                      const SizedBox(height: 16),
                    ],
                    AscentSegmentedControl<int>(
                      segments: const [
                        AscentSegment(value: 150, label: '150 ml'),
                        AscentSegment(value: 250, label: '250 ml'),
                        AscentSegment(value: 500, label: '500 ml'),
                      ],
                      selected: _amount,
                      enabled: !_saving,
                      onChanged: (value) => setState(() => _amount = value),
                    ),
                    const SizedBox(height: 14),
                    AscentButton.primary(
                      label: 'Log water',
                      expanded: true,
                      compact: true,
                      loading: _saving,
                      onPressed: _saving ? null : _logWater,
                    ),
                    TextButton.icon(
                      onPressed: () => context.push(tool.route),
                      icon: const Icon(Icons.history_rounded, size: 18),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text('Today’s history and goal'),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: SharedControlColors.errorInk(dark),
                          ),
                        ),
                      ),
                  ] else ...[
                    Text(
                      tool.detail,
                      style: AscentTextStyles.bodySmall.copyWith(
                        color: g.inkSecondary,
                      ),
                    ),
                    const SizedBox(height: 14),
                    AscentButton.outlined(
                      label: tool.action,
                      expanded: true,
                      compact: true,
                      onPressed: () => context.push(tool.route),
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}
