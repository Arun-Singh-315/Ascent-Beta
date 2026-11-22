import '../../shared/widgets/ascent_dialog.dart';
import '../../shared/widgets/glass_surface.dart';
import '../../shared/widgets/history_action.dart';
import '../../shared/widgets/music_companion_card.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/widgets/live_session_bar.dart';
import '../today/add_activity_sheet.dart';

class FocusScreen extends ConsumerStatefulWidget {
  const FocusScreen({super.key});

  @override
  ConsumerState<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends ConsumerState<FocusScreen> {
  bool _showStats = false;
  final _addTaskController = TextEditingController();

  @override
  void dispose() {
    _addTaskController.dispose();
    super.dispose();
  }

  String _formatDuration(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
    }
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  String _formatMinutes(int seconds) {
    final m = seconds ~/ 60;
    if (m >= 60) return '${(m / 60).toStringAsFixed(1)}h';
    return '${m}m';
  }

  String _formatHoursAndMinutes(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) {
      return '${h}h ${m}m';
    }
    return '${m}m';
  }

  int? _targetSeconds(int? taskId, List<Task> tasks) {
    if (taskId == null) return null;
    for (final t in tasks) {
      if (t.id == taskId) {
        final m = t.estimatedMinutes;
        return (m == null || m <= 0) ? null : m * 60;
      }
    }
    return null;
  }

  Future<void> _addTaskForToday(String title) async {
    if (title.trim().isEmpty) return;
    final taskDao = ref.read(taskDaoProvider);
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    await taskDao.insertTask(
      TaskTableCompanion.insert(
        title: title.trim(),
        plannedDate: drift.Value(today),
        priority: const drift.Value('normal'),
      ),
    );
    _addTaskController.clear();
    ref.invalidate(todayFocusTaskProvider);
  }

  Future<void> _confirmCompleteSession(
    String taskTitle,
    String totalTime,
  ) async {
    final active = ref.read(timeTrackingProvider).activeSession;
    if (active == null) return;
    final remaining = await ref
        .read(timeSessionDaoProvider)
        .focusSecondsRemaining(active.id);
    if (!mounted) return;
    if (remaining > 0) {
      AscentSnackBar.show(
        context,
        message: 'Keep focusing: ${_formatDuration(remaining)} remaining before this activity can be completed.',
      );
      return;
    }
    final confirm = await AscentDialog.confirm(
      context: context,
      title: 'Complete session?',
      content: 'Complete session for "$taskTitle"?\nTotal duration: $totalTime',
      confirmLabel: 'Complete',
      cancelLabel: 'Keep focusing',
      icon: Icons.check_circle_outline_rounded,
    );

    if (confirm == true && mounted) {
      final tracking = ref.read(timeTrackingProvider);
      final linkedTask = tracking.activeSession?.linkedTaskId == null
          ? null
          : await ref
                .read(taskDaoProvider)
                .getTaskById(tracking.activeSession!.linkedTaskId!);
      final taskCompleted = await ref
          .read(timeTrackingProvider.notifier)
          .completeSession();
      if (tracking.activeSession != null &&
          await ref
                  .read(timeSessionDaoProvider)
                  .focusSecondsRemaining(tracking.activeSession!.id) >
              0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'The activity target has changed. Keep focusing to complete it.',
              ),
            ),
          );
        }
        return;
      }
      ref.invalidate(todayFocusTaskProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              linkedTask != null &&
                      linkedTask.estimatedMinutes != null &&
                      linkedTask.estimatedMinutes! > 0 &&
                      !taskCompleted
                  ? 'Session saved ($totalTime). Keep focusing until "$taskTitle" reaches its ${linkedTask.estimatedMinutes}-minute target.'
                  : 'Session completed for "$taskTitle" ($totalTime)',
            ),
            backgroundColor: context.accentPrimary,
            duration: const Duration(seconds: 2),
            behavior: SnackBarBehavior.floating,
          ),
        );
        if (Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      }
    }
  }

  Future<void> _showSwitchTaskSheet(
    BuildContext context,
    List<Task> tasks,
  ) async {
    await showAscentFrostedDialog<void>(
      context: context,
      builder: (sheetCtx) {
        final activeTaskId = ref
            .watch(timeTrackingProvider)
            .activeSession
            ?.linkedTaskId;
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: 440,
                maxHeight: MediaQuery.sizeOf(sheetCtx).height * 0.7,
              ),
              child: Material(
                color: sheetCtx.glass.bg,
                shape: ContinuousRectangleBorder(
                  borderRadius: BorderRadius.circular(32),
                ),
                clipBehavior: Clip.antiAlias,
                child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s20,
              AppSpace.s20,
              AppSpace.s20,
              AppSpace.s20,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Switch Task',
                  style: AscentTextStyles.displaySmall.copyWith(
                    color: sheetCtx.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current session will pause and your new task will start tracking immediately.',
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: sheetCtx.textMuted,
                  ),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ...tasks.where((t) => t.actualCompletedDate == null).map((
                        task,
                      ) {
                        final isCurrent = task.id == activeTaskId;
                        return ListTile(
                          shape: RoundedRectangleBorder(
                            borderRadius: AppGeometry.roundedr12,
                          ),
                          tileColor: isCurrent
                              ? sheetCtx.accentPrimary.withValues(alpha: 0.1)
                              : null,
                          leading: Icon(
                            isCurrent
                                ? Icons.radio_button_checked
                                : Icons.radio_button_unchecked,
                            color: isCurrent
                                ? sheetCtx.accentPrimary
                                : sheetCtx.textMuted,
                          ),
                          title: Text(
                            task.title,
                            style: AscentTextStyles.bodyMedium
                                .copyWith(color: sheetCtx.textPrimary)
                                .merge(
                                  AppStateTypography.stateType6(
                                    state0: isCurrent,
                                  ),
                                ),
                          ),
                          trailing: isCurrent
                              ? Text(
                                  'Active',
                                  style: AppTypeRoles.typeRole27.copyWith(
                                    color: sheetCtx.accentPrimary,
                                  ),
                                )
                              : null,
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            if (!isCurrent) {
                              ref
                                  .read(timeTrackingProvider.notifier)
                                  .switchToTask(
                                    title: task.title,
                                    taskId: task.id,
                                  );
                            }
                          },
                        );
                      }),
                      ListTile(
                        shape: RoundedRectangleBorder(
                          borderRadius: AppGeometry.roundedr12,
                        ),
                        leading: Icon(
                          Icons.add_rounded,
                          color: sheetCtx.accentPrimary,
                        ),
                        title: Text(
                          'Start untracked or custom activity...',
                          style: AscentTextStyles.bodyMedium.copyWith(
                            color: sheetCtx.accentPrimary,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(sheetCtx).pop();
                          showStartSessionSheet(context, ref);
                        },
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(timeTrackingProvider);
    final today = DateTime(
      DateTime.now().year,
      DateTime.now().month,
      DateTime.now().day,
    );
    final todayTasksAsync = ref.watch(todayTimeSessionsProvider(today));
    final todayTasks = ref.watch(_todayTasksProvider(today));

    // Calculate total logged today across all tasks (completed + active)
    final todaySessions = todayTasksAsync.value ?? [];
    int totalLoggedTodaySeconds = 0;
    bool activeIncluded = false;
    for (final s in todaySessions) {
      if (s.id == trackingState.activeSession?.id) {
        totalLoggedTodaySeconds += trackingState.elapsedSeconds;
        activeIncluded = true;
      } else {
        totalLoggedTodaySeconds += TimeSessionDao.computeActiveDurationSeconds(
          s.startedAt,
          s.endedAt ?? (s.status == 'running' ? DateTime.now() : s.startedAt),
          s.pausedIntervals,
        );
      }
    }
    if (!activeIncluded && trackingState.activeSession != null) {
      totalLoggedTodaySeconds += trackingState.elapsedSeconds;
    }

    final g = context.glass;

    return AscentScaffold(
      title: 'Focus Timer',
      subtitle: 'One thing at a time',
      actions: [
        const HistoryAction(module:'focus'),
        IconButton(
          onPressed: () {
            HapticFeedback.lightImpact();
            setState(() => _showStats = !_showStats);
          },
          icon: Icon(
            _showStats ? Icons.bar_chart_rounded : Icons.bar_chart_outlined,
            color: _showStats ? g.clay : g.inkMuted,
          ),
          tooltip: 'Today\'s stats',
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s20),
        children: [
          // ── Today across all tasks strip ───────────────────────────
          GlassSurface(
            radius: 14,
            fillColor: g.isDark
                ? g.elevated
                : g.fill.withValues(alpha: 0.5),
            customBorder: Border.all(
              color: g.line.withValues(alpha: 0.25),
              width: 1.0,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s16,
              vertical: AppSpace.s12,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.schedule_rounded,
                  size: 16,
                  color: g.clay,
                ),
                const SizedBox(width: 8),
                Text(
                  'Today across all tasks:',
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: g.inkMuted,
                  ),
                ),
                const Spacer(),
                Text(
                  _formatHoursAndMinutes(totalLoggedTodaySeconds),
                  style: AppTypography.jetBrainsMonoInheritedRegular72(
                    textStyle: AscentTextStyles.labelMedium
                        .copyWith(
                          color: g.clay,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                Text(
                  ' logged',
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: g.inkMuted,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // ── Big Clock ──────────────────────────────────────────────
          _BigClockCard(
            trackingState: trackingState,
            formatDuration: _formatDuration,
            targetSeconds: _targetSeconds(
              trackingState.activeSession?.linkedTaskId,
              todayTasks.value ?? const <Task>[],
            ),
            onStart: () => showStartSessionSheet(context, ref),
            onPause: () =>
                ref.read(timeTrackingProvider.notifier).pauseSession(),
            onResume: () =>
                ref.read(timeTrackingProvider.notifier).resumeSession(),
            onSwitchTask: () {
              final tasks = todayTasks.value ?? [];
              _showSwitchTaskSheet(context, tasks);
            },
            onComplete: () {
              final title =
                  trackingState.activeSession?.label ?? 'Current session';
              final totalTime = _formatDuration(trackingState.elapsedSeconds);
              _confirmCompleteSession(title, totalTime);
            },
          ),

          const SizedBox(height: 10),

          // ── Focus Audio Dock / Study Soundtrack ───────────────────
          const MusicCompanionCard(),

          const SizedBox(height: 16),

          // ── Stats Panel ──────────────────────────────────────────
          if (_showStats) ...[
            _StatsPanel(
              todayTasksAsync: todayTasksAsync,
              formatMinutes: _formatMinutes,
            ),
            const SizedBox(height: 16),
          ],

          // ── Today's Tasks ────────────────────────────────────────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Today's Tasks",
                style: AscentTextStyles.labelLarge.copyWith(
                  color: context.textPrimary,
                ),
              ),
              Text(
                DateFormat('EEEE, MMM d').format(DateTime.now()),
                style: AscentTextStyles.bodySmall.copyWith(
                  color: context.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Task List
          todayTasks.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpace.s20),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, _) => const SizedBox.shrink(),
            data: (tasks) {
              if (tasks.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s16),
                  child: Text(
                    'No tasks planned for today.\nAdd one below to get started!',
                    style: AscentTextStyles.bodyMedium.copyWith(
                      color: context.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                );
              }

              return Column(
                children: tasks.map((task) {
                  final isActive =
                      trackingState.activeSession?.linkedTaskId == task.id;
                  final isDone = task.actualCompletedDate != null;

                  // Find time spent on this task today
                  final taskSeconds =
                      todayTasksAsync.value
                          ?.where((s) => s.linkedTaskId == task.id)
                          .fold<int>(0, (acc, s) {
                            return acc +
                                TimeSessionDao.computeActiveDurationSeconds(
                                  s.startedAt,
                                  s.endedAt ??
                                      (s.status == 'running'
                                          ? DateTime.now()
                                          : s.startedAt),
                                  s.pausedIntervals,
                                );
                          }) ??
                      0;

                  final isTodoOnly =
                      task.estimatedMinutes == null ||
                      task.estimatedMinutes == 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s8),
                    child: _TaskRow(
                      task: task,
                      isActive: isActive,
                      isDone: isDone,
                      timeSpent: _formatMinutes(taskSeconds),
                      onEdit: () {
                        AddActivitySheet.show(context, existingTask: task);
                      },
                      onTap: isDone
                          ? null
                          : (isTodoOnly
                                ? () async {
                                    final taskDao = ref.read(taskDaoProvider);
                                    HapticFeedback.lightImpact();
                                    await taskDao.markComplete(task.id);
                                    ref.invalidate(todayFocusTaskProvider);
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Completed "${task.title}"',
                                          ),
                                          duration: const Duration(seconds: 2),
                                          behavior: SnackBarBehavior.floating,
                                        ),
                                      );
                                    }
                                  }
                                : () {
                                    ref
                                        .read(timeTrackingProvider.notifier)
                                        .switchToTask(
                                          title: task.title,
                                          taskId: task.id,
                                        );
                                  }),
                      onToggleDone: () async {
                        final taskDao = ref.read(taskDaoProvider);
                        if (isDone) {
                          AscentSnackBar.show(
                            context,
                            message: 'Completed tasks cannot be reopened.',
                          );
                          return;
                        }
                        if (!isTodoOnly) {
                          AscentSnackBar.show(
                            context,
                            message:
                                'Timed activities complete after their focus target is reached.',
                          );
                          return;
                        }
                        await taskDao.markComplete(task.id);
                        ref.invalidate(todayFocusTaskProvider);
                      },
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 12),

          // Add Task Input
          _AddTaskRow(controller: _addTaskController, onAdd: _addTaskForToday),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Provider for today's tasks ─────────────────────────────────────────────────

final _todayTasksProvider = StreamProvider.family<List<Task>, DateTime>((
  ref,
  date,
) {
  final dao = ref.watch(taskDaoProvider);
  return dao.watchTasksByDate(date);
});

// ── Big Clock Card ─────────────────────────────────────────────────────────────

class _BigClockCard extends StatelessWidget {
  final TimeTrackingState trackingState;
  final String Function(int) formatDuration;
  final int? targetSeconds;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onResume;
  final VoidCallback onSwitchTask;
  final VoidCallback onComplete;

  const _BigClockCard({
    required this.trackingState,
    required this.formatDuration,
    required this.onStart,
    required this.onPause,
    required this.onResume,
    required this.onSwitchTask,
    required this.onComplete,
    this.targetSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = trackingState.isRunning;
    final isPaused = trackingState.isPaused;
    final hasSession = trackingState.activeSession != null;
    final elapsed = trackingState.elapsedSeconds;
    final g = context.glass;
    final target = targetSeconds;
    final hasTarget = hasSession && target != null && target > 0;
    final progress = hasTarget
        ? (elapsed / target).clamp(0.0, 1.0)
        : (hasSession ? (elapsed % 60) / 60.0 : 0.0);
    final remaining = hasTarget ? (target - elapsed).clamp(0, target) : 0;

    return GlassSurface(
      radius: 28,
      fillColor: g.isDark ? g.elevated : g.fill.withValues(alpha: 0.65),
      customBorder: Border.all(color: g.line.withValues(alpha: 0.3), width: 1.0),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s20,
        vertical: AppSpace.s24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Task label
          Text(
            hasSession ? trackingState.activeSession!.label : 'Ready when you are',
            style: AscentTextStyles.bodyMedium.copyWith(
              color: hasSession ? g.ink : g.inkMuted,
              fontWeight: hasSession ? FontWeight.w600 : FontWeight.w400,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpace.s20),

          // Progress ring with the clock inside
          SizedBox(
            width: 240,
            height: 240,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween<double>(end: progress),
                  duration: const Duration(milliseconds: 350),
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) => CustomPaint(
                    size: const Size.square(240),
                    painter: _FocusRingPainter(
                      progress: value,
                      track: g.line.withValues(alpha: 0.35),
                      color: isPaused ? g.amber : g.clay,
                      active: hasSession,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 36),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Semantics(
                        label: 'Focus time',
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            hasSession ? formatDuration(elapsed) : '00:00',
                            style: AscentTextStyles.focusTimer.copyWith(
                              color: isPaused
                                  ? g.inkMuted
                                  : (hasSession ? g.ink : g.inkSecondary),
                              letterSpacing: 1.5,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        isPaused
                            ? 'Paused'
                            : hasTarget
                            ? (remaining > 0
                                  ? '${formatDuration(remaining)} left'
                                  : 'Target reached')
                            : (isRunning ? 'Focusing' : 'No session'),
                        style: AscentTextStyles.bodySmall.copyWith(
                          color: isPaused ? g.amber : g.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s24),

          // Controls
          if (!hasSession)
            AscentButton.primary(
              label: 'Start Focus Session',
              icon: Icons.play_arrow_rounded,
              compact: true,
              onPressed: () {
                HapticFeedback.selectionClick();
                onStart();
              },
            )
          else
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                _RoundControl(
                  icon: Icons.swap_horiz_rounded,
                  tooltip: 'Switch task',
                  onTap: onSwitchTask,
                ),
                const SizedBox(width: AppSpace.s24),
                _RoundControl(
                  icon: isRunning
                      ? Icons.pause_rounded
                      : Icons.play_arrow_rounded,
                  tooltip: isRunning ? 'Pause' : 'Resume',
                  primary: true,
                  onTap: isRunning ? onPause : onResume,
                ),
                const SizedBox(width: AppSpace.s24),
                _RoundControl(
                  icon: Icons.check_rounded,
                  tooltip: 'Complete session',
                  onTap: onComplete,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _RoundControl extends StatefulWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final bool primary;

  const _RoundControl({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.primary = false,
  });

  @override
  State<_RoundControl> createState() => _RoundControlState();
}

class _RoundControlState extends State<_RoundControl> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final size = widget.primary ? 72.0 : 52.0;
    return Tooltip(
      message: widget.tooltip,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapCancel: () => setState(() => _pressed = false),
        onTapUp: (_) => setState(() => _pressed = false),
        onTap: () {
          HapticFeedback.selectionClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _pressed ? 0.94 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: widget.primary ? g.clay : g.claySoft,
              border: widget.primary
                  ? null
                  : Border.all(color: g.line.withValues(alpha: 0.5), width: 1.0),
            ),
            child: Icon(
              widget.icon,
              size: widget.primary ? 34 : 24,
              color: widget.primary ? g.bg : g.ink,
            ),
          ),
        ),
      ),
    );
  }
}

class _FocusRingPainter extends CustomPainter {
  final double progress;
  final Color track;
  final Color color;
  final bool active;

  const _FocusRingPainter({
    required this.progress,
    required this.track,
    required this.color,
    required this.active,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 8.0;
    final rect = Rect.fromLTWH(
      stroke / 2,
      stroke / 2,
      size.width - stroke,
      size.height - stroke,
    );
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(rect, 0, 6.283185307179586, false, base);
    if (!active || progress <= 0) return;
    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..color = color;
    canvas.drawArc(rect, -1.5707963267948966, 6.283185307179586 * progress, false, arc);
  }

  @override
  bool shouldRepaint(_FocusRingPainter old) =>
      old.progress != progress ||
      old.track != track ||
      old.color != color ||
      old.active != active;
}

// ── Stats Panel ────────────────────────────────────────────────────────────────

class _StatsPanel extends ConsumerWidget {
  final AsyncValue<List<TimeSession>> todayTasksAsync;
  final String Function(int) formatMinutes;

  const _StatsPanel({
    required this.todayTasksAsync,
    required this.formatMinutes,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    return todayTasksAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => const SizedBox.shrink(),
      data: (sessions) {
        int studySeconds = 0;
        int breakSeconds = 0;
        for (final s in sessions) {
          final dur = TimeSessionDao.computeActiveDurationSeconds(
            s.startedAt,
            s.endedAt ?? (s.status == 'running' ? DateTime.now() : s.startedAt),
            s.pausedIntervals,
          );
          if (s.activityType.toLowerCase() == 'entertainment') {
            breakSeconds += dur;
          } else {
            studySeconds += dur;
          }
        }

        return GlassSurface(
          radius: 18,
          fillColor: g.isDark
              ? g.elevated
              : g.fill.withValues(alpha: 0.5),
          customBorder: Border.all(
            color: g.line.withValues(alpha: 0.25),
            width: 1.0,
          ),
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Today's Stats",
                style: AscentTextStyles.labelMedium.copyWith(
                  color: g.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatChip(
                    label: 'Study',
                    value: formatMinutes(studySeconds),
                    color: g.clay,
                    icon: Icons.school_rounded,
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    label: 'Break',
                    value: formatMinutes(breakSeconds),
                    color: g.amber,
                    icon: Icons.sports_esports_rounded,
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    label: 'Sessions',
                    value: '${sessions.length}',
                    color: g.sage,
                    icon: Icons.repeat_rounded,
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  final IconData icon;

  const _StatChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s10,
          vertical: AppSpace.s10,
        ),
        decoration: BoxDecoration(
          color: color.withValues(alpha: g.isDark ? 0.12 : 0.08),
          borderRadius: AppGeometry.roundedr12,
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: AscentTextStyles.statMedium.copyWith(
                color: g.ink,
                fontWeight: FontWeight.w600,
              ),
            ),
            Text(
              label,
              style: AppTypeRoles.typeRole18.copyWith(color: g.inkMuted),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Task Row ───────────────────────────────────────────────────────────────────

class _TaskRow extends StatelessWidget {
  final Task task;
  final bool isActive;
  final bool isDone;
  final String timeSpent;
  final VoidCallback? onTap;
  final VoidCallback onToggleDone;
  final VoidCallback? onEdit;

  const _TaskRow({
    required this.task,
    required this.isActive,
    required this.isDone,
    required this.timeSpent,
    this.onTap,
    required this.onToggleDone,
    this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final isTodoOnly =
        task.estimatedMinutes == null || task.estimatedMinutes == 0;

    return AppTapArea(
      onTap: onTap,
      borderRadius: AppGeometry.roundedr14,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s14,
          vertical: AppSpace.s11,
        ),
        decoration: AppCard.decoration(
          context,
          selected: isActive,
          night: BoxDecoration(
            color: isActive
                ? context.accentPrimary.withValues(alpha: 0.12)
                : context.bgSurface,
            borderRadius: AppGeometry.roundedr14,
            border: Border.all(
              color: isActive
                  ? context.accentPrimary.withValues(alpha: 0.4)
                  : context.divider,
              width: isActive ? 1.5 : 1.0,
            ),
          ),
        ),
        child: Row(
          children: [
            // Done checkbox
            AppGestureTap(
              onTap: onToggleDone,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: AppTag.decoration(
                  context,
                  night: BoxDecoration(
                    color: isDone
                        ? context.accentPrimary.withValues(alpha: 0.15)
                        : AppPalette.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDone ? context.accentPrimary : context.divider,
                      width: AppBorderScale.w2,
                    ),
                  ),
                ),
                child: isDone
                    ? Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: context.accentPrimary,
                      )
                    : null,
              ),
            ),
            const SizedBox(width: 12),

            // Task title + chips
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: AscentTextStyles.bodyMedium
                        .copyWith(
                          color: isDone
                              ? context.textMuted
                              : context.textPrimary,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : null,
                        )
                        .merge(AppStateTypography.stateType6(state0: isActive)),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      AppTag(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s5,
                          vertical: AppSpace.s1,
                        ),
                        nightDecoration: BoxDecoration(
                          color: context.bgBase,
                          borderRadius: AppGeometry.roundedr5,
                          border: Border.all(
                            color: context.divider,
                            width: AppBorderScale.w0point6,
                          ),
                        ),
                        child: Text(
                          isTodoOnly
                              ? (task.priority.toUpperCase())
                              : (task.estimatedMinutes == -1
                                    ? 'FLEXIBLE'
                                    : '${task.estimatedMinutes}M TIMER'),
                          style: AppTypeRoles.typeRole62.copyWith(
                            color: context.textMuted,
                          ),
                        ),
                      ),
                      if (timeSpent != '0m') ...[
                        const SizedBox(width: 6),
                        Text(
                          timeSpent,
                          style:
                              AppStateTypography.stateType22(
                                state0: isActive,
                              ).copyWith(
                                color: isActive
                                    ? context.accentPrimary
                                    : context.textMuted,
                              ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 6),

            // Edit button
            if (onEdit != null)
              IconButton(
                icon: Icon(
                  Icons.edit_outlined,
                  size: 16,
                  color: context.textMuted,
                ),
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 26, minHeight: 26),
                tooltip: 'Edit task',
                onPressed: onEdit,
              ),

            // Active indicator / Finish chip (for To-Do) / Start timer button (for Timed)
            if (isActive)
              AppTag(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s8,
                  vertical: AppSpace.s4,
                ),
                nightDecoration: BoxDecoration(
                  color: context.accentPrimary,
                  borderRadius: AppGeometry.roundedr8,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.radio_button_on_rounded,
                      size: 10,
                      color: context.textOnPrimary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'Active',
                      style: AppTypeRoles.typeRole3.copyWith(
                        color: context.textOnPrimary,
                      ),
                    ),
                  ],
                ),
              )
            else if (!isDone) ...[
              if (isTodoOnly)
                AppTapArea(
                  onTap: onToggleDone,
                  borderRadius: AppGeometry.roundedr8,
                  child: AppTag(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s8,
                      vertical: AppSpace.s4,
                    ),
                    nightDecoration: BoxDecoration(
                      color: context.accentPrimary.withValues(alpha: 0.12),
                      borderRadius: AppGeometry.roundedr8,
                      border: Border.all(
                        color: context.accentPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.check_rounded,
                          size: 12,
                          color: context.accentPrimary,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Finish',
                          style: AppTypeRoles.typeRole33.copyWith(
                            color: context.accentPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                Icon(
                  Icons.play_circle_outline_rounded,
                  size: 22,
                  color: context.textMuted,
                ),
            ],
          ],
        ),
      ),
    );
  }
}

// ── Add Task Row ──────────────────────────────────────────────────────────────

class _AddTaskRow extends StatelessWidget {
  final TextEditingController controller;
  final Future<void> Function(String) onAdd;

  const _AddTaskRow({required this.controller, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(
              hintText: 'Add a task for today...',
              prefixIcon: Icon(
                Icons.add_circle_outline_rounded,
                color: context.accentPrimary,
                size: 20,
              ),
            ),
            onSubmitted: onAdd,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          style: context.surfaces.buttonStyle(
            IconButton.styleFrom(
              backgroundColor: context.accentPrimary,
              foregroundColor: context.textOnPrimary,
            ),
            filled: true,
            icon: true,
          ),
          icon: const Icon(Icons.add_rounded),
          onPressed: () => onAdd(controller.text),
        ),
      ],
    );
  }
}
