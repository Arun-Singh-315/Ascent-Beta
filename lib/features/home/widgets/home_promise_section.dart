import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/locked_commitment_tile.dart';
import '../../promises/models/promise_model.dart';
import '../../promises/providers/promise_providers.dart';
import '../../promises/widgets/promise_action_button.dart';
import '../../promises/widgets/promise_actions.dart';
import '../../promises/widgets/promise_chat_composer.dart';
import '../../promises/widgets/promise_detail_sheet.dart';
import '../../vault/providers/vault_providers.dart';
import 'home_outline_surface.dart';
import 'home_section_heading.dart';

/// Compact, highly focused Promise section on the Ascent Home screen.
/// Answers three questions immediately:
/// 1. What commitment matters now?
/// 2. What is the next useful action?
/// 3. Am I making progress?
class HomePromiseSection extends ConsumerWidget {
  const HomePromiseSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final priorityPromise = ref.watch(priorityPromiseProvider);
    final allActive = ref.watch(activePromisesStreamProvider).value ?? [];
    final completedPromises =
        ref.watch(completedPromisesStreamProvider).value ?? [];

    if (priorityPromise == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeading(
            title: 'Commitments',
            centered: false,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('home_promise_add'),
                  tooltip: 'New commitment',
                  icon: Icon(Icons.add_rounded, color: g.ink),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    PromiseChatComposer.show(context);
                  },
                ),
                HomeSectionArrowButton(
                  tooltip: 'Open commitments',
                  color: const Color(0xFFC67D32),
                  onTap: () => context.push('/promises'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          if (completedPromises.isNotEmpty)
            _buildCompletedState(context, completedPromises.first, g)
          else
            _buildEmptyState(context, g),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header adhering strictly to Rule 18 & Rule 13
        HomeSectionHeading(
          title: 'Commitments',
          centered: false,
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: const ValueKey('home_promise_add'),
                tooltip: 'New commitment',
                icon: Icon(Icons.add_rounded, color: g.ink),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  PromiseChatComposer.show(context);
                },
              ),
              HomeSectionArrowButton(
                tooltip: 'Open commitments',
                color: const Color(0xFFC67D32),
                onTap: () => context.push('/promises'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Priority commitment card
        _buildPriorityCard(context, ref, priorityPromise, g),

        // Actionable footer: unblocked "+ New commitment" alongside view more
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              TextButton.icon(
                key: const ValueKey('home_promise_add_inline'),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  PromiseChatComposer.show(context);
                },
                icon: Icon(Icons.add_rounded, size: 16, color: g.clay),
                label: Text(
                  'New commitment',
                  style: TextStyle(
                    color: g.clay,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (allActive.length > 1)
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.push('/promises');
                  },
                  icon: Icon(Icons.commit_rounded, size: 15, color: g.clay),
                  label: Text(
                    '+${allActive.length - 1} more commitments',
                    style: TextStyle(
                      color: g.clay,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                )
              else
                TextButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    context.push('/promises');
                  },
                  icon: Icon(Icons.arrow_forward_rounded, size: 14, color: g.clay),
                  label: Text(
                    'View all',
                    style: TextStyle(
                      color: g.clay,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState(BuildContext context, AscentGlass g) {
    return InkWell(
      key: const ValueKey('home_promise_empty_card'),
      onTap: () {
        HapticFeedback.lightImpact();
        PromiseChatComposer.show(context);
      },
      borderRadius: BorderRadius.circular(24),
      child: HomeOutlineSurface(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: g.ink.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.handshake_outlined,
                color: g.clay,
                size: 24,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Add commitment',
                    style: AscentTextStyles.interfaceSection.copyWith(
                      color: g.ink,
                      fontSize: 16.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Set a next step · Keep your progress in view',
                    style: TextStyle(
                      color: g.inkMuted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            AscentButton.tonal(
              compact: true,
              label: 'Add',
              icon: Icons.add_rounded,
              onPressed: () {
                HapticFeedback.lightImpact();
                PromiseChatComposer.show(context);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCompletedState(
    BuildContext context,
    PromiseModel completed,
    AscentGlass g,
  ) {
    return HomeOutlineSurface(
      key: const ValueKey('home_promise_empty_card'),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: const Color(0xFF388E3C).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.check_circle_rounded,
                      size: 13,
                      color: Color(0xFF388E3C),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      'COMPLETED TODAY',
                      style: TextStyle(
                        color: const Color(0xFF388E3C),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.4,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'All commitments',
                icon: Icon(Icons.arrow_forward_rounded, color: g.inkMuted, size: 18),
                onPressed: () => context.push('/promises'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            completed.title,
            style: AscentTextStyles.interfaceSection.copyWith(
              color: g.ink,
              fontSize: 16.5,
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.lineThrough,
              decorationColor: g.inkMuted,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Commitment kept today · Keep your streak alive',
            style: TextStyle(
              color: g.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AscentButton.tonal(
                compact: true,
                label: 'New commitment',
                icon: Icons.add_rounded,
                onPressed: () {
                  HapticFeedback.lightImpact();
                  PromiseChatComposer.show(context);
                },
              ),
              TextButton(
                onPressed: () => context.push('/promises'),
                child: Text(
                  'View all',
                  style: TextStyle(
                    color: g.clay,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPriorityCard(
    BuildContext context,
    WidgetRef ref,
    PromiseModel promise,
    AscentGlass g,
  ) {
    final unlockedIds = ref.watch(unlockedPromiseIdsProvider);
    final isLocked = promise.isPrivate && !unlockedIds.contains(promise.id);

    return InkWell(
      key: const ValueKey('home_promise_card'),
      onLongPress: () =>
          showPromiseActionMenu(context, promise, locked: isLocked),
      onTap: () {
        HapticFeedback.selectionClick();
        PromiseDetailSheet.show(context, promise);
      },
      borderRadius: BorderRadius.circular(24),
      child: HomeOutlineSurface(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top tag & status
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: g.ink.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      promise.category.toUpperCase(),
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: g.inkMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (promise.isPrivate)
                      Tooltip(
                        message: !isLocked
                            ? 'Tap to lock commitment'
                            : 'Private commitment',
                        child: InkWell(
                          key: ValueKey('toggle_lock_home_promise_${promise.id}'),
                          onTap: !isLocked
                              ? () {
                                  HapticFeedback.lightImpact();
                                  ref
                                      .read(unlockedPromiseIdsProvider.notifier)
                                      .lock(promise.id);
                                }
                              : null,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 2,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (!isLocked) ...[
                                  Text(
                                    'LOCK',
                                    style: TextStyle(
                                      color: g.clay,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                ],
                                Icon(
                                  isLocked
                                      ? Icons.lock_outline_rounded
                                      : Icons.lock_open_rounded,
                                  size: 14,
                                  color: isLocked ? g.inkMuted : g.clay,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    IconButton(
                      tooltip: 'Commitment actions',
                      icon: Icon(Icons.more_horiz_rounded, color: g.inkMuted),
                      onPressed: () =>
                          showPromiseActionMenu(context, promise, locked: isLocked),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            if (isLocked) ...[
              LockedCommitmentTile(
                label: 'Private commitment',
                onTap: () async {
                  final security = ref.read(vaultSecurityServiceProvider);
                  final unlocked = await security.authenticateBiometrics(
                    reason: 'Unlock private commitment',
                  );
                  if (unlocked) {
                    ref
                        .read(unlockedPromiseIdsProvider.notifier)
                        .unlock(promise.id);
                  }
                },
              ),
            ] else ...[
              // Title
              Text(
                promise.title,
                style: AscentTextStyles.interfaceSection.copyWith(
                  color: g.ink,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w600,
                ),
              ),

              if (promise.intention.trim().isNotEmpty &&
                  promise.intention.trim().toLowerCase() !=
                      promise.title.trim().toLowerCase()) ...[
                const SizedBox(height: 4),
                Text(
                  promise.intention,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: g.inkMuted,
                    fontSize: 13,
                    height: 1.35,
                  ),
                ),
              ],
            ],
            const SizedBox(height: 14),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: promise.progressFraction,
                minHeight: 5,
                backgroundColor: g.ink.withValues(alpha: 0.08),
                valueColor: AlwaysStoppedAnimation<Color>(g.ink),
              ),
            ),
            const SizedBox(height: 14),

            // Bottom footer: Progress summary & Direct Action Button
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Text(
                  promise.progressSummary,
                  style: TextStyle(
                    color: g.inkMuted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                PromiseActionButton(
                  promise: promise,
                  onPressed: () {
                    _triggerAction(context, ref, promise);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _triggerAction(
    BuildContext context,
    WidgetRef ref,
    PromiseModel promise,
  ) {
    PromiseActions.perform(context, ref, promise);
  }
}
