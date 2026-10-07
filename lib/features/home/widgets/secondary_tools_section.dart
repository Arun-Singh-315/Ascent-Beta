import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/ascent_card.dart';

class SecondaryToolsSection extends StatefulWidget {
  const SecondaryToolsSection({super.key});

  @override
  State<SecondaryToolsSection> createState() => _SecondaryToolsSectionState();
}

class _SecondaryToolsSectionState extends State<SecondaryToolsSection> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider, width: 0.8),
      ),
      child: Column(
        children: [
          InkWell(
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _isExpanded = !_isExpanded);
            },
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              child: Row(
                children: [
                  Icon(
                    Icons.inventory_2_outlined,
                    size: 16,
                    color: context.accentPrimary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Secondary Tools • Notes & Reminders',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: context.bgSurfaceElevated,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      _isExpanded ? 'Collapse' : 'Expand (2)',
                      style: AscentTextStyles.labelSmall.copyWith(
                        color: context.textMuted,
                        fontSize: 11,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    _isExpanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                    color: context.textMuted,
                    size: 20,
                  ),
                ],
              ),
            ),
          ),
          if (_isExpanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                children: const [
                  _NotesPreviewCard(),
                  SizedBox(height: 12),
                  _RemindersPreviewCard(),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NotesPreviewCard extends ConsumerWidget {
  const _NotesPreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final noteAsync = ref.watch(mostRecentNoteProvider);

    return AscentCard(
      padding: const EdgeInsets.all(14),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_note_rounded, size: 18, color: context.accentPrimary),
                  const SizedBox(width: 6),
                  Text(
                    'Notes & Journal',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => context.push('/notes'),
                child: Text(
                  'View all ›',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          noteAsync.when(
            loading: () => const SizedBox(height: 16),
            error: (_, _) => const SizedBox.shrink(),
            data: (note) {
              return Text(
                note?.title ?? 'Jot down your first reflection or STAR prep notes ›',
                style: TextStyle(
                  fontSize: 12,
                  color: context.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              );
            },
          ),
        ],
      ),
    );
  }
}

class _RemindersPreviewCard extends ConsumerWidget {
  const _RemindersPreviewCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reminderAsync = ref.watch(nextUpcomingReminderProvider);

    return AscentCard(
      padding: const EdgeInsets.all(14),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.notifications_none_rounded, size: 18, color: context.accentSecondary),
                  const SizedBox(width: 6),
                  Text(
                    'Upcoming Reminders',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      color: context.textPrimary,
                    ),
                  ),
                ],
              ),
              InkWell(
                onTap: () => context.push('/reminders'),
                child: Text(
                  '+ Add',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: context.accentSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          reminderAsync.when(
            loading: () => const SizedBox(height: 16),
            error: (_, _) => const SizedBox.shrink(),
            data: (reminder) {
              if (reminder == null) {
                return Text(
                  'No upcoming reminders scheduled.',
                  style: TextStyle(fontSize: 12, color: context.textMuted),
                );
              }
              final dateStr = DateFormat('EEE, MMM d • h:mm a').format(reminder.scheduledAt);
              return Row(
                children: [
                  Container(
                    width: 5,
                    height: 5,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.accentSecondary,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      '${reminder.title} ($dateStr)',
                      style: TextStyle(fontSize: 12, color: context.textPrimary),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
