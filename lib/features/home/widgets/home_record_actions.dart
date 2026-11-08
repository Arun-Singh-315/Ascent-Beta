import 'package:drift/drift.dart' show Value, BooleanExpressionOperators;
import 'package:intl/intl.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/notifications/reminder_alert_sync.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../plans/widgets/plan_protection_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../shared/widgets/ascent_action_menu.dart';
import '../../../shared/widgets/ascent_dialog.dart';
import '../../thought_wall/board/board_actions.dart';
import '../../thought_wall/drop_thought_sheet.dart';
import '../../reminders/reminder_action_ui.dart';

Future<void> showHomeThoughtActions(
  BuildContext context,
  WidgetRef ref,
  Thought thought, {
  required bool locked,
}) async {
  final action = await showAscentActionMenu<String>(
    context: context,
    title: locked ? 'Private commitment' : thought.content,
    actions: [
      const AscentAction('view', 'View details', Icons.open_in_new_rounded),
      if (!locked)
        const AscentAction('edit', 'Edit thought', Icons.edit_outlined),
      if (!locked)
        const AscentAction(
          'delete',
          'Delete thought',
          Icons.delete_outline_rounded,
          destructive: true,
        ),
    ],
  );
  if (!context.mounted) return;
  if (action == 'view') {
    context.push('/thought-wall?thought=${thought.id}');
  } else if (action == 'edit') {
    final confirmed = await AscentDialog.confirm(
      context: context,
      title: 'Edit this thought?',
      content: 'Your changes will only be applied when you save.',
      confirmLabel: 'Continue editing',
      cancelLabel: 'Keep as is',
      icon: Icons.edit_outlined,
    );
    if (confirmed == true && context.mounted) {
      await DropThoughtSheet.show(context, existingThought: thought);
    }
  } else if (action == 'delete') {
    final confirmed = await confirmHomeThoughtDeletion(context);
    if (confirmed && context.mounted) {
      await deleteThoughtsWithUndo(context, ref, [thought]);
    }
  }
}

Future<bool> confirmHomeThoughtDeletion(BuildContext context) async =>
    await AscentDialog.confirm(
      context: context,
      title: 'Delete this thought?',
      content:
          'Remove this thought and its linked items? You can undo this after deleting.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep thought',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    ) ==
    true;

Future<void> showHomeReminderActions(
  BuildContext context,
  WidgetRef ref,
  Reminder reminder,
) async {
  final action = await showAscentActionMenu<String>(
    context: context,
    title: reminder.title,
    actions: const [
      AscentAction('view', 'View reminder', Icons.open_in_new_rounded),
      AscentAction('done', 'Mark done', Icons.check_rounded),
      AscentAction('edit', 'Edit reminder', Icons.edit_outlined),
      AscentAction('snooze', 'Remind me in 10 minutes', Icons.snooze_rounded),
      AscentAction(
        'delete',
        'Delete reminder',
        Icons.delete_outline_rounded,
        destructive: true,
      ),
    ],
  );
  if (!context.mounted || action == null) return;
  if (action == 'view') {
    context.push('/reminders?reminder=${reminder.id}');
  } else if (action == 'edit') {
    await editHomeReminder(context, ref, reminder);
  } else if (action == 'done') {
    await runReminderAction(context, ref, reminder, ReminderRowAction.done);
  } else if (action == 'snooze') {
    await runReminderAction(context, ref, reminder, ReminderRowAction.snooze);
  } else if (action == 'delete') {
    final confirmed = await AscentDialog.confirm(
      context: context,
      title: 'Delete this reminder?',
      content:
          'Its alert will also be cancelled. You can undo this after deleting.',
      confirmLabel: 'Delete',
      cancelLabel: 'Keep reminder',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (confirmed == true && context.mounted) {
      await runReminderAction(context, ref, reminder, ReminderRowAction.delete);
    }
  }
}

Future<void> editHomeReminder(
  BuildContext context,
  WidgetRef ref,
  Reminder reminder,
) async {
  final db = ref.read(databaseProvider);
  try {
    final protection = await db.reminderDao.getReminderProtection(reminder.id);
    if (!context.mounted) return;
    if (protection != null) {
      await showPlanProtectionDialog(
        context,
        ref,
        protection,
        manageOnly: true,
      );
      return;
    }
    await showAscentFrostedDialog<void>(
      context: context,
      builder: (_) =>
          _HomeReminderEditor(reminder: reminder, parentContext: context),
    );
  } catch (_) {
    if (context.mounted) {
      AscentSnackBar.error(
        context,
        message: 'Could not open this reminder. Please retry.',
      );
    }
  }
}

class _HomeReminderEditor extends ConsumerStatefulWidget {
  const _HomeReminderEditor({
    required this.reminder,
    required this.parentContext,
  });
  final Reminder reminder;
  final BuildContext parentContext;
  @override
  ConsumerState<_HomeReminderEditor> createState() =>
      _HomeReminderEditorState();
}

class _HomeReminderEditorState extends ConsumerState<_HomeReminderEditor> {
  late final controller = TextEditingController(text: widget.reminder.title);
  late DateTime at = widget.reminder.scheduledAt;
  bool busy = false;
  String? error;
  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext ctx) {
    final reminder = widget.reminder;
    final context = widget.parentContext;
    final db = ref.read(databaseProvider);
    return AscentDialog(
      title: 'Edit reminder',
      icon: Icons.edit_outlined,
      contentWidget: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            maxLength: 300,
            maxLines: 2,
            decoration: InputDecoration(
              labelText: 'Reminder',
              errorText: error,
            ),
          ),
          const SizedBox(height: 12),
          TextButton.icon(
            icon: const Icon(Icons.calendar_month_outlined),
            label: Text(DateFormat('EEE, d MMM · h:mm a').format(at)),
            onPressed: busy
                ? null
                : () async {
                    final now = DateTime.now();
                    final date = await showDatePicker(
                      context: ctx,
                      initialDate: at.isBefore(now) ? now : at,
                      firstDate: DateTime(now.year, now.month, now.day),
                      lastDate: DateTime(now.year + 20),
                    );
                    if (date == null || !ctx.mounted) return;
                    final time = await showTimePicker(
                      context: ctx,
                      initialTime: TimeOfDay.fromDateTime(at),
                    );
                    if (time != null && ctx.mounted) {
                      setState(
                        () => at = DateTime(
                          date.year,
                          date.month,
                          date.day,
                          time.hour,
                          time.minute,
                        ),
                      );
                    }
                  },
          ),
        ],
      ),
      actions: [
        AscentButton.tonal(
          label: busy ? 'Saving…' : 'Save changes',
          expanded: true,
          onPressed: busy
              ? null
              : () async {
                  final title = controller.text.trim();
                  if (title.isEmpty) {
                    setState(() => error = 'Add a reminder title.');
                    return;
                  }
                  if (!at.isAfter(DateTime.now())) {
                    setState(() => error = 'Choose a future date and time.');
                    return;
                  }
                  final confirmed = await AscentDialog.confirm(
                    context: ctx,
                    title: 'Save these changes?',
                    content:
                        'The reminder and its alert will use your updated details.',
                    confirmLabel: 'Save changes',
                    cancelLabel: 'Keep editing',
                    icon: Icons.check_rounded,
                  );
                  if (confirmed != true || !ctx.mounted) return;
                  setState(() {
                    busy = true;
                    error = null;
                  });
                  try {
                    final count = await db.transaction(() async {
                      if (await db.reminderDao.getReminderProtection(
                            reminder.id,
                          ) !=
                          null) {
                        throw StateError('Reminder is now managed by a plan');
                      }
                      return (db.update(db.reminderTable)..where(
                            (r) =>
                                r.id.equals(reminder.id) &
                                r.title.equals(reminder.title) &
                                r.scheduledAt.equals(reminder.scheduledAt) &
                                r.isActive.equals(reminder.isActive),
                          ))
                          .write(
                            ReminderTableCompanion(
                              title: Value(title),
                              scheduledAt: Value(at),
                              alertSyncPending: const Value(true),
                            ),
                          );
                    });
                    if (count != 1) throw StateError('Reminder changed');
                    var synced = true;
                    try {
                      synced = (await ReminderAlertSync.device(
                        db,
                      ).sync(ids: [reminder.id], onlyPending: true)).complete;
                    } catch (_) {
                      synced = false;
                    }
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      AscentSnackBar.show(
                        context,
                        message: synced
                            ? 'Reminder updated'
                            : 'Saved. Retry Sync reminder alerts to update the alert.',
                      );
                    }
                  } catch (_) {
                    if (ctx.mounted) {
                      setState(() {
                        busy = false;
                        error =
                            'Could not save. Reopen the reminder and try again.';
                      });
                    }
                  }
                },
        ),
        const SizedBox(height: 8),
        AscentButton.outlined(
          label: 'Cancel',
          expanded: true,
          onPressed: busy ? null : () => Navigator.pop(ctx),
        ),
      ],
    );
  }
}
