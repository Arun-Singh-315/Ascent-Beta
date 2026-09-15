import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/skeleton_shimmer.dart';

class SeriesReportCardScreen extends ConsumerStatefulWidget {
  final int seriesId;

  const SeriesReportCardScreen({super.key, required this.seriesId});

  @override
  ConsumerState<SeriesReportCardScreen> createState() => _SeriesReportCardScreenState();
}

class _SeriesReportCardScreenState extends ConsumerState<SeriesReportCardScreen> {
  final _taskTitleController = TextEditingController();

  @override
  void dispose() {
    _taskTitleController.dispose();
    super.dispose();
  }

  void _showAddTaskSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(ctx).viewInsets.bottom,
          left: 20,
          right: 20,
          top: 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Add Series Milestone',
                  style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _taskTitleController,
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
              decoration: InputDecoration(
                hintText: 'e.g. Problems 1-15: Arrays & Two Pointers',
                hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                filled: true,
                fillColor: context.bgBase,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: context.divider),
                ),
              ),
            ),
            const SizedBox(height: 20),
            AscentButton.primary(
              label: 'Add Task to Series',
              onPressed: () async {
                final title = _taskTitleController.text.trim();
                if (title.isNotEmpty) {
                  await ref.read(taskDaoProvider).insertTask(
                    TaskTableCompanion.insert(
                      title: title,
                      seriesId: drift.Value(widget.seriesId),
                      plannedDate: drift.Value(DateTime.now().add(const Duration(days: 3))),
                    ),
                  );
                  _taskTitleController.clear();
                  if (ctx.mounted) Navigator.pop(ctx);
                }
              },
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final seriesDao = ref.watch(seriesDaoProvider);
    final taskDao = ref.watch(taskDaoProvider);

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        backgroundColor: context.bgBase,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text(
          'Series Report Card',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
      ),
      body: FutureBuilder<Series?>(
        future: seriesDao.getSeriesById(widget.seriesId),
        builder: (context, seriesSnapshot) {
          if (seriesSnapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: SkeletonShimmer(height: 250),
            );
          }

          final series = seriesSnapshot.data;
          if (series == null) {
            return Center(
              child: Text(
                'Series not found',
                style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
              ),
            );
          }

          return StreamBuilder<List<Task>>(
            stream: taskDao.watchTasksBySeries(series.id),
            builder: (context, tasksSnapshot) {
              final tasks = tasksSnapshot.data ?? [];
              final completedTasks = tasks.where((t) => t.actualCompletedDate != null).toList();
              final totalCount = series.totalItems ?? (tasks.isNotEmpty ? tasks.length : 1);
              final progress = (completedTasks.length / totalCount).clamp(0.0, 1.0);
              final percentStr = '${(progress * 100).toInt()}%';

              // Pacing status calculation
              final daysLeft = series.endDate?.difference(DateTime.now()).inDays;

              String paceLabel = 'On Track';
              Color paceColor = context.stateSuccess;
              if (daysLeft != null && daysLeft < 5 && progress < 0.8) {
                paceLabel = 'Behind Pace';
                paceColor = context.stateWarning;
              } else if (progress >= 1.0) {
                paceLabel = 'Completed';
                paceColor = context.stateSuccess;
              }

              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                children: [
                  // ── Hero Series Card ─────────────────────────────────
                  AscentCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: paceColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                paceLabel.toUpperCase(),
                                style: AscentTextStyles.labelSmall.copyWith(
                                  color: paceColor,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const Spacer(),
                            if (daysLeft != null)
                              Text(
                                daysLeft >= 0 ? '$daysLeft days remaining' : 'Past deadline',
                                style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          series.title,
                          style: AscentTextStyles.displaySmall.copyWith(
                            color: context.textPrimary,
                            fontSize: 22,
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Progress Bar & Percentage
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Progress',
                              style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
                            ),
                            Text(
                              '$percentStr (${completedTasks.length}/$totalCount)',
                              style: AscentTextStyles.monoCode.copyWith(
                                color: context.accentPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 8,
                            backgroundColor: context.bgBase,
                            valueColor: AlwaysStoppedAnimation<Color>(context.accentPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Velocity / Burn-up Chart ─────────────────────────
                  AscentCard(
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Velocity Curve',
                              style: AscentTextStyles.headlineMedium.copyWith(
                                color: context.textPrimary,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              'Burn-up trajectory',
                              style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          height: 160,
                          child: _buildBurnUpChart(context, completedTasks.length, totalCount),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Tasks & Milestones Header ────────────────────────
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Milestones & Tasks',
                        style: AscentTextStyles.headlineMedium.copyWith(
                          color: context.textPrimary,
                          fontSize: 18,
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Add Task'),
                        onPressed: () => _showAddTaskSheet(context),
                      ),
                    ],
                  ),

                  const SizedBox(height: 8),

                  if (tasks.isEmpty)
                    AscentCard(
                      padding: const EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No specific tasks linked to this series yet.\nTap "Add Task" to track individual steps.',
                          textAlign: TextAlign.center,
                          style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                        ),
                      ),
                    )
                  else
                    ...tasks.map((task) {
                      final isDone = task.actualCompletedDate != null;
                      return AscentCard(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        child: Row(
                          children: [
                            Checkbox(
                              value: isDone,
                              activeColor: context.accentPrimary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(4),
                              ),
                              onChanged: (val) async {
                                if (val == true) {
                                  await taskDao.markComplete(task.id);
                                } else {
                                  await taskDao.markIncomplete(task.id);
                                }
                              },
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                task.title,
                                style: AscentTextStyles.bodyMedium.copyWith(
                                  color: isDone ? context.textMuted : context.textPrimary,
                                  decoration: isDone ? TextDecoration.lineThrough : null,
                                ),
                              ),
                            ),
                          ],
                        ),
                      );
                    }),

                  const SizedBox(height: 32),
                ],
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildBurnUpChart(BuildContext context, int completed, int total) {
    // Generate simple cumulative points
    final spots = <FlSpot>[
      const FlSpot(0, 0),
      FlSpot(1, (completed * 0.3).toDouble()),
      FlSpot(2, (completed * 0.6).toDouble()),
      FlSpot(3, completed.toDouble()),
    ];

    final targetSpots = <FlSpot>[
      const FlSpot(0, 0),
      FlSpot(1, (total * 0.33).toDouble()),
      FlSpot(2, (total * 0.66).toDouble()),
      FlSpot(3, total.toDouble()),
    ];

    final maxY = total > 0 ? (total * 1.2).toDouble() : 10.0;

    return LineChart(
      LineChartData(
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          getDrawingHorizontalLine: (value) => FlLine(
            color: context.divider.withValues(alpha: 0.5),
            strokeWidth: 0.8,
          ),
        ),
        titlesData: FlTitlesData(
          show: true,
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 22,
              getTitlesWidget: (val, meta) {
                switch (val.toInt()) {
                  case 0:
                    return Text('Start', style: TextStyle(color: context.textMuted, fontSize: 10));
                  case 1:
                    return Text('Week 1', style: TextStyle(color: context.textMuted, fontSize: 10));
                  case 2:
                    return Text('Week 2', style: TextStyle(color: context.textMuted, fontSize: 10));
                  case 3:
                    return Text('Target', style: TextStyle(color: context.textMuted, fontSize: 10));
                  default:
                    return const SizedBox.shrink();
                }
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              getTitlesWidget: (val, meta) {
                return Text(
                  val.toInt().toString(),
                  style: TextStyle(color: context.textMuted, fontSize: 10),
                );
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 3,
        minY: 0,
        maxY: maxY,
        lineBarsData: [
          // Target trajectory (dashed look)
          LineChartBarData(
            spots: targetSpots,
            isCurved: true,
            color: context.textMuted.withValues(alpha: 0.4),
            barWidth: 1.5,
            dashArray: [5, 5],
            dotData: const FlDotData(show: false),
          ),
          // Actual completed trajectory
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: context.accentPrimary,
            barWidth: 3,
            dotData: FlDotData(
              show: true,
              getDotPainter: (spot, percent, barData, index) => FlDotCirclePainter(
                radius: 4,
                color: context.accentPrimary,
                strokeWidth: 2,
                strokeColor: context.bgSurface,
              ),
            ),
            belowBarData: BarAreaData(
              show: true,
              color: context.accentPrimary.withValues(alpha: 0.15),
            ),
          ),
        ],
      ),
    );
  }
}
