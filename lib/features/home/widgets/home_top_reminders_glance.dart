import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/dimension_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../shared/widgets/ascent_card.dart';
import '../../reminders/reminder_action_ui.dart';

/// Top-of-screen glanceable reminder bar placed directly beneath the Home header.
///
/// Gives immediate high-signal visibility into the user's next upcoming reminder
/// without forcing them to scroll to the bottom of the feed.
class HomeTopRemindersGlance extends ConsumerWidget {
  const HomeTopRemindersGlance({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminders = ref.watch(homeVisibleRemindersProvider);
    if (reminders.isEmpty) return const SizedBox.shrink();

    final g = context.glass;
    final nextReminder = reminders.first;
    final totalCount = reminders.length;
    final timeStr = nextReminder.scheduledAt != null
        ? DateFormat('h:mm a').format(nextReminder.scheduledAt!)
        : 'Today';

    return Padding(
      padding: EdgeInsets.only(bottom: AppSpace.s12),
      child: AscentCard.glass(
        key: const ValueKey('home_top_reminders_glance'),
        onTap: () {
          HapticFeedback.lightImpact();
          context.push('/reminders');
        },
        radius: AscentDimensions.radiusMd,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          children: [
            // Alarm / Bell Indicator Icon
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: SharedControlColors.actionBlue.withValues(
                  alpha: context.isDark ? 0.20 : 0.12,
                ),
                border: Border.all(
                  color: SharedControlColors.actionBlue.withValues(alpha: 0.35),
                  width: 0.8,
                ),
              ),
              child: const Center(
                child: Icon(
                  Icons.alarm_rounded,
                  size: 16,
                  color: SharedControlColors.actionBlue,
                ),
              ),
            ),

            const SizedBox(width: 12),

            // Reminder Title & Scheduled Time
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      Text(
                        timeStr,
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: SharedControlColors.actionBlue,
                          letterSpacing: 0.2,
                        ),
                      ),
                      if (totalCount > 1) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 1.5,
                          ),
                          decoration: BoxDecoration(
                            color: g.line.withValues(alpha: 0.4),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '+${totalCount - 1} more',
                            style: GoogleFonts.dmSans(
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              color: g.inkMuted,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    nextReminder.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: g.ink,
                      letterSpacing: -0.1,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Quick Complete Checkmark Action
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () async {
                  HapticFeedback.mediumImpact();
                  await runReminderAction(
                    context,
                    ref,
                    nextReminder,
                    ReminderRowAction.done,
                  );
                },
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: g.fill.withValues(alpha: context.isDark ? 0.3 : 0.6),
                    border: Border.all(
                      color: g.line.withValues(alpha: 0.4),
                      width: 0.8,
                    ),
                  ),
                  child: Icon(
                    Icons.check_rounded,
                    size: 16,
                    color: g.inkMuted,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
