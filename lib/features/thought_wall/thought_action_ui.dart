import 'package:flutter/material.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import 'thought_actions.dart';

Future<void> applyThoughtAction(
  BuildContext context,
  AppDatabase db,
  List<Thought> thoughts,
  String action,
) async {
  if (thoughts.isEmpty) return;
  final service = ThoughtActions(db);
  String message;
  try {
    if (action == 'todo') {
      final ids = await service.addToTodo(thoughts);
      message = '${ids.length} notes available in Todo';
    } else {
      final now = DateTime.now();
      final date = await showDatePicker(
        context: context,
        initialDate: now,
        firstDate: DateTime(now.year, now.month, now.day),
        lastDate: now.add(const Duration(days: 365)),
      );
      if (date == null || !context.mounted) return;
      final time = await showTimePicker(
        context: context,
        initialTime: TimeOfDay.fromDateTime(now.add(const Duration(hours: 1))),
      );
      if (time == null || !context.mounted) return;
      final at = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
      if (!at.isAfter(DateTime.now())) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Choose a future date and time.')),
        );
        return;
      }
      final reminders = await service.remind(
        thoughts,
        at,
        asList: action == 'list_reminder',
      );
      message = action == 'list_reminder'
          ? 'List reminder saved'
          : '${reminders.length} reminders saved';
      try {
        await scheduleThoughtReminders(
          reminders,
          (r) => NotificationService.instance.scheduleReminderNotification(
            id: r.id,
            title: r.title,
            scheduledAt: r.scheduledAt,
          ),
        );
      } catch (_) {
        message =
            'Saved in Reminders. Device alerts could not be scheduled; check notification settings.';
      }
    }
  } catch (_) {
    message = 'Could not save. Your notes are still here; please try again.';
  }
  if (context.mounted) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 4),
        persist: false,
      ),
    );
  }
}
