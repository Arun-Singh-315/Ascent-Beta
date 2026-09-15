import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables/enums.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';


class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  void _openCreateSeriesSheet(BuildContext context) {
    final titleController = TextEditingController();
    final itemsController = TextEditingController(text: '30');
    DateTime? targetDate = DateTime.now().add(const Duration(days: 30));

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) => Padding(
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
                    'Create New Series',
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
                controller: titleController,
                style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                decoration: InputDecoration(
                  hintText: 'Series Title (e.g. Blind 75 DSA, System Design Primer)',
                  hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                  filled: true,
                  fillColor: context.bgBase,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: context.divider),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: itemsController,
                      keyboardType: TextInputType.number,
                      style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                      decoration: InputDecoration(
                        labelText: 'Total Items / Target',
                        labelStyle: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
                        filled: true,
                        fillColor: context.bgBase,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: context.divider),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton(
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        side: BorderSide(color: context.divider),
                      ),
                      child: Text(
                        targetDate != null ? DateFormat.MMMd().format(targetDate!) : 'No Deadline',
                        style: AscentTextStyles.bodySmall.copyWith(color: context.textPrimary),
                      ),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: targetDate ?? DateTime.now().add(const Duration(days: 30)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setSheetState(() => targetDate = picked);
                        }
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              AscentButton.primary(
                label: 'Start Series',
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isNotEmpty) {
                    final items = int.tryParse(itemsController.text.trim()) ?? 20;
                    await ref.read(seriesDaoProvider).insertSeries(
                      SeriesTableCompanion.insert(
                        title: title,
                        totalItems: drift.Value(items),
                        endDate: drift.Value(targetDate),
                      ),
                    );
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final consistencyDao = ref.watch(consistencyDaoProvider);
    final applicationDao = ref.watch(applicationDaoProvider);
    final dsaDao = ref.watch(dsaDaoProvider);
    final prepDao = ref.watch(interviewPrepDaoProvider);
    final seriesDao = ref.watch(seriesDaoProvider);
    final profileDao = ref.watch(userProfileDaoProvider);

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        backgroundColor: context.bgBase,
        elevation: 0,
        title: Text(
          'Analytics & Velocity',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.playlist_add_rounded, color: context.accentPrimary, size: 26),
            tooltip: 'New Series',
            onPressed: () => _openCreateSeriesSheet(context),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: StreamBuilder<List<ConsistencyLog>>(
        stream: consistencyDao.watchAllLogs(),
        builder: (context, logSnapshot) {
          return StreamBuilder<List<ApplicationRow>>(
            stream: applicationDao.watchAllApplications(),
            builder: (context, appSnapshot) {
              return StreamBuilder<List<DsaLog>>(
                stream: dsaDao.watchAllLogs(),
                builder: (context, dsaSnapshot) {
                  return StreamBuilder<List<InterviewPrep>>(
                    stream: prepDao.watchAllQuestions(),

                    builder: (context, prepSnapshot) {
                      return StreamBuilder<List<SeriesWithTaskCounts>>(
                        stream: seriesDao.watchSeriesWithTaskCounts(),
                        builder: (context, seriesSnapshot) {
                          return StreamBuilder<UserProfile?>(
                            stream: profileDao.watchProfile(),
                            builder: (context, profileSnapshot) {
                              final apps = appSnapshot.data ?? [];
                              final dsaList = dsaSnapshot.data ?? [];
                              final questions = prepSnapshot.data ?? [];
                              final seriesList = seriesSnapshot.data ?? [];
                              final profile = profileSnapshot.data;

                              return ListView(
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                                children: [
                                  // ── 1. Weekly Rhythm / Study Hours Chart ──
                                  _WeeklyStudyHoursCard(
                                    weeklyTargetHours: profile?.weeklyHoursAvailable ?? 10,
                                  ),

                                  const SizedBox(height: 20),

                                  // ── 2. Job Search Funnel ─────────────────
                                  _ApplicationFunnelCard(applications: apps),

                                  const SizedBox(height: 20),

                                  // ── 3. Readiness Breakdown (DSA & Interview)
                                  _ReadinessBreakdownCard(
                                    dsaProblems: dsaList,
                                    interviewQuestions: questions,
                                  ),

                                  const SizedBox(height: 20),

                                  // ── 4. Active Series Report Cards ────────
                                  _SeriesReportCardsSection(
                                    seriesList: seriesList,
                                    onAddNew: () => _openCreateSeriesSheet(context),
                                  ),

                                  const SizedBox(height: 32),
                                ],
                              );
                            },
                          );
                        },
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// 1. Weekly Study Hours Card (fl_chart BarChart)
// ---------------------------------------------------------------------------

class _WeeklyStudyHoursCard extends ConsumerWidget {
  final int weeklyTargetHours;

  const _WeeklyStudyHoursCard({
    required this.weeklyTargetHours,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final timeSessionDao = ref.watch(timeSessionDaoProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final startOfWeek = today.subtract(const Duration(days: 6));
    final endOfWeek = today.add(const Duration(days: 1));

    return StreamBuilder<List<SessionCategory>>(
      stream: timeSessionDao.watchAllCategories(),
      builder: (context, catSnapshot) {
        final categories = catSnapshot.data ?? [];
        final categoryMap = {for (final c in categories) c.id: c};

        return StreamBuilder<List<TimeSession>>(
          stream: timeSessionDao.watchSessionsBetween(startOfWeek, endOfWeek),
          builder: (context, sessionSnapshot) {
            final sessions = sessionSnapshot.data ?? [];

            final List<double> dailyStudyHours = List.filled(7, 0.0);
            final List<double> dailyBreakHours = List.filled(7, 0.0);
            final List<String> dayLabels = List.filled(7, '');

            for (int i = 0; i < 7; i++) {
              final date = today.subtract(Duration(days: 6 - i));
              dayLabels[i] = DateFormat('E').format(date).substring(0, 1);
              final dayStart = DateTime(date.year, date.month, date.day);
              final dayEnd = dayStart.add(const Duration(days: 1));

              for (final s in sessions) {
                if ((s.startedAt.isAfter(dayStart) && s.startedAt.isBefore(dayEnd)) ||
                    s.startedAt.isAtSameMomentAs(dayStart)) {
                  final durationSec = TimeSessionDao.computeActiveDurationSeconds(
                    s.startedAt,
                    s.endedAt ?? DateTime.now(),
                    s.pausedIntervals,
                  );
                  final hours = durationSec / 3600.0;
                  final cat = categoryMap[s.categoryId];
                  final isStudy = (cat?.name.toLowerCase() == 'study') || (s.activityType.toLowerCase() == 'study');
                  if (isStudy) {
                    dailyStudyHours[i] += hours;
                  } else {
                    dailyBreakHours[i] += hours;
                  }
                }
              }
            }

            final totalStudyHours = dailyStudyHours.fold<double>(0.0, (acc, h) => acc + h);
            final totalBreakHours = dailyBreakHours.fold<double>(0.0, (acc, h) => acc + h);
            final totalCombinedHours = totalStudyHours + totalBreakHours;

            double maxVal = 6.0;
            for (int i = 0; i < 7; i++) {
              if (dailyStudyHours[i] > maxVal) maxVal = (dailyStudyHours[i] + 1.0).ceilToDouble();
              if (dailyBreakHours[i] > maxVal) maxVal = (dailyBreakHours[i] + 1.0).ceilToDouble();
            }

            return AscentCard(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Weekly Study Rhythm',
                        style: AscentTextStyles.headlineMedium.copyWith(
                          color: context.textPrimary,
                          fontSize: 17,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: context.accentPrimary.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${totalStudyHours.toStringAsFixed(1)} / $weeklyTargetHours hrs',
                          style: AscentTextStyles.monoCode.copyWith(
                            color: context.accentPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '${totalStudyHours.toStringAsFixed(1)}h study + ${totalBreakHours.toStringAsFixed(1)}h breaks = ${totalCombinedHours.toStringAsFixed(1)}h total',
                    style: AscentTextStyles.bodySmall.copyWith(
                      color: context.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _buildLegendItem(
                        context,
                        color: context.accentPrimaryBright,
                        label: 'Study',
                      ),
                      const SizedBox(width: 16),
                      _buildLegendItem(
                        context,
                        color: context.accentSecondaryBright,
                        label: 'Entertainment / Breaks',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 150,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: maxVal,
                        barTouchData: BarTouchData(
                          touchTooltipData: BarTouchTooltipData(
                            getTooltipColor: (_) => context.bgSurface,
                            getTooltipItem: (group, groupIndex, rod, rodIndex) {
                              final isStudy = rodIndex == 0;
                              final type = isStudy ? 'Study' : 'Break';
                              return BarTooltipItem(
                                '$type: ${rod.toY.toStringAsFixed(1)}h',
                                AscentTextStyles.labelSmall.copyWith(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.bold,
                                ),
                              );
                            },
                          ),
                        ),
                        titlesData: FlTitlesData(
                          show: true,
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              getTitlesWidget: (val, meta) {
                                if (val % 2 == 0 && val <= maxVal) {
                                  return Text(
                                    '${val.toInt()}h',
                                    style: TextStyle(color: context.textMuted, fontSize: 10),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              getTitlesWidget: (val, meta) {
                                final idx = val.toInt();
                                if (idx >= 0 && idx < 7) {
                                  final isToday = idx == 6;
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 6),
                                    child: Text(
                                      dayLabels[idx],
                                      style: TextStyle(
                                        color: isToday ? context.accentPrimary : context.textMuted,
                                        fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 11,
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                        ),
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          getDrawingHorizontalLine: (val) => FlLine(
                            color: context.divider.withValues(alpha: 0.5),
                            strokeWidth: 0.8,
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        barGroups: List.generate(7, (i) {
                          final study = dailyStudyHours[i];
                          final brk = dailyBreakHours[i];
                          return BarChartGroupData(
                            x: i,
                            barsSpace: 4,
                            barRods: [
                              BarChartRodData(
                                toY: study > 0 ? study : 0.05,
                                color: study > 0
                                    ? context.accentPrimaryBright
                                    : context.divider.withValues(alpha: 0.3),
                                width: 8,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                              BarChartRodData(
                                toY: brk > 0 ? brk : 0.05,
                                color: brk > 0
                                    ? context.accentSecondaryBright
                                    : context.divider.withValues(alpha: 0.15),
                                width: 8,
                                borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
                              ),
                            ],
                          );
                        }),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildLegendItem(BuildContext context, {required Color color, required String label}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: AscentTextStyles.caption.copyWith(
            color: context.textMuted,
            fontSize: 11,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 2. Job Search Funnel Card
// ---------------------------------------------------------------------------

class _ApplicationFunnelCard extends StatelessWidget {
  final List<ApplicationRow> applications;

  const _ApplicationFunnelCard({required this.applications});

  @override
  Widget build(BuildContext context) {
    final wishlist = applications.where((a) => a.currentStage == ApplicationStage.wishlist.name).length;
    final applied = applications.where((a) => a.currentStage == ApplicationStage.applied.name).length;
    final oa = applications.where((a) => a.currentStage == ApplicationStage.oaScreen.name).length;
    final tech = applications.where((a) => a.currentStage == ApplicationStage.interview.name).length;
    final offer = applications.where((a) => a.currentStage == ApplicationStage.offer.name).length;
    final total = applications.length;

    return AscentCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Application Conversion Funnel',
                style: AscentTextStyles.headlineMedium.copyWith(
                  color: context.textPrimary,
                  fontSize: 17,
                ),
              ),
              Text(
                '$total Total Apps',
                style: AscentTextStyles.monoCode.copyWith(
                  color: context.textMuted,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Stage progression and conversion ratios',
            style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
          ),
          const SizedBox(height: 18),

          _FunnelStageRow(
            label: 'Wishlist',
            count: wishlist,
            total: total > 0 ? total : 1,
            color: context.textMuted,
          ),
          const SizedBox(height: 8),
          _FunnelStageRow(
            label: 'Applied',
            count: applied,
            total: total > 0 ? total : 1,
            color: context.accentSecondary,
          ),
          const SizedBox(height: 8),
          _FunnelStageRow(
            label: 'OA / Screen',
            count: oa,
            total: total > 0 ? total : 1,
            color: context.accentPrimary,
          ),
          const SizedBox(height: 8),
          _FunnelStageRow(
            label: 'Interview Round',
            count: tech,
            total: total > 0 ? total : 1,
            color: context.accentInfo,
          ),
          const SizedBox(height: 8),
          _FunnelStageRow(
            label: 'Offers',
            count: offer,
            total: total > 0 ? total : 1,
            color: context.stateSuccess,
          ),
        ],
      ),
    );
  }
}


class _FunnelStageRow extends StatelessWidget {
  final String label;
  final int count;
  final int total;
  final Color color;

  const _FunnelStageRow({
    required this.label,
    required this.count,
    required this.total,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final ratio = (count / total).clamp(0.0, 1.0);
    final percentStr = '${(ratio * 100).toInt()}%';

    return Row(
      children: [
        SizedBox(
          width: 110,
          child: Text(
            label,
            style: AscentTextStyles.bodySmall.copyWith(
              color: context.textPrimary,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: ratio > 0 ? ratio : 0.03,
              minHeight: 10,
              backgroundColor: context.bgBase,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ),
        const SizedBox(width: 12),
        SizedBox(
          width: 50,
          child: Text(
            '$count ($percentStr)',
            textAlign: TextAlign.end,
            style: AscentTextStyles.monoCode.copyWith(
              color: context.textSecondary,
              fontSize: 11,
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// 3. Readiness Breakdown (DSA & Interview)
// ---------------------------------------------------------------------------

class _ReadinessBreakdownCard extends StatelessWidget {
  final List<DsaLog> dsaProblems;
  final List<InterviewPrep> interviewQuestions;

  const _ReadinessBreakdownCard({
    required this.dsaProblems,
    required this.interviewQuestions,
  });

  @override
  Widget build(BuildContext context) {
    final easy = dsaProblems.where((p) => p.difficulty == 'easy').length;
    final medium = dsaProblems.where((p) => p.difficulty == 'medium').length;
    final hard = dsaProblems.where((p) => p.difficulty == 'hard').length;
    final totalDsa = dsaProblems.length;

    final totalQuestions = interviewQuestions.length;
    final practicedQuestions = interviewQuestions.where((q) => q.lastInteractedAt != null).length;

    return AscentCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Readiness & Practice Matrix',
            style: AscentTextStyles.headlineMedium.copyWith(
              color: context.textPrimary,
              fontSize: 17,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              // DSA Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.bgBase,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'DSA Solved',
                            style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
                          ),
                          Text(
                            '$totalDsa',
                            style: AscentTextStyles.monoCode.copyWith(
                              color: context.accentPrimary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('Easy: $easy', style: TextStyle(color: context.stateSuccess, fontSize: 11)),
                          Text('Med: $medium', style: TextStyle(color: context.stateWarning, fontSize: 11)),
                          Text('Hard: $hard', style: TextStyle(color: context.stateDanger, fontSize: 11)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 12),
              // Interview Prep Box
              Expanded(
                child: Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.bgBase,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.divider),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Interview Q&A',
                            style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
                          ),
                          Text(
                            '$totalQuestions',
                            style: AscentTextStyles.monoCode.copyWith(
                              color: context.accentSecondary,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Text(
                        '$practicedQuestions reviewed and active',
                        style: AscentTextStyles.bodySmall.copyWith(
                          color: context.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
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
// 4. Series Report Cards Section
// ---------------------------------------------------------------------------

class _SeriesReportCardsSection extends StatelessWidget {
  final List<SeriesWithTaskCounts> seriesList;
  final VoidCallback onAddNew;

  const _SeriesReportCardsSection({
    required this.seriesList,
    required this.onAddNew,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Series Report Cards',
              style: AscentTextStyles.headlineMedium.copyWith(
                color: context.textPrimary,
                fontSize: 17,
              ),
            ),
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Series'),
              onPressed: onAddNew,
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (seriesList.isEmpty)
          AscentCard(
            padding: const EdgeInsets.all(20),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.playlist_play_rounded, size: 36, color: context.accentPrimary),
                  const SizedBox(height: 8),
                  Text(
                    'No active series',
                    style: AscentTextStyles.bodyMedium.copyWith(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Start a structured target like "Blind 75 DSA" or "100 Applications"',
                    textAlign: TextAlign.center,
                    style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                  ),
                ],
              ),
            ),
          )
        else
          ...seriesList.map((item) {
            final series = item.series;
            final target = series.totalItems ?? (item.totalCount > 0 ? item.totalCount : 1);
            final progress = (item.completedCount / target).clamp(0.0, 1.0);
            final percent = (progress * 100).toInt();

            return AscentCard(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(16),
              onTap: () => context.push('/analytics/series/${series.id}'),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          series.title,
                          style: AscentTextStyles.labelLarge.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Text(
                              '$percent% complete',
                              style: AscentTextStyles.monoCode.copyWith(
                                color: context.accentPrimary,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '(${item.completedCount}/$target milestones)',
                              style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(6),
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: context.bgBase,
                            valueColor: AlwaysStoppedAnimation<Color>(context.accentPrimary),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Icon(Icons.chevron_right_rounded, color: context.textMuted),
                ],
              ),
            );
          }),
      ],
    );
  }
}
