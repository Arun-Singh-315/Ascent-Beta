import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/providers/database_provider.dart';

class InAppReminderDialog extends ConsumerWidget {
  final Reminder reminder;

  const InAppReminderDialog({
    super.key,
    required this.reminder,
  });

  static Future<void> show(BuildContext context, Reminder reminder) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => InAppReminderDialog(reminder: reminder),
    );
  }

  Future<void> _snooze(BuildContext context, WidgetRef ref, Duration duration) async {
    HapticFeedback.lightImpact();
    final newScheduled = DateTime.now().add(duration);
    final dao = ref.read(reminderDaoProvider);

    await dao.updateReminder(
      reminder.toCompanion(true).copyWith(
        scheduledAt: drift.Value(newScheduled),
      ),
    );
    await NotificationService.instance.scheduleReminderNotification(
      id: reminder.id,
      title: reminder.title,
      scheduledAt: newScheduled,
    );

    ref.invalidate(allRemindersProvider);
    ref.invalidate(nextUpcomingReminderProvider);

    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Snoozed for ${duration.inMinutes >= 60 ? "${duration.inHours}h" : "${duration.inMinutes}m"}'),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _snoozeTomorrow(BuildContext context, WidgetRef ref) async {
    HapticFeedback.lightImpact();
    final now = DateTime.now();
    final tomorrow9am = DateTime(now.year, now.month, now.day + 1, 9, 0);
    final dao = ref.read(reminderDaoProvider);

    await dao.updateReminder(
      reminder.toCompanion(true).copyWith(
        scheduledAt: drift.Value(tomorrow9am),
      ),
    );
    await NotificationService.instance.scheduleReminderNotification(
      id: reminder.id,
      title: reminder.title,
      scheduledAt: tomorrow9am,
    );

    ref.invalidate(allRemindersProvider);
    ref.invalidate(nextUpcomingReminderProvider);

    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Snoozed until tomorrow 9:00 AM'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _markDone(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final dao = ref.read(reminderDaoProvider);

    await dao.updateReminder(
      reminder.toCompanion(true).copyWith(
        isActive: const drift.Value(false),
      ),
    );
    await NotificationService.instance.cancel(reminder.id);

    ref.invalidate(allRemindersProvider);
    ref.invalidate(nextUpcomingReminderProvider);

    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Reminder marked as completed!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final infoColor = context.accentInfo;

    return Dialog(
      backgroundColor: context.bgSurfaceElevated,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: infoColor.withValues(alpha: 0.3), width: 1.2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: infoColor.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.alarm_on_rounded,
                    color: infoColor,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'REMINDER DUE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.1,
                          color: infoColor,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Time for your planned task',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          color: context.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: context.textMuted, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                  tooltip: 'Dismiss',
                ),
              ],
            ),

            const SizedBox(height: 18),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: g.fill,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: g.edge),
              ),
              child: Text(
                reminder.title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: context.textPrimary,
                  height: 1.3,
                ),
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'SNOOZE OPTIONS',
              style: GoogleFonts.jetBrainsMono(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.0,
                color: context.textMuted,
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _snooze(context, ref, const Duration(minutes: 10)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.textPrimary,
                      side: BorderSide(color: context.divider),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      '+10m',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _snooze(context, ref, const Duration(hours: 1)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.textPrimary,
                      side: BorderSide(color: context.divider),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      '+1h',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _snoozeTomorrow(context, ref),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: context.textPrimary,
                      side: BorderSide(color: context.divider),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                    child: Text(
                      'Tomorrow',
                      style: GoogleFonts.plusJakartaSans(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 14),

            ElevatedButton.icon(
              onPressed: () => _markDone(context, ref),
              icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
              label: Text(
                'Mark as Done',
                style: GoogleFonts.plusJakartaSans(fontSize: 13, fontWeight: FontWeight.w700),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: context.stateSuccess,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
