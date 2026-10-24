import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../models/promise_model.dart';

/// Compact, editable proposal card shown in the chat composer.
class PromiseProposalCard extends StatelessWidget {
  const PromiseProposalCard({
    super.key,
    required this.proposal,
    required this.onAccept,
    required this.onModify,
    this.isSaving = false,
  });

  final PromiseProposal proposal;
  final VoidCallback onAccept;
  final void Function(String prompt) onModify;
  final bool isSaving;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return GlassSurface(
      borderRadius: BorderRadius.circular(20),
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Coach Reflection
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                size: 18,
                color: g.clay,
              ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    proposal.coachReflection,
                    style: TextStyle(
                      color: g.ink,
                      fontSize: 13.5,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Proposed commitment title
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: g.ink.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: g.ink.withValues(alpha: 0.08),
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        proposal.isPrivate
                            ? Icons.lock_outline_rounded
                            : Icons.bookmark_border_rounded,
                        size: 16,
                        color: g.inkMuted,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        proposal.category.toUpperCase(),
                        style: TextStyle(
                          color: g.inkMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.8,
                        ),
                      ),
                      if (proposal.isPrivate) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: g.ink.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Private',
                            style: TextStyle(
                              color: g.ink,
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    proposal.title,
                    style: AscentTextStyles.homeTitle.copyWith(
                      color: g.ink,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _formatProposalPlan(proposal),
                    style: TextStyle(
                      color: g.inkMuted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Quick adjustment pills
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _QuickActionChip(
                  label: proposal.isPrivate ? 'Make Public' : 'Keep Private',
                  icon: proposal.isPrivate ? Icons.public_rounded : Icons.lock_outline_rounded,
                  onTap: () => onModify(proposal.isPrivate ? 'Make it public' : 'Keep this private'),
                ),
                if (proposal.trackingType == PromiseTrackingType.duration)
                  _QuickActionChip(
                    label: '30 mins',
                    icon: Icons.timer_outlined,
                    onTap: () => onModify('Make it 30 minutes'),
                  ),
                _QuickActionChip(
                  label: 'Weekdays only',
                  icon: Icons.calendar_today_rounded,
                  onTap: () => onModify('Only on weekdays'),
                ),
                _QuickActionChip(
                  label: 'Morning reminder',
                  icon: Icons.wb_sunny_outlined,
                  onTap: () => onModify('Remind in the morning'),
                ),
              ],
            ),
            const SizedBox(height: 18),

            // Accept button
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: isSaving
                    ? null
                    : () {
                        HapticFeedback.mediumImpact();
                        onAccept();
                      },
                icon: isSaving
                    ? SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: g.bg,
                        ),
                      )
                    : const Icon(Icons.handshake_rounded, size: 18),
                label: Text(
                  isSaving ? 'Sealing Promise...' : 'I Promise Myself',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: FilledButton.styleFrom(
                  backgroundColor: g.ink,
                  foregroundColor: g.bg,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

  static String _formatProposalPlan(PromiseProposal p) {
    final buffer = StringBuffer();
    switch (p.trackingType) {
      case PromiseTrackingType.duration:
        buffer.write('Target: ${p.targetValue.toInt()} ${p.unit} per session');
        break;
      case PromiseTrackingType.frequency:
        buffer.write('Target: ${p.frequencyPerWeek} times per week');
        break;
      case PromiseTrackingType.milestone:
        if (p.targetDate != null) {
          buffer.write('Target Date: ${p.targetDate!.day}/${p.targetDate!.month}/${p.targetDate!.year}');
        } else {
          buffer.write('Milestone project tracking');
        }
        break;
      case PromiseTrackingType.reflection:
        buffer.write('Mindful personal reflection');
        break;
      case PromiseTrackingType.completion:
        buffer.write('One-time or direct completion');
        break;
    }

    if (p.reminderTime != null) {
      buffer.write(' • Reminder at ${p.reminderTime}');
    }
    return buffer.toString();
  }
}

class _QuickActionChip extends StatelessWidget {
  const _QuickActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: g.ink.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: g.ink.withValues(alpha: 0.09),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: g.inkMuted),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                color: g.ink,
                fontSize: 11.5,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
