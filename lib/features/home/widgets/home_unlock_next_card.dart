import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/brand_palette.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/features/feature_registry.dart';
import '../../../core/providers/local_day_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/undo_snackbar.dart';

/// Pref: ISO day before which the card stays hidden.
const unlockNextHiddenUntilKey = 'ascent_unlock_next_hidden_until_v1';

/// Pref: ISO day the person finished onboarding with their first features.
const featuresStartedKey = 'ascent_features_started_v1';

/// The day before which the card stays hidden, persisted in prefs.
class UnlockNextHiddenUntilNotifier extends Notifier<String?> {
  @override
  String? build() =>
      ref.watch(sharedPreferencesProvider).getString(unlockNextHiddenUntilKey);

  Future<void> hideFor(int days) async {
    final until = ref
        .read(localDayProvider)
        .add(Duration(days: days))
        .toIso8601String();
    state = until;
    await ref
        .read(sharedPreferencesProvider)
        .setString(unlockNextHiddenUntilKey, until);
  }
}

final unlockNextHiddenUntilProvider =
    NotifierProvider<UnlockNextHiddenUntilNotifier, String?>(
      UnlockNextHiddenUntilNotifier.new,
    );

/// Whether the card should show today. It comes and goes: never on the first
/// day (the person just chose their features), at most one suggestion a day,
/// and three quiet days after "Not now".
bool shouldShowUnlockNext({
  required Set<AscentFeature> unlocked,
  required DateTime today,
  String? startedDay,
  String? hiddenUntil,
}) {
  if (nextLockedFeature(unlocked) == null) return false;
  final started = startedDay == null ? null : DateTime.tryParse(startedDay);
  if (started != null && !today.isAfter(started)) return false;
  final until = hiddenUntil == null ? null : DateTime.tryParse(hiddenUntil);
  return until == null || !today.isBefore(until);
}

/// Suggests the next feature to switch on, one at a time. Replaces the old
/// "Coming soon" shelf: every suggestion is a real feature that works now.
class HomeUnlockNextCard extends ConsumerWidget {
  const HomeUnlockNextCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unlocked = ref.watch(unlockedFeaturesProvider);
    final today = ref.watch(localDayProvider);
    final prefs = ref.watch(sharedPreferencesProvider);
    final show = shouldShowUnlockNext(
      unlocked: unlocked,
      today: today,
      startedDay: prefs.getString(featuresStartedKey),
      hiddenUntil: ref.watch(unlockNextHiddenUntilProvider),
    );
    final next = nextLockedFeature(unlocked);
    return AnimatedSize(
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 280),
      curve: Curves.easeOutCubic,
      alignment: Alignment.topCenter,
      child: !show || next == null
          ? const SizedBox(width: double.infinity)
          : _Card(spec: specOf(next)),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.spec});
  final FeatureSpec spec;

  Future<void> _hideFor(WidgetRef ref, int days) =>
      ref.read(unlockNextHiddenUntilProvider.notifier).hideFor(days);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final tint = BrandPalette.pillarTint(spec.tintId, dark: g.isDark);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s4,
        AppSpace.s16,
        AppSpace.s16,
      ),
      child: Container(
        key: const ValueKey('home_unlock_next'),
        padding: const EdgeInsets.all(AppSpace.s16),
        decoration: BoxDecoration(
          color: g.surface,
          borderRadius: BorderRadius.circular(20),
          border: g.isDark ? Border.all(color: g.line) : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: .12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(spec.icon, color: tint, size: 22),
                ),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Ready for ${spec.title}?',
                        style: AscentTextStyles.cardTitle.copyWith(
                          color: g.ink,
                        ),
                      ),
                      const SizedBox(height: AppSpace.s4),
                      Text(
                        spec.pitch,
                        style: AscentTextStyles.body.copyWith(
                          color: g.inkSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: AppSpace.s12),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              alignment: WrapAlignment.end,
              children: [
                AscentButton.ghost(
                  key: const ValueKey('home_unlock_next_later'),
                  label: 'Not now',
                  compact: true,
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    _hideFor(ref, 3);
                  },
                ),
                AscentButton.tonal(
                  key: const ValueKey('home_unlock_next_on'),
                  label: 'Turn on ${spec.title}',
                  compact: true,
                  onPressed: () async {
                    HapticFeedback.lightImpact();
                    final notifier = ref.read(
                      unlockedFeaturesProvider.notifier,
                    );
                    await notifier.unlock(spec.id);
                    // One suggestion a day: the next one waits for tomorrow.
                    await _hideFor(ref, 1);
                    if (!context.mounted) return;
                    showUndoSnackbar(
                      context,
                      message:
                          '${spec.title} is on. Find it on Home and in You.',
                      onUndo: () => notifier.lock(spec.id),
                    );
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
