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
            Wrap(
              spacing: 8,
              runSpacing: 8,
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
                    _showConnectedPopup(
                      context,
                      title: 'Today’s Tasks',
                      popupKey: const ValueKey('glance_popup_tasks'),
                      closeKey: const ValueKey('glance_popup_close_tasks'),
                      content: _TasksPopupContent(
                        activities: activities.value ?? [],
                      ),
                    );
                  },
                ),

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
                    _showConnectedPopup(
                      context,
                      title: 'Today’s Reminders',
                      popupKey: const ValueKey('glance_popup_reminders'),
                      closeKey: const ValueKey('glance_popup_close_reminders'),
                      content: _RemindersPopupContent(
                        reminders: reminders.value ?? [],
                      ),
                    );
                  },
                ),

                // 3. Quick Note / Thought Toggle
                GlassChip(
                  key: const ValueKey('glance_toggle_notes'),
                  icon: Icons.lightbulb_outline_rounded,
                  label: 'Drop thought',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showConnectedPopup(
                      context,
                      title: 'Quick Thought',
                      popupKey: const ValueKey('glance_popup_notes'),
                      closeKey: const ValueKey('glance_popup_close_notes'),
                      content: const _NotesPopupContent(),
                    );
                  },
                ),

                // 4. Focus & Habit Toggle
                GlassChip(
                  key: const ValueKey('glance_toggle_focus'),
                  icon: Icons.bolt_rounded,
                  label: 'Focus & Habit',
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showConnectedPopup(
                      context,
                      title: 'Focus & Habits',
                      popupKey: const ValueKey('glance_popup_focus'),
                      closeKey: const ValueKey('glance_popup_close_focus'),
                      content: const _FocusPopupContent(),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _showConnectedPopup(
    BuildContext context, {
    required String title,
    required Key popupKey,
    required Key closeKey,
    required Widget content,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        final g = ctx.glass;
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
            left: 12,
            right: 12,
            top: 24,
          ),
          child: SafeArea(
            child: Material(
              key: popupKey,
              color: Colors.transparent,
              child: GlassSurface(
                radius: 24,
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Connected Header
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            title,
                            style: AscentTextStyles.homeTitle.copyWith(
                              color: g.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          key: closeKey,
                          tooltip: 'Close',
                          icon: Icon(Icons.close_rounded, color: g.ink, size: 20),
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            Navigator.of(ctx).pop();
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Flexible(child: SingleChildScrollView(child: content)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ── Content: Tasks ─────────────────────────────────────────────────────────

class _TasksPopupContent extends ConsumerWidget {
  const _TasksPopupContent({required this.activities});
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
  const _RemindersPopupContent({required this.reminders});
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
  const _NotesPopupContent();

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
  const _FocusPopupContent();

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
