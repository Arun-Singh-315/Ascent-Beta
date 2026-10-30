import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../core/providers/settings_provider.dart';
import 'dart:async';
import 'package:drift/drift.dart' show BooleanExpressionOperators;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../core/providers/daily_briefing_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../core/providers/island_preferences_provider.dart';
import '../../../core/walk/walk_tracking_service.dart';
import 'island_surface.dart';
import 'island_content.dart';
import 'island_customization_sheet.dart';
import '../../chai_break/chai_break_provider.dart';

// Read the persisted session as well as playback state so a paused lecture
// remains resumable without making every previously studied course appear live.
final islandLectureSessionProvider = StreamProvider.autoDispose<TimeSession?>((
  ref,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.timeSessionTable)
        ..where(
          (s) =>
              s.activityRefType.equals('lecture') &
              s.status.isIn(['running', 'paused']),
        )
        ..limit(1))
      .watchSingleOrNull();
});

/// A live surface, never an app launcher. Every activity keeps its own identity
/// and controls; selecting another activity does not pause the previous one.
class AscentDynamicIsland extends ConsumerStatefulWidget {
  const AscentDynamicIsland({super.key, this.initiallyExpanded = false});

  final bool initiallyExpanded;

  @override
  ConsumerState<AscentDynamicIsland> createState() =>
      _AscentDynamicIslandState();
}

class _IslandActivity {
  const _IslandActivity({
    required this.id,
    required this.label,
    required this.title,
    required this.detail,
    required this.icon,
    required this.route,
    this.metric,
    this.progress,
    this.paused = false,
    this.toggle,
    this.metricCaption = 'ELAPSED',
    this.stats = const [],
  });

  final String id, label, title, detail, route;
  final IconData icon;
  final String? metric;
  final String metricCaption;
  final List<({String value, String label})> stats;
  final double? progress;
  final bool paused;
  final VoidCallback? toggle;
  bool get isLive => toggle != null;
}

class _AscentDynamicIslandState extends ConsumerState<AscentDynamicIsland>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  static const _recapDismissedKey = 'ascent_island_recap_dismissed_day_v1';
  late final AnimationController _expansion;
  late bool _expanded;
  String? _selectedId;
  String? _dismissedRecapDay;
  String _signature = '';
  bool _hadActivities = false;
  final _dismissedReminders = <String>{};
  late DateTime _now;
  Timer? _clock;
  Timer? _recapTimer;
  ScrollPosition? _scrollPosition;

  String get _day => briefingDay(_now).toIso8601String().split('T').first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _expanded = widget.initiallyExpanded;
    _expansion = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 420),
      value: _expanded ? 1 : 0,
    );
    _now = DateTime.now();
    _dismissedRecapDay = ref
        .read(sharedPreferencesProvider)
        .getString(_recapDismissedKey);
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _scrollPosition?.isScrollingNotifier.removeListener(_onScroll);
    _recapTimer?.cancel();
    _clock?.cancel();
    _expansion.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      _signature = '';
      setState(() => _now = DateTime.now());
    } else {
      _recapTimer?.cancel();
      if (state == AppLifecycleState.paused && _selectedId == 'summary') {
        _consumeRecap();
      }
    }
  }

  void _expand(bool value, {bool manual = true}) {
    if (!mounted) return;
    if (!value && _expanded && _selectedId == 'summary') _consumeRecap();
    final changed = _expanded != value;
    setState(() => _expanded = value);
    _scheduleRecapExpiry();
    if (manual && changed) HapticFeedback.selectionClick();
    final animate =
        ref.read(islandPreferencesProvider).animate &&
        !MediaQuery.disableAnimationsOf(context);
    if (animate) {
      _expansion.animateTo(
        value ? 1 : 0,
        duration: const Duration(milliseconds: 420),
        curve: Curves.easeOutCubic,
      );
    } else {
      _expansion.value = value ? 1 : 0;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollPosition?.isScrollingNotifier.removeListener(_onScroll);
    _scrollPosition = Scrollable.maybeOf(context)?.position;
    _scrollPosition?.isScrollingNotifier.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollPosition?.isScrollingNotifier.value != true) return;
    if (_expanded) _expand(false);
    if (_selectedId == 'summary') _consumeRecap();
  }

  Future<void> _consumeRecap() async {
    if (_dismissedRecapDay == _day) return;
    final day = _day;
    // Hide immediately; a failed write leaves it available on the next visit.
    setState(() => _dismissedRecapDay = day);
    await ref
        .read(sharedPreferencesProvider)
        .setString(_recapDismissedKey, day);
  }

  void _syncActivities(List<_IslandActivity> items) {
    final signature = '$_day:${items.map((a) => a.id).join(',')}';
    if (_signature == signature) return;
    _signature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _signature != signature) return;
      if (items.isEmpty) {
        if (!_hadActivities) return;
        _hadActivities = false;
        _selectedId = null;
        _expand(false, manual: false);
      } else {
        _hadActivities = true;
        if (!items.any((a) => a.id == _selectedId)) {
          _selectedId = items.first.id;
        }
        _scheduleRecapExpiry();
      }
    });
  }

  void _scheduleRecapExpiry() {
    _recapTimer?.cancel();
    if (_selectedId != 'summary' || _dismissedRecapDay == _day) return;
    // Remember that this launch already presented the recap, even if the user
    // leaves before the display timeout. No repeat on every home visit.
    ref.read(sharedPreferencesProvider).setString(_recapDismissedKey, _day);
    _recapTimer = Timer(Duration(seconds: _expanded ? 60 : 20), () {
      if (mounted) _consumeRecap();
    });
  }

  void _select(String id) {
    setState(() => _selectedId = id);
    _expand(true);
    _scheduleRecapExpiry();
  }

  Future<void> _dismiss(_IslandActivity item) async {
    if (item.isLive) return;
    if (item.id == 'summary') {
      final saved = await ref
          .read(sharedPreferencesProvider)
          .setString(_recapDismissedKey, _day);
      if (!mounted) return;
      if (!saved) {
        AscentSnackBar.error(
          context,
          message: 'Could not dismiss recap. Please retry.',
        );
        return;
      }
      setState(() => _dismissedRecapDay = _day);
    } else {
      setState(() => _dismissedReminders.add(item.id));
    }
  }

  List<_IslandActivity> _activities() {
    final time = ref.watch(timeTrackingProvider);
    final learning = ref.watch(learningHubProvider);
    final lectureSession = ref.watch(islandLectureSessionProvider).value;
    final walk = ref.watch(walkTrackingProvider);
    final chai = ref.watch(chaiBreakProvider);
    final briefing = ref.watch(dailyBriefingProvider(briefingDay(_now))).value;
    final tasks = ref.watch(islandTasksProvider).value ?? <Task>[];
    final starred = ref.watch(islandStarredTasksProvider(briefingDay(_now)));
    final reminders = ref.watch(allRemindersProvider).value ?? [];
    final upcoming =
        reminders
            .where(
              (r) =>
                  r.isActive &&
                  r.scheduledAt.isAfter(
                    _now.subtract(const Duration(minutes: 15)),
                  ) &&
                  r.scheduledAt.difference(_now) <= const Duration(minutes: 30),
            )
            .toList()
          ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
    return [
      if (time.activeSession != null && (time.isRunning || time.isPaused))
        _IslandActivity(
          id: 'focus',
          label: time.isPaused ? 'Focus paused' : 'Focus',
          title: time.activeSession!.label.isEmpty
              ? 'Focus session'
              : time.activeSession!.label,
          detail:
              'Time spent · ${time.activeCategory?.name ?? 'Focus session'}',
          metric: time.formattedTime,
          icon: Icons.timer_outlined,
          route: '/focus',
          paused: time.isPaused,
          toggle: () {
            final notifier = ref.read(timeTrackingProvider.notifier);
            if (time.isPaused) {
              notifier.resumeSession();
            } else {
              notifier.pauseSession();
            }
          },
        ),
      if (learning.isPlaying ||
          (lectureSession != null &&
              lectureSession.learningCourseId == learning.activeCourseId))
        _IslandActivity(
          id: 'learning',
          label: learning.isPlaying ? 'Learning' : 'Learning paused',
          title: learning.activeLecture.title,
          detail: '${learning.course.title} · time remaining',
          metric: learning.formattedRemaining,
          metricCaption: 'REMAINING',
          progress: learning.progressFraction,
          icon: Icons.school_outlined,
          route: '/learning',
          paused: !learning.isPlaying,
          toggle: () =>
              ref.read(learningHubProvider.notifier).togglePlayPause(),
        ),
      if (walk.status != WalkTrackingStatus.idle)
        _IslandActivity(
          id: 'walk',
          label: walk.status == WalkTrackingStatus.paused
              ? 'Walk paused'
              : 'Walking',
          title: 'Outdoor walk',
          detail: 'Distance and pace from your walking tracker',
          stats: [
            (value: walk.distanceKm.toStringAsFixed(2), label: 'Kilometres'),
            (value: walk.formattedPace, label: 'Pace /km'),
            (value: '${walk.calories}', label: 'Est. kcal'),
          ],
          metric: walk.formattedDuration,
          icon: Icons.directions_walk_rounded,
          route: '/walk',
          paused: walk.status == WalkTrackingStatus.paused,
          toggle: () {
            final notifier = ref.read(walkTrackingProvider.notifier);
            if (walk.status == WalkTrackingStatus.paused) {
              notifier.resumeWalk();
            } else {
              notifier.pauseWalk();
            }
          },
        ),
      if (chai.isRunning || (chai.hasStarted && chai.remainingSeconds > 0))
        _IslandActivity(
          id: 'chai',
          label: chai.isRunning ? 'Chai break' : 'Break paused',
          title:
              chai.isAudioMuted ||
                  chai.selectedSoundscape == SoundscapePreset.silentZen
              ? 'A moment to breathe'
              : chai.isPlayingCustomAudio
              ? (chai.customAudioName ?? 'Your audio')
              : chai.selectedSoundscape.title,
          detail: chai.isAudioMuted
              ? 'Sound muted · time remaining'
              : 'Time remaining · ${chai.selectedSoundscape.description}',
          metric: chai.formattedRemaining,
          metricCaption: 'REMAINING',
          progress: chai.progressFraction,
          icon: Icons.coffee_outlined,
          route: '/chai-break',
          paused: !chai.isRunning,
          toggle: () => ref.read(chaiBreakProvider.notifier).togglePlayPause(),
        ),
      for (final reminder in upcoming)
        _IslandActivity(
          id: 'reminder-${reminder.id}',
          label: reminder.scheduledAt.isAfter(_now) ? 'Coming up' : 'Due now',
          metricCaption: 'UP NEXT',
          title: reminder.title,
          detail:
              'Reminder · ${TimeOfDay.fromDateTime(reminder.scheduledAt).format(context)}',
          metric: reminder.scheduledAt.difference(_now).inMinutes < 1
              ? 'Now'
              : 'in ${reminder.scheduledAt.difference(_now).inMinutes}m',
          icon: Icons.notifications_active_outlined,
          route: '/reminders',
        ),
      for (final task in starred.take(3))
        _IslandActivity(
          id: 'task-${task.id}-$_day',
          label: 'Starred to-do',
          title: task.title,
          detail:
              task.plannedDate != null &&
                  briefingDay(task.plannedDate!).isBefore(briefingDay(_now))
              ? 'Still on your list. Take a step, or choose a better day.'
              : 'You marked this as important. Make room for it when you can.',
          icon: Icons.star_rounded,
          route: '/today',
        ),
      if (briefing != null &&
          (briefing.completedYesterday > 0 ||
              briefing.trackedMinutesYesterday > 0))
        _IslandActivity(
          id: 'summary',
          label: 'A fresh start',
          title: 'Yesterday, then onward',
          detail: islandRecapPoints(briefing, tasks, _now).join('\n\n'),
          icon: Icons.auto_awesome_outlined,
          route: '/today',
        ),
    ];
  }

  Color _accent(_IslandActivity item, IslandPalette p) => p.accent;
  String _headline(_IslandActivity item) => item.title;
  String _subtitle(_IslandActivity item) => item.id == 'summary'
      ? 'A brief reflection'
      : '${item.label}${item.metric == null ? '' : ' · ${item.metric}'}';

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(islandPreferencesProvider);
    final all = _activities();
    final items = [
      ...all.where((a) => a.isLive && !a.paused),
      if (preferences.showPaused) ...all.where((a) => a.isLive && a.paused),
      ...all.where(
        (a) =>
            !a.isLive &&
            (a.id == 'summary'
                ? preferences.showRecap && _dismissedRecapDay != _day
                : (a.id.startsWith('task-') || preferences.showUpcoming) &&
                      !_dismissedReminders.contains(a.id)),
      ),
    ];
    _syncActivities(items);
    if (items.isEmpty) return const SizedBox.shrink();
    final selected = items.firstWhere(
      (a) => a.id == _selectedId,
      orElse: () => items.first,
    );
    final palette = IslandPalette.resolve(
      preferences.finish,
      Theme.of(context).brightness == Brightness.dark,
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: AnimatedBuilder(
        animation: _expansion,
        builder: (context, _) {
          final t = _expansion.value;
          return FractionallySizedBox(
            widthFactor: .96 + .04 * t,
            child: Semantics(
              container: true,
              label: 'Ascent live activities',
              child: TapRegion(
                onTapOutside: (_) {
                  if (_expanded) {
                    _expand(false, manual: false);
                  }
                },
                child: IslandSurface(
                  key: const ValueKey('dynamic_island_surface'),
                  palette: palette,
                  radius: 32 - 5 * t,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _header(items, selected, palette, preferences.density),
                      if (_expanded || t > 0)
                        ClipRect(
                          child: Align(
                            alignment: Alignment.topCenter,
                            heightFactor: t,
                            child: Opacity(
                              opacity: t,
                              child: IgnorePointer(
                                ignoring: t < .95,
                                child: ExcludeSemantics(
                                  excluding: t < .95,
                                  child: _details(items, selected, palette),
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _badge(_IslandActivity item, IslandPalette p, {double size = 32}) =>
      SizedBox(
        width: size,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _accent(item, p).withValues(alpha: .08),
              ),
            ),
            if (item.progress != null)
              Positioned.fill(
                child: CircularProgressIndicator(
                  value: item.progress!.clamp(0, 1),
                  strokeWidth: 2,
                  color: p.accent,
                  backgroundColor: p.accent.withValues(alpha: .08),
                ),
              ),
            Icon(
              item.paused ? Icons.pause_rounded : item.icon,
              color: _accent(item, p),
              size: size * .5,
            ),
          ],
        ),
      );

  Widget _header(
    List<_IslandActivity> items,
    _IslandActivity item,
    IslandPalette p,
    IslandDensity density,
  ) {
    final other = items.where((a) => a.id != item.id).firstOrNull;
    return GestureDetector(
      key: const ValueKey('island_drag_handle'),
      behavior: HitTestBehavior.opaque,
      onVerticalDragStart: (_) {
        _expansion.stop();
      },
      onVerticalDragUpdate: (d) {
        if (!_expanded) setState(() => _expanded = true);
        _expansion.value = (_expansion.value + d.delta.dy / 180).clamp(0, 1);
      },
      onVerticalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        _expand(v.abs() > 150 ? v > 0 : _expansion.value > .35);
      },
      onVerticalDragCancel: () => _expand(_expansion.value > .35),
      child: InkWell(
        key: const ValueKey('dynamic_island_compact'),
        onTap: () => _expand(!_expanded),
        onLongPress: () => _expand(true),
        borderRadius: BorderRadius.circular(32),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 9, 4, 9),
          child: Row(
            children: [
              _badge(item, p),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      density == IslandDensity.minimal
                          ? item.label
                          : _headline(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: item.id == 'summary' ? _accent(item, p) : p.ink,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      density == IslandDensity.minimal
                          ? (item.metric ?? item.title)
                          : _subtitle(item),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: p.secondary,
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
              if (!_expanded && other != null)
                InkWell(
                  key: const ValueKey('island_secondary_activity'),
                  onTap: () => _select(other.id),
                  borderRadius: BorderRadius.circular(22),
                  child: Tooltip(
                    message: 'Show ${other.title}',
                    child: SizedBox(
                      width: 43,
                      height: 44,
                      child: _badge(other, p, size: 27),
                    ),
                  ),
                ),
              if (_expanded)
                IconButton(
                  tooltip: 'Customize Dynamic Island',
                  onPressed: () => showIslandCustomization(context),
                  icon: Icon(
                    Icons.settings_outlined,
                    size: 17,
                    color: p.secondary,
                  ),
                ),
              IconButton(
                tooltip: _expanded
                    ? 'Collapse live activities'
                    : 'Expand live activities',
                onPressed: () => _expand(!_expanded),
                icon: AnimatedRotation(
                  turns: _expansion.value * .5,
                  duration: Duration.zero,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 19,
                    color: p.secondary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _details(
    List<_IslandActivity> items,
    _IslandActivity item,
    IslandPalette p,
  ) {
    return ConstrainedBox(
      key: const ValueKey('dynamic_island_expanded'),
      constraints: const BoxConstraints(maxHeight: 330),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 3, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            ...[
              if (item.metric != null)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.metricCaption,
                            style: TextStyle(
                              color: p.secondary,
                              fontSize: 9,
                              letterSpacing: 1,
                            ),
                          ),
                          const SizedBox(height: 4),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              item.metric!,
                              style: TextStyle(
                                color: p.ink,
                                fontSize: 32,
                                height: 1.1,
                                fontWeight: FontWeight.w500,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (item.toggle != null)
                      FilledButton.icon(
                        key: ValueKey('island_toggle_${item.id}'),
                        onPressed: () {
                          setState(() => _selectedId = item.id);
                          item.toggle!();
                        },
                        icon: Icon(
                          item.paused
                              ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                          size: 17,
                        ),
                        label: Text(item.paused ? 'Resume' : 'Pause'),
                      ),
                  ],
                ),
              if (item.progress != null) ...[
                const SizedBox(height: 13),
                LinearProgressIndicator(
                  value: item.progress!.clamp(0, 1),
                  minHeight: 3,
                  borderRadius: BorderRadius.circular(3),
                  color: p.accent,
                  backgroundColor: p.accent.withValues(alpha: .10),
                ),
              ],
              if (item.stats.isNotEmpty) ...[
                const SizedBox(height: 12),
                _statistics(item, p),
              ],
              const SizedBox(height: 10),
              Text(
                item.detail,
                style: TextStyle(color: p.secondary, fontSize: 13, height: 1.5),
              ),
            ],
            if (items.length > 1) ...[
              const SizedBox(height: 12),
              _activityPicker(items, item),
            ],
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton(
                  onPressed: () => context.push(item.route),
                  child: Text(
                    item.isLive
                        ? 'Open ${item.label.replaceAll(' paused', '')}'
                        : item.id == 'summary'
                        ? 'View ›'
                        : item.id.startsWith('task-')
                        ? 'View to-dos ›'
                        : 'View reminder ›',
                  ),
                ),
                if (!item.isLive)
                  TextButton(
                    key: const ValueKey('island_dismiss_report_button'),
                    onPressed: () => _dismiss(item),
                    child: Text(
                      'Dismiss',
                      style: TextStyle(color: p.secondary),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _activityPicker(
    List<_IslandActivity> items,
    _IslandActivity selected,
  ) {
    final control = AscentSegmentedControl<String>(
      segments: [
        for (final activity in items)
          AscentSegment(
            value: activity.id,
            key: ValueKey('island_select_${activity.id}'),
            label: activity.isLive ? activity.label : activity.title,
          ),
      ],
      selected: selected.id,
      onChanged: _select,
    );
    if (MediaQuery.textScalerOf(context).scale(1) >= 1.45) return control;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: (items.length * 150.0).clamp(
            constraints.maxWidth,
            double.infinity,
          ),
          child: control,
        ),
      ),
    );
  }

  Widget _statistics(_IslandActivity item, IslandPalette p) => LayoutBuilder(
    builder: (context, c) {
      final vertical = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
      return Wrap(
        spacing: 8,
        runSpacing: 10,
        children: [
          for (final stat in item.stats)
            SizedBox(
              width: vertical ? c.maxWidth : (c.maxWidth - 16) / 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      stat.value,
                      style: TextStyle(
                        color:
                            stat.label == 'Overdue tasks' &&
                                (int.tryParse(stat.value) ?? 0) > 0
                            ? (p.isDark
                                  ? SharedControlColors.dueRedDark
                                  : SharedControlColors.dueRed)
                            : stat.label == 'Minutes tracked' &&
                                  (int.tryParse(stat.value) ?? 0) > 0
                            ? p.accent
                            : p.ink,
                        fontSize: 28,
                        fontWeight: FontWeight.w600,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    stat.label,
                    style: TextStyle(
                      color: p.secondary,
                      fontSize: 10,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
        ],
      );
    },
  );
}
