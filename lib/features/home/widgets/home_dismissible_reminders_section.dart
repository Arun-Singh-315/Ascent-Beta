import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../core/database/app_database.dart';
import '../../reminders/widgets/in_app_reminder_dialog.dart';

class HomeDismissibleRemindersSection extends StatelessWidget {
  final List<Reminder> reminders;
  final Future<void> Function(Reminder reminder) onDismissReminder;
  final Future<void> Function(Reminder reminder)? onCompleteReminder;
  final VoidCallback? onAddReminder;
  final VoidCallback? onViewAll;

  const HomeDismissibleRemindersSection({
    super.key,
    required this.reminders,
    required this.onDismissReminder,
    this.onCompleteReminder,
    this.onAddReminder,
    this.onViewAll,
  });

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final reminderDate = DateTime(dt.year, dt.month, dt.day);
    final hour = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    final timeStr = '$hour:$minute $period';

    final diffDays = reminderDate.difference(today).inDays;
    if (diffDays == 0) {
      if (dt.isBefore(now)) {
        return 'Overdue today • $timeStr';
      }
      return 'Today • $timeStr';
    } else if (diffDays == 1) {
      return 'Tomorrow • $timeStr';
    } else if (diffDays < 0) {
      return 'Past due • $timeStr';
    } else {
      return '${DateFormat('EEE, d MMM').format(dt)} • $timeStr';
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    if (reminders.isEmpty) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'REMINDERS',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                  color: g.inkMuted,
                ),
              ),
              if (onAddReminder != null)
                InkWell(
                  onTap: onAddReminder,
                  borderRadius: BorderRadius.circular(6),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.add_rounded, size: 14, color: g.clay),
                        const SizedBox(width: 2),
                        Text(
                          'Add',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: g.clay,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: g.fill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: g.edge),
            ),
            child: Row(
              children: [
                Icon(Icons.notifications_none_rounded, size: 18, color: g.clay),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'No active reminders scheduled',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: g.inkMuted,
                    ),
                  ),
                ),
                if (onAddReminder != null)
                  InkWell(
                    onTap: onAddReminder,
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: g.clay.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: g.clay.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        'Set',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: g.clay,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      );
    }

    // Rule 7 & User Direction: Cap Home preview to exactly 1 primary reminder.
    // Remaining reminders are indicated via "+X more" navigation to preserve screen space.
    final primaryReminder = reminders.first;
    final remainingCount = reminders.length - 1;
    final isOverdue = primaryReminder.scheduledAt.isBefore(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Text(
                  'REMINDERS',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                    color: g.inkMuted,
                  ),
                ),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: g.clay.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${reminders.length}',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      color: g.clay,
                    ),
                  ),
                ),
              ],
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (remainingCount > 0)
                  InkWell(
                    onTap: onViewAll,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      child: Text(
                        '+$remainingCount more',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: g.clay,
                        ),
                      ),
                    ),
                  )
                else
                  Text(
                    'Swipe to dismiss',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: g.inkMuted.withValues(alpha: 0.7),
                    ),
                  ),
                if (onAddReminder != null) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: onAddReminder,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                      child: Icon(Icons.add_rounded, size: 16, color: g.clay),
                    ),
                  ),
                ],
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),

        // ── Single Primary Reminder (Rule 7 Capped Preview) ──
        Dismissible(
          key: ValueKey('home_reminder_${primaryReminder.id}'),
          direction: DismissDirection.horizontal,
          background: Container(
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Row(
              children: [
                Icon(Icons.delete_outline_rounded, color: Colors.redAccent, size: 20),
                SizedBox(width: 8),
                Text(
                  'Dismiss',
                  style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.w600),
                ),
              ],
            ),
          ),
          secondaryBackground: Container(
            decoration: BoxDecoration(
              color: Colors.green.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.green.withValues(alpha: 0.4)),
            ),
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Mark Done',
                  style: TextStyle(color: Colors.greenAccent, fontWeight: FontWeight.w600),
                ),
                SizedBox(width: 8),
                Icon(Icons.check_circle_outline_rounded, color: Colors.greenAccent, size: 20),
              ],
            ),
          ),
          onDismissed: (direction) {
            HapticFeedback.lightImpact();
            if (direction == DismissDirection.endToStart && onCompleteReminder != null) {
              onCompleteReminder!(primaryReminder);
            } else {
              onDismissReminder(primaryReminder);
            }
          },
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () {
                HapticFeedback.lightImpact();
                if (onViewAll != null) {
                  onViewAll!();
                } else {
                  InAppReminderDialog.show(context, primaryReminder);
                }
              },
              onLongPress: () {
                HapticFeedback.mediumImpact();
                InAppReminderDialog.show(context, primaryReminder);
              },
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: g.fill,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isOverdue ? Colors.redAccent.withValues(alpha: 0.35) : g.edge,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isOverdue ? Colors.redAccent : g.clay).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        isOverdue ? Icons.notification_important_rounded : Icons.notifications_active_rounded,
                        size: 18,
                        color: isOverdue ? Colors.redAccent : g.clay,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            primaryReminder.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: g.ink,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatTime(primaryReminder.scheduledAt),
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 12,
                              fontWeight: isOverdue ? FontWeight.w600 : FontWeight.w500,
                              color: isOverdue ? Colors.redAccent : g.inkMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, size: 16, color: g.inkMuted.withValues(alpha: 0.5)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
