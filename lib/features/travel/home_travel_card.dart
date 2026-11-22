import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_navigation.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/features/feature_registry.dart';
import '../../core/travel/travel_providers.dart';
import '../../core/travel/travel_service.dart';
import '../../core/utils/human_time.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/glass_card.dart';
import 'bill_sheet.dart';
import 'travel_ui.dart';
import 'visit_sheet.dart';

/// Home's travel card. It appears only while a trip is on or a recent visit
/// is waiting for its bill or photos, so Home stays quiet otherwise.
class HomeTravelCard extends ConsumerWidget {
  const HomeTravelCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(unlockedFeaturesProvider).contains(AscentFeature.travel)) {
      return const SizedBox.shrink();
    }
    final live = ref.watch(liveTripProvider);
    final prompts = ref.watch(visitPromptsProvider).value ?? const [];
    if (live == null && prompts.isEmpty) return const SizedBox.shrink();
    final g = context.glass;
    final now = DateTime.now();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        0,
        AppSpace.s16,
        AppSpace.s20,
      ),
      child: GlassCard(
        key: const ValueKey('home_travel_card'),
        padding: const EdgeInsets.all(AppSpace.s20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => context.open(
                live == null ? '/travel' : '/travel/trip?id=${live.id}',
              ),
              child: Row(
                children: [
                  const VisitTile(kind: 'transit'),
                  const SizedBox(width: AppSpace.s12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          live?.trip.name ?? 'Recent visits',
                          style: AscentTextStyles.homeTitle.copyWith(
                            color: g.ink,
                          ),
                        ),
                        if (live != null)
                          Text(
                            [
                              live.dayLabel(now) ?? '',
                              if (live.total > 0) '${rupees(live.total)} spent',
                            ].where((s) => s.isNotEmpty).join(' · '),
                            style: AscentTextStyles.caption.copyWith(
                              color: g.inkSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: g.inkMuted),
                ],
              ),
            ),
            for (final p in prompts.take(2)) ...[
              const SizedBox(height: AppSpace.s12),
              _Prompt(key: ValueKey('prompt_${p.visit.id}'), prompt: p),
            ],
            const SizedBox(height: AppSpace.s16),
            AscentButton.tonal(
              key: const ValueKey('home_here'),
              label: 'I’m here',
              icon: Icons.my_location_rounded,
              expanded: true,
              onPressed: () => showHereSheet(context),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Thalassa · last night — Add the bill?" with one-tap answers.
class _Prompt extends ConsumerWidget {
  const _Prompt({super.key, required this.prompt});
  final VisitPrompt prompt;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final v = prompt.visit;
    final ask = !prompt.hasBill
        ? (v.kind == 'food' ? 'Add the bill?' : 'Any bill to add?')
        : 'Add photos from here?';
    return Container(
      padding: const EdgeInsets.all(AppSpace.s12),
      decoration: BoxDecoration(
        color: g.recessed,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => showVisitSheet(context, v.id),
            child: Row(
              children: [
                VisitTile(kind: v.kind),
                const SizedBox(width: AppSpace.s8),
                Expanded(
                  child: Text(
                    '${v.name} · ${humanWhen(v.at)}',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AscentTextStyles.listRowTitle.copyWith(color: g.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            ask,
            style: AscentTextStyles.caption.copyWith(color: g.inkSecondary),
          ),
          const SizedBox(height: AppSpace.s8),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              if (!prompt.hasBill)
                AppChip(
                  key: const ValueKey('prompt_bill'),
                  label: 'Add bill',
                  icon: Icons.receipt_long_outlined,
                  isSelected: true,
                  onTap: () => showBillSheet(
                    context,
                    tripId: v.tripId,
                    visitId: v.id,
                    title: v.name,
                  ),
                ),
              if (prompt.photos == 0)
                AppChip(
                  key: const ValueKey('prompt_photos'),
                  label: 'Photos',
                  icon: Icons.photo_camera_outlined,
                  onTap: () => addVisitPhotos(context, ref, v.id),
                ),
              AppChip(
                key: const ValueKey('prompt_skip'),
                label: 'Skip',
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref.read(travelServiceProvider).settleVisit(v.id);
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}
