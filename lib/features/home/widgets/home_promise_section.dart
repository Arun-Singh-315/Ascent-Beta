import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../promises/models/promise_model.dart';
import '../../promises/providers/promise_providers.dart';
import '../../promises/widgets/promise_action_button.dart';
import '../../promises/widgets/promise_actions.dart';
import '../../promises/widgets/promise_chat_composer.dart';
import '../../promises/widgets/promise_detail_sheet.dart';
import '../../vault/providers/vault_providers.dart';

/// An iOS-style structured Commitment section on the Ascent Home screen.
/// Renders an enclosed glass card with a 3-metric dashboard grid, privacy guards, and unblocked creation flows.
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
          width: 32,
          height: 32,
          decoration: BoxDecoration(
            color: c.accentTint,
            borderRadius: BorderRadius.circular(AppRadius.iconChip),
          ),
          child: Icon(
            Icons.verified_rounded,
            size: 18,
            color: c.accent,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'Commitments',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
          ),
        ),
        IconButton(
          key: const ValueKey('home_promise_add'),
          tooltip: 'New commitment',
          icon: Icon(Icons.add_rounded, size: 22, color: c.textPrimary),
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
          onPressed: onAdd,
        ),
        const SizedBox(width: 4),
        InkResponse(
          onTap: onViewAll,
          radius: 20,
          child: Padding(
            padding: const EdgeInsets.all(4),
            child: Icon(
              Icons.chevron_right_rounded,
              size: 22,
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 14),
        Divider(height: 1, color: c.border.withValues(alpha: 0.6)),
        const SizedBox(height: 8),
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
              icon: Icon(Icons.add_rounded, size: 16, color: c.accent),
              label: Text(
                'New commitment',
                style: TextStyle(
                  color: c.accent,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.selectionClick();
                context.push('/promises');
              },
              icon: Icon(
                Icons.arrow_forward_rounded,
                size: 14,
                color: c.textSecondary,
              ),
              label: Text(
                allActive.length > 1
                    ? '+${allActive.length - 1} more commitments'
                    : 'View all',
                style: TextStyle(
                  color: c.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
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
    PromiseModel promise,
    List<PromiseModel> allActive,
    AppColors c,
  ) {
    final unlockedIds = ref.watch(unlockedPromiseIdsProvider);
    final isLocked = promise.isPrivate && !unlockedIds.contains(promise.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            context,
            c,
            onAdd: () {
              HapticFeedback.selectionClick();
              PromiseChatComposer.show(context);
            },
            onViewAll: () {
              HapticFeedback.selectionClick();
              context.push('/promises');
            },
          ),
          const SizedBox(height: 14),

          if (isLocked) ...[
            // ── PRIVACY ENCLOSURE (LOCKED) ──
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: c.border.withValues(alpha: 0.6)),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.accentTint,
                    ),
                    child: Icon(
                      Icons.lock_rounded,
                      size: 24,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Private commitment',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: c.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Unlock with biometrics to view and update',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  OutlinedButton.icon(
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
                      side: BorderSide(color: c.accent, width: 1.2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    icon: Icon(
                      Icons.fingerprint_rounded,
                      size: 18,
                      color: c.accent,
                    ),
                    label: Text(
                      'Unlock commitment',
                      style: TextStyle(
                        color: c.accent,
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ] else ...[
            // ── UNLOCKED / PUBLIC COMMITMENT ──
            // Top Tag & Actions Row
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3.5,
                        ),
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: c.border.withValues(alpha: 0.6),
                          ),
                        ),
                        child: Text(
                          promise.category.toUpperCase(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: c.accent,
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                      if (promise.isPrivate) ...[
                        const SizedBox(width: 6),
                        Tooltip(
                          message: 'Tap to lock commitment',
                          child: InkWell(
                            key: ValueKey('toggle_lock_home_promise_${promise.id}'),
                            onTap: () {
                              HapticFeedback.lightImpact();
                              ref
                                  .read(unlockedPromiseIdsProvider.notifier)
                                  .lock(promise.id);
                            },
                            borderRadius: BorderRadius.circular(8),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 4,
                                vertical: 2,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    'LOCK',
                                    style: TextStyle(
                                      color: c.textSecondary,
                                      fontSize: 9.5,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: 0.5,
                                    ),
                                  ),
                                  const SizedBox(width: 3),
                                  Icon(
                                    Icons.lock_open_rounded,
                                    size: 14,
                                    color: c.textSecondary,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (promise.isDoneToday) ...[
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: isDark
                              ? const Color(0xFF1B382B)
                              : const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF2E6B4A)
                                : const Color(0xFFA5D6A7),
                          ),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.check_circle_rounded,
                              size: 12,
                              color: Color(0xFF2E7D32),
                            ),
                            SizedBox(width: 4),
                            Text(
                              'DONE TODAY',
                              style: TextStyle(
                                color: Color(0xFF2E7D32),
                                fontSize: 10,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                    IconButton(
                      tooltip: 'Commitment actions',
                      icon: Icon(
                        Icons.more_horiz_rounded,
                        color: c.textSecondary,
                      ),
                      onPressed: () => showPromiseActionMenu(
                        context,
                        promise,
                        locked: false,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Commitment Title
            InkWell(
              onTap: () {
                HapticFeedback.selectionClick();
                PromiseDetailSheet.show(context, promise);
              },
              borderRadius: BorderRadius.circular(8),
              child: Text(
                promise.title,
                style: TextStyle(
                  fontSize: 18.5,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                  letterSpacing: -0.3,
                  height: 1.25,
                ),
              ),
            ),

            if (promise.intention.trim().isNotEmpty &&
                promise.intention.trim().toLowerCase() !=
                    promise.title.trim().toLowerCase()) ...[
              const SizedBox(height: 6),
              Text(
                '"${promise.intention}"',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontStyle: FontStyle.italic,
                  color: c.textSecondary,
                  fontSize: 13,
                  height: 1.35,
                ),
              ),
            ],
            const SizedBox(height: 14),

            // Structured 3-Metric iOS Grid
            _buildMetricsGrid(context, promise, c),
            const SizedBox(height: 14),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: promise.progressFraction.clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: c.surfaceAlt,
                valueColor: AlwaysStoppedAnimation<Color>(c.accent),
              ),
            ),
            const SizedBox(height: 14),

            // Action row with 1-tap primary action button
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                Text(
                  '${(promise.progressFraction.clamp(0.0, 1.0) * 100).toInt()}% completed · ${promise.progressSummary}',
                  style: TextStyle(
                    color: c.textSecondary,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                PromiseActionButton(
                  promise: promise,
                  onPressed: () {
                    PromiseActions.perform(context, ref, promise);
                  },
                ),
              ],
            ),
          ],

          _buildCardFooter(context, c, allActive),
        ],
      ),
    );
  }

  Widget _buildMetricsGrid(
    BuildContext context,
    PromiseModel promise,
    AppColors c,
  ) {
    final cadence = promise.frequencyPerWeek > 0
        ? '${promise.frequencyPerWeek}× / week'
        : (promise.schedule != null
            ? promise.schedule!.repeat.name.toUpperCase()
            : 'ONE-TIME');

    final progressVal = promise.progressSummary.isNotEmpty
        ? promise.progressSummary
        : '${(promise.progressFraction * 100).toInt()}%';

    final timing = promise.reminderTime != null
        ? promise.reminderTime!
        : (promise.targetDate != null
            ? DateFormat('MMM d').format(promise.targetDate!)
            : 'Anytime');

    final isScaled = MediaQuery.textScalerOf(context).scale(1) >= 1.45 ||
        MediaQuery.sizeOf(context).width < 340;

    Widget buildTile(String label, String value, IconData icon) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: c.textSecondary),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                    color: c.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
            ),
          ),
        ],
      );
    }

    if (isScaled) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: c.surfaceAlt,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.border.withValues(alpha: 0.6)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            buildTile('CADENCE', cadence, Icons.repeat_rounded),
            const SizedBox(height: 8),
            buildTile('PROGRESS', progressVal, Icons.trending_up_rounded),
            const SizedBox(height: 8),
            buildTile('SCHEDULE', timing, Icons.schedule_rounded),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: c.surfaceAlt,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: c.border.withValues(alpha: 0.6)),
      ),
      child: Row(
        children: [
          Expanded(child: buildTile('CADENCE', cadence, Icons.repeat_rounded)),
          Container(
            width: 1,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: c.border,
          ),
          Expanded(child: buildTile('PROGRESS', progressVal, Icons.trending_up_rounded)),
          Container(
            width: 1,
            height: 26,
            margin: const EdgeInsets.symmetric(horizontal: 8),
            color: c.border,
          ),
          Expanded(child: buildTile('SCHEDULE', timing, Icons.schedule_rounded)),
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            context,
            c,
            onAdd: () {
              HapticFeedback.selectionClick();
              PromiseChatComposer.show(context);
            },
            onViewAll: () {
              HapticFeedback.selectionClick();
              context.push('/promises');
            },
          ),
          const SizedBox(height: 20),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.accentTint,
                  ),
                  child: Icon(
                    Icons.verified_outlined,
                    size: 26,
                    color: c.accent,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'No active commitments',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Make a promise to yourself — one small step each day.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: c.textSecondary,
                  ),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    PromiseChatComposer.show(context);
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: c.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text(
                    'Create commitment',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
          _buildCardFooter(context, c, const []),
        ],
      ),
    );
  }

  Widget _buildCompletedCard(
    BuildContext context,
    WidgetRef ref,
    PromiseModel completed,
    List<PromiseModel> allActive,
    AppColors c,
  ) {
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
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCardHeader(
            context,
            c,
            onAdd: () {
              HapticFeedback.selectionClick();
              PromiseChatComposer.show(context);
            },
            onViewAll: () {
              HapticFeedback.selectionClick();
              context.push('/promises');
            },
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: const Color(0xFF388E3C).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.check_circle_rounded,
                  size: 13,
                  color: Color(0xFF388E3C),
                ),
                SizedBox(width: 4),
                Text(
                  'COMPLETED TODAY',
                  style: TextStyle(
                    color: Color(0xFF388E3C),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.4,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            completed.title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: c.textPrimary,
              decoration: TextDecoration.lineThrough,
              decorationColor: c.textSecondary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Commitment kept today · Keep your streak alive',
            style: TextStyle(
              color: c.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          _buildCardFooter(context, c, allActive),
        ],
      ),
    );
  }
}
