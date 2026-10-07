import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';

/// Level 3 · Supporting: Notes & Reminders
/// Redesigned according to Ascent Home Redesign spec:
/// - One-line preview so user knows they exist without having to expand.
/// - Open layout with clean hairline dividers.
/// - 56dp min height rows for effortless 48dp+ hit targets.
class SecondaryToolsSection extends ConsumerWidget {
  const SecondaryToolsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final noteAsync = ref.watch(mostRecentNoteProvider);
    final reminderAsync = ref.watch(nextUpcomingReminderProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── SECTION HEADING ───────────────────────────────────────────
        Text(
          'Notes & reminders',
          style: AscentTextStyles.homeTitle.copyWith(
            color: g.ink,
          ),
        ),

        const SizedBox(height: 8),

        // ── ROW 1: NOTES PREVIEW ──────────────────────────────────────
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/notes');
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: g.line, width: 1.0)),
              ),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.description_outlined, size: 20, color: g.inkMuted),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Notes',
                          style: AscentTextStyles.homeHeadline.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: g.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        noteAsync.when(
                          loading: () => Text(
                            'Loading notes...',
                            style: AscentTextStyles.homeSecondary.copyWith(color: g.inkMuted),
                          ),
                          error: (_, _) => Text(
                            'View notes',
                            style: AscentTextStyles.homeSecondary.copyWith(color: g.inkMuted),
                          ),
                          data: (note) => Text(
                            note?.title ?? 'Revisit Spring Security filter order',
                            style: AscentTextStyles.homeSecondary.copyWith(
                              color: g.inkMuted,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: g.inkMuted),
                ],
              ),
            ),
          ),
        ),

        // ── ROW 2: REMINDERS PREVIEW ──────────────────────────────────
        Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              context.push('/reminders');
            },
            child: Container(
              constraints: const BoxConstraints(minHeight: 56),
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                children: [
                  Icon(Icons.notifications_none_rounded, size: 20, color: g.inkMuted),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Reminders',
                          style: AscentTextStyles.homeHeadline.copyWith(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: g.ink,
                          ),
                        ),
                        const SizedBox(height: 2),
                        reminderAsync.when(
                          loading: () => Text(
                            'Loading reminders...',
                            style: AscentTextStyles.homeSecondary.copyWith(color: g.inkMuted),
                          ),
                          error: (_, _) => Text(
                            'Nothing due today',
                            style: AscentTextStyles.homeSecondary.copyWith(color: g.inkMuted),
                          ),
                          data: (rem) {
                            if (rem == null) {
                              return Text(
                                'Nothing due today',
                                style: AscentTextStyles.homeSecondary.copyWith(color: g.inkMuted),
                              );
                            }
                            final dateStr = DateFormat('h:mm a').format(rem.scheduledAt);
                            return Text(
                              '${rem.title} • $dateStr',
                              style: AscentTextStyles.homeSecondary.copyWith(
                                color: g.inkMuted,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            );
                          },
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 18, color: g.inkMuted),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
