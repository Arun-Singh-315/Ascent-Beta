import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../core/database/app_database.dart';

/// Compact, read-only preview. Editing lives on the Reminders screen.
class HomeDismissibleRemindersSection extends StatelessWidget {
  const HomeDismissibleRemindersSection({
    super.key,
    required this.reminders,
    required this.onDismissReminder,
    this.onCompleteReminder,
    this.onAddReminder,
    this.onViewAll,
  });
  final List<Reminder> reminders;
  final Future<void> Function(Reminder) onDismissReminder;
  final Future<void> Function(Reminder)? onCompleteReminder;
  final VoidCallback? onAddReminder;
  final VoidCallback? onViewAll;
  @override
  Widget build(BuildContext context) {
    if (reminders.isEmpty) return const SizedBox.shrink();
    final g = context.glass;
    final reminder = reminders.first;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onViewAll,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: g.fill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: g.edge),
          ),
          child: Row(
            children: [
              Icon(
                Icons.notifications_active_outlined,
                color: g.clay,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: g.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${DateFormat('d MMM · h:mm a').format(reminder.scheduledAt)}${reminders.length > 1 ? ' · +${reminders.length - 1} more' : ''}',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: g.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: g.inkMuted, size: 18),
            ],
          ),
        ),
      ),
    );
  }
}
