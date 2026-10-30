import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
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
  const AscentDynamicIsland({
    super.key,
    this.initiallyExpanded = false,
    this.autoPeek = true,
  });

  final bool initiallyExpanded;
  final bool autoPeek;

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
  bool _manualExpanded = false;
  String? _selectedId;
  String? _dismissedRecapDay;
  String _signature = '';
  bool _hadActivities = false;
  final _dismissedReminders = <String>{};
  late DateTime _now;
  Timer? _clock;
  Timer? _settleTimer;

  String get _day => briefingDay(_now).toIso8601String().split('T').first;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _expanded = widget.initiallyExpanded;
    _manualExpanded = _expanded;
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
    _clock?.cancel();
    _settleTimer?.cancel();
    _expansion.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _now = DateTime.now());
    }
  }

  void _expand(bool value, {bool manual = true}) {
    if (!mounted) return;
    _settleTimer?.cancel();
    if (manual) _manualExpanded = value;
    final changed = _expanded != value;
    setState(() => _expanded = value);
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

  void _syncActivities(List<_IslandActivity> items) {
    final signature =
        '$_day:${items.map((a) => '${a.id}:${a.paused}').join(',')}';
    if (_signature == signature) return;
    _signature = signature;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _signature != signature) return;
      if (items.isEmpty) {
        if (!_hadActivities) return;
        _hadActivities = false;
        _settleTimer?.cancel();
        _manualExpanded = false;
        _selectedId = null;
        _expanded = false;
        _expansion.value = 0;
      } else {
        _hadActivities = true;
        if (!widget.autoPeek || _manualExpanded) return;
        _expand(true, manual: false);
        _settleTimer = Timer(const Duration(seconds: 6), () {
          if (mounted && !_manualExpanded) _expand(false, manual: false);
        });
      }
    });
  }

  void _select(String id) {
    _settleTimer?.cancel();
    _manualExpanded = true;
    setState(() => _selectedId = id);
    _expand(true);
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
    final reminders = ref.watch(allRemindersProvider).value ?? [];
    final upcoming =
        reminders
            .where(
              (r) =>
                  r.isActive &&
                  !r.scheduledAt.isBefore(_now) &&
                  r.scheduledAt.difference(_now) <= const Duration(hours: 2),
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
          label: 'Coming up',
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
      if (briefing != null &&
          (briefing.completedYesterday > 0 ||
              briefing.trackedMinutesYesterday > 0 ||
              briefing.overdue > 0))
        _IslandActivity(
          id: 'summary',
          label: 'Daily recap',
          title: 'Yesterday',
          detail: briefing.overdue > 0
              ? 'Recorded progress, with overdue work to review.'
              : 'Your recorded progress from yesterday.',
          stats: [
            (value: '${briefing.completedYesterday}', label: 'Completed'),
            (
              value: '${briefing.trackedMinutesYesterday}',
              label: 'Minutes tracked',
            ),
            (value: '${briefing.overdue}', label: 'Overdue tasks'),
          ],
          icon: Icons.assignment_outlined,
          route: '/today',
        ),
    ];
  }

  String _group(_IslandActivity item) => item.isLive
      ? 'live'
      : item.id == 'summary'
      ? 'summary'
      : 'next';
  int _count(_IslandActivity item, String label) =>
      int.tryParse(
        item.stats.where((s) => s.label == label).firstOrNull?.value ?? '',
      ) ??
      0;
  Color _accent(_IslandActivity item, IslandPalette p) =>
      item.id == 'summary' && _count(item, 'Overdue tasks') > 0
      ? (p.isDark ? SharedControlColors.dueRedDark : SharedControlColors.dueRed)
      : p.accent;
  String _headline(_IslandActivity item) => item.id == 'summary'
      ? (_count(item, 'Overdue tasks') > 0
            ? '${_count(item, 'Overdue tasks')} overdue ${_count(item, 'Overdue tasks') == 1 ? 'task' : 'tasks'}'
            : 'Yesterday, at a glance')
      : item.title;
  String _subtitle(_IslandActivity item) => item.id == 'summary'
      ? 'Yesterday · ${_count(item, 'Completed')} completed · ${_count(item, 'Minutes tracked')} min tracked'
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
                : preferences.showUpcoming &&
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
                    _manualExpanded = false;
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
              item.paused
                  ? Icons.pause_rounded
                  : item.id == 'summary' && _count(item, 'Overdue tasks') > 0
                  ? Icons.schedule_rounded
                  : item.icon,
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
        _settleTimer?.cancel();
        _manualExpanded = true;
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
                          ? (item.metric ?? 'Yesterday')
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
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          _badge(other, p, size: 27),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Text(
                              '+${items.length - 1}',
                              style: TextStyle(
                                color: p.accent,
                                fontSize: 9,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              if (_expanded)
                IconButton(
                  tooltip: 'Customize Dynamic Island',
                  onPressed: () => showIslandCustomization(context),
                  icon: Icon(Icons.settings_outlined, size: 17, color: p.secondary),
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
    final groups = items.map(_group).toSet().toList();
    final siblings = items.where((a) => _group(a) == _group(item)).toList();
    return ConstrainedBox(
      key: const ValueKey('dynamic_island_expanded'),
      constraints: const BoxConstraints(maxHeight: 330),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 3, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (groups.length > 1) ...[
              AscentSegmentedControl<String>(
                segments: [
                  for (final group in groups)
                    AscentSegment(
                      value: group,
                      key: ValueKey('island_group_$group'),
                      label: switch (group) {
                        'live' => 'Live',
                        'next' => 'Up next',
                        _ => 'Yesterday',
                      },
                    ),
                ],
                selected: _group(item),
                onChanged: (value) =>
                    _select(items.firstWhere((a) => _group(a) == value).id),
              ),
              const SizedBox(height: 12),
            ],
            if (siblings.length > 1) ...[
              AscentSegmentedControl<String>(
                segments: [
                  for (final sibling in siblings)
                    AscentSegment(
                      value: sibling.id,
                      key: ValueKey('island_select_${sibling.id}'),
                      label: sibling.isLive ? sibling.label : sibling.title,
                    ),
                ],
                selected: item.id,
                onChanged: _select,
              ),
              const SizedBox(height: 14),
            ],
            if (item.id == 'summary')
              _statistics(item, p)
            else ...[
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
                          _manualExpanded = true;
                          _settleTimer?.cancel();
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
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: p.secondary, fontSize: 12, height: 1.4),
              ),
            ],
            const SizedBox(height: 8),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => context.push(item.route),
                  icon: const Icon(Icons.open_in_new_rounded, size: 15),
                  label: Text(
                    item.isLive
                        ? 'Open ${item.label.replaceAll(' paused', '')}'
                        : item.id == 'summary'
                        ? 'Review tasks'
                        : 'Open reminder',
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
