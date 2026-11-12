import 'home_section_heading.dart';
import '../../../core/database/app_database.dart';
import '../../../app/theme/home_design.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import 'home_shortcut_summary.dart';
import 'home_rhythm_artwork.dart';
import 'home_outline_surface.dart';
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
  const _RhythmTool(this.id, this.title, this.detail, this.action, this.route);
  final String id, title, detail, action, route;
}

/// One illustrated ritual at a time, with natural height for accessible text.
class HomeLifeShelf extends ConsumerStatefulWidget {
  const HomeLifeShelf({super.key});
  @override
  ConsumerState<HomeLifeShelf> createState() => _HomeLifeShelfState();
}

class _HomeLifeShelfState extends ConsumerState<HomeLifeShelf> {
  String? _expanded;
  String _current = 'hydration';
  double _dragDistance = 0;
  int _direction = 1;

  void _showTool(List<_RhythmTool> tools, int requestedIndex) {
    if (_saving || tools.isEmpty) return;
    final index = requestedIndex % tools.length;
    final previous = tools.indexWhere((tool) => tool.id == _current);
    if (tools[index].id == _current) return;
    HapticFeedback.selectionClick();
    setState(() {
      _direction = requestedIndex > previous ? 1 : -1;
      _current = tools[index].id;
      _expanded = null;
      _error = null;
    });
  }

  int _amount = 250;
  bool _saving = false;
  String? _error;

  Future<void> _quickLogWater(int amount) async {
    _amount = amount;
    await _logWater();
  }

  Color _getSummaryColor(
    String toolId,
    int? water,
    int? goal,
    List<MedicineLog> doses,
  ) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = HomeDesign.of(context).primaryText;
    final blue = dark
        ? SharedControlColors.actionBlueDark
        : SharedControlColors.actionBlue;
    final red = dark
        ? SharedControlColors.dueRedDark
        : SharedControlColors.dueRed;
    if (toolId == 'hydration') {
      if (water == null) return ink;
      if (water == 0) return HomeDesign.of(context).wellnessInk;
      return goal != null && goal > 0 && water >= goal
          ? blue
          : HomeDesign.of(context).wellnessInk;
    }
    if (toolId == 'medicine') {
      if (doses.any(
        (dose) =>
            !dose.isTaken &&
            (DateTime.tryParse(
                  '${dose.dateStr}T${dose.timeSlot}',
                )?.isBefore(DateTime.now()) ??
                false),
      )) {
        return red;
      }
      return doses.isNotEmpty && doses.every((dose) => dose.isTaken)
          ? blue
          : ink;
    }
    return ink;
  }

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
          'Choose an amount to log',
          'Choose an amount',
          '/hydration',
        ),
      if (layout.tools.contains('walk'))
        _RhythmTool(
          'walk',
          'Move',
          'Keep your walking distance together, one walk at a time.',
          'Start a walk',
          '/walk',
        ),
      if (layout.tools.contains('chai-break'))
        const _RhythmTool(
          'chai-break',
          'Pause',
          'Take a breather',
          'Take a minute',
          '/chai-break',
        ),
      if (layout.tools.contains('medicine'))
        _RhythmTool(
          'medicine',
          'Care',
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
          '/medicine',
        ),
      if (layout.tools.contains('momentum'))
        _RhythmTool(
          'momentum',
          'Momentum',
          challenge?.title ?? 'Choose a challenge to build a little momentum.',
          'View challenge',
          '/momentum',
        ),
    ];

    if (tools.isEmpty) return const SizedBox.shrink();
    final currentIndex = tools.indexWhere((tool) => tool.id == _current);
    final index = currentIndex < 0 ? 0 : currentIndex;
    final current = tools[index];
    final duration = Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: AnimatedSize(
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
        ),
        curve: Curves.easeInOutCubic,
        alignment: Alignment.topCenter,
        child: HomeOutlineSurface(
          surfaceKey: const ValueKey('home_life_shelf_enclosure'),
          frameless: true,
          radius: 30,
          padding: EdgeInsets.zero,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const HomeSectionHeading(title: 'Daily rhythm'),
              const SizedBox(height: 14),
              AscentSegmentedControl<String>(
                key: const ValueKey('rhythm_tool_selector'),
                accented: true,
                inline: true,
                segments: [
                  for (final tool in tools)
                    AscentSegment(
                      value: tool.id,
                      label: tool.title,
                      flex: tool.title.length,
                      key: ValueKey('rhythm_select_${tool.id}'),
                    ),
                ],
                selected: current.id,
                enabled: !_saving,
                onChanged: (id) =>
                    _showTool(tools, tools.indexWhere((tool) => tool.id == id)),
              ),
              const SizedBox(height: 16),
              GestureDetector(
                key: const ValueKey('home_life_shelf'),
                behavior: HitTestBehavior.opaque,
                onHorizontalDragStart: (_) => _dragDistance = 0,
                onHorizontalDragUpdate: (details) =>
                    _dragDistance += details.delta.dx,
                onHorizontalDragEnd: (details) {
                  final velocity = details.primaryVelocity ?? 0;
                  if (_dragDistance.abs() < 40 && velocity.abs() < 250) return;
                  final delta = _dragDistance.abs() >= 40
                      ? _dragDistance
                      : velocity;
                  final rtl = Directionality.of(context) == TextDirection.rtl;
                  _showTool(tools, index + ((delta < 0) != rtl ? 1 : -1));
                },
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Padding(
                      padding: EdgeInsets.zero,
                      child: ClipRRect(
                        borderRadius: BorderRadius.zero,
                        child: ColoredBox(
                          color: Colors.transparent,
                          child: AnimatedSwitcher(
                            duration: duration,
                            switchInCurve: Curves.easeOutCubic,
                            switchOutCurve: Curves.easeInCubic,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween<Offset>(
                                      begin: Offset(.12 * _direction, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: SizedBox(
                              key: ValueKey('rhythm_card_${current.id}'),
                              width: double.infinity,
                              child: _tile(current, dark, g, water, goal),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
    if (tool.id == 'hydration' &&
        goal != null &&
        goal > 0 &&
        water != null &&
        water > 0) {
      progress = (water / goal).clamp(0.0, 1.0);
    }

    final summary = ref
        .watch(homeShortcutSummaryProvider(tool.id))
        .replaceFirst(RegExp(r' today$'), '');

    final doses = ref.watch(todayMedicineLogsStreamProvider).value ?? [];
    final challenge = ref.watch(activeChallengeProvider).value;
    final summaryColor = _getSummaryColor(tool.id, water, goal, doses);

    final design = HomeDesign.of(context);
    final metric = AnimatedSwitcher(
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 220,
      ),
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      child: KeyedSubtree(
        key: ValueKey(summary),
        child: Text(
          summary,
          key: ValueKey('rhythm_summary_${tool.id}'),
          style:
              (RegExp(r'^\d').hasMatch(summary)
                      ? HomeType.metric
                      : HomeType.section)
                  .copyWith(color: summaryColor),
        ),
      ),
    );
    return Container(
      decoration: HomeSurfaceStyle.wellness(context),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.zero,
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            // Subtle colored left-edge accent bar
            Positioned(
              top: 0,
              bottom: 0,
              left: 0,
              child: Container(
                width: 3,
                decoration: BoxDecoration(
                  color: design.wellnessInk.withValues(alpha: 0.55),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(3),
                    bottomLeft: Radius.circular(3),
                  ),
                ),
              ),
            ),
            Column(
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
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final details = Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                tool.title,
                                style: HomeType.section.copyWith(
                                  color: design.wellnessInk,
                                  fontSize: 17,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 18),
                              if (tool.id == 'hydration') ...[
                                Text(
                                  'DRANK TODAY',
                                  style: HomeType.label.copyWith(
                                    color: design.wellnessInk,
                                  ),
                                ),
                                const SizedBox(height: 6),
                              ],
                              metric,
                            ],
                          );
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              Expanded(child: details),
                              if (constraints.maxWidth >= 270 &&
                                  MediaQuery.textScalerOf(context).scale(1) <
                                      1.45 &&
                                  summary.length < 20) ...[
                                const SizedBox(width: 12),
                                ExcludeSemantics(
                                  child: CustomPaint(
                                    size: const Size(108, 116),
                                    painter: HomeRhythmArtwork(
                                      id: tool.id,
                                      dark: dark,
                                      tint: design.wellnessInk,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 12),
                      Text(switch (tool.id) {
                        'hydration' =>
                          goal != null && goal > 0 && water != null
                              ? water >= goal
                                    ? 'Daily goal reached · $goal ml'
                                    : '${(goal - water).clamp(0, goal)} ml left · Goal $goal ml'
                              : 'Build a little refresh into your day.',
                        'medicine' =>
                          doses.isEmpty
                              ? 'Add medicines and dose times when you need them.'
                              : tool.detail,
                        'momentum' =>
                          challenge == null
                              ? tool.detail
                              : 'One step at a time. Open your challenge for the next action.',
                        _ => tool.detail,
                      }, style: HomeType.supporting.copyWith(color: g.inkSecondary)),
                      if (progress != null && !selected) ...[
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(3),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 4,
                            backgroundColor: g.line.withValues(alpha: 0.25),
                            valueColor: AlwaysStoppedAnimation<Color>(blue),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
            if (!selected && tool.id == 'hydration')
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: Row(
                  children: [
                    Expanded(
                      child: AscentButton.primary(
                        label: '+250 ml',
                        compact: true,
                        onPressed: _saving ? null : () => _quickLogWater(250),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AscentButton.primary(
                        label: '+500 ml',
                        compact: true,
                        onPressed: _saving ? null : () => _quickLogWater(500),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: AscentButton.secondary(
                        label: 'Custom',
                        compact: true,
                        onPressed: _saving ? null : () => _toggle(tool.id),
                      ),
                    ),
                  ],
                ),
              ),
            if (!selected && tool.id != 'hydration')
              Padding(
                padding: const EdgeInsets.only(bottom: 24),
                child: AscentButton.primary(
                  label: tool.action,
                  icon: Icons.arrow_forward_rounded,
                  expanded: true,
                  compact: true,
                  onPressed: _saving
                      ? null
                      : () {
                          context.push(tool.route);
                        },
                ),
              ),
            if (selected)
              Padding(
                key: ValueKey('rhythm_detail_${tool.id}'),
                padding: const EdgeInsets.only(bottom: 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(child: Divider(height: 1, color: g.line)),
                        IconButton(
                          tooltip: 'Close details',
                          onPressed: _saving ? null : () => _toggle(tool.id),
                          icon: Icon(
                            Icons.keyboard_arrow_up_rounded,
                            color: blue,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    if (ref.watch(homeShortcutSummaryProvider(tool.id)) ==
                        'Unavailable')
                      AscentButton.ghost(
                        label: 'Retry',
                        icon: Icons.refresh_rounded,
                        compact: true,
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
                          style: AscentTextStyles.interfaceLabel.copyWith(
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
                        accented: true,
                        inline: true,
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
                        label: 'Add $_amount ml',
                        expanded: true,
                        compact: true,
                        loading: _saving,
                        onPressed: _saving ? null : _logWater,
                      ),
                      AscentButton.ghost(
                        label: 'Today’s history and goal',
                        icon: Icons.history_rounded,
                        compact: true,
                        onPressed: () => context.push(tool.route),
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
                        style: AscentTextStyles.interfaceSupporting.copyWith(
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
          ],
        ),
      ),
    );
  }
}
