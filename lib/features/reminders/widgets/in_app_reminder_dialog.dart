import '../reminder_action_ui.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../core/database/app_database.dart';

class InAppReminderDialog extends ConsumerWidget {
  final Reminder reminder;
  final bool isPreview;

  const InAppReminderDialog({
    super.key,
    required this.reminder,
    this.isPreview = false,
  });

  static Future<void> show(
    BuildContext context,
    Reminder reminder, {
    bool isPreview = false,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (context) =>
          InAppReminderDialog(reminder: reminder, isPreview: isPreview),
    );
  }

  Future<void> _snooze(
    BuildContext context,
    WidgetRef ref,
    Duration duration,
  ) async {
    final changed = await runReminderAction(
      context,
      ref,
      reminder,
      ReminderRowAction.snooze,
      snoozeUntil: DateTime.now().add(duration),
    );
    if (changed && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _snoozeTomorrow(BuildContext context, WidgetRef ref) async {
    final now = DateTime.now();
    final changed = await runReminderAction(
      context,
      ref,
      reminder,
      ReminderRowAction.snooze,
      snoozeUntil: DateTime(now.year, now.month, now.day + 1, 9),
    );
    if (changed && context.mounted) Navigator.of(context).pop();
  }

  Future<void> _markDone(BuildContext context, WidgetRef ref) async {
    final changed = await runReminderAction(
      context,
      ref,
      reminder,
      ReminderRowAction.done,
    );
    if (changed && context.mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final isDark = context.isDark;
    final dialogBg = context.bgSurface;
    final dialogBorder = g.edge;
    final headerAccent = context.accentPrimary;

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
                          isPreview ? 'REMINDER DETAILS' : 'REMINDER DUE',
                          style: AppTypography.jetBrainsMono11W70087(
                            color: headerAccent,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          isPreview
                              ? DateFormat.yMMMd().add_jm().format(
                                  reminder.scheduledAt,
                                )
                              : 'Time for your planned task',
                          style: AppTypography.plusJakartaSans12Regular57(
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: context.textMuted,
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
                      : context.bgSurfaceElevated,
                  borderRadius: AppGeometry.roundedr14,
                  border: Border.all(color: g.edge),
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
                  color: context.textMuted,
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
                            : context.bgSurfaceElevated,
                        minimumSize: const Size(48, 44),
                        side: BorderSide(color: g.edge),
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
                            : context.bgSurfaceElevated,
                        minimumSize: const Size(48, 44),
                        side: BorderSide(color: g.edge),
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
                            : context.bgSurfaceElevated,
                        minimumSize: const Size(48, 44),
                        side: BorderSide(color: g.edge),
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
                  backgroundColor: g.clay,
                  elevation: 0,
                  minimumSize: const Size(48, 48),
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
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
