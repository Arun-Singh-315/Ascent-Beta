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
    with WidgetsBindingObserver {
  late bool _expanded;
  String? _selectedId;
  String? _dismissedContext;
  late DateTime _now;
  Timer? _clock;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _expanded = widget.initiallyExpanded;
    _now = DateTime.now();
    // Refresh date boundaries and reminder eligibility even without DB writes.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      setState(() => _now = DateTime.now());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    super.dispose();
  }

  void _expand(bool expanded) {
    if (_expanded == expanded) return;
    HapticFeedback.selectionClick();
    setState(() => _expanded = expanded);
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
          title: "Yesterday's Executive Report",
          detail: briefing.overdue > 0
              ? 'Your recorded progress from yesterday, with overdue work to review.'
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

  @override
  Widget build(BuildContext context) {
    final preferences = ref.watch(islandPreferencesProvider);
    final all = _activities();
    final activities = [
      ...all.where((a) => a.isLive && !a.paused),
      if (preferences.showPaused) ...all.where((a) => a.isLive && a.paused),
      ...all.where(
        (a) =>
            !a.isLive &&
            (a.id == 'summary'
                ? preferences.showRecap
                : preferences.showUpcoming),
      ),
    ];
    final contextKey =
        '${briefingDay(_now)}:${activities.where((a) => !a.isLive).map((a) => a.id).join(',')}';
    final visible = activities
        .where((a) => a.isLive || _dismissedContext != contextKey)
        .toList();
    final duration = Duration(
      milliseconds:
          !preferences.animate || MediaQuery.disableAnimationsOf(context)
          ? 0
          : 320,
    );
    if (visible.isEmpty) {
      _selectedId = null;
      _expanded = widget.initiallyExpanded;
    }
    final selected = visible.isEmpty
        ? null
        : visible.firstWhere(
            (a) => a.id == _selectedId,
            orElse: () => visible.first,
          );
    final palette = IslandPalette.resolve(
      preferences.finish,
      Theme.of(context).brightness == Brightness.dark,
    );
    return AnimatedSize(
      duration: duration,
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: selected == null
          ? const SizedBox.shrink()
          : Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Semantics(
                container: true,
                label: 'Ascent live activities',
                child: TapRegion(
                  onTapOutside: (_) => _expand(false),
                  child: GestureDetector(
                    onVerticalDragEnd: _expanded
                        ? null
                        : (details) {
                            if ((details.primaryVelocity ?? 0) > 100) {
                              _expand(true);
                            }
                          },
                    child: IslandSurface(
                      key: const ValueKey('dynamic_island_surface'),
                      palette: palette,
                      radius: _expanded ? 28 : 34,
                      child: DefaultTextStyle.merge(
                        style: TextStyle(color: palette.ink),
                        child: IconTheme(
                          data: IconThemeData(color: palette.accent, size: 22),
                          child: _expanded
                              ? _expandedContent(
                                  visible,
                                  selected,
                                  palette,
                                  contextKey,
                                  duration,
                                )
                              : _compact(
                                  visible,
                                  selected,
                                  palette,
                                  preferences.density,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _activityBadge(
    _IslandActivity item,
    IslandPalette p, {
    double size = 42,
  }) => SizedBox(
    width: size,
    height: size,
    child: Stack(
      alignment: Alignment.center,
      children: [
        Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                p.accent.withValues(alpha: .18),
                p.accent.withValues(alpha: .03),
              ],
            ),
            border: Border.all(color: p.accent.withValues(alpha: .16)),
          ),
        ),
        if (item.progress != null)
          Positioned.fill(
            child: CircularProgressIndicator(
              value: item.progress!.clamp(0, 1),
              strokeWidth: 2,
              strokeCap: StrokeCap.round,
              color: p.accent,
              backgroundColor: p.accent.withValues(alpha: .09),
            ),
          ),
        Icon(
          item.paused ? Icons.pause_rounded : item.icon,
          size: size * .46,
          color: p.accent,
        ),
      ],
    ),
  );

  Widget _compact(
    List<_IslandActivity> items,
    _IslandActivity selected,
    IslandPalette p,
    IslandDensity density,
  ) {
    final extra = items.where((a) => a.id != selected.id).firstOrNull;
    final minimal = density == IslandDensity.minimal;
    return InkWell(
      key: const ValueKey('dynamic_island_compact'),
      onTap: () => _expand(true),
      onLongPress: () => _expand(true),
      borderRadius: BorderRadius.circular(34),
      child: Padding(
        padding: EdgeInsets.fromLTRB(12, minimal ? 8 : 12, 4, minimal ? 8 : 12),
        child: Row(
          children: [
            _activityBadge(selected, p, size: minimal ? 34 : 42),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    minimal ? selected.label : selected.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.ink,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    minimal
                        ? (selected.metric ??
                              (selected.id == 'summary'
                                  ? 'Yesterday'
                                  : selected.detail))
                        : '${selected.label}${selected.metric == null ? '' : ' · ${selected.metric}'}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: p.secondary,
                      fontSize: 12,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            if (extra != null)
              Padding(
                padding: const EdgeInsets.only(left: 6),
                child: Semantics(
                  label:
                      '${items.length - 1} more activities. Show ${extra.title}',
                  button: true,
                  child: Tooltip(
                    message: 'Show ${extra.title}',
                    child: InkWell(
                      key: const ValueKey('island_secondary_activity'),
                      borderRadius: BorderRadius.circular(24),
                      onTap: () {
                        setState(() => _selectedId = extra.id);
                        _expand(true);
                      },
                      child: SizedBox(
                        width: 46,
                        height: 48,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            _activityBadge(extra, p, size: 32),
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                decoration: BoxDecoration(
                                  color: p.tile,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: p.accent.withValues(alpha: .22),
                                  ),
                                ),
                                child: Text(
                                  '+${items.length - 1}',
                                  style: TextStyle(
                                    color: p.accent,
                                    fontSize: 9,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            IconButton(
              tooltip: 'Expand live activities',
              onPressed: () => _expand(true),
              icon: Icon(
                Icons.expand_more_rounded,
                color: p.secondary,
                size: 20,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _activitySelectors(
    List<_IslandActivity> items,
    _IslandActivity selected,
    IslandPalette p,
    Duration duration,
  ) => LayoutBuilder(
    builder: (context, constraints) {
      final columns =
          constraints.maxWidth >= 270 &&
              MediaQuery.textScalerOf(context).scale(1) < 1.5
          ? 2
          : 1;
      final width = (constraints.maxWidth - (columns - 1) * 8) / columns;
      return Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final item in items)
            SizedBox(
              width: width,
              child: Semantics(
                selected: item.id == selected.id,
                button: true,
                child: InkWell(
                  key: ValueKey('island_select_${item.id}'),
                  borderRadius: BorderRadius.circular(18),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _selectedId = item.id);
                  },
                  child: AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Color.alphaBlend(
                        p.accent.withValues(
                          alpha: item.id == selected.id ? .13 : .025,
                        ),
                        p.tile,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: p.accent.withValues(
                          alpha: item.id == selected.id ? .5 : .12,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(item.icon, size: 18, color: p.accent),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.id.startsWith('reminder-')
                                    ? item.title
                                    : item.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: p.ink,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 11,
                                ),
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item.metric ??
                                    (item.id == 'summary'
                                        ? 'Yesterday'
                                        : 'Review'),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: p.secondary,
                                  fontSize: 12,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );

  Widget _statistics(_IslandActivity item, IslandPalette p) {
    String getPhrase(String label, String value) {
      final count = int.tryParse(value) ?? 0;
      switch (label) {
        case 'Completed':
          return count == 1
              ? '1 task finished on schedule'
              : '$count tasks finished on schedule';
        case 'Minutes tracked':
          return '$count minutes of deep tracked flow';
        case 'Overdue tasks':
          return count == 1
              ? '1 overdue task pending review'
              : '$count overdue tasks pending review';
        default:
          return label;
      }
    }

    IconData getIcon(String label) {
      switch (label) {
        case 'Completed':
          return Icons.check_circle_outline_rounded;
        case 'Minutes tracked':
          return Icons.hourglass_bottom_rounded;
        case 'Overdue tasks':
          return Icons.assignment_late_outlined;
        default:
          return Icons.assessment_outlined;
      }
    }

    String getDisplayTitle(String label) {
      switch (label) {
        case 'Completed':
          return 'Completed Tasks';
        case 'Minutes tracked':
          return 'Focus & Flow';
        case 'Overdue tasks':
          return 'Action Needed';
        default:
          return label;
      }
    }

    return Container(
      decoration: BoxDecoration(
        color: p.accent.withValues(alpha: .04),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.accent.withValues(alpha: .12)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.assessment_outlined, size: 14, color: p.accent),
              const SizedBox(width: 6),
              Text(
                'EXECUTIVE AUDIT BREAKDOWN',
                style: TextStyle(
                  color: p.secondary,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.4,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          for (int i = 0; i < item.stats.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child:
                    Divider(color: p.accent.withValues(alpha: .08), height: 1),
              ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.accent.withValues(alpha: .10),
                  ),
                  child: Center(
                    child: Icon(
                      getIcon(item.stats[i].label),
                      size: 16,
                      color: p.accent,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            getDisplayTitle(item.stats[i].label),
                            style: TextStyle(
                              color: p.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            item.stats[i].label,
                            style: TextStyle(
                              color: p.secondary.withValues(alpha: 0.7),
                              fontSize: 10,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                        getPhrase(item.stats[i].label, item.stats[i].value),
                        style: TextStyle(
                          color: p.secondary,
                          fontSize: 11,
                          height: 1.3,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: p.accent.withValues(alpha: .10),
                    borderRadius: BorderRadius.circular(10),
                    border:
                        Border.all(color: p.accent.withValues(alpha: .15)),
                  ),
                  child: Text(
                    item.stats[i].value,
                    style: TextStyle(
                      color: p.accent,
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _expandedContent(
    List<_IslandActivity> items,
    _IslandActivity selected,
    IslandPalette p,
    String contextKey,
    Duration duration,
  ) {
    return Padding(
      key: const ValueKey('dynamic_island_expanded'),
      padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            key: const ValueKey('island_drag_handle'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) < -100) _expand(false);
            },
            child: Row(
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: p.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 7),
                Expanded(
                  child: Text(
                    items.any((a) => a.isLive && !a.paused)
                        ? 'LIVE NOW'
                        : 'AT A GLANCE',
                    style: TextStyle(
                      color: p.secondary,
                      fontSize: 9,
                      letterSpacing: 1.8,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Customize Dynamic Island',
                  onPressed: () => showIslandCustomization(context),
                  icon: Icon(Icons.tune_rounded, size: 18, color: p.secondary),
                ),
                if (!items.any((a) => a.isLive))
                  IconButton(
                    tooltip: 'Dismiss this update',
                    onPressed: () =>
                        setState(() => _dismissedContext = contextKey),
                    icon: Icon(
                      Icons.close_rounded,
                      size: 18,
                      color: p.secondary,
                    ),
                  ),
                IconButton(
                  tooltip: 'Collapse live activities',
                  onPressed: () => _expand(false),
                  icon: Icon(
                    Icons.expand_less_rounded,
                    size: 20,
                    color: p.secondary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              _activityBadge(selected, p, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  selected.label,
                  style: TextStyle(
                    color: p.secondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .2,
                  ),
                ),
              ),
              if (selected.progress != null)
                Text(
                  '${(selected.progress! * 100).round()}%',
                  style: TextStyle(
                    color: p.accent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          AnimatedSwitcher(
            duration: duration,
            switchInCurve: Curves.easeOutCubic,
            layoutBuilder: (current, previous) =>
                current ?? const SizedBox.shrink(),
            child: Align(
              key: ValueKey(selected.id),
              alignment: Alignment.centerLeft,
              child: Text(
                selected.title,
                style: TextStyle(
                  color: p.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
              ),
            ),
          ),
          const SizedBox(height: 7),
          Text(
            selected.detail,
            style: TextStyle(color: p.secondary, fontSize: 12, height: 1.5),
          ),
          if (selected.metric != null) ...[
            const SizedBox(height: 18),
            Text(
              selected.metricCaption,
              style: TextStyle(
                color: p.secondary,
                fontSize: 9,
                letterSpacing: 1.7,
              ),
            ),
            const SizedBox(height: 4),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                selected.metric!,
                style: TextStyle(
                  color: p.accent,
                  fontSize: selected.isLive ? 46 : 30,
                  height: 1.15,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  letterSpacing: -1.8,
                ),
              ),
            ),
          ],
          if (selected.stats.isNotEmpty) ...[
            const SizedBox(height: 18),
            _statistics(selected, p),
          ],
          if (selected.progress != null) ...[
            const SizedBox(height: 16),
            LinearProgressIndicator(
              value: selected.progress!.clamp(0, 1),
              minHeight: 3,
              borderRadius: BorderRadius.circular(3),
              color: p.accent,
              backgroundColor: p.accent.withValues(alpha: .12),
            ),
          ],
          const SizedBox(height: 20),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              if (selected.toggle != null)
                FilledButton.icon(
                  key: ValueKey('island_toggle_${selected.id}'),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() => _selectedId = selected.id);
                    selected.toggle!();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: p.accent,
                    foregroundColor: p.isDark
                        ? const Color(0xFF102B45)
                        : Colors.white,
                  ),
                  icon: Icon(
                    selected.paused
                        ? Icons.play_arrow_rounded
                        : Icons.pause_rounded,
                    size: 18,
                  ),
                  label: Text(selected.paused ? 'Resume' : 'Pause'),
                ),
              OutlinedButton.icon(
                onPressed: () => context.push(selected.route),
                style: OutlinedButton.styleFrom(
                  foregroundColor: p.ink,
                  side: BorderSide(color: p.accent.withValues(alpha: .3)),
                ),
                icon: const Icon(Icons.open_in_new_rounded, size: 16),
                label: Text(selected.isLive ? 'Open' : 'Review'),
              ),
              if (!selected.isLive)
                OutlinedButton.icon(
                  key: const ValueKey('island_dismiss_report_button'),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    setState(() {
                      _dismissedContext = contextKey;
                    });
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: p.secondary,
                    side: BorderSide(color: p.accent.withValues(alpha: .2)),
                  ),
                  icon: const Icon(Icons.done_all_rounded, size: 16),
                  label: const Text('Got it · Dismiss'),
                ),
            ],
          ),
          if (items.length > 1) ...[
            const SizedBox(height: 22),
            Divider(color: p.accent.withValues(alpha: .12), height: 1),
            const SizedBox(height: 16),
            Text(
              'YOUR ACTIVITIES',
              style: TextStyle(
                color: p.secondary,
                fontSize: 9,
                letterSpacing: 1.5,
              ),
            ),
            const SizedBox(height: 10),
            _activitySelectors(items, selected, p, duration),
          ],
        ],
      ),
    );
  }
}
