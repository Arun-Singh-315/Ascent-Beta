import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/promises/promise_providers.dart';
import '../../../core/promises/promise_service.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../promise_copy.dart';
import '../promise_sheet.dart';
import 'promise_dots.dart';


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


