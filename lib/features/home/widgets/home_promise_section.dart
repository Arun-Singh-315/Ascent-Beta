import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../promises/models/promise_model.dart';
import '../../promises/providers/promise_providers.dart';
import '../../promises/widgets/promise_action_button.dart';
import '../../promises/widgets/promise_actions.dart';
import '../../promises/widgets/promise_chat_composer.dart';
import '../../promises/widgets/promise_detail_sheet.dart';
import '../../vault/providers/vault_providers.dart';

/// An intelligent, multi-item iOS-style Commitment screen on the Ascent Home screen.
/// Renders an enclosed glass card utilizing space efficiently through structured rows,
/// glanceable status badges, 1-tap direct actions, and privacy guards.
class HomePromiseSection extends ConsumerWidget {
  const HomePromiseSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.c;
    final priorityPromise = ref.watch(priorityPromiseProvider);
    final allActive = ref.watch(activePromisesStreamProvider).value ?? [];
    final completedPromises =
        ref.watch(completedPromisesStreamProvider).value ?? [];

    if (priorityPromise == null) {
      if (completedPromises.isNotEmpty) {
        return _buildCompletedCard(context, ref, completedPromises.first, allActive, c);
      }
      return _buildEmptyCard(context, c);
    }

    return _buildActiveCard(context, ref, priorityPromise, allActive, c);
  }

  Widget _buildCardHeader(
    BuildContext context,
    AppColors c, {
    required VoidCallback onAdd,
    required VoidCallback onViewAll,
  }) {
    return Row(
      children: [
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: c.accentTint,
            borderRadius: BorderRadius.circular(AppRadius.iconChip),
          ),
          child: Icon(
            Icons.verified_rounded,
            size: 16,
            color: c.accent,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            'Commitments',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
          ),
        ),
        IconButton(
          key: const ValueKey('home_promise_add'),
          tooltip: 'New commitment',
          icon: Icon(Icons.add_rounded, size: 20, color: c.textPrimary),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
          onPressed: onAdd,
        ),
        const SizedBox(width: 4),
        InkResponse(
          onTap: onViewAll,
          radius: 18,
          child: Padding(
            padding: const EdgeInsets.all(2),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: c.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCardFooter(
    BuildContext context,
    AppColors c,
    List<PromiseModel> allActive,
  ) {
    final bool hasMore = allActive.length > 1;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 10),
        Divider(height: 1, color: c.border.withValues(alpha: 0.5)),
        const SizedBox(height: 6),
        Wrap(
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
              icon: Icon(Icons.add_rounded, size: 15, color: c.accent),
              label: Text(
                'New commitment',
                style: TextStyle(
                  color: c.accent,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (hasMore)
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.push('/promises');
                },
                icon: Text(
                  '+${allActive.length - 1} more commitments',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                label: Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: c.textSecondary,
                ),
              )
            else
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.push('/promises');
                },
                icon: Text(
                  'View all',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                label: Icon(
                  Icons.arrow_forward_rounded,
                  size: 13,
                  color: c.textSecondary,
                ),
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildActiveCard(
    BuildContext context,
    WidgetRef ref,
    PromiseModel priorityPromise,
    List<PromiseModel> allActive,
    AppColors c,
  ) {
    final unlockedIds = ref.watch(unlockedPromiseIdsProvider);
    final displayedPromises = allActive.isNotEmpty
        ? allActive.take(2).toList()
        : [priorityPromise];
    final textScaler = MediaQuery.textScalerOf(context);
    final isScaled = textScaler.scale(14) > 20;

    return Container(
      key: const ValueKey('home_promise_card'),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: c.border.withValues(alpha: 0.7), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: c.warmShadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCardHeader(
            context,
            c,
            onAdd: () {
              HapticFeedback.selectionClick();
              PromiseChatComposer.show(context);
            },
            onViewAll: () => context.push('/promises'),
          ),
          const SizedBox(height: 12),

          // ── MULTI-ROW COMMITMENTS SCREEN ──
          for (var i = 0; i < displayedPromises.length; i++) ...[
            if (i > 0) ...[
              const SizedBox(height: 10),
              Divider(height: 1, color: c.border.withValues(alpha: 0.4)),
              const SizedBox(height: 10),
            ],
            _buildCommitmentRow(
              context,
              ref,
              displayedPromises[i],
              isLocked: displayedPromises[i].isPrivate &&
                  !unlockedIds.contains(displayedPromises[i].id),
              isScaled: isScaled,
              c: c,
            ),
          ],

          _buildCardFooter(context, c, allActive),
        ],
      ),
    );
  }

  Widget _buildCommitmentRow(
    BuildContext context,
    WidgetRef ref,
    PromiseModel promise, {
    required bool isLocked,
    required bool isScaled,
    required AppColors c,
  }) {
    if (isLocked) {
      return _buildLockedRow(context, ref, promise, c);
    }

    final String cadenceLabel = promise.schedule?.repeat == PromiseRepeat.selectedDays
        ? 'Selected days'
        : (promise.schedule?.repeat.name.toUpperCase() ?? 'DAILY');

    return InkWell(
      onTap: () {
        HapticFeedback.lightImpact();
        PromiseDetailSheet.show(context, promise);
      },
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: isScaled
            ? Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTagsRow(ref, promise, cadenceLabel, c),
                  const SizedBox(height: 4),
                  Text(
                    promise.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w600,
                      color: c.textPrimary,
                    ),
                  ),
                  if (promise.intention.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      promise.intention,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                  const SizedBox(height: 8),
                  PromiseActionButton(
                    promise: promise,
                    onPressed: () => _executeAction(context, ref, promise),
                  ),
                ],
              )
            : Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildTagsRow(ref, promise, cadenceLabel, c),
                        const SizedBox(height: 3),
                        Text(
                          promise.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        _buildProgressSnippet(promise, c),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  PromiseActionButton(
                    promise: promise,
                    onPressed: () => _executeAction(context, ref, promise),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildTagsRow(
    WidgetRef ref,
    PromiseModel promise,
    String cadenceLabel,
    AppColors c,
  ) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: c.surfaceAlt,
            borderRadius: BorderRadius.circular(5),
            border: Border.all(color: c.border.withValues(alpha: 0.5)),
          ),
          child: Text(
            promise.category.toUpperCase(),
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
              color: c.accent,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Text(
          '·  $cadenceLabel',
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w500,
            color: c.textSecondary,
          ),
        ),
        if (promise.isPrivate) ...[
          const SizedBox(width: 6),
          InkWell(
            key: ValueKey('toggle_lock_home_promise_${promise.id}'),
            onTap: () {
              HapticFeedback.lightImpact();
              ref
                  .read(unlockedPromiseIdsProvider.notifier)
                  .lock(promise.id);
            },
            borderRadius: BorderRadius.circular(6),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'LOCK',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 9.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.lock_open_rounded,
                    size: 12,
                    color: c.textSecondary,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildProgressSnippet(PromiseModel promise, AppColors c) {
    String text;
    switch (promise.trackingType) {
      case PromiseTrackingType.duration:
        text = '${promise.currentValue.toInt()}/${promise.targetValue.toInt()} ${promise.unit.isNotEmpty ? promise.unit : 'mins'}';
        break;
      case PromiseTrackingType.frequency:
        text = '${promise.currentValue.toInt()}/${promise.frequencyPerWeek} this week';
        break;
      case PromiseTrackingType.completion:
        text = promise.isDoneToday ? 'Completed today' : 'Scheduled for today';
        break;
      default:
        text = promise.intention.isNotEmpty ? promise.intention : 'Active commitment';
    }

    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 11,
        color: c.textSecondary,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildLockedRow(
    BuildContext context,
    WidgetRef ref,
    PromiseModel promise,
    AppColors c,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Icon(Icons.lock_rounded, size: 16, color: c.accent),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Private commitment',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.textPrimary,
              ),
            ),
          ),
          OutlinedButton(
            key: ValueKey('toggle_lock_home_promise_${promise.id}'),
            onPressed: () async {
              HapticFeedback.mediumImpact();
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
            style: OutlinedButton.styleFrom(
              side: BorderSide(color: c.accent, width: 1.0),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              minimumSize: const Size(0, 28),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: Text(
              'Unlock',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: c.accent,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context, AppColors c) {
    return Container(
      key: const ValueKey('home_promise_empty_card'),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: c.border.withValues(alpha: 0.7), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: c.warmShadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCardHeader(
            context,
            c,
            onAdd: () {
              HapticFeedback.selectionClick();
              PromiseChatComposer.show(context);
            },
            onViewAll: () => context.push('/promises'),
          ),
          const SizedBox(height: 16),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.accentTint,
                  ),
                  child: Icon(
                    Icons.flag_outlined,
                    size: 22,
                    color: c.accent,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'No commitments yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Set a personal standard for today',
                  style: TextStyle(
                    fontSize: 12.5,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  key: const ValueKey('home_promise_add_inline'),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    PromiseChatComposer.show(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 16),
                  label: const Text(
                    'New Commitment',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(
    BuildContext context,
    WidgetRef ref,
    PromiseModel completedPromise,
    List<PromiseModel> allActive,
    AppColors c,
  ) {
    return Container(
      key: const ValueKey('home_promise_card'),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        border: Border.all(color: c.border.withValues(alpha: 0.7), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: c.warmShadow,
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildCardHeader(
            context,
            c,
            onAdd: () {
              HapticFeedback.selectionClick();
              PromiseChatComposer.show(context);
            },
            onViewAll: () => context.push('/promises'),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: c.accentTint,
                ),
                child: Icon(
                  Icons.check_circle_rounded,
                  size: 20,
                  color: c.accent,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'All commitments completed!',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: c.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Great job keeping your word today.',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: c.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          _buildCardFooter(context, c, allActive),
        ],
      ),
    );
  }

  void _executeAction(
    BuildContext context,
    WidgetRef ref,
    PromiseModel promise,
  ) {
    PromiseActions.perform(context, ref, promise);
  }
}
