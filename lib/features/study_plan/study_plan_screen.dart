import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

import '../../app/router.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/color_tokens.dart';
import '../../app/theme/shared_control_tokens.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/widgets/ascent_switch.dart';
import '../../shared/widgets/ascent_button.dart';

final studyPlansListStreamProvider = StreamProvider<List<PlanCollection>>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.planCollectionTable)
        ..where((c) =>
            c.description.like('%study%') |
            c.title.like('%Study%') |
            c.title.like('%DSA%') |
            c.title.like('%Exam%') |
            c.title.like('%Syllabus%'))
        ..orderBy([(c) => drift.OrderingTerm.desc(c.createdAt)]))
      .watch();
});

final studyPlanItemsStreamProvider =
    StreamProvider.family<List<PlanCollectionItem>, String>((ref, collectionId) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.planCollectionItemTable)
        ..where((i) => i.collectionId.equals(collectionId))
        ..orderBy([(i) => drift.OrderingTerm.asc(i.position)]))
      .watch();
});

final studyReminderStreamProvider = StreamProvider<Reminder?>((ref) {
  final db = ref.watch(databaseProvider);
  return (db.select(db.reminderTable)
        ..where((r) => r.title.like('%Study%') | r.title.like('%study%'))
        ..limit(1))
      .watchSingleOrNull();
});

final planTasksStreamProvider =
    StreamProvider.family<List<Task>, String>((ref, planId) {
  final db = ref.watch(databaseProvider);
  final itemsQuery = db.select(db.planCollectionItemTable)
    ..where((i) => i.collectionId.equals(planId));
  return itemsQuery.watch().asyncMap((items) async {
    final taskIds = items.map((i) => i.taskId).whereType<int>().toList();
    if (taskIds.isEmpty) return <Task>[];
    return (db.select(db.taskTable)..where((t) => t.id.isIn(taskIds))).get();
  });
});

class StudyPlanScreen extends ConsumerStatefulWidget {
  final String? courseId;
  const StudyPlanScreen({super.key, this.courseId});

  @override
  ConsumerState<StudyPlanScreen> createState() => _StudyPlanScreenState();
}

class _StudyPlanScreenState extends ConsumerState<StudyPlanScreen> {
  String? _selectedPlanId;

  Future<void> _deletePlan(PlanCollection plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.bgSurface,
        title: Text(
          'Delete Study Plan?',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700),
        ),
        content: Text(
          'This will remove "${plan.title}" and its scheduled study sessions and reminders cleanly.',
          style: GoogleFonts.plusJakartaSans(fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: SharedControlColors.dueRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      final db = ref.read(databaseProvider);
      await db.transaction(() async {
        final items = await (db.select(db.planCollectionItemTable)
              ..where((i) => i.collectionId.equals(plan.id)))
            .get();
        for (final item in items) {
          if (item.taskId != null) {
            await (db.delete(db.reminderTable)
                  ..where((r) => r.linkedTaskId.equals(item.taskId!)))
                .go();
            await (db.delete(db.taskTable)
                  ..where((t) => t.id.equals(item.taskId!)))
                .go();
          }
        }
        await (db.delete(db.planCollectionTable)
              ..where((c) => c.id.equals(plan.id)))
            .go();
      });

      if (mounted) {
        setState(() => _selectedPlanId = null);
        AscentSnackBar.show(context, message: 'Study plan deleted.');
      }
    } catch (e) {
      if (mounted) {
        AscentSnackBar.error(context, message: 'Could not delete plan: $e');
      }
    }
  }

  Future<void> _toggleTaskCompletion(int taskId, bool currentlyDone) async {
    HapticFeedback.lightImpact();
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    await db.taskDao.updateTask(
      TaskTableCompanion(
        id: drift.Value(taskId),
        actualCompletedDate: drift.Value(currentlyDone ? null : now),
      ),
    );
  }

  Future<void> _toggleStudyReminder(bool enable, Reminder? existingReminder) async {
    final db = ref.read(databaseProvider);
    HapticFeedback.lightImpact();
    if (existingReminder != null) {
      await db.reminderDao.updateReminder(
        ReminderTableCompanion(
          id: drift.Value(existingReminder.id),
          isActive: drift.Value(enable),
          alertSyncPending: const drift.Value(true),
        ),
      );
      if (mounted) {
        AscentSnackBar.show(
          context,
          message: enable
              ? 'Daily study reminder enabled'
              : 'Daily study reminder paused',
          icon: enable ? Icons.alarm_on_rounded : Icons.alarm_off_rounded,
        );
      }
    } else if (enable) {
      final now = DateTime.now();
      var scheduled = DateTime(now.year, now.month, now.day, 19, 30);
      if (scheduled.isBefore(now)) {
        scheduled = scheduled.add(const Duration(days: 1));
      }
      await db.reminderDao.insertReminder(
        ReminderTableCompanion.insert(
          title: 'Daily Study Session · Deep Focus & Mastery 📚',
          scheduledAt: scheduled,
          isActive: const drift.Value(true),
          alertSyncPending: const drift.Value(true),
        ),
      );
      if (mounted) {
        AscentSnackBar.show(
          context,
          message: 'Daily study reminder scheduled for 7:30 PM',
          icon: Icons.notifications_active_rounded,
        );
      }
    }
  }

  void _showAddMilestoneDialog(PlanCollection plan, int nextPosition) {
    final titleController = TextEditingController();
    final minutesController = TextEditingController(text: '45');
    final notesController = TextEditingController();

    showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      useSafeArea: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final g = ctx.glass;
        final isDark = Theme.of(ctx).brightness == Brightness.dark;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? g.surface : Colors.white,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              border: Border.all(
                color: g.line.withValues(alpha: isDark ? 0.35 : 0.20),
              ),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Add Study Topic',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: g.ink,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: titleController,
                    decoration: InputDecoration(
                      labelText: 'Topic Title',
                      hintText: 'e.g. Dynamic Programming, Trees',
                      filled: true,
                      fillColor: isDark ? g.surface : g.track.withValues(alpha: 0.1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: minutesController,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Target Duration (Minutes)',
                      prefixIcon: const Icon(Icons.timer_outlined),
                      filled: true,
                      fillColor: isDark ? g.surface : g.track.withValues(alpha: 0.1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: notesController,
                    decoration: InputDecoration(
                      labelText: 'Key Concepts / Notes (Optional)',
                      hintText: 'e.g. Recursion base cases',
                      filled: true,
                      fillColor: isDark ? g.surface : g.track.withValues(alpha: 0.1),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                  const SizedBox(height: 20),
                  AscentButton.primary(
                    label: 'Add to Syllabus',
                    icon: Icons.add_rounded,
                    onPressed: () async {
                      final title = titleController.text.trim();
                      if (title.isEmpty) return;
                      final minutes = int.tryParse(minutesController.text.trim()) ?? 45;
                      final notes = notesController.text.trim();
                      final db = ref.read(databaseProvider);
                      final taskId = await db.taskDao.insertTask(
                        TaskTableCompanion.insert(
                          title: title,
                          notes: drift.Value(notes),
                          estimatedMinutes: drift.Value(minutes),
                        ),
                      );
                      final itemId = 'item-${DateTime.now().millisecondsSinceEpoch}';
                      await db.into(db.planCollectionItemTable).insert(
                        PlanCollectionItemTableCompanion.insert(
                          id: itemId,
                          collectionId: plan.id,
                          title: title,
                          notes: drift.Value(notes),
                          position: nextPosition,
                          taskId: drift.Value(taskId),
                        ),
                      );
                      if (ctx.mounted) Navigator.pop(ctx);
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final plansAsync = ref.watch(studyPlansListStreamProvider);
    final studyReminderAsync = ref.watch(studyReminderStreamProvider);

    return AscentScaffold(
      title: 'Study Plan Hub',
      backgroundColor: context.bgSurface,
      actions: [
        IconButton(
          icon: const Icon(Icons.auto_awesome_rounded, size: 20),
          tooltip: 'Ask Riya to build a plan',
          onPressed: () => context.push(AscentRoutes.aiAssistant),
        ),
      ],
      body: plansAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error loading plans: $e')),
        data: (plans) {
          if (plans.isEmpty) {
            return Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: context.accentPrimary.withValues(alpha: 0.12),
                        border: Border.all(
                          color: context.accentPrimary.withValues(alpha: 0.30),
                          width: 1,
                        ),
                      ),
                      child: Center(
                        child: Icon(Icons.school_rounded, color: context.accentPrimary, size: 30),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'No Study Plans Active',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: g.ink,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ask Riya to compose a structured study plan for your upcoming exams or topics.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13.5,
                        color: g.inkSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () => context.push(AscentRoutes.aiAssistant),
                      icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                      label: const Text('Create Study Plan with Riya'),
                      style: FilledButton.styleFrom(
                        backgroundColor: context.accentPrimary,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            );
          }

          final activePlan = plans.firstWhere(
            (p) => p.id == _selectedPlanId,
            orElse: () => plans.first,
          );

          final itemsAsync = ref.watch(studyPlanItemsStreamProvider(activePlan.id));
          final planTasksAsync = ref.watch(planTasksStreamProvider(activePlan.id));
          final tasks = planTasksAsync.value ?? [];

          return Column(
            children: [
              // Multiple Plans Switcher (If > 1 active plan)
              if (plans.length > 1) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: plans.map((p) {
                        final isSelected = p.id == activePlan.id;
                        return Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            selected: isSelected,
                            onSelected: (_) => setState(() => _selectedPlanId = p.id),
                            label: Text(
                              p.title,
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 12,
                                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],

              Expanded(
                child: itemsAsync.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (items) {
                    final taskMap = {for (final t in tasks) t.id: t};
                    final completedCount = items
                        .where((i) => i.taskId != null && taskMap[i.taskId]?.actualCompletedDate != null)
                        .length;
                    final progress = items.isEmpty ? 0.0 : (completedCount / items.length).clamp(0.0, 1.0);
                    final remainingMinutes = items
                        .where((i) => i.taskId == null || taskMap[i.taskId]?.actualCompletedDate == null)
                        .fold<int>(0, (sum, i) => sum + (taskMap[i.taskId]?.estimatedMinutes ?? 45));

                    // Next pending focus topic
                    final nextFocusItem = items
                        .where((i) => i.taskId == null || taskMap[i.taskId]?.actualCompletedDate == null)
                        .firstOrNull;

                    // First completed item for spaced review
                    final completedItem = items
                        .where((i) => i.taskId != null && taskMap[i.taskId]?.actualCompletedDate != null)
                        .firstOrNull;

                    final reminder = studyReminderAsync.value;
                    final isReminderActive = reminder?.isActive == true;

                    return ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        // Active Plan Glass Overview Card
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark
                                ? g.surface.withValues(alpha: 0.90)
                                : Colors.white.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: g.line.withValues(alpha: isDark ? 0.35 : 0.20),
                              width: 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.05),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      activePlan.title,
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 18,
                                        fontWeight: FontWeight.w700,
                                        color: g.ink,
                                      ),
                                    ),
                                  ),
                                  IconButton(
                                    icon: Icon(Icons.delete_outline_rounded,
                                        color: SharedControlColors.dueRed, size: 20),
                                    onPressed: () => _deletePlan(activePlan),
                                    tooltip: 'Delete Plan',
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '$completedCount of ${items.length} Milestones Mastered • ~${remainingMinutes}m Study Left',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: g.inkSecondary,
                                ),
                              ),
                              const SizedBox(height: 14),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(6),
                                child: LinearProgressIndicator(
                                  value: progress,
                                  minHeight: 6,
                                  backgroundColor: g.line.withValues(alpha: 0.25),
                                  valueColor: AlwaysStoppedAnimation(context.accentPrimary),
                                ),
                              ),
                            ],
                          ),
                        ),

                        // "Today's Study Focus" Companion Card
                        if (nextFocusItem != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: context.accentPrimary.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: context.accentPrimary.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.bolt_rounded, color: context.accentPrimary, size: 20),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        "Today's Study Focus",
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w700,
                                          color: context.accentPrimary,
                                        ),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                      decoration: BoxDecoration(
                                        color: context.accentPrimary.withValues(alpha: 0.15),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        '${taskMap[nextFocusItem.taskId]?.estimatedMinutes ?? 45}m focus',
                                        style: GoogleFonts.jetBrainsMono(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                          color: context.accentPrimary,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  nextFocusItem.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: g.ink,
                                  ),
                                ),
                                if (nextFocusItem.notes.isNotEmpty) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    nextFocusItem.notes,
                                    style: GoogleFonts.plusJakartaSans(
                                      fontSize: 12,
                                      color: g.inkSecondary,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 14),
                                AscentButton.primary(
                                  label: 'Start Study Session',
                                  icon: Icons.play_arrow_rounded,
                                  onPressed: () {
                                    HapticFeedback.lightImpact();
                                    context.push(AscentRoutes.chaiBreak);
                                  },
                                ),
                              ],
                            ),
                          ),
                        ],

                        // Daily Study Habit Reminder Card
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: isDark ? g.surface.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.90),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: g.line.withValues(alpha: isDark ? 0.30 : 0.15),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 40,
                                height: 40,
                                decoration: BoxDecoration(
                                  color: isReminderActive
                                      ? context.accentPrimary.withValues(alpha: 0.15)
                                      : g.track.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.alarm_rounded,
                                  color: isReminderActive ? context.accentPrimary : g.inkMuted,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Daily Study Reminder',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w700,
                                        color: g.ink,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      isReminderActive && reminder != null
                                          ? 'Scheduled daily at ${DateFormat.jm().format(reminder.scheduledAt)}'
                                          : 'Gentle nudge to protect daily learning',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 11.5,
                                        color: g.inkSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              AscentSwitch(
                                key: const ValueKey('study_reminder_switch'),
                                value: isReminderActive,
                                onChanged: (val) => _toggleStudyReminder(val, reminder),
                              ),
                            ],
                          ),
                        ),

                        // Spaced Repetition / Memory Retention Card
                        if (completedItem != null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: g.sage.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: g.sage.withValues(alpha: 0.25),
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.psychology_outlined, color: g.sage, size: 22),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Spaced Recall Suggestion',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w700,
                                          color: g.sage,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Review "${completedItem.title}" to reinforce long-term retention.',
                                        style: GoogleFonts.plusJakartaSans(
                                          fontSize: 11.5,
                                          color: g.ink,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

                        const SizedBox(height: 20),

                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Syllabus & Milestones',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: g.ink,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => _showAddMilestoneDialog(activePlan, items.length),
                              icon: const Icon(Icons.add_rounded, size: 16),
                              label: const Text('Add Topic'),
                              style: TextButton.styleFrom(
                                foregroundColor: context.accentPrimary,
                                textStyle: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),

                        // List of items
                        for (final item in items) ...[
                          _StudyMilestoneTile(
                            item: item,
                            onToggleDone: (taskId, isDone) =>
                                _toggleTaskCompletion(taskId, isDone),
                          ),
                          const SizedBox(height: 8),
                        ],
                      ],
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _StudyMilestoneTile extends ConsumerWidget {
  const _StudyMilestoneTile({
    required this.item,
    required this.onToggleDone,
  });

  final PlanCollectionItem item;
  final void Function(int taskId, bool isDone) onToggleDone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final db = ref.watch(databaseProvider);
    final taskAsync = item.taskId != null
        ? ref.watch(
            StreamProvider((ref) => (db.select(db.taskTable)
                  ..where((t) => t.id.equals(item.taskId!)))
                .watchSingleOrNull()),
          )
        : null;

    final task = taskAsync?.value;
    final isCompleted = task?.actualCompletedDate != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: isDark ? g.surface.withValues(alpha: 0.85) : Colors.white.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isCompleted
              ? g.sage.withValues(alpha: 0.3)
              : g.line.withValues(alpha: isDark ? 0.30 : 0.15),
          width: 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GestureDetector(
            onTap: item.taskId != null ? () => onToggleDone(item.taskId!, isCompleted) : null,
            child: Container(
              margin: const EdgeInsets.only(top: 2),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isCompleted ? g.sage : Colors.transparent,
                border: Border.all(
                  color: isCompleted ? g.sage : g.inkMuted,
                  width: 1.5,
                ),
              ),
              child: isCompleted
                  ? const Center(
                      child: Icon(Icons.check_rounded, color: Colors.white, size: 14),
                    )
                  : null,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: isCompleted ? g.inkMuted : g.ink,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                if (item.notes.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    item.notes,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11.5,
                      color: g.inkSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (task?.estimatedMinutes != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
              decoration: BoxDecoration(
                color: context.accentPrimary.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                '${task!.estimatedMinutes}m',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: context.accentPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
