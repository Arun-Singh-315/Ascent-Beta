import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/providers/database_provider.dart';

class InAppReminderDialog extends ConsumerWidget {
  final Reminder reminder;

  const InAppReminderDialog({super.key, required this.reminder});

  static Future<void> show(BuildContext context, Reminder reminder) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) => InAppReminderDialog(reminder: reminder),
    );
  }

  Future<void> _snooze(
    BuildContext context,
    WidgetRef ref,
    Duration duration,
  ) async {
    HapticFeedback.lightImpact();
    final newScheduled = DateTime.now().add(duration);
    final dao = ref.read(reminderDaoProvider);

    await dao.updateReminder(
      reminder
          .toCompanion(true)
          .copyWith(scheduledAt: drift.Value(newScheduled)),
    );
    await NotificationService.instance.scheduleReminderNotification(
      id: reminder.id,
      title: reminder.title,
      scheduledAt: newScheduled,
      alarmEnabled: reminder.alarmEnabled,
    );

    ref.invalidate(allRemindersProvider);
    ref.invalidate(nextUpcomingReminderProvider);

    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        AscentSnackBar.build(
          context,
          content: Text(
            'Snoozed for ${duration.inMinutes >= 60 ? "${duration.inHours}h" : "${duration.inMinutes}m"}',
          ),
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
      reminder
          .toCompanion(true)
          .copyWith(scheduledAt: drift.Value(tomorrow9am)),
    );
    await NotificationService.instance.scheduleReminderNotification(
      id: reminder.id,
      title: reminder.title,
      scheduledAt: tomorrow9am,
      alarmEnabled: reminder.alarmEnabled,
    );

    ref.invalidate(allRemindersProvider);
    ref.invalidate(nextUpcomingReminderProvider);

    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        AscentSnackBar.build(
          context,
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
      reminder.toCompanion(true).copyWith(isActive: const drift.Value(false)),
    );
    await NotificationService.instance.cancel(reminder.id);

    ref.invalidate(allRemindersProvider);
    ref.invalidate(nextUpcomingReminderProvider);

    if (context.mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        AscentSnackBar.build(
          context,
          content: Text('Reminder marked as completed!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final isDark = context.isDark;
    final dialogBg = g.frozen
        ? context.bgSurface
        : isDark
        ? const Color(0xFF1E1813)
        : const Color(0xFFFAF7F2);
    final dialogBorder = (isDark || g.frozen)
        ? g.edge
        : const Color(0xFFE2D6CA);
    final headerAccent = g.frozen
        ? g.clay
        : isDark
        ? const Color(0xFFE6A088)
        : const Color(0xFFA4523A);

    return Dialog(
      backgroundColor: dialogBg,
      elevation: 12,
      shadowColor: AppPalette.black.withValues(alpha: 0.2),
      shape: RoundedRectangleBorder(
        borderRadius: AppGeometry.roundedr24,
        side: BorderSide(color: dialogBorder, width: AppBorderScale.w1point2),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s22),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(AppSpace.s10),
                    decoration: BoxDecoration(
                      color: headerAccent.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.alarm_on_rounded,
                      color: headerAccent,
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
                          style: AppTypography.jetBrainsMono11W70087(
                            color: headerAccent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Time for your planned task',
                          style: AppTypography.plusJakartaSans12Regular57(
                            color: (isDark || g.frozen)
                                ? context.textMuted
                                : const Color(0xFF6B5E52),
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: (isDark || g.frozen)
                          ? context.textMuted
                          : const Color(0xFF7A6D61),
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    tooltip: 'Dismiss',
                  ),
                ],
              ),

              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(AppSpace.s16),
                decoration: BoxDecoration(
                  color: (isDark || g.frozen)
                      ? g.fill
                      : const Color(0xFFF1E9DE),
                  borderRadius: AppGeometry.roundedr14,
                  border: Border.all(
                    color: (isDark || g.frozen)
                        ? g.edge
                        : const Color(0xFFDFD2C3),
                  ),
                ),
                child: Text(
                  reminder.title,
                  style: AppTypography.plusJakartaSans16W70095(
                    color: context.textPrimary,
                  ),
                ),
              ),

              const SizedBox(height: 20),

              Text(
                'SNOOZE OPTIONS',
                style: AppTypography.jetBrainsMono10W70096(
                  color: (isDark || g.frozen)
                      ? context.textMuted
                      : const Color(0xFF7A6D61),
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _snooze(context, ref, const Duration(minutes: 10)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.textPrimary,
                        backgroundColor: (isDark || g.frozen)
                            ? g.fill
                            : const Color(0xFFF5EFE8),
                        minimumSize: const Size(48, 44),
                        side: BorderSide(
                          color: (isDark || g.frozen)
                              ? g.edge
                              : const Color(0xFFDCCFBF),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.s10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppGeometry.roundedr14,
                        ),
                      ),
                      child: Text(
                        '+10m',
                        style: AppTypography.plusJakartaSans12W60097(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          _snooze(context, ref, const Duration(hours: 1)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.textPrimary,
                        backgroundColor: (isDark || g.frozen)
                            ? g.fill
                            : const Color(0xFFF5EFE8),
                        minimumSize: const Size(48, 44),
                        side: BorderSide(
                          color: (isDark || g.frozen)
                              ? g.edge
                              : const Color(0xFFDCCFBF),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.s10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppGeometry.roundedr14,
                        ),
                      ),
                      child: Text(
                        '+1h',
                        style: AppTypography.plusJakartaSans12W60097(),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _snoozeTomorrow(context, ref),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: context.textPrimary,
                        backgroundColor: (isDark || g.frozen)
                            ? g.fill
                            : const Color(0xFFF5EFE8),
                        minimumSize: const Size(48, 44),
                        side: BorderSide(
                          color: (isDark || g.frozen)
                              ? g.edge
                              : const Color(0xFFDCCFBF),
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.s10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: AppGeometry.roundedr14,
                        ),
                      ),
                      child: Text(
                        'Tomorrow',
                        style: AppTypography.plusJakartaSans12W60097(),
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
                  style: AppTypography.plusJakartaSans13W70098(),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: (isDark || g.frozen)
                      ? g.clay
                      : const Color(0xFFB8634D),
                  elevation: 0,
                  minimumSize: const Size(48, 48),
                  foregroundColor: AppPalette.white,
                  padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
                  shape: RoundedRectangleBorder(
                    borderRadius: AppGeometry.roundedr14,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
