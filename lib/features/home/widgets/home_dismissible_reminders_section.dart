import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import 'package:ascent/app/theme/merlot_palette.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../core/database/app_database.dart';

/// Swipeable and actionable preview on Home:
/// - Swipe Right -> Mark Done
/// - Swipe Left -> Delete
/// - Quick action icons and tap-through to Reminders screen.
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final reminder = reminders.first;

    return Dismissible(
      key: ValueKey('home_reminder_${reminder.id}'),
      direction: DismissDirection.horizontal,
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          // Swipe right: Mark done
          HapticFeedback.mediumImpact();
          if (onCompleteReminder != null) {
            await onCompleteReminder!(reminder);
          }
          return true;
        } else {
          // Swipe left: Delete
          HapticFeedback.lightImpact();
          await onDismissReminder(reminder);
          return true;
        }
      },
      background: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerLeft,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          children: [
            Icon(Icons.check_circle_outline_rounded, color: Colors.white, size: 24),
            SizedBox(width: 8),
            Text(
              'Done',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ],
        ),
      ),
      secondaryBackground: Container(
        margin: const EdgeInsets.symmetric(vertical: 2),
        decoration: BoxDecoration(
          color: const Color(0xFFEF4444).withValues(alpha: 0.90),
          borderRadius: BorderRadius.circular(18),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
            SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.white, size: 24),
          ],
        ),
      ),
      child: Material(
        color: AppPalette.transparent,
        child: AppTapArea(
          onTap: onViewAll,
          borderRadius: AppGeometry.roundedr16,
          child: GlassSurface(
            radius: 18,
            fillColor: isDark
                ? null
                : (g.merlot ? MerlotPalette.surface : Colors.white),
            customBorder: Border.all(
              color: g.merlot ? MerlotPalette.line : g.edge,
              width: 0.75,
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s14,
              vertical: AppSpace.s12,
            ),
            child: Row(
              children: [
                // Quick mark done toggle button
                InkWell(
                  onTap: () async {
                    HapticFeedback.mediumImpact();
                    if (onCompleteReminder != null) {
                      await onCompleteReminder!(reminder);
                    }
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: g.merlot
                          ? (isDark ? MerlotPalette.darkTint : MerlotPalette.tint)
                          : g.clay.withValues(alpha: 0.12),
                    ),
                    child: Center(
                      child: Icon(
                        Icons.notifications_active_outlined,
                        color: g.merlot
                            ? (isDark ? MerlotPalette.darkActionBright : MerlotPalette.action)
                            : g.clay,
                        size: 18,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
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
                // Trailing 1-tap quick complete and delete actions
                IconButton(
                  icon: const Icon(Icons.check_rounded, size: 18),
                  tooltip: 'Mark done',
                  color: const Color(0xFF10B981),
                  onPressed: () async {
                    HapticFeedback.mediumImpact();
                    if (onCompleteReminder != null) {
                      await onCompleteReminder!(reminder);
                    }
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  tooltip: 'Delete',
                  color: g.inkMuted,
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    await onDismissReminder(reminder);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
