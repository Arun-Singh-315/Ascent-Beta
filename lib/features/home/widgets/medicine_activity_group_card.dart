import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../../shared/widgets/glass_chip.dart';

/// Grouped expandable medicine activity card.
/// Combines multiple doses for the same medicine into a single top-level row,
/// preventing the activity list from being bombarded by repetitive todos.
/// Clicking the card smoothly expands all doses with their respective scheduled times.
class MedicineActivityGroupCard extends ConsumerStatefulWidget {
  const MedicineActivityGroupCard({
    super.key,
    required this.medicineName,
    required this.dosage,
    required this.activities,
    this.compact = true,
  });

  final String medicineName;
  final String dosage;
  final List<TodayActivityItem> activities;
  final bool compact;

  @override
  ConsumerState<MedicineActivityGroupCard> createState() =>
      _MedicineActivityGroupCardState();
}

class _MedicineActivityGroupCardState
    extends ConsumerState<MedicineActivityGroupCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;

  int get _takenCount =>
      widget.activities
          .where((a) => a.status == TodayActivityStatus.done)
          .length;

  bool get _isAllDone =>
      widget.activities.isNotEmpty &&
      widget.activities.every((a) => a.status == TodayActivityStatus.done);

  TodayActivityItem? get _nextPendingDose {
    final pending =
        widget.activities
            .where((a) => a.status != TodayActivityStatus.done)
            .toList()
          ..sort((a, b) {
            final aTime = a.scheduledTime ?? a.plannedDate ?? DateTime(0);
            final bTime = b.scheduledTime ?? b.plannedDate ?? DateTime(0);
            return aTime.compareTo(bTime);
          });
    return pending.firstOrNull;
  }

  String _formatTime(DateTime? dt) {
    if (dt == null) return '';
    return DateFormat('h:mm a').format(dt);
  }

  Future<void> _completeDose(TodayActivityItem dose) async {
    if (dose.status == TodayActivityStatus.done) {
      AscentSnackBar.show(
        context,
        message: 'Completed items are finished and cannot be reopened.',
      );
      return;
    }
    if (dose.isScheduledInFuture) {
      HapticFeedback.lightImpact();
      final timeStr = _formatTime(dose.scheduledTime);
      AscentSnackBar.show(
        context,
        message:
            'Scheduled for $timeStr. You can complete it once that time arrives.',
      );
      return;
    }
    if (dose.linkedTaskId != null) {
      HapticFeedback.mediumImpact();
      try {
        final dao = ref.read(taskDaoProvider);
        await dao.toggleTaskCompletion(dose.linkedTaskId!, true);
        if (mounted) {
          AscentSnackBar.show(context, message: 'Dose marked completed');
        }
      } catch (_) {
        if (mounted) {
          AscentSnackBar.error(
            context,
            message: 'Could not complete dose. Please retry.',
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final total = widget.activities.length;
    final taken = _takenCount;
    final allDone = _isAllDone;
    final nextDose = _nextPendingDose;

    String subtitle;
    if (allDone) {
      subtitle = '✓ All $total doses completed today';
    } else if (taken > 0) {
      final nextStr = nextDose != null && nextDose.scheduledTime != null
          ? ' · Next at ${_formatTime(nextDose.scheduledTime)}'
          : '';
      subtitle = '$taken of $total taken$nextStr';
    } else {
      final nextStr = nextDose != null && nextDose.scheduledTime != null
          ? ' · Next at ${_formatTime(nextDose.scheduledTime)}'
          : '';
      subtitle = '$total doses scheduled$nextStr';
    }

    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: allDone
            ? g.sage.withValues(alpha: 0.08)
            : g.ink.withValues(alpha: 0.025),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: allDone
              ? g.sage.withValues(alpha: 0.45)
              : g.edge.withValues(alpha: 0.35),
          width: 1,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // ── Header / Collapsed Summary Row ──────────────────────────────
          InkWell(
            key: ValueKey('medicine_group_${widget.medicineName}'),
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              HapticFeedback.selectionClick();
              setState(() => _expanded = !_expanded);
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  // Icon
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: allDone
                          ? g.sage.withValues(alpha: 0.16)
                          : g.clay.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.medication_outlined,
                      size: 19,
                      color: allDone ? g.sage : g.clay,
                    ),
                  ),
                  const SizedBox(width: 10),
                  // Title & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.dosage.isNotEmpty
                                    ? '${widget.medicineName} (${widget.dosage})'
                                    : widget.medicineName,
                                style: AppTypography.thoughtContent(
                                  color: allDone ? g.inkMuted : g.ink,
                                ).copyWith(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  decoration: allDone
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: AscentTextStyles.homeSecondary.copyWith(
                            color: allDone ? g.inkMuted : g.clay,
                            fontSize: 12,
                            fontWeight: allDone
                                ? FontWeight.w400
                                : FontWeight.w500,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Badge + Chevron
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: g.ink.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: g.ink.withValues(alpha: 0.12)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$taken/$total',
                          style: TextStyle(
                            color: g.inkSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(width: 3),
                        Icon(
                          _expanded
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: g.inkMuted,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // ── Expanded Dose List ──────────────────────────────────────────
          if (_expanded) ...[
            Divider(
              height: 1,
              thickness: 1,
              color: g.line.withValues(alpha: 0.25),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  for (final dose in widget.activities) ...[
                    _buildDoseRow(context, dose),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDoseRow(BuildContext context, TodayActivityItem dose) {
    final g = context.glass;
    final isDone = dose.status == TodayActivityStatus.done;
    final isFuture = dose.isScheduledInFuture;
    final timeStr = _formatTime(dose.scheduledTime ?? dose.plannedDate);

    return Container(
      key: ValueKey('group_dose_${dose.id}'),
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: isDone
            ? g.sage.withValues(alpha: 0.06)
            : g.ink.withValues(alpha: 0.015),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: isDone
              ? g.sage.withValues(alpha: 0.25)
              : g.line.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          // Circular Check / Time target
          SizedBox(
            width: 34,
            height: 34,
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(17),
                onTap: () => _completeDose(dose),
                child: Center(
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDone
                          ? g.sage.withValues(alpha: 0.16)
                          : (isFuture
                              ? g.ink.withValues(alpha: 0.04)
                              : Colors.transparent),
                      border: Border.all(
                        color: isDone
                            ? g.sage
                            : (isFuture ? g.inkMuted : g.clay),
                        width: 1.5,
                      ),
                    ),
                    child: isDone
                        ? Center(
                            child: Icon(
                              Icons.check_rounded,
                              size: 14,
                              color: g.sage,
                            ),
                          )
                        : (isFuture
                            ? Center(
                                child: Icon(
                                  Icons.schedule_rounded,
                                  size: 12,
                                  color: g.inkMuted,
                                ),
                              )
                            : null),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 8),

          // Time & Title
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    if (timeStr.isNotEmpty) ...[
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: isDone ? g.inkMuted : g.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 6),
                    ],
                    Flexible(
                      child: Text(
                        dose.notes?.split('•').first.trim().isNotEmpty == true
                            ? dose.notes!.split('•').first.trim()
                            : (widget.dosage.isNotEmpty
                                ? widget.dosage
                                : dose.title),
                        style: TextStyle(
                          color: isDone ? g.inkMuted : g.inkSecondary,
                          fontSize: 12,
                          decoration: isDone
                              ? TextDecoration.lineThrough
                              : null,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // Action: Done chip vs Scheduled Badge vs Done button
          if (isDone) ...[
            const GlassChip(
              label: 'Done',
              icon: Icons.check_rounded,
              selected: true,
              success: true,
              tooltip: 'Completed',
            ),
          ] else if (isFuture) ...[
            Semantics(
              button: true,
              label: 'Scheduled for $timeStr',
              child: InkWell(
                key: ValueKey('activity_scheduled_${dose.id}'),
                onTap: () {
                  HapticFeedback.lightImpact();
                  AscentSnackBar.show(
                    context,
                    message:
                        'Scheduled for $timeStr. You can complete it once that time arrives.',
                  );
                },
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: g.ink.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: g.ink.withValues(alpha: 0.15)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.schedule_rounded, size: 12, color: g.clay),
                      const SizedBox(width: 4),
                      Text(
                        timeStr,
                        style: TextStyle(
                          color: g.ink,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ] else ...[
            FilledButton.icon(
              key: ValueKey('activity_action_${dose.id}'),
              style: FilledButton.styleFrom(
                backgroundColor: g.ink,
                foregroundColor: g.bg,
                minimumSize: const Size(0, 32),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                textStyle: Theme.of(context).textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              icon: const Icon(Icons.check_rounded, size: 13),
              label: const Text('Done'),
              onPressed: () => _completeDose(dose),
            ),
          ],
        ],
      ),
    );
  }
}
