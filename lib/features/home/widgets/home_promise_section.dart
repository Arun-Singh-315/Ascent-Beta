import 'package:flutter/material.dart';
import 'package:ascent/features/promises/widgets/promise_actions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../promises/models/promise_model.dart';
import '../../promises/providers/promise_providers.dart';
import '../../vault/providers/vault_providers.dart';
import '../../promises/widgets/promise_action_button.dart';
import '../../promises/widgets/promise_chat_composer.dart';
import '../../promises/widgets/promise_detail_sheet.dart';

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
    final activePromisesAsync = ref.watch(activePromisesStreamProvider);

    final totalActive = activePromisesAsync.value?.length ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Section Header adhering strictly to Rule 18
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Promises',
                style: AscentTextStyles.homeTitle.copyWith(
                  color: g.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                context.push('/promises');
              },
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      totalActive > 1 ? '$totalActive active' : 'View all',
                      style: TextStyle(
                        color: g.inkMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 12,
                      color: g.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        // Priority card or quiet empty state
        if (priorityPromise != null)
          _buildPriorityCard(context, ref, priorityPromise, g)
        else
          _buildQuietEmptyState(context, g),
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
      onTap: () {
        HapticFeedback.selectionClick();
        PromiseDetailSheet.show(context, promise);
      },
      borderRadius: BorderRadius.circular(20),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(18),
        enableBlur: false,
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
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
                if (promise.isPrivate)
                  Icon(
                    isLocked
                        ? Icons.lock_outline_rounded
                        : Icons.lock_open_rounded,
                    size: 14,
                    color: g.inkMuted,
                  ),
              ],
            ),
            const SizedBox(height: 10),

            if (isLocked) ...[
              InkWell(
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
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: g.fill.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: g.line),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.lock_outline_rounded,
                        size: 16,
                        color: g.inkMuted,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Private commitment · Tap to unlock',
                          style: TextStyle(
                            color: g.inkMuted,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else ...[
              // Title
              Text(
                promise.title,
                style: AscentTextStyles.homeTitle.copyWith(
                  color: g.ink,
                  fontSize: 16.5,
                  fontWeight: FontWeight.w700,
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
                    fontSize: 12,
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

  Widget _buildQuietEmptyState(BuildContext context, AscentGlass g) {
    return InkWell(
      key: const ValueKey('home_promise_empty_card'),
      onTap: () {
        HapticFeedback.lightImpact();
        PromiseChatComposer.show(context);
      },
      borderRadius: BorderRadius.circular(20),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(18),
        enableBlur: false,
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: g.ink.withValues(alpha: 0.05),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.handshake_outlined, size: 20, color: g.ink),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'No active promises',
                    style: TextStyle(
                      color: g.ink,
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Make a realistic commitment to yourself',
                    style: TextStyle(color: g.inkMuted, fontSize: 12.5),
                  ),
                ],
              ),
            ),
            Icon(Icons.add_rounded, color: g.ink, size: 22),
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
