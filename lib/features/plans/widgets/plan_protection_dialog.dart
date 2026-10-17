import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/frozen_palette.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/plan_child_protection.dart';
import '../../../shared/widgets/ascent_button.dart';

/// Shows an owner-aware replacement dialog when a user attempts to delete a protected plan-owned item.
Future<void> showPlanProtectionDialog(
  BuildContext context,
  WidgetRef ref,
  PlanChildRestriction restriction,
) {
  HapticFeedback.mediumImpact();
  final g = context.glass;
  final isDark = Theme.of(context).brightness == Brightness.dark;

  String titleText;
  String messageText;
  String primaryLabel;

  if (restriction.targetType == 'task') {
    titleText = restriction.isRoutine
        ? 'Part of ${restriction.planTitle}'
        : 'Part of ${restriction.planTitle}';
    messageText = restriction.isRoutine
        ? 'This activity is part of your recurring routine. Instead of deleting it from the entire system, you can skip this session or manage the routine.'
        : 'This activity is part of a scheduled plan. Instead of deleting it, you can skip this plan or open its controls.';
    primaryLabel = restriction.isRoutine ? 'Skip this session' : 'Skip this plan';
  } else if (restriction.targetType == 'start_reminder') {
    titleText = 'Start Reminder';
    messageText =
        'This reminder was scheduled by "${restriction.planTitle}". You can turn off the start reminder for this session while keeping the activity and check-in active.';
    primaryLabel = 'Turn off reminder for this session';
  } else {
    titleText = 'Check-in Follow-up';
    messageText =
        'This check-in was scheduled by "${restriction.planTitle}". You can stop asking questions for this session while keeping the activity unfinished.';
    primaryLabel = 'Stop asking for this session';
  }

  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: isDark ? g.bg : Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (sheetContext) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isDark
                        ? FrozenPalette.darkAction.withValues(alpha: 0.15)
                        : FrozenPalette.action.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    Icons.event_repeat_rounded,
                    color: isDark ? FrozenPalette.darkActionBright : FrozenPalette.action,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titleText,
                        style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                      Text(
                        restriction.isRoutine ? 'Recurring Routine' : 'Managed Plan',
                        style: TextStyle(
                          fontSize: 12,
                          color: g.inkMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              messageText,
              style: TextStyle(
                fontSize: 14,
                color: g.inkSecondary,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: AscentButton.tonal(
                label: primaryLabel,
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  Navigator.pop(sheetContext);

                  final planService = ref.read(planServiceProvider);
                  if (restriction.targetType == 'task') {
                    if (restriction.occurrenceId != null) {
                      await planService.skipOccurrence(restriction.occurrenceId!);
                    }
                  } else if (restriction.targetType == 'start_reminder') {
                    // Turn off start reminder
                    if (restriction.occurrenceId != null) {
                      final links = await ref
                          .read(databaseProvider)
                          .planDao
                          .getAlertLinksForOccurrence(restriction.occurrenceId!);
                      final start = links.where((l) => l.role == 'start').firstOrNull;
                      if (start != null) {
                        await planService.turnOffOccurrenceReminder(
                          restriction.occurrenceId!,
                          start.reminderId,
                        );
                      }
                    }
                  } else if (restriction.targetType == 'checkin_reminder') {
                    if (restriction.occurrenceId != null) {
                      await planService.stopAskingForOccurrence(restriction.occurrenceId!);
                    }
                  }

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          restriction.targetType == 'task'
                              ? 'Session marked as skipped. Future sessions remain active.'
                              : restriction.targetType == 'start_reminder'
                                  ? 'Reminder turned off for this session.'
                                  : 'Check-in stopped for this session.',
                        ),
                      ),
                    );
                  }
                },
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: AscentButton.ghost(
                    label: restriction.isRoutine ? 'Open routine' : 'Open plan',
                    onPressed: () {
                      Navigator.pop(sheetContext);
                      context.push('/plans?id=${restriction.planId}');
                    },
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(sheetContext),
                    child: const Text('Cancel'),
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
