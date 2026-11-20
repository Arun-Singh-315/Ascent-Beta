import 'package:ascent/app/app_navigation.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../plans/widgets/plan_protection_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../shared/widgets/ascent_action_menu.dart';
import '../../../shared/widgets/ascent_dialog.dart';
import '../../thought_wall/board/board_actions.dart';
import '../../thought_wall/drop_thought_sheet.dart';
import '../../reminders/reminder_action_ui.dart';
import '../../reminders/widgets/ios_reminder_dialog.dart';

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
    context.open('/thought-wall?thought=${thought.id}');
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
    final result = await showIOSReminderDialog(
      context,
      existing: reminder,
    );
    if (result != null && context.mounted) {
      ref.invalidate(homeVisibleRemindersProvider);
      AscentSnackBar.show(
        context,
        message: 'Reminder updated',
      );
    }
  } catch (_) {
    if (context.mounted) {
      AscentSnackBar.error(
        context,
        message: 'Could not open this reminder. Please retry.',
      );
    }
  }
}
