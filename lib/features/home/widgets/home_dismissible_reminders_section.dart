import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../shared/widgets/glass_surface.dart';
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
      color: AppPalette.transparent,
      child: AppTapArea(
        onTap: onViewAll,
        borderRadius: AppGeometry.roundedr16,
        child: GlassSurface(
          radius: 18,
          padding: const EdgeInsets.all(AppSpace.s14),
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
                      style: AppTypography.plusJakartaSans14W60080(
                        color: g.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${DateFormat('d MMM · h:mm a').format(reminder.scheduledAt)}${reminders.length > 1 ? ' · +${reminders.length - 1} more' : ''}',
                      style: AppTypography.plusJakartaSans12Regular57(
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
