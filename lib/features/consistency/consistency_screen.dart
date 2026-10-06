import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';

class ConsistencyScreen extends ConsumerStatefulWidget {
  const ConsistencyScreen({super.key});

  @override
  ConsumerState<ConsistencyScreen> createState() => _ConsistencyScreenState();
}

class _ConsistencyScreenState extends ConsumerState<ConsistencyScreen> {
  DateTime _selectedDate = DateTime.now();
  final _dailyNoteController = TextEditingController();

  @override
  void dispose() {
    _dailyNoteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final consistencyDao = ref.watch(consistencyDaoProvider);
    final taskDao = ref.watch(taskDaoProvider);

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        title: Text(
          'Consistency Tracker',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
        backgroundColor: context.bgBase,
        elevation: 0,
      ),
      body: StreamBuilder<List<ConsistencyLog>>(
        stream: consistencyDao.watchAllLogs(),
        builder: (context, snapshot) {
          final logs = snapshot.data ?? [];
          final logMap = {
            for (final log in logs)
              DateTime(log.date.year, log.date.month, log.date.day): log
          };

          return StreamBuilder<int>(
            stream: consistencyDao.watchCurrentStreak(),
            builder: (context, streakSnapshot) {
              final currentStreak = streakSnapshot.data ?? 0;

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                children: [
                  // ── Streak Stats Cards ─────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: AscentCard(
                          padding: const EdgeInsets.all(16),
                          color: context.accentPrimary.withValues(alpha: 0.1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'CURRENT STREAK',
                                style: AscentTextStyles.labelSmall.copyWith(
                                  color: context.accentPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '$currentStreak',
                                    style: AscentTextStyles.statLarge.copyWith(
                                      color: context.accentPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'days',
                                    style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: AscentCard(
                          padding: const EdgeInsets.all(16),
                          color: context.accentSecondary.withValues(alpha: 0.1),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'TOTAL CHECK-INS',
                                style: AscentTextStyles.labelSmall.copyWith(
                                  color: context.accentSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.baseline,
                                textBaseline: TextBaseline.alphabetic,
                                children: [
                                  Text(
                                    '${logs.where((l) => l.present).length}',
                                    style: AscentTextStyles.statLarge.copyWith(
                                      color: context.accentSecondary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'sessions',
                                    style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Today's Check-in Card ──────────────────────────────
                  _DailyCheckInBlock(
                    today: today,
                    todayLog: logMap[today],
                    onCheckIn: (present, note) async {
                      await consistencyDao.logDay(
                        today,
                        present,
                        note: note,
                      );
                      setState(() {});
                    },
                  ),
                  const SizedBox(height: 24),

                  // ── Heatmap Calendar Grid (GitHub Style) ───────────────
                  Text(
                    'STUDY ACTIVITY HEATMAP',
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: context.textMuted,
                      letterSpacing: 1.0,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 12),
                  AscentCard(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeatmapGrid(
                          daysCount: 84, // 12 weeks
                          endDate: today,
                          logMap: logMap,
                          selectedDate: _selectedDate,
                          onDateSelected: (date) {
                            setState(() => _selectedDate = date);
                          },
                        ),
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text('Absent', style: AscentTextStyles.bodySmall.copyWith(fontSize: 10, color: context.textMuted)),
                            const SizedBox(width: 6),
                            _LegendBox(color: context.divider),
                            const SizedBox(width: 4),
                            _LegendBox(color: context.accentPrimary.withValues(alpha: 0.3)),
                            const SizedBox(width: 4),
                            _LegendBox(color: context.accentPrimary.withValues(alpha: 0.6)),
                            const SizedBox(width: 4),
                            _LegendBox(color: context.accentPrimary),
                            const SizedBox(width: 6),
                            Text('Present', style: AscentTextStyles.bodySmall.copyWith(fontSize: 10, color: context.textMuted)),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // ── Day Detail Inspection (Spec §5.4) ──────────────────
                  _DayDetailSection(
                    date: _selectedDate,
                    log: logMap[DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day)],
                    taskDao: taskDao,
                  ),
                  const SizedBox(height: 32),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Daily Check-in Card
// ---------------------------------------------------------------------------

class _DailyCheckInBlock extends StatelessWidget {
  final DateTime today;
  final ConsistencyLog? todayLog;
  final void Function(bool present, String? note) onCheckIn;

  const _DailyCheckInBlock({
    required this.today,
    required this.todayLog,
    required this.onCheckIn,
  });

  @override
  Widget build(BuildContext context) {
    final isCheckedIn = todayLog != null;

    return AscentCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isCheckedIn ? Icons.check_circle_rounded : Icons.help_outline_rounded,
                color: isCheckedIn
                    ? (todayLog!.present ? context.accentPrimary : context.textMuted)
                    : context.accentSecondary,
                size: 22,
              ),
              const SizedBox(width: 10),
              Text(
                'Did you show up today?',
                style: AscentTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            isCheckedIn
                ? (todayLog!.present
                    ? 'Logged as present! Consistency builds career breakthroughs.'
                    : 'Rest day logged. Rest is part of the process.')
                : 'Take 5 seconds to log your presence. Every session counts toward your goal.',
            style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: AscentButton.primary(
                  label: todayLog?.present == true ? 'Checked In' : 'Yes, showed up',
                  compact: true,
                  onPressed: () => onCheckIn(true, null),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AscentButton.outlined(
                  label: todayLog?.present == false ? 'Logged Rest' : 'Rest day / No',
                  compact: true,
                  onPressed: () => onCheckIn(false, null),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Heatmap Grid
// ---------------------------------------------------------------------------

class _HeatmapGrid extends StatelessWidget {
  final int daysCount;
  final DateTime endDate;
  final Map<DateTime, ConsistencyLog> logMap;
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateSelected;

  const _HeatmapGrid({
    required this.daysCount,
    required this.endDate,
    required this.logMap,
    required this.selectedDate,
    required this.onDateSelected,
  });

  @override
  Widget build(BuildContext context) {
    // 7 rows (days of week: Mon..Sun) x 12 columns (weeks)
    final weeks = daysCount ~/ 7;
    final startDate = endDate.subtract(Duration(days: daysCount - 1));

    return Column(
      children: List.generate(7, (row) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(weeks, (col) {
              final dayOffset = col * 7 + row;
              final date = startDate.add(Duration(days: dayOffset));
              final normalized = DateTime(date.year, date.month, date.day);
              final log = logMap[normalized];
              final isPresent = log?.present == true;
              final isSelected = normalized.year == selectedDate.year &&
                  normalized.month == selectedDate.month &&
                  normalized.day == selectedDate.day;

              Color cellColor = context.divider;
              if (isPresent) {
                cellColor = context.accentPrimary;
              } else if (log != null && !log.present) {
                cellColor = context.accentSecondary.withValues(alpha: 0.25);
              }

              return GestureDetector(
                onTap: () => onDateSelected(normalized),
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: cellColor,
                    borderRadius: BorderRadius.circular(4),
                    border: isSelected
                        ? Border.all(color: context.textPrimary, width: 2)
                        : null,
                  ),
                ),
              );
            }),
          ),
        );
      }),
    );
  }
}

class _LegendBox extends StatelessWidget {
  final Color color;

  const _LegendBox({required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 12,
      height: 12,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(3),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Day Detail Section (Spec §5.4: Never just a color with no story)
// ---------------------------------------------------------------------------

class _DayDetailSection extends StatelessWidget {
  final DateTime date;
  final ConsistencyLog? log;
  final TaskDao taskDao;

  const _DayDetailSection({
    required this.date,
    required this.log,
    required this.taskDao,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat.yMMMMd().format(date);
    final isPresent = log?.present == true;

    return AscentCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                dateStr,
                style: AscentTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isPresent
                      ? context.accentPrimary.withValues(alpha: 0.15)
                      : context.divider,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  log == null
                      ? 'No Record'
                      : (isPresent ? 'Present' : 'Rest Day'),
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: isPresent ? context.accentPrimary : context.textMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (log?.note != null && log!.note!.isNotEmpty) ...[
            Text(
              'Session Note:',
              style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
            ),
            const SizedBox(height: 4),
            Text(
              log!.note!,
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
            ),
            const SizedBox(height: 12),
          ],
          // Tasks completed on this day
          StreamBuilder<List<Task>>(
            stream: taskDao.watchAllTasks(),
            builder: (context, snapshot) {
              final all = snapshot.data ?? [];
              final doneOnDay = all.where((t) {
                if (t.actualCompletedDate == null) return false;
                final c = t.actualCompletedDate!;
                return c.year == date.year && c.month == date.month && c.day == date.day;
              }).toList();

              if (doneOnDay.isEmpty) {
                return Text(
                  'No completed tasks logged for this day.',
                  style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Tasks Completed (${doneOnDay.length}):',
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: context.accentPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ...doneOnDay.map((t) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded,
                                size: 16, color: context.accentPrimary),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                t.title,
                                style: AscentTextStyles.bodySmall.copyWith(
                                  color: context.textPrimary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
