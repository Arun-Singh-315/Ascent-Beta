import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/skeleton_shimmer.dart';

class StudyPlanScreen extends ConsumerStatefulWidget {
  const StudyPlanScreen({super.key});

  @override
  ConsumerState<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends ConsumerState<StudyPlanScreen> {
  void _openAddPhaseSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => const _AddPhaseSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final studyPhaseDao = ref.watch(studyPhaseDaoProvider);
    final taskDao = ref.watch(taskDaoProvider);

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        title: Text(
          'Study Plan Roadmap',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
        backgroundColor: context.bgBase,
        elevation: 0,
      ),
      floatingActionButton: AscentButton.fab(
        icon: Icons.add_rounded,
        onPressed: () => _openAddPhaseSheet(context),
      ),
      body: StreamBuilder<List<StudyPhase>>(
        stream: studyPhaseDao.watchAllPhases(),
        builder: (context, phaseSnapshot) {
          if (phaseSnapshot.connectionState == ConnectionState.waiting) {
            return Padding(
              padding: const EdgeInsets.all(20),
              child: SkeletonShimmer(height: 240),
            );
          }


          final phases = phaseSnapshot.data ?? [];

          if (phases.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.alt_route_rounded, size: 54, color: context.textMuted),
                    const SizedBox(height: 16),
                    Text(
                      'No Study Phases Set',
                      style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Create your first roadmap phase to organize tasks into structured milestones.',
                      textAlign: TextAlign.center,
                      style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                    ),
                    const SizedBox(height: 24),
                    AscentButton.primary(
                      label: 'Create Phase 1',
                      onPressed: () => _openAddPhaseSheet(context),
                    ),
                  ],
                ),
              ),
            );
          }

          return StreamBuilder<List<Task>>(
            stream: taskDao.watchAllTasks(),
            builder: (context, taskSnapshot) {
              final allTasks = taskSnapshot.data ?? [];

              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: phases.length,
                itemBuilder: (context, index) {
                  final phase = phases[index];
                  final phaseTasks = allTasks
                      .where((t) => t.linkedPhaseId == phase.id)
                      .toList();
                  final completedCount = phaseTasks
                      .where((t) => t.actualCompletedDate != null)
                      .length;
                  final progress = phaseTasks.isNotEmpty
                      ? completedCount / phaseTasks.length
                      : 0.0;

                  return _PhaseCard(
                    phase: phase,
                    tasks: phaseTasks,
                    progress: progress,
                    completedCount: completedCount,
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

class _PhaseCard extends ConsumerStatefulWidget {
  final StudyPhase phase;
  final List<Task> tasks;
  final double progress;
  final int completedCount;

  const _PhaseCard({
    required this.phase,
    required this.tasks,
    required this.progress,
    required this.completedCount,
  });

  @override
  ConsumerState<_PhaseCard> createState() => _PhaseCardState();
}

class _PhaseCardState extends ConsumerState<_PhaseCard> {
  bool _expanded = false;

  Color _parseColor(String hex) {
    try {
      final clean = hex.replaceAll('#', '');
      return Color(int.parse('FF$clean', radix: 16));
    } catch (_) {
      return const Color(0xFF7FA88A);
    }
  }

  void _showAddTaskDialog(BuildContext context) {
    final titleController = TextEditingController();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
        return Padding(
          padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Add Task to ${widget.phase.title}',
                style: AscentTextStyles.displaySmall.copyWith(color: ctx.textPrimary),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                autofocus: true,
                style: AscentTextStyles.bodyMedium.copyWith(color: ctx.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Task Title *',
                  hintText: 'e.g. Master Binary Trees, Mock interview round',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 20),
              AscentButton.primary(
                label: 'Add Task',
                onPressed: () async {
                  final title = titleController.text.trim();
                  if (title.isNotEmpty) {
                    await ref.read(taskDaoProvider).insertTask(
                          TaskTableCompanion.insert(
                            title: title,
                            linkedPhaseId: drift.Value(widget.phase.id),
                            plannedDate: drift.Value(DateTime.now()),
                          ),
                        );
                    if (ctx.mounted) Navigator.pop(ctx);
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final phaseColor = _parseColor(widget.phase.colorHex);
    final percentInt = (widget.progress * 100).toInt();

    return AscentCard(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(color: phaseColor, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  widget.phase.title,
                  style: AscentTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.textPrimary,
                  ),
                ),
              ),
              Text(
                '$percentInt%',
                style: AscentTextStyles.statMedium.copyWith(
                  color: phaseColor,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (widget.phase.description != null && widget.phase.description!.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              widget.phase.description!,
              style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
            ),
          ],
          const SizedBox(height: 12),

          // Linear Progress Bar (Computed from real tasks - Spec §5.6)
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: widget.progress,
              backgroundColor: context.divider,
              color: phaseColor,
              minHeight: 6,
            ),
          ),
          const SizedBox(height: 10),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${widget.completedCount} / ${widget.tasks.length} tasks completed',
                style: AscentTextStyles.statSmall.copyWith(
                  color: context.textMuted,
                  fontSize: 12,
                ),
              ),
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _expanded ? 'Hide Tasks' : 'View Tasks',
                      style: AscentTextStyles.labelSmall.copyWith(color: phaseColor),
                    ),
                    Icon(
                      _expanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                      size: 16,
                      color: phaseColor,
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Expanding Tasks List with Interactive Toggle and Add Task Button
          if (_expanded) ...[
            const Divider(height: 16),
            if (widget.tasks.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'No tasks attached to this phase yet.',
                  style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                ),
              )
            else
              ...widget.tasks.map((t) {
                final isDone = t.actualCompletedDate != null;
                return InkWell(
                  onTap: () async {
                    final taskDao = ref.read(taskDaoProvider);
                    if (isDone) {
                      await taskDao.markIncomplete(t.id);
                    } else {
                      await taskDao.markComplete(t.id);
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(
                          isDone ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: isDone ? context.accentPrimary : context.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            t.title,
                            style: AscentTextStyles.bodySmall.copyWith(
                              color: isDone ? context.textMuted : context.textPrimary,
                              decoration: isDone ? TextDecoration.lineThrough : null,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
            const SizedBox(height: 6),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                icon: Icon(Icons.add_rounded, size: 18, color: phaseColor),
                label: Text(
                  'Add task to phase',
                  style: AscentTextStyles.labelSmall.copyWith(color: phaseColor, fontWeight: FontWeight.w600),
                ),
                onPressed: () => _showAddTaskDialog(context),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Add Phase Sheet
// ---------------------------------------------------------------------------

class _AddPhaseSheet extends ConsumerStatefulWidget {
  const _AddPhaseSheet();

  @override
  ConsumerState<_AddPhaseSheet> createState() => _AddPhaseSheetState();
}

class _AddPhaseSheetState extends ConsumerState<_AddPhaseSheet> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  String _colorHex = '#7FA88A';
  bool _saving = false;

  static const _palette = ['#7FA88A', '#E8A57C', '#7C9CC4', '#D98C86', '#8FBB9A'];

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    setState(() => _saving = true);
    final dao = ref.read(studyPhaseDaoProvider);

    await dao.insertPhase(
      StudyPhaseTableCompanion.insert(
        title: title,
        description: drift.Value(_descController.text.trim().isEmpty ? null : _descController.text.trim()),
        colorHex: drift.Value(_colorHex),
      ),
    );

    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + bottomInset),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'New Roadmap Phase',
            style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _titleController,
            decoration: InputDecoration(
              labelText: 'Phase Title *',
              hintText: 'e.g. Phase 4: Mock Interviews & Behavioral',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descController,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Description / Goals',
              hintText: 'STAR method practice, system design mock sessions',
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Phase Color Accent:',
            style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
          ),
          const SizedBox(height: 8),
          Row(
            children: _palette.map((hex) {
              final color = Color(int.parse('FF${hex.replaceAll('#', '')}', radix: 16));
              final isSel = _colorHex == hex;
              return GestureDetector(
                onTap: () => setState(() => _colorHex = hex),
                child: Container(
                  width: 32,
                  height: 32,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: isSel ? Border.all(color: context.textPrimary, width: 3) : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),
          AscentButton.primary(
            label: 'Add Phase',
            loading: _saving,
            onPressed: _save,
          ),
        ],
      ),
    );
  }
}
