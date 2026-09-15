import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/database/tables/enums.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_card.dart';
import '../today/task_board_screen.dart';
import 'pipeline_screen.dart';

class CardDetailScreen extends ConsumerStatefulWidget {
  final int applicationId;

  const CardDetailScreen({super.key, required this.applicationId});

  @override
  ConsumerState<CardDetailScreen> createState() => _CardDetailScreenState();
}

class _CardDetailScreenState extends ConsumerState<CardDetailScreen> {
  final _notesController = TextEditingController();
  bool _isEditingNotes = false;
  DateTime? _nextActionDate;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _confirmDelete(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: context.stateDanger.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.delete_outline_rounded, color: context.stateDanger, size: 28),
              ),
              const SizedBox(height: 16),
              Text(
                'Delete Application?',
                style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
              ),
              const SizedBox(height: 8),
              Text(
                'This will permanently delete this application card and its timeline history.',
                textAlign: TextAlign.center,
                style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: AscentButton.destructive(
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: AscentButton.destructive(
                      label: 'Delete',
                      onPressed: () async {
                        Navigator.pop(ctx);
                        await ref
                            .read(applicationDaoProvider)
                            .deleteApplication(widget.applicationId);
                        if (context.mounted) context.pop();
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final appDao = ref.watch(applicationDaoProvider);

    return StreamBuilder<ApplicationRow?>(
      stream: appDao.watchApplicationById(widget.applicationId),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return Scaffold(
            backgroundColor: context.bgBase,
            appBar: AppBar(backgroundColor: context.bgBase, elevation: 0),
            body: const Center(child: CircularProgressIndicator()),
          );
        }

        final app = snapshot.data;
        if (app == null) {
          return Scaffold(
            backgroundColor: context.bgBase,
            appBar: AppBar(backgroundColor: context.bgBase, elevation: 0),
            body: const Center(child: Text('Application not found')),
          );
        }

        if (!_isEditingNotes && _notesController.text.isEmpty) {
          _notesController.text = app.notes ?? '';
          _nextActionDate = app.nextActionDate;
        }

        return Scaffold(
          backgroundColor: context.bgBase,
          appBar: AppBar(
            backgroundColor: context.bgBase,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.pop(),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.edit_outlined),
                tooltip: 'Edit Application',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: context.bgSurface,
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (ctx) => AddApplicationSheet(existing: app),
                  );
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded),
                color: context.stateDanger,
                tooltip: 'Delete Application',
                onPressed: () => _confirmDelete(context),
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            children: [
              // ── Header Card ──────────────────────────────────────────
              AscentCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            app.company,
                            style: AscentTextStyles.displayMedium.copyWith(
                              color: context.textPrimary,
                            ),
                          ),
                        ),
                        _StageBadge(stageName: app.currentStage),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      app.role,
                      style: AscentTextStyles.bodyLarge.copyWith(
                        color: context.textMuted,
                      ),
                    ),
                    if (app.salary != null && app.salary!.trim().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Icon(Icons.payments_outlined, size: 16, color: context.accentSecondary),
                          const SizedBox(width: 8),
                          Text(
                            'Compensation: ${app.salary}',
                            style: AscentTextStyles.bodyMedium.copyWith(
                              color: context.accentSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                    if (app.jobUrl != null && app.jobUrl!.trim().isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.link_rounded, size: 16, color: context.accentPrimary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              app.jobUrl!,
                              style: AscentTextStyles.bodySmall.copyWith(
                                color: context.accentPrimary,
                                decoration: TextDecoration.underline,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 16),
                            tooltip: 'Copy Job URL',
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: app.jobUrl!));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Job URL copied to clipboard')),
                              );
                            },
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.access_time_rounded, size: 16, color: context.textMuted),
                        const SizedBox(width: 6),
                        Text(
                          'Last updated: ${DateFormat.yMMMd().format(app.updatedAt)}',
                          style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // ── Stage Changer Strip ──────────────────────────────────
              Text(
                'MOVE STAGE',
                style: AscentTextStyles.labelSmall.copyWith(
                  color: context.textMuted,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: ApplicationStage.values.map((stage) {
                    final isCurrent = stage.name == app.currentStage;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        selected: isCurrent,
                        label: Text(stage.name.toUpperCase()),
                        onSelected: (selected) async {
                          if (selected && !isCurrent) {
                            await appDao.moveToStage(app.id, stage);
                            setState(() {});
                          }
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),

              // ── Next Action Date ─────────────────────────────────────
              AscentCard(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(Icons.event_note_rounded, color: context.accentPrimary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Next Action Deadline',
                            style: AscentTextStyles.labelLarge.copyWith(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            _nextActionDate != null
                                ? DateFormat.yMMMd().format(_nextActionDate!)
                                : 'No action scheduled',
                            style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      child: Text(_nextActionDate == null ? 'Set Date' : 'Change'),
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: _nextActionDate ?? DateTime.now().add(const Duration(days: 3)),
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (picked != null) {
                          setState(() => _nextActionDate = picked);
                          await appDao.updateApplication(
                            ApplicationTableCompanion(
                              id: drift.Value(app.id),
                              nextActionDate: drift.Value(picked),
                              updatedAt: drift.Value(DateTime.now()),
                            ),
                          );
                        }
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Quick Shortcut: Interview Prep ───────────────────────
              AscentCard(
                color: context.accentPrimary.withValues(alpha: 0.08),
                padding: const EdgeInsets.all(16),
                onTap: () {
                  context.push('/interview-prep?applicationId=${app.id}');
                },
                child: Row(
                  children: [
                    Icon(Icons.psychology_rounded, color: context.accentPrimary),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Interview Prep for ${app.company}',
                            style: AscentTextStyles.labelLarge.copyWith(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Log expected questions, practice notes & outcomes',
                            style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: context.accentPrimary),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Tasks for this Application (§8) ──────────────────────────
              AscentCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.check_circle_outline_rounded, color: context.accentPrimary, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Tasks for this Application',
                              style: AscentTextStyles.labelLarge.copyWith(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle_outline_rounded, color: context.accentPrimary),
                          tooltip: 'Add Task',
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: context.bgSurface,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                              ),
                              builder: (ctx) => AddTaskSheet(
                                prefilledApplicationId: app.id,
                                initialTitle: '${app.company} - ',
                              ),
                            );
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    StreamBuilder<List<Task>>(
                      stream: ref.watch(taskDaoProvider).watchTasksForApplication(app.id),
                      builder: (context, taskSnapshot) {
                        final tasks = taskSnapshot.data ?? [];
                        if (tasks.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No tasks linked yet. Tap + to create one (e.g. submit resume, send thank you email).',
                              style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                            ),
                          );
                        }

                        return ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: tasks.length,
                          separatorBuilder: (_, _) => const Divider(height: 12),
                          itemBuilder: (context, idx) {
                            final task = tasks[idx];
                            final isDone = task.actualCompletedDate != null;

                            return InkWell(
                              onTap: () async {
                                final now = DateTime.now();
                                await ref.read(taskDaoProvider).updateTask(
                                  TaskTableCompanion(
                                    id: drift.Value(task.id),
                                    actualCompletedDate: drift.Value(isDone ? null : now),
                                  ),
                                );
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 6),
                                child: Row(
                                  children: [
                                    Icon(
                                      isDone ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                                      color: isDone ? context.accentPrimary : context.textMuted,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        task.title,
                                        style: AscentTextStyles.bodyMedium.copyWith(
                                          color: isDone ? context.textMuted : context.textPrimary,
                                          decoration: isDone ? TextDecoration.lineThrough : null,
                                        ),
                                      ),
                                    ),
                                    if (task.plannedDate != null)
                                      Text(
                                        DateFormat('MMM d').format(task.plannedDate!),
                                        style: AscentTextStyles.caption.copyWith(
                                          color: context.textMuted,
                                          fontSize: 11,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // ── Notes Editor ─────────────────────────────────────────
              AscentCard(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Notes & Context',
                          style: AscentTextStyles.labelLarge.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (_isEditingNotes)
                          IconButton(
                            icon: const Icon(Icons.check_rounded),
                            color: context.accentPrimary,
                            onPressed: () async {
                              setState(() => _isEditingNotes = false);
                              await appDao.updateApplication(
                                ApplicationTableCompanion(
                                  id: drift.Value(app.id),
                                  notes: drift.Value(_notesController.text.trim()),
                                  updatedAt: drift.Value(DateTime.now()),
                                ),
                              );
                            },
                          )
                        else
                          IconButton(
                            icon: const Icon(Icons.edit_outlined, size: 18),
                            onPressed: () => setState(() => _isEditingNotes = true),
                          ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    _isEditingNotes
                        ? TextField(
                            controller: _notesController,
                            maxLines: 4,
                            decoration: InputDecoration(
                              hintText: 'Recruiter name, referral info, salary range, interview impressions...',
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                            ),
                          )
                        : Text(
                            _notesController.text.isEmpty
                                ? 'No notes added yet. Tap edit to add context.'
                                : _notesController.text,
                            style: AscentTextStyles.bodyMedium.copyWith(
                              color: _notesController.text.isEmpty
                                  ? context.textMuted
                                  : context.textPrimary,
                            ),
                          ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // ── Status Journey Timeline (Spec §5.3) ──────────────────
              Text(
                'STATUS JOURNEY TIMELINE',
                style: AscentTextStyles.labelSmall.copyWith(
                  color: context.textMuted,
                  letterSpacing: 1.0,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              StreamBuilder<List<ApplicationStatusHistory>>(
                stream: appDao.watchStatusHistory(app.id),
                builder: (context, histSnapshot) {
                  final history = histSnapshot.data ?? [];
                  if (history.isEmpty) {
                    return Text(
                      'No timeline history recorded yet.',
                      style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                    );
                  }

                  return Column(
                    children: history.map((item) {
                      return _TimelineTile(item: item);
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        );
      },
    );
  }
}

class _StageBadge extends StatelessWidget {
  final String stageName;

  const _StageBadge({required this.stageName});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: context.accentPrimary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        stageName.toUpperCase(),
        style: AscentTextStyles.labelSmall.copyWith(
          color: context.accentPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TimelineTile extends StatelessWidget {
  final ApplicationStatusHistory item;

  const _TimelineTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 12,
              height: 12,
              decoration: BoxDecoration(
                color: context.accentPrimary,
                shape: BoxShape.circle,
              ),
            ),
            Container(
              width: 2,
              height: 48,
              color: context.divider,
            ),
          ],
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Moved to ${item.stage.toUpperCase()}',
                style: AscentTextStyles.labelLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                DateFormat('MMM d, yyyy · h:mm a').format(item.occurredAt),
                style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
              ),
              if (item.notes != null) ...[
                const SizedBox(height: 4),
                Text(
                  item.notes!,
                  style: AscentTextStyles.bodySmall.copyWith(color: context.textPrimary),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
