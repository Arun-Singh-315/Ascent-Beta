import 'home_section_heading.dart';
import 'home_module_row.dart';
import 'package:flutter/material.dart';
import 'package:ascent/features/promises/widgets/promise_actions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/locked_commitment_tile.dart';
import '../../promises/models/promise_model.dart';
import '../../promises/providers/promise_providers.dart';
import '../../vault/providers/vault_providers.dart';
import '../../promises/widgets/promise_action_button.dart';
import '../../promises/widgets/promise_detail_sheet.dart';
import '../../promises/widgets/promise_chat_composer.dart';

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

    if (priorityPromise == null) {
      return HomeModuleRow(
        key: const ValueKey('home_promise_empty_card'),
        title: 'Add commitment',
        subtitle: 'Set a next step · Keep your progress in view',
        icon: Icons.handshake_outlined,
        actionIcon: Icons.add_rounded,
        onTap: () {
          HapticFeedback.lightImpact();
          PromiseChatComposer.show(context);
        },
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header adhering strictly to Rule 18 & Rule 13
        HomeSectionHeading(
          title: 'Commitments',
          centered: false,
          trailing: HomeSectionArrowButton(
            tooltip: 'Open commitments',
            color: const Color(0xFFC67D32),
            onTap: () => context.push('/promises'),
          ),
        ),
        const SizedBox(height: 12),

        // Priority card or quiet empty state
        ...[
          _buildPriorityCard(context, ref, priorityPromise, g),
          if (allActive.length > 1)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
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
                ),
              ),
            ),
        ],
      ],
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
      borderRadius: BorderRadius.zero,
      child: GlassSurface(
        borderRadius: BorderRadius.zero,
        padding: const EdgeInsets.symmetric(vertical: 18),
        fillColor: Colors.transparent,
        enableBlur: false,
        hasShadow: false,
        customBorder: MediaQuery.highContrastOf(context)
            ? Border.all(color: g.controlOutline)
            : const Border(),
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
                      promise.category,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: g.inkMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0,
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
