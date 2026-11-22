import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/promises/promise_providers.dart';
import '../../core/promises/promise_service.dart';
import '../../shared/widgets/ascent_backdrop.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/glass_card.dart';
import 'promise_copy.dart';
import 'promise_sheet.dart';
import 'widgets/home_promise_card.dart';
import 'widgets/promise_dots.dart';

/// All promises: active ones as full cards you can answer right here, then
/// Past (finished and released) as quiet rows you can start again.
class PromisesScreen extends ConsumerWidget {
  const PromisesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final all = ref.watch(promisesProvider);
    final active = ref.watch(activePromisesProvider).value ?? const [];
    return AscentScaffold(
      title: 'Promises',
      largeTitle: true,
      backgroundColor: Colors.transparent,
      actions: [
        AscentButton.icon(
          key: const ValueKey('promises_new'),
          icon: Icons.add_rounded,
          tooltip: 'New promise',
          semanticLabel: 'New promise',
          onPressed: () => showPromiseSheet(context),
        ),
      ],
      body: AscentBackdrop(
        child: all.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => EmptyState(
            icon: Icons.cloud_off_rounded,
            title: "Couldn't load your promises",
            subtitle: 'Something went wrong. Please try again.',
            actionLabel: 'Try again',
            onAction: () => ref.invalidate(promisesProvider),
          ),
          data: (list) {
            if (list.isEmpty) return _Empty(ref: ref);
            final past = list.where((p) => !p.isActive).toList().reversed;
            return ListView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s16,
                AppSpace.s8,
                AppSpace.s16,
                AppSpace.s40,
              ),
              children: [
                for (final p in active)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s16),
                    child: GlassCard(
                      key: ValueKey('promise_card_${p.id}'),
                      padding: const EdgeInsets.all(AppSpace.s20),
                      child: PromiseHero(view: p),
                    ),
                  ),
                if (active.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s16),
                    child: GlassCard(
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              'No active promise. Ready for the next one?',
                              style: AscentTextStyles.body.copyWith(
                                color: g.ink,
                              ),
                            ),
                          ),
                          AscentButton.tonal(
                            label: 'Make one',
                            compact: true,
                            onPressed: () => showPromiseSheet(context),
                          ),
                        ],
                      ),
                    ),
                  ),
                if (past.isNotEmpty) ...[
                  const SizedBox(height: AppSpace.s12),
                  Text(
                    'Past',
                    style: AscentTextStyles.homeTitle.copyWith(color: g.ink),
                  ),
                  const SizedBox(height: AppSpace.s8),
                  GlassCard(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s16,
                      vertical: AppSpace.s4,
                    ),
                    child: Column(
                      children: [
                        for (final (i, p) in past.indexed) ...[
                          if (i > 0) Divider(height: 1, color: g.line),
                          _PastRow(key: ValueKey('past_${p.id}'), view: p),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PastRow extends ConsumerWidget {
  const _PastRow({super.key, required this.view});
  final PromiseView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final p = view.progress;
    final sub = view.promise.status == 'done'
        ? promiseFinishLine(p)
        : 'Released on day ${p.dayNumber} · kept ${p.kept}';
    return InkWell(
      onTap: () => showPromiseDetail(context, view.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    view.title,
                    style: AscentTextStyles.listRowTitle.copyWith(color: g.ink),
                  ),
                  const SizedBox(height: AppSpace.s4),
                  Text(
                    sub,
                    style: AscentTextStyles.caption.copyWith(
                      color: g.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            AscentButton.ghost(
              label: 'Again',
              icon: Icons.replay_rounded,
              compact: true,
              onPressed: () async {
                HapticFeedback.lightImpact();
                final id = await ref
                    .read(promiseServiceProvider)
                    .renew(view.id);
                if (context.mounted) {
                  AscentSnackBar.undo(
                    context,
                    message: 'Started again from today',
                    onUndo: () => ref.read(promiseServiceProvider).delete(id),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.ref});
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) => Center(
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(AppSpace.s24),
      child: EmptyState(
        icon: Icons.handshake_outlined,
        tint: promiseTint(context),
        title: 'Keep your word to yourself',
        subtitle:
            'Make one small daily promise. Check in each evening and watch '
            'the days fill in.',
        actionLabel: 'Make a promise',
        onAction: () => showPromiseSheet(context),
        starters: [
          for (final s in promiseStarters)
            EmptyStarter(
              label: s,
              icon: Icons.add_rounded,
              onTap: () async {
                final service = ref.read(promiseServiceProvider);
                final id = await service.create(title: s);
                if (context.mounted) {
                  AscentSnackBar.undo(
                    context,
                    message: 'Promise made: $s',
                    onUndo: () => service.delete(id),
                  );
                }
              },
            ),
        ],
      ),
    ),
  );
}
