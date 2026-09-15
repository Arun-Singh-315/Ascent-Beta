import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/live_session_bar.dart';
import 'package:google_fonts/google_fonts.dart';

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

  Future<void> _addTaskForToday(String title) async {
    if (title.trim().isEmpty) return;
    final taskDao = ref.read(taskDaoProvider);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
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

  Future<void> _confirmCompleteSession(BuildContext context, String taskTitle, String totalTime) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: context.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Complete session?',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
        content: Text(
          'Complete session for "$taskTitle"?\nTotal duration: $totalTime',
          style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: Text('Cancel', style: TextStyle(color: context.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentPrimary,
              foregroundColor: context.textOnPrimary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            child: const Text('Complete'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(timeTrackingProvider.notifier).completeSession();
      ref.invalidate(todayFocusTaskProvider);
    }
  }

  Future<void> _showSwitchTaskSheet(BuildContext context, List<Task> tasks) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: context.bgSurface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetCtx) {
        final activeTaskId = ref.watch(timeTrackingProvider).activeSession?.linkedTaskId;
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: sheetCtx.divider,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Switch Task',
                  style: AscentTextStyles.displaySmall.copyWith(color: sheetCtx.textPrimary),
                ),
                const SizedBox(height: 4),
                Text(
                  'Current session will pause and your new task will start tracking immediately.',
                  style: AscentTextStyles.bodySmall.copyWith(color: sheetCtx.textMuted),
                ),
                const SizedBox(height: 16),
                Flexible(
                  child: ListView(
                    shrinkWrap: true,
                    children: [
                      ...tasks.where((t) => t.actualCompletedDate == null).map((task) {
                        final isCurrent = task.id == activeTaskId;
                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: isCurrent ? sheetCtx.accentPrimary.withValues(alpha: 0.1) : null,
                          leading: Icon(
                            isCurrent ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                            color: isCurrent ? sheetCtx.accentPrimary : sheetCtx.textMuted,
                          ),
                          title: Text(
                            task.title,
                            style: AscentTextStyles.bodyMedium.copyWith(
                              color: sheetCtx.textPrimary,
                              fontWeight: isCurrent ? FontWeight.w600 : FontWeight.w400,
                            ),
                          ),
                          trailing: isCurrent
                              ? Text('Active', style: TextStyle(color: sheetCtx.accentPrimary, fontSize: 12))
                              : null,
                          onTap: () {
                            Navigator.of(sheetCtx).pop();
                            if (!isCurrent) {
                              ref.read(timeTrackingProvider.notifier).switchToTask(
                                title: task.title,
                                taskId: task.id,
                              );
                            }
                          },
                        );
                      }),
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        leading: Icon(Icons.add_rounded, color: sheetCtx.accentPrimary),
                        title: Text(
                          'Start untracked or custom activity...',
                          style: AscentTextStyles.bodyMedium.copyWith(color: sheetCtx.accentPrimary),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final trackingState = ref.watch(timeTrackingProvider);
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
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

    return Scaffold(
      backgroundColor: context.bgBase,
      body: SafeArea(
        child: Column(
          children: [
            // App Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
                    style: IconButton.styleFrom(
                      backgroundColor: context.bgSurface,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Focus Timer',
                      style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _showStats = !_showStats),
                    icon: Icon(
                      _showStats ? Icons.bar_chart_rounded : Icons.bar_chart_outlined,
                      color: _showStats ? context.accentPrimary : context.textMuted,
                    ),
                    tooltip: 'Today\'s stats',
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                children: [
                  // ── Today across all tasks strip ───────────────────────────
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: context.bgSurface,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: context.divider),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.schedule_rounded, size: 16, color: context.accentPrimary),
                        const SizedBox(width: 8),
                        Text(
                          'Today across all tasks:',
                          style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                        ),
                        const Spacer(),
                        Text(
                          _formatHoursAndMinutes(totalLoggedTodaySeconds),
                          style: GoogleFonts.jetBrainsMono(
                            textStyle: AscentTextStyles.labelMedium.copyWith(
                              color: context.accentPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Text(
                          ' logged',
                          style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                        ),
                      ],
                    ),
                  ),

                  // ── Big Clock ──────────────────────────────────────────────
                  _BigClockCard(
                    trackingState: trackingState,
                    formatDuration: _formatDuration,
                    onStart: () => showStartSessionSheet(context, ref),
                    onPause: () => ref.read(timeTrackingProvider.notifier).pauseSession(),
                    onResume: () => ref.read(timeTrackingProvider.notifier).resumeSession(),
                    onSwitchTask: () {
                      final tasks = todayTasks.value ?? [];
                      _showSwitchTaskSheet(context, tasks);
                    },
                    onComplete: () {
                      final title = trackingState.activeSession?.label ?? 'Current session';
                      final totalTime = _formatDuration(trackingState.elapsedSeconds);
                      _confirmCompleteSession(context, title, totalTime);
                    },
                  ),

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
                        style: AscentTextStyles.labelLarge.copyWith(color: context.textPrimary),
                      ),
                      Text(
                        DateFormat('EEEE, MMM d').format(DateTime.now()),
                        style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),

                  // Task List
                  todayTasks.when(
                    loading: () => const Center(child: Padding(
                      padding: EdgeInsets.all(20),
                      child: CircularProgressIndicator(),
                    )),
                    error: (_, _) => const SizedBox.shrink(),
                    data: (tasks) {
                      if (tasks.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'No tasks planned for today.\nAdd one below to get started!',
                            style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }

                      return Column(
                        children: tasks.map((task) {
                          final isActive = trackingState.activeSession?.linkedTaskId == task.id;
                          final isDone = task.actualCompletedDate != null;

                          // Find time spent on this task today
                          final taskSeconds = todayTasksAsync.value?.where(
                            (s) => s.linkedTaskId == task.id,
                          ).fold<int>(0, (acc, s) {
                            return acc + TimeSessionDao.computeActiveDurationSeconds(
                              s.startedAt,
                              s.endedAt ?? (s.status == 'running' ? DateTime.now() : s.startedAt),
                              s.pausedIntervals,
                            );
                          }) ?? 0;

                          return Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: _TaskRow(
                              task: task,
                              isActive: isActive,
                              isDone: isDone,
                              timeSpent: _formatMinutes(taskSeconds),
                              onTap: isDone
                                  ? null
                                  : () {
                                      ref.read(timeTrackingProvider.notifier).switchToTask(
                                            title: task.title,
                                            taskId: task.id,
                                          );
                                    },
                              onToggleDone: () async {
                                final taskDao = ref.read(taskDaoProvider);
                                if (isDone) {
                                  await taskDao.markIncomplete(task.id);
                                } else {
                                  await taskDao.markComplete(task.id);
                                  if (isActive) {
                                    await ref.read(timeTrackingProvider.notifier).completeSession();
                                  }
                                }
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
                  _AddTaskRow(
                    controller: _addTaskController,
                    onAdd: _addTaskForToday,
                  ),

                  const SizedBox(height: 32),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Provider for today's tasks ─────────────────────────────────────────────────

final _todayTasksProvider = StreamProvider.family<List<Task>, DateTime>((ref, date) {
  final dao = ref.watch(taskDaoProvider);
  return dao.watchTasksByDate(date);
});

// ── Big Clock Card ─────────────────────────────────────────────────────────────

class _BigClockCard extends StatelessWidget {
  final TimeTrackingState trackingState;
  final String Function(int) formatDuration;
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
  });

  @override
  Widget build(BuildContext context) {
    final isRunning = trackingState.isRunning;
    final isPaused = trackingState.isPaused;
    final hasSession = trackingState.activeSession != null;
    final elapsed = trackingState.elapsedSeconds;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.accentPrimary.withValues(alpha: 0.15),
            context.accentPrimary.withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.accentPrimary.withValues(alpha: 0.25),
          width: 1.5,
        ),
      ),
      child: Column(
        children: [
          // Task label
          if (hasSession) ...[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.accentPrimary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                trackingState.activeSession!.label,
                style: AscentTextStyles.labelSmall.copyWith(
                  color: context.accentPrimary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 16),
          ] else ...[
            Text(
              'No active session',
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
            ),
            const SizedBox(height: 16),
          ],

          // Big clock
          TweenAnimationBuilder<int>(
            tween: IntTween(begin: elapsed, end: elapsed),
            duration: Duration.zero,
            builder: (context, value, _) {
              return Text(
                hasSession ? formatDuration(elapsed) : '00:00',
                style: TextStyle(
                  fontSize: 64,
                  fontWeight: FontWeight.w300,
                  letterSpacing: -2,
                  color: hasSession
                      ? (isRunning ? context.textPrimary : context.textMuted)
                      : context.textMuted.withValues(alpha: 0.5),
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              );
            },
          ),

          if (isPaused) ...[
            const SizedBox(height: 4),
            Text(
              'PAUSED',
              style: AscentTextStyles.labelSmall.copyWith(
                color: context.accentSecondary,
                letterSpacing: 2,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Controls
          if (!hasSession)
            AscentButton.primary(
              label: 'Start Session',
              onPressed: onStart,
            )
          else ...[
            // Row 1: [ ⏸ Pause / ▶ Resume ] and [ 🔄 Switch task ]
            Row(
              children: [
                Expanded(
                  child: isRunning
                      ? AscentButton.secondary(
                          label: '⏸ Pause',
                          expanded: true,
                          onPressed: onPause,
                        )
                      : AscentButton.secondary(
                          label: '▶ Resume',
                          expanded: true,
                          onPressed: onResume,
                        ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: AscentButton.secondary(
                    label: '🔄 Switch task',
                    expanded: true,
                    onPressed: onSwitchTask,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Row 2: Demoted Complete Session action
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                onPressed: onComplete,
                icon: Icon(Icons.check_circle_outline_rounded, size: 18, color: context.accentPrimary),
                label: Text(
                  'Complete session',
                  style: AscentTextStyles.labelMedium.copyWith(
                    color: context.accentPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  backgroundColor: context.accentPrimary.withValues(alpha: 0.08),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: context.accentPrimary.withValues(alpha: 0.2)),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stats Panel ────────────────────────────────────────────────────────────────

class _StatsPanel extends ConsumerWidget {
  final AsyncValue<List<TimeSession>> todayTasksAsync;
  final String Function(int) formatMinutes;

  const _StatsPanel({required this.todayTasksAsync, required this.formatMinutes});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.bgSurface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: context.divider),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Today's Stats",
                style: AscentTextStyles.labelMedium.copyWith(color: context.textPrimary),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _StatChip(
                    label: 'Study',
                    value: formatMinutes(studySeconds),
                    color: context.accentPrimary,
                    icon: Icons.school_rounded,
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    label: 'Break',
                    value: formatMinutes(breakSeconds),
                    color: context.accentSecondary,
                    icon: Icons.sports_esports_rounded,
                  ),
                  const SizedBox(width: 10),
                  _StatChip(
                    label: 'Sessions',
                    value: '${sessions.length}',
                    color: context.accentInfo,
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
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(height: 4),
            Text(
              value,
              style: AscentTextStyles.statMedium.copyWith(
                color: context.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            Text(
              label,
              style: TextStyle(fontSize: 10, color: context.textMuted),
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

  const _TaskRow({
    required this.task,
    required this.isActive,
    required this.isDone,
    required this.timeSpent,
    this.onTap,
    required this.onToggleDone,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isActive
              ? context.accentPrimary.withValues(alpha: 0.12)
              : context.bgSurface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isActive
                ? context.accentPrimary.withValues(alpha: 0.4)
                : context.divider,
            width: isActive ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            // Done checkbox
            GestureDetector(
              onTap: onToggleDone,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: isDone
                      ? context.accentPrimary.withValues(alpha: 0.15)
                      : Colors.transparent,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isDone ? context.accentPrimary : context.divider,
                    width: 2,
                  ),
                ),
                child: isDone
                    ? Icon(Icons.check_rounded, size: 14, color: context.accentPrimary)
                    : null,
              ),
            ),
            const SizedBox(width: 12),

            // Task title
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    style: AscentTextStyles.bodyMedium.copyWith(
                      color: isDone ? context.textMuted : context.textPrimary,
                      decoration: isDone ? TextDecoration.lineThrough : null,
                      fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (timeSpent != '0m') ...[
                    const SizedBox(height: 2),
                    Text(
                      timeSpent,
                      style: TextStyle(
                        fontSize: 11,
                        color: isActive ? context.accentPrimary : context.textMuted,
                        fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Active indicator / start button
            if (isActive)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: context.accentPrimary,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.radio_button_on_rounded, size: 10, color: context.textOnPrimary),
                    const SizedBox(width: 4),
                    Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 10,
                        color: context.textOnPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              )
            else if (!isDone)
              Icon(
                Icons.play_circle_outline_rounded,
                size: 22,
                color: context.textMuted,
              ),
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
              prefixIcon: Icon(Icons.add_circle_outline_rounded, color: context.accentPrimary, size: 20),
            ),
            onSubmitted: onAdd,
          ),
        ),
        const SizedBox(width: 8),
        IconButton.filled(
          style: IconButton.styleFrom(
            backgroundColor: context.accentPrimary,
            foregroundColor: context.textOnPrimary,
          ),
          icon: const Icon(Icons.add_rounded),
          onPressed: () => onAdd(controller.text),
        ),
      ],
    );
  }
}
