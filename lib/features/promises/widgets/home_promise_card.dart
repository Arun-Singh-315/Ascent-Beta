import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_navigation.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/promises/promise_providers.dart';
import '../../../core/promises/promise_service.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../../shared/widgets/glass_card.dart';
import '../promise_copy.dart';
import '../promise_sheet.dart';
import 'promise_dots.dart';

/// Home's promise card (CLAUDE.md §5.1, right under the Now card).
///
/// One promise gets the big card: the promise in large type, a row of day
/// dots, the streak, and one tap to answer today ("Kept it" / "Not today").
/// Other promises sit below as compact rows with a round check. With no
/// promises it becomes a gentle invitation with one-tap starters.
class HomePromiseCard extends ConsumerWidget {
  const HomePromiseCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final promises = ref.watch(homePromisesProvider).value;
    if (promises == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        0,
        AppSpace.s16,
        AppSpace.s20,
      ),
      child: GlassCard(
        key: const ValueKey('home_promise_card'),
        padding: const EdgeInsets.all(AppSpace.s20),
        child: promises.isEmpty
            ? const _Invite()
            : Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  PromiseHero(view: promises.first),
                  if (promises.length > 1) ...[
                    const SizedBox(height: AppSpace.s16),
                    Divider(height: 1, color: context.glass.line),
                    for (final p in promises.skip(1).take(3))
                      _CompactRow(
                        key: ValueKey('promise_row_${p.id}'),
                        view: p,
                      ),
                    if (promises.length > 4)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: AscentButton.ghost(
                          label: 'Show all ${promises.length}',
                          compact: true,
                          onPressed: () => context.open('/promises'),
                        ),
                      ),
                  ],
                ],
              ),
      ),
    );
  }
}

/// Answers today (or yesterday) for a promise, with haptics, Undo and a
/// small celebration at milestones.
Future<void> answerPromise(
  BuildContext context,
  WidgetRef ref,
  PromiseView view,
  String result, {
  DateTime? day,
}) async {
  final service = ref.read(promiseServiceProvider);
  final when = day ?? DateTime.now();
  if (result == 'kept') {
    HapticFeedback.lightImpact();
  } else {
    HapticFeedback.selectionClick();
  }
  try {
    await service.checkIn(view.id, result, day: when);
  } on ArgumentError catch (e) {
    if (context.mounted) {
      AscentSnackBar.error(context, message: '${e.message}');
    }
    return;
  }
  if (!context.mounted || result != 'kept') return;
  final after = await service.get(view.id);
  if (after == null || !context.mounted) return;
  final p = after.progress;
  if (after.promise.status == 'done') {
    AscentSnackBar.applaud(
      context,
      message: 'Promise kept',
      subtitle: promiseFinishLine(p),
    );
  } else if (p.streak > view.progress.streak &&
      promiseMilestones.contains(p.streak)) {
    AscentSnackBar.applaud(
      context,
      message: '${p.streak}-day streak',
      subtitle: 'You keep your word.',
    );
  }
}

/// The big state of one promise. Also used on the detail screen.
class PromiseHero extends ConsumerWidget {
  const PromiseHero({super.key, required this.view, this.linkToDetail = true});
  final PromiseView view;
  final bool linkToDetail;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final gold = promiseTint(context);
    final p = view.progress;
    final finished = view.promise.status == 'done';
    final facts = promiseFacts(p);
    final header = Row(
      children: [
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            color: gold.withValues(alpha: .14),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(Icons.handshake_outlined, size: 18, color: gold),
        ),
        const SizedBox(width: AppSpace.s8),
        Expanded(
          child: Text(
            finished ? 'Promise kept' : 'Promise · ${promiseDayLabel(p)}',
            style: AscentTextStyles.caption.copyWith(color: g.inkSecondary),
          ),
        ),
        if (linkToDetail)
          Icon(Icons.chevron_right_rounded, color: g.inkMuted, size: 22),
      ],
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (linkToDetail)
          Semantics(
            button: true,
            label: 'Open promise ${view.title}',
            child: InkWell(
              key: ValueKey('promise_open_${view.id}'),
              borderRadius: BorderRadius.circular(12),
              onTap: () => showPromiseDetail(context, view.id),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
                child: ExcludeSemantics(child: header),
              ),
            ),
          )
        else
          header,
        const SizedBox(height: AppSpace.s8),
        Text(
          view.title,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: AscentTextStyles.pageTitle.copyWith(color: g.ink),
        ),
        const SizedBox(height: AppSpace.s16),
        PromiseDots(progress: p),
        if (facts.isNotEmpty) ...[
          const SizedBox(height: AppSpace.s12),
          Wrap(
            spacing: AppSpace.s12,
            runSpacing: AppSpace.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final (i, f) in facts.indexed)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (i == 0 && p.streak > 1) ...[
                      Icon(
                        Icons.local_fire_department_rounded,
                        size: 16,
                        color: g.warningInk,
                      ),
                      const SizedBox(width: 2),
                    ],
                    Text(
                      f,
                      style: AscentTextStyles.caption.copyWith(
                        color: g.inkSecondary,
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ],
        const SizedBox(height: AppSpace.s16),
        AnimatedSwitcher(
          duration: MediaQuery.disableAnimationsOf(context)
              ? Duration.zero
              : const Duration(milliseconds: 250),
          child: _Actions(
            key: ValueKey('${view.promise.status}${p.today}${p.yesterdayOpen}'),
            view: view,
          ),
        ),
      ],
    );
  }
}

class _Actions extends ConsumerWidget {
  const _Actions({super.key, required this.view});
  final PromiseView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final p = view.progress;
    final service = ref.read(promiseServiceProvider);
    if (view.promise.status == 'done') {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            promiseFinishLine(p),
            style: AscentTextStyles.body.copyWith(color: g.ink),
          ),
          const SizedBox(height: AppSpace.s12),
          AscentButton.primary(
            key: const ValueKey('promise_again'),
            label: 'Promise again',
            icon: Icons.replay_rounded,
            expanded: true,
            onPressed: () => service.renew(view.id),
          ),
        ],
      );
    }
    if (p.yesterdayOpen) {
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'How did yesterday go?',
            style: AscentTextStyles.body.copyWith(color: g.ink),
          ),
          const SizedBox(height: AppSpace.s8),
          _Pair(
            keptKey: const ValueKey('promise_yesterday_kept'),
            missedKey: const ValueKey('promise_yesterday_missed'),
            keptLabel: 'I kept it',
            missedLabel: 'I missed it',
            onKept: () =>
                answerPromise(context, ref, view, 'kept', day: yesterday),
            onMissed: () =>
                answerPromise(context, ref, view, 'missed', day: yesterday),
          ),
        ],
      );
    }
    if (!p.answeredToday) {
      return _Pair(
        keptKey: const ValueKey('promise_kept'),
        missedKey: const ValueKey('promise_missed'),
        keptLabel: 'Kept it',
        missedLabel: 'Not today',
        onKept: () => answerPromise(context, ref, view, 'kept'),
        onMissed: () => answerPromise(context, ref, view, 'missed'),
      );
    }
    final kept = p.keptToday;
    return Row(
      children: [
        Icon(
          kept ? Icons.check_circle_rounded : Icons.nights_stay_outlined,
          color: kept ? g.successInk : g.inkSecondary,
          size: 22,
        ),
        const SizedBox(width: AppSpace.s8),
        Expanded(
          child: Text(
            promiseAnsweredLine(p),
            style: AscentTextStyles.body.copyWith(color: g.ink),
          ),
        ),
        AscentButton.ghost(
          key: const ValueKey('promise_undo'),
          label: 'Undo',
          compact: true,
          onPressed: () {
            HapticFeedback.selectionClick();
            service.clearCheckIn(view.id, DateTime.now());
          },
        ),
      ],
    );
  }
}

/// "Kept it" (primary) beside "Not today" (secondary). Stacks when the
/// text is large so nothing truncates.
class _Pair extends StatelessWidget {
  const _Pair({
    required this.keptKey,
    required this.missedKey,
    required this.keptLabel,
    required this.missedLabel,
    required this.onKept,
    required this.onMissed,
  });
  final Key keptKey, missedKey;
  final String keptLabel, missedLabel;
  final VoidCallback onKept, onMissed;

  @override
  Widget build(BuildContext context) {
    final kept = AscentButton.primary(
      key: keptKey,
      label: keptLabel,
      icon: Icons.check_rounded,
      expanded: true,
      onPressed: onKept,
    );
    final missed = AscentButton.secondary(
      key: missedKey,
      label: missedLabel,
      expanded: true,
      onPressed: onMissed,
    );
    final big = MediaQuery.textScalerOf(context).scale(10) > 13;
    if (big) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          kept,
          const SizedBox(height: AppSpace.s8),
          missed,
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: 3, child: kept),
        const SizedBox(width: AppSpace.s8),
        Expanded(flex: 2, child: missed),
      ],
    );
  }
}

/// A second (third, fourth) promise: title, day, and a round check.
class _CompactRow extends ConsumerWidget {
  const _CompactRow({super.key, required this.view});
  final PromiseView view;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final gold = promiseTint(context);
    final p = view.progress;
    final kept = p.keptToday;
    final sub = [
      promiseDayLabel(p),
      if (p.streak > 1) '${p.streak}-day streak',
      if (p.today == 'missed') 'Not today',
    ].join(' · ');
    return InkWell(
      onTap: () => showPromiseDetail(context, view.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    view.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AscentTextStyles.listRowTitle.copyWith(color: g.ink),
                  ),
                  Text(
                    sub,
                    style: AscentTextStyles.caption.copyWith(
                      color: g.inkSecondary,
                    ),
                  ),
                ],
              ),
            ),
            Semantics(
              button: true,
              checked: kept,
              label: kept ? 'Kept today, undo' : 'Mark kept today',
              child: InkResponse(
                key: ValueKey('promise_check_${view.id}'),
                radius: 24,
                onTap: () => kept
                    ? ref
                          .read(promiseServiceProvider)
                          .clearCheckIn(view.id, DateTime.now())
                    : answerPromise(context, ref, view, 'kept'),
                child: SizedBox(
                  width: 44,
                  height: 44,
                  child: Center(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: kept ? gold : Colors.transparent,
                        border: Border.all(
                          color: kept ? gold : g.inkMuted,
                          width: 1.5,
                        ),
                      ),
                      child: kept
                          ? const Icon(
                              Icons.check_rounded,
                              size: 18,
                              color: Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// No promises yet: say what this is and make starting effortless.
class _Invite extends ConsumerWidget {
  const _Invite();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final gold = promiseTint(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: gold.withValues(alpha: .14),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.handshake_outlined, color: gold, size: 24),
            ),
            const SizedBox(width: AppSpace.s12),
            Expanded(
              child: Text(
                'Make a promise to yourself',
                style: AscentTextStyles.homeTitle.copyWith(color: g.ink),
              ),
            ),
          ],
        ),
        const SizedBox(height: AppSpace.s8),
        Text(
          'One small thing, every day. Tap Kept it each evening and watch '
          'the days fill in.',
          style: AscentTextStyles.supportingText.copyWith(
            color: g.inkSecondary,
          ),
        ),
        const SizedBox(height: AppSpace.s12),
        Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            for (final s in promiseStarters)
              AppChip(
                key: ValueKey('promise_starter_$s'),
                label: s,
                icon: Icons.add_rounded,
                iconColor: gold,
                onTap: () => _start(context, ref, s),
              ),
          ],
        ),
        const SizedBox(height: AppSpace.s16),
        AscentButton.primary(
          key: const ValueKey('promise_make'),
          label: 'Make a promise',
          expanded: true,
          onPressed: () => showPromiseSheet(context),
        ),
      ],
    );
  }

  static Future<void> _start(
    BuildContext context,
    WidgetRef ref,
    String title,
  ) async {
    HapticFeedback.lightImpact();
    final service = ref.read(promiseServiceProvider);
    final id = await service.create(title: title);
    if (!context.mounted) return;
    AscentSnackBar.undo(
      context,
      message: 'Promise made: $title, 21 days',
      onUndo: () => service.delete(id),
    );
  }
}
