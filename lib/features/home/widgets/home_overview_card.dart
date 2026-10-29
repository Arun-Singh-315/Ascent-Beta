import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../../shared/widgets/glass_chip.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../reminders/reminder_action_ui.dart';

import '../../promises/widgets/promise_chat_composer.dart';

enum GlanceTab {
  tasks,
  reminders,
  notes,
  focus,
  add,
}

class HomeOverviewCard extends ConsumerWidget {
  const HomeOverviewCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activities = ref.watch(todayActivitiesProvider);
    final reminders = ref.watch(allRemindersProvider);
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);

    final pending = activities.value
        ?.where((a) => a.status != TodayActivityStatus.done)
        .length;
    final done = activities.value
        ?.where((a) => a.status == TodayActivityStatus.done)
        .length;
    final due = reminders.value
        ?.where((r) => r.isActive && r.scheduledAt.isBefore(tomorrow))
        .length;

    final g = context.glass;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: GlassSurface(
        key: const ValueKey('home_overview'),
        radius: 18,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'Your day at a glance',
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        color: g.ink,
                        fontWeight: FontWeight.w700,
                      ),
                ),
                if (done != null && done > 0)
                  Text(
                    '$done done',
                    style: TextStyle(
                      color: g.sage,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 10),

            // Single Row: Todo • Reminder • Thought • Focus • +
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  // 1. Tasks Toggle
                  GlassChip(
                    key: const ValueKey('glance_toggle_tasks'),
                    icon: Icons.checklist_rounded,
                    label: pending == null
                        ? 'Loading…'
                        : pending == 0
                            ? 'All clear'
                            : '$pending to do',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _openConnectedModal(
                        context,
                        initialTab: GlanceTab.tasks,
                        activities: activities.value ?? [],
                        reminders: reminders.value ?? [],
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // 2. Reminders Toggle
                  GlassChip(
                    key: const ValueKey('glance_toggle_reminders'),
                    icon: Icons.notifications_none_rounded,
                    label: due == null
                        ? 'Loading…'
                        : due == 0
                            ? 'No reminders'
                            : '$due due',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _openConnectedModal(
                        context,
                        initialTab: GlanceTab.reminders,
                        activities: activities.value ?? [],
                        reminders: reminders.value ?? [],
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // 3. Quick Note / Thought Toggle
                  GlassChip(
                    key: const ValueKey('glance_toggle_notes'),
                    icon: Icons.lightbulb_outline_rounded,
                    label: 'Drop thought',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _openConnectedModal(
                        context,
                        initialTab: GlanceTab.notes,
                        activities: activities.value ?? [],
                        reminders: reminders.value ?? [],
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // 4. Focus & Habit Toggle
                  GlassChip(
                    key: const ValueKey('glance_toggle_focus'),
                    icon: Icons.bolt_rounded,
                    label: 'Focus & Habit',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _openConnectedModal(
                        context,
                        initialTab: GlanceTab.focus,
                        activities: activities.value ?? [],
                        reminders: reminders.value ?? [],
                      );
                    },
                  ),
                  const SizedBox(width: 8),

                  // 5. Quick Add Toggle (+)
                  GlassChip(
                    key: const ValueKey('glance_toggle_add'),
                    icon: Icons.add_rounded,
                    label: 'Add',
                    onTap: () {
                      HapticFeedback.lightImpact();
                      _openConnectedModal(
                        context,
                        initialTab: GlanceTab.add,
                        activities: activities.value ?? [],
                        reminders: reminders.value ?? [],
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openConnectedModal(
    BuildContext context, {
    required GlanceTab initialTab,
    required List<TodayActivityItem> activities,
    required List<Reminder> reminders,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return _DayAtAGlanceConnectedModal(
          initialTab: initialTab,
          activities: activities,
          reminders: reminders,
        );
      },
    );
  }
}

class _DayAtAGlanceConnectedModal extends ConsumerStatefulWidget {
  const _DayAtAGlanceConnectedModal({
    required this.initialTab,
    required this.activities,
    required this.reminders,
  });

  final GlanceTab initialTab;
  final List<TodayActivityItem> activities;
  final List<Reminder> reminders;

  @override
  ConsumerState<_DayAtAGlanceConnectedModal> createState() =>
      _DayAtAGlanceConnectedModalState();
}

class _DayAtAGlanceConnectedModalState
    extends ConsumerState<_DayAtAGlanceConnectedModal> {
  late GlanceTab _currentTab = widget.initialTab;

  String _titleForTab(GlanceTab tab) {
    switch (tab) {
      case GlanceTab.tasks:
        return 'Today’s Tasks';
      case GlanceTab.reminders:
        return 'Today’s Reminders';
      case GlanceTab.notes:
        return 'Quick Thought';
      case GlanceTab.focus:
        return 'Focus & Habits';
      case GlanceTab.add:
        return 'Quick Add';
    }
  }

  Key _popupKeyForTab(GlanceTab tab) {
    switch (tab) {
      case GlanceTab.tasks:
        return const ValueKey('glance_popup_tasks');
      case GlanceTab.reminders:
        return const ValueKey('glance_popup_reminders');
      case GlanceTab.notes:
        return const ValueKey('glance_popup_notes');
      case GlanceTab.focus:
        return const ValueKey('glance_popup_focus');
      case GlanceTab.add:
        return const ValueKey('glance_popup_add');
    }
  }

  Key _closeKeyForTab(GlanceTab tab) {
    switch (tab) {
      case GlanceTab.tasks:
        return const ValueKey('glance_popup_close_tasks');
      case GlanceTab.reminders:
        return const ValueKey('glance_popup_close_reminders');
      case GlanceTab.notes:
        return const ValueKey('glance_popup_close_notes');
      case GlanceTab.focus:
        return const ValueKey('glance_popup_close_focus');
      case GlanceTab.add:
        return const ValueKey('glance_popup_close_add');
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final pendingCount = widget.activities
        .where((a) => a.status != TodayActivityStatus.done)
        .length;
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final dueCount = widget.reminders
        .where((r) => r.isActive && r.scheduledAt.isBefore(tomorrow))
        .length;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 12,
        right: 12,
        top: 24,
      ),
      child: SafeArea(
        child: Material(
          key: _popupKeyForTab(_currentTab),
          color: Colors.transparent,
          child: GlassSurface(
            radius: 26,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Apple Grab Handle
                Center(
                  child: Container(
                    width: 38,
                    height: 4.5,
                    margin: const EdgeInsets.only(bottom: 12),
                    decoration: BoxDecoration(
                      color: g.ink.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),

                // Connected Header with Title and Close
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        _titleForTab(_currentTab),
                        style: AscentTextStyles.homeTitle.copyWith(
                          color: g.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      key: _closeKeyForTab(_currentTab),
                      tooltip: 'Close',
                      icon: Icon(Icons.close_rounded, color: g.ink, size: 20),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        Navigator.of(context).pop();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 10),

                // Connected Tab Selector Row
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  child: Row(
                    children: [
                      _buildTabPill(
                        tab: GlanceTab.tasks,
                        label: 'Tasks ($pendingCount)',
                        icon: Icons.checklist_rounded,
                        g: g,
                      ),
                      const SizedBox(width: 6),
                      _buildTabPill(
                        tab: GlanceTab.reminders,
                        label: 'Reminders ($dueCount)',
                        icon: Icons.notifications_none_rounded,
                        g: g,
                      ),
                      const SizedBox(width: 6),
                      _buildTabPill(
                        tab: GlanceTab.notes,
                        label: 'Thought',
                        icon: Icons.lightbulb_outline_rounded,
                        g: g,
                      ),
                      const SizedBox(width: 6),
                      _buildTabPill(
                        tab: GlanceTab.focus,
                        label: 'Focus',
                        icon: Icons.bolt_rounded,
                        g: g,
                      ),
                      const SizedBox(width: 6),
                      _buildTabPill(
                        tab: GlanceTab.add,
                        label: '+ Add',
                        icon: Icons.add_rounded,
                        g: g,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),

                // Expanded Connected Content
                Flexible(
                  child: SingleChildScrollView(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 200),
                      child: _buildCurrentContent(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabPill({
    required GlanceTab tab,
    required String label,
    required IconData icon,
    required AscentGlass g,
  }) {
    final isSelected = _currentTab == tab;
    return InkWell(
      key: ValueKey('glance_modal_tab_${tab.name}'),
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _currentTab = tab);
      },
      borderRadius: BorderRadius.circular(16),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6.5),
        decoration: BoxDecoration(
          color: isSelected ? g.ink : g.ink.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? g.ink : g.edge.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 14,
              color: isSelected ? g.bg : g.ink,
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? g.bg : g.ink,
                fontSize: 12,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentContent() {
    switch (_currentTab) {
      case GlanceTab.tasks:
        return _TasksPopupContent(
          key: const ValueKey('glance_tab_content_tasks'),
          activities: widget.activities,
        );
      case GlanceTab.reminders:
        return _RemindersPopupContent(
          key: const ValueKey('glance_tab_content_reminders'),
          reminders: widget.reminders,
        );
      case GlanceTab.notes:
        return _NotesPopupContent(
          key: const ValueKey('glance_tab_content_notes'),
        );
      case GlanceTab.focus:
        return _FocusPopupContent(
          key: const ValueKey('glance_tab_content_focus'),
        );
      case GlanceTab.add:
        return _AddPopupContent(
          key: const ValueKey('glance_tab_content_add'),
        );
    }
  }
}

// ── Content: Tasks ─────────────────────────────────────────────────────────

class _TasksPopupContent extends ConsumerWidget {
  const _TasksPopupContent({super.key, required this.activities});
  final List<TodayActivityItem> activities;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final pending = activities
        .where((a) => a.status != TodayActivityStatus.done)
        .toList();

    if (pending.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.check_circle_outline_rounded, size: 36, color: g.sage),
              const SizedBox(height: 8),
              Text(
                'All tasks completed for today!',
                style: TextStyle(color: g.ink, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/today');
                },
                child: const Text('Open board'),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final item in pending.take(5))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: g.fill.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: g.edge),
              ),
              child: Row(
                children: [
                  Checkbox(
                    value: item.status == TodayActivityStatus.done,
                    activeColor: g.clay,
                    onChanged: (val) async {
                      if (item.isScheduledInFuture) {
                        HapticFeedback.lightImpact();
                        final timeStr = item.scheduledTime != null
                            ? DateFormat('h:mm a').format(item.scheduledTime!)
                            : 'later';
                        AscentSnackBar.show(
                          context,
                          message:
                              'Scheduled for $timeStr. You can complete it once that time arrives.',
                        );
                        return;
                      }
                      HapticFeedback.mediumImpact();
                      if (item.linkedTaskId != null) {
                        await ref
                            .read(taskDaoProvider)
                            .toggleTaskCompletion(item.linkedTaskId!, true);
                      }
                      if (context.mounted) {
                        AscentSnackBar.success(
                          context,
                          message: 'Marked "${item.title}" done',
                        );
                      }
                    },
                  ),
                  Expanded(
                    child: Text(
                      item.title,
                      style: TextStyle(
                        color: g.ink,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 8),
        Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: 8,
          runSpacing: 4,
          children: [
            TextButton.icon(
              onPressed: () {
                Navigator.pop(context);
                context.push('/today');
              },
              icon: const Icon(Icons.add_task_rounded, size: 16),
              label: const Text('Open board'),
            ),
            Text(
              '${pending.length} pending',
              style: TextStyle(color: g.inkMuted, fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

// ── Content: Reminders ─────────────────────────────────────────────────────

class _RemindersPopupContent extends ConsumerWidget {
  const _RemindersPopupContent({super.key, required this.reminders});
  final List<Reminder> reminders;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final now = DateTime.now();
    final tomorrow = DateTime(now.year, now.month, now.day + 1);
    final due = reminders
        .where((r) => r.isActive && r.scheduledAt.isBefore(tomorrow))
        .toList();

    if (due.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Center(
          child: Column(
            children: [
              Icon(Icons.notifications_none_rounded, size: 36, color: g.clay),
              const SizedBox(height: 8),
              Text(
                'No upcoming reminders due today',
                style: TextStyle(color: g.ink, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.push('/reminders');
                },
                child: const Text('View all reminders'),
              ),
            ],
          ),
        ),
      );
    }

    final timeFmt = DateFormat.jm();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final reminder in due.take(4))
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: g.fill.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: g.edge),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          reminder.title,
                          style: TextStyle(
                            color: g.ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          timeFmt.format(reminder.scheduledAt),
                          style: TextStyle(color: g.inkMuted, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.check_rounded, color: g.sage, size: 20),
                    tooltip: 'Done',
                    onPressed: () async {
                      await runReminderAction(
                        context,
                        ref,
                        reminder,
                        ReminderRowAction.done,
                      );
                    },
                  ),
                  IconButton(
                    icon: Icon(Icons.snooze_rounded, color: g.amber, size: 20),
                    tooltip: 'Snooze',
                    onPressed: () async {
                      await runReminderAction(
                        context,
                        ref,
                        reminder,
                        ReminderRowAction.snooze,
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        TextButton(
          onPressed: () {
            Navigator.pop(context);
            context.push('/reminders');
          },
          child: const Text('View all reminders'),
        ),
      ],
    );
  }
}

// ── Content: Quick Note ────────────────────────────────────────────────────

class _NotesPopupContent extends ConsumerStatefulWidget {
  const _NotesPopupContent({super.key});

  @override
  ConsumerState<_NotesPopupContent> createState() => _NotesPopupContentState();
}

class _NotesPopupContentState extends ConsumerState<_NotesPopupContent> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _saving) return;

    setState(() => _saving = true);
    try {
      await ref.read(thoughtDaoProvider).insertThought(
            ThoughtTableCompanion.insert(
              content: text,
              mood: const drift.Value('thought'),
            ),
          );
      if (mounted) {
        Navigator.pop(context);
        AscentSnackBar.success(context, message: 'Thought saved to Mind Palace');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('glance_quick_note_field'),
          controller: _controller,
          autofocus: true,
          minLines: 2,
          maxLines: 4,
          style: TextStyle(color: g.ink, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'What’s on your mind? Capture it fast…',
            hintStyle: TextStyle(color: g.inkMuted),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: g.edge),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: g.edge),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: g.clay, width: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 12),
        ElevatedButton.icon(
          onPressed: _saving ? null : _save,
          style: ElevatedButton.styleFrom(
            backgroundColor: g.clay,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
            padding: const EdgeInsets.symmetric(vertical: 12),
          ),
          icon: _saving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.arrow_upward_rounded, size: 18),
          label: const Text('Save Thought'),
        ),
      ],
    );
  }
}

// ── Content: Focus & Habit ─────────────────────────────────────────────────

class _FocusPopupContent extends ConsumerWidget {
  const _FocusPopupContent({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: g.edge),
          ),
          tileColor: g.fill.withValues(alpha: 0.5),
          leading: CircleAvatar(
            backgroundColor: g.slateSoft,
            child: Icon(Icons.water_drop_rounded, color: g.slate, size: 20),
          ),
          title: Text(
            'Log +250ml Water',
            style: TextStyle(color: g.ink, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'Stay hydrated throughout your day',
            style: TextStyle(color: g.inkMuted, fontSize: 12),
          ),
          onTap: () async {
            HapticFeedback.mediumImpact();
            await ref.read(waterDaoProvider).addWater(250);
            if (context.mounted) {
              Navigator.pop(context);
              AscentSnackBar.success(context, message: 'Logged 250ml of water');
            }
          },
        ),
        const SizedBox(height: 10),
        ListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: g.edge),
          ),
          tileColor: g.fill.withValues(alpha: 0.5),
          leading: CircleAvatar(
            backgroundColor: g.amberSoft,
            child: Icon(Icons.timer_rounded, color: g.amber, size: 20),
          ),
          title: Text(
            'Start 25m Focus Session',
            style: TextStyle(color: g.ink, fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            'Deep work countdown timer',
            style: TextStyle(color: g.inkMuted, fontSize: 12),
          ),
          onTap: () {
            HapticFeedback.mediumImpact();
            Navigator.pop(context);
            context.push('/focus');
          },
        ),
      ],
    );
  }
}

// ── Content: Quick Add Hub ──────────────────────────────────────────────────

class _AddPopupContent extends ConsumerStatefulWidget {
  const _AddPopupContent({super.key});

  @override
  ConsumerState<_AddPopupContent> createState() => _AddPopupContentState();
}

class _AddPopupContentState extends ConsumerState<_AddPopupContent> {
  final _taskController = TextEditingController();
  bool _savingTask = false;

  @override
  void dispose() {
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _handleCreateTask() async {
    final title = _taskController.text.trim();
    if (title.isEmpty || _savingTask) return;

    setState(() => _savingTask = true);
    try {
      HapticFeedback.mediumImpact();
      final db = ref.read(databaseProvider);
      await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: title,
          plannedDate: drift.Value(DateTime.now()),
        ),
      );
      _taskController.clear();
      if (mounted) {
        Navigator.pop(context);
        AscentSnackBar.success(context, message: 'Added task: "$title"');
      }
    } finally {
      if (mounted) setState(() => _savingTask = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Quick To-do Input (Rule 19 Compliant Single-Enclosure Pill)
        Container(
          height: 48,
          padding: const EdgeInsets.only(left: 14, right: 4),
          decoration: BoxDecoration(
            color: g.ink.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: g.edge.withValues(alpha: 0.2),
              width: 1,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _taskController,
                  style: TextStyle(color: g.ink, fontSize: 14),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _handleCreateTask(),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Quick to-do item…',
                    hintStyle: TextStyle(
                      color: g.inkMuted.withValues(alpha: 0.6),
                      fontSize: 13.5,
                    ),
                    isDense: true,
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              IconButton(
                onPressed: _savingTask ? null : _handleCreateTask,
                tooltip: 'Add Task',
                icon: _savingTask
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(Icons.add_circle_rounded, color: g.clay, size: 26),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // Quick Creator Shortcuts
        _buildActionTile(
          context: context,
          icon: Icons.handshake_rounded,
          color: g.coral,
          bgColor: g.coralSoft,
          title: 'Seal a Promise',
          subtitle: 'Commit to a meaningful life habit or intention',
          onTap: () {
            Navigator.pop(context);
            PromiseChatComposer.show(context);
          },
        ),
        const SizedBox(height: 8),

        _buildActionTile(
          context: context,
          icon: Icons.notifications_active_rounded,
          color: g.amber,
          bgColor: g.amberSoft,
          title: 'Set a Reminder',
          subtitle: 'Schedule an alert for today or later',
          onTap: () {
            Navigator.pop(context);
            context.push('/reminders');
          },
        ),
        const SizedBox(height: 8),

        _buildActionTile(
          context: context,
          icon: Icons.timer_rounded,
          color: g.slate,
          bgColor: g.slateSoft,
          title: 'Focus Timer',
          subtitle: 'Start deep work session or Pomodoro countdown',
          onTap: () {
            Navigator.pop(context);
            context.push('/focus');
          },
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required BuildContext context,
    required IconData icon,
    required Color color,
    required Color bgColor,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    final g = context.glass;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: g.fill.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: g.edge.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: g.ink,
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(color: g.inkMuted, fontSize: 12),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              size: 13,
              color: g.inkMuted.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}
