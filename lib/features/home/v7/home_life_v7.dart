import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat, NumberFormat;

import '../../../app/app_navigation.dart';
import '../../../app/theme/ascent_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/features/feature_registry.dart';
import '../../../core/promises/promise_providers.dart';
import '../../../core/promises/promise_service.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/streak/study_streak_provider.dart';
import '../../../shared/widgets/ascent_icon.dart';
import '../../../shared/widgets/ascent_small_button.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../hydration/hydration_pace.dart';
import '../../promises/promise_copy.dart';
import '../../promises/promise_sheet.dart';
import '../../promises/widgets/home_promise_card.dart' show answerPromise;
import '../../promises/widgets/promise_dots.dart';
import '../model/life_rows.dart';
import 'home_region.dart';

final homeLifeSessionsProvider = StreamProvider.autoDispose<List<TimeSession>>((
  ref,
) {
  final now = DateTime.now();
  return ref
      .watch(timeSessionDaoProvider)
      .watchSessionsForDate(DateTime(now.year, now.month, now.day));
});

String _clock(DateTime t) => DateFormat('h:mm a').format(t);

String _slot(String slot) {
  final p = slot.split(':');
  if (p.length != 2) return slot;
  return _clock(
    DateTime(2000, 1, 1, int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0),
  );
}

/// One Life row before it is drawn.
class _Row {
  const _Row({
    required this.id,
    required this.glyph,
    required this.color,
    required this.name,
    required this.value,
    required this.unit,
    required this.indicator,
    required this.body,
    this.onTrack,
  });
  final String id, name, value, unit;
  final AscentGlyph glyph;
  final Color color;
  final Widget indicator;
  final Widget body;

  /// Null when there is nothing to judge (no doses today, say).
  final bool? onTrack;
}

/// Home v7 Life: water, medicine, focus, money and your promise as one
/// list. Each row shows today's number in its own colour; tap to open a
/// small chart and one-tap actions. One row is open at a time.
class HomeLifeSection extends ConsumerStatefulWidget {
  const HomeLifeSection({super.key, this.showPromise = true});

  /// Promise row (hidden when the user turned promises off on Home).
  final bool showPromise;

  @override
  ConsumerState<HomeLifeSection> createState() => _HomeLifeSectionState();
}

class _HomeLifeSectionState extends ConsumerState<HomeLifeSection> {
  String? _open = 'water';
  bool _saving = false;

  Future<void> _logWater() async {
    if (_saving) return;
    setState(() => _saving = true);
    final dao = ref.read(waterDaoProvider);
    try {
      final id = await dao.addWater(250);
      if (!mounted) return;
      AscentSnackBar.show(
        context,
        message: '250 ml water logged',
        actionLabel: 'Undo',
        onAction: () => dao.deleteWater(id),
      );
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(context, message: 'Could not log water.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _take(MedicineLog dose, String name) async {
    final service = ref.read(medicineServiceProvider);
    await service.toggleDose(dose.id, true);
    if (!mounted) return;
    AscentSnackBar.show(
      context,
      message: '$name taken',
      actionLabel: 'Undo',
      onAction: () => service.toggleDose(dose.id, false),
    );
  }

  @override
  Widget build(BuildContext context) {
    final on = ref.watch(unlockedFeaturesProvider);
    final t = context.tokens;
    final rows = <_Row>[
      if (on.contains(AscentFeature.care)) ...[_water(t), _medicine(t)],
      if (on.contains(AscentFeature.focus)) _focus(t),
      if (on.contains(AscentFeature.money)) _money(t),
      if (widget.showPromise && on.contains(AscentFeature.things)) ?_promise(t),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return HomeRegion(
      key: const ValueKey('home_day_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeRegionHeader(
            glyph: AscentGlyph.life,
            title: 'Life',
            tint: t.care,
            count: onTrackLabel([
              for (final r in rows)
                if (r.onTrack != null) r.onTrack!,
            ]),
          ),
          const SizedBox(height: 6),
          for (final (i, r) in rows.indexed)
            _LifeRow(
              key: ValueKey('home_life_${r.id}'),
              row: r,
              first: i == 0,
              open: _open == r.id,
              onToggle: () {
                HapticFeedback.selectionClick();
                setState(() => _open = _open == r.id ? null : r.id);
              },
            ),
        ],
      ),
    );
  }

  _Row _water(AscentTokens t) {
    final ml = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final goal = ref.watch(dailyWaterGoalStreamProvider).value ?? 2000;
    final logs = ref.watch(todayWaterLogsStreamProvider).value ?? const [];
    final behind = hydrationBehindMl(
      now: DateTime.now(),
      drankMl: ml,
      goalMl: goal,
    );
    final last = logs.isEmpty
        ? null
        : logs.map((l) => l.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);
    final glasses = (ml / 250).floor();
    return _Row(
      id: 'water',
      glyph: AscentGlyph.water,
      color: t.water,
      name: 'Water',
      value: litres(ml),
      unit: '/${litres(goal)} L',
      onTrack: behind == null,
      indicator: _Bar(progress: goal == 0 ? 0 : ml / goal, color: t.water),
      body: _Body(
        chart: _Bars(
          values: dayBuckets([for (final l in logs) (l.timestamp, l.amountMl)]),
          color: t.water,
        ),
        note: ml == 0
            ? 'Nothing logged yet today'
            : [
                '$glasses ${glasses == 1 ? 'glass' : 'glasses'}',
                if (last != null) 'last ${_clock(last)}',
              ].join(' · '),
        warning: behind == null ? null : '$behind ml behind pace',
        actions: [
          AscentSmallButton.filled(
            key: const ValueKey('home_bento_water_add'),
            label: '+250 ml',
            semanticLabel: 'Log 250 ml of water',
            onPressed: _saving ? null : _logWater,
          ),
          AscentSmallButton(
            label: 'Open',
            semanticLabel: 'Open water',
            onPressed: () => context.open('/hydration'),
          ),
        ],
      ),
    );
  }

  _Row _medicine(AscentTokens t) {
    final doses = [
      ...(ref.watch(todayMedicineLogsStreamProvider).value ?? const []),
    ]..sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
    final meds = {
      for (final m
          in ref.watch(activeMedicinesStreamProvider).value ?? const [])
        m.id: m,
    };
    final now = DateTime.now();
    final taken = doses.where((d) => d.isTaken).length;
    final missed = missedDoses([
      for (final d in doses) (d.timeSlot, d.isTaken),
    ], now);
    final next = doses.where((d) => !d.isTaken).firstOrNull;
    final nextName = next == null
        ? null
        : meds[next.medicineId]?.name ?? 'Medicine';
    return _Row(
      id: 'medicine',
      glyph: AscentGlyph.medicine,
      color: t.care,
      name: 'Medicine',
      value: doses.isEmpty ? '–' : '$taken',
      unit: doses.isEmpty ? '' : '/${doses.length} taken',
      onTrack: doses.isEmpty ? null : missed == 0,
      indicator: _Dots(
        states: [
          for (final d in doses)
            d.isTaken
                ? _DotState.done
                : missedDoses([(d.timeSlot, false)], now) > 0
                ? _DotState.missed
                : _DotState.open,
        ],
      ),
      body: _Body(
        rows: [
          for (final d in doses.take(5))
            _DoseLine(
              key: ValueKey('home_dose_${d.id}'),
              name: meds[d.medicineId]?.name ?? 'Medicine',
              dosage: meds[d.medicineId]?.dosage.trim() ?? '',
              when: d.isTaken && d.takenAt != null
                  ? 'taken ${_clock(d.takenAt!)}'
                  : _slot(d.timeSlot),
              taken: d.isTaken,
              missed: !d.isTaken && missedDoses([(d.timeSlot, false)], now) > 0,
            ),
        ],
        note: doses.isEmpty
            ? 'Nothing due today'
            : doses.length > 5
            ? '+${doses.length - 5} more'
            : null,
        warning: missed == 0
            ? null
            : '$missed ${missed == 1 ? 'dose' : 'doses'} not taken yet',
        actions: [
          if (next != null)
            AscentSmallButton.filled(
              key: const ValueKey('home_bento_medicine_take'),
              label: 'Take $nextName',
              onPressed: () => _take(next, nextName!),
            ),
          AscentSmallButton(
            label: doses.isEmpty ? 'Add medicine' : 'Open',
            semanticLabel: 'Open medicine',
            onPressed: () => context.open('/medicine'),
          ),
        ],
      ),
    );
  }

  _Row _focus(AscentTokens t) {
    final minutes = ref.watch(studyStreakProvider).todaySeconds ~/ 60;
    final sessions =
        (ref.watch(homeLifeSessionsProvider).value ?? const <TimeSession>[])
            .where((s) => s.durationSeconds >= 60)
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    const goal = 60;
    final n = sessions.length;
    return _Row(
      id: 'focus',
      glyph: AscentGlyph.focus,
      color: t.focus,
      name: 'Focus',
      value: minutes == 0 ? '–' : '$minutes',
      unit: '/$goal min',
      indicator: _Bar(progress: minutes / goal, color: t.focus),
      body: _Body(
        chart: _Bars(
          values: dayBuckets([
            for (final s in sessions) (s.startedAt, s.durationSeconds / 60),
          ]),
          color: t.focus,
        ),
        note: n == 0
            ? 'A 25-minute session is a good start'
            : '$n ${n == 1 ? 'session' : 'sessions'} · last: ${sessions.first.label}',
        actions: [
          AscentSmallButton.filled(
            key: const ValueKey('home_bento_focus_start'),
            label: 'Start focus',
            onPressed: () => context.open('/focus'),
          ),
        ],
      ),
    );
  }

  _Row _money(AscentTokens t) {
    final today = ref.watch(todaySpendingStreamProvider).value ?? 0;
    final month = ref.watch(currentMonthSpendingStreamProvider).value ?? 0;
    final budget = ref.watch(overallBudgetStreamProvider).value;
    final recent =
        (ref.watch(recentTransactionsStreamProvider).value ??
                const <FinanceTransaction>[])
            .take(3)
            .toList();
    final limit = budget != null && budget.monthlyLimit > 0
        ? budget.monthlyLimit
        : null;
    final exact = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final now = DateTime.now();
    String when(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day
        ? _clock(d)
        : DateFormat('d MMM').format(d);
    return _Row(
      id: 'money',
      glyph: AscentGlyph.money,
      color: t.money,
      name: 'Money',
      value: rupees(today),
      unit: ' today',
      onTrack: limit == null ? null : month <= limit,
      indicator: limit == null
          ? _Note(
              month == 0
                  ? 'Nothing spent this month'
                  : '${rupees(month)} this month',
            )
          : _Bar(
              progress: month / limit,
              color: month > limit ? t.danger : t.money,
            ),
      body: _Body(
        rows: [
          for (final x in recent)
            _MoneyLine(
              key: ValueKey('home_txn_${x.id}'),
              title: x.title,
              when: when(x.date),
              amount:
                  '${x.type == 'income' ? '+' : ''}${exact.format(x.amount)}',
              income: x.type == 'income',
            ),
        ],
        note: recent.isEmpty
            ? 'No transactions yet'
            : limit == null
            ? null
            : '${rupees(month)} of ${rupees(limit)} this month',
        warning: limit != null && month > limit
            ? 'Over this month’s budget'
            : null,
        actions: [
          AscentSmallButton.filled(
            key: const ValueKey('home_bento_money_add'),
            label: 'Add expense',
            onPressed: () => context.open('/money'),
          ),
        ],
      ),
    );
  }

  _Row? _promise(AscentTokens t) {
    final promises = ref.watch(homePromisesProvider).value;
    if (promises == null) return null;
    if (promises.isEmpty) {
      return _Row(
        id: 'promise',
        glyph: AscentGlyph.promise,
        color: t.commit,
        name: 'Promise',
        value: '–',
        unit: '',
        indicator: const _Note('One small thing, every day'),
        body: _Body(
          note: 'Pick one small thing and mark it kept each evening.',
          actions: [
            for (final s in promiseStarters.take(2))
              AscentSmallButton(
                key: ValueKey('promise_starter_$s'),
                label: s,
                glyph: AscentGlyph.plus,
                onPressed: () => _startPromise(s),
              ),
            AscentSmallButton.filled(
              key: const ValueKey('promise_make'),
              label: 'Make a promise',
              onPressed: () => showPromiseSheet(context),
            ),
          ],
        ),
      );
    }
    final v = promises.first;
    final p = v.progress;
    return _Row(
      id: 'promise',
      glyph: AscentGlyph.promise,
      color: t.commit,
      name: v.title,
      value: 'Day ${p.dayNumber}',
      unit: p.length == null ? '' : '/${p.length}',
      onTrack: v.isActive ? !p.answeredToday || p.keptToday : null,
      indicator: PromiseDots(progress: p, size: 7, window: 7),
      body: _Body(
        note: p.streak > 0
            ? '${p.streak}-day streak · best ${p.best}'
            : 'Mark it each evening to build a streak',
        rows: [
          if (p.answeredToday)
            _PromiseAnswered(view: v, line: promiseAnsweredLine(p)),
        ],
        actions: [
          if (!p.answeredToday && v.isActive) ...[
            AscentSmallButton.filled(
              key: const ValueKey('promise_kept'),
              label: 'Kept it',
              onPressed: () => answerPromise(context, ref, v, 'kept'),
            ),
            AscentSmallButton(
              key: const ValueKey('promise_missed'),
              label: 'Not today',
              onPressed: () => answerPromise(context, ref, v, 'missed'),
            ),
          ],
          AscentSmallButton.ghost(
            label: promises.length > 1 ? 'All ${promises.length}' : 'Open',
            semanticLabel: 'Open promises',
            onPressed: () => context.open('/promises'),
          ),
        ],
      ),
    );
  }

  Future<void> _startPromise(String title) async {
    HapticFeedback.lightImpact();
    final service = ref.read(promiseServiceProvider);
    final id = await service.create(title: title);
    if (!mounted) return;
    AscentSnackBar.undo(
      context,
      message: 'Promise made: $title, 21 days',
      onUndo: () => service.delete(id),
    );
  }
}

class _LifeRow extends StatelessWidget {
  const _LifeRow({
    super.key,
    required this.row,
    required this.first,
    required this.open,
    required this.onToggle,
  });
  final _Row row;
  final bool first, open;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = Duration(milliseconds: reduce ? 0 : 300);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: t.lineFaint)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            label: '${row.name}: ${row.value}${row.unit}',
            excludeSemantics: true,
            child: InkWell(
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 54),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: row.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: AscentIcon(row.glyph, size: 17, color: row.color),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            row.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AscentTextStyles.label.copyWith(
                              color: t.label,
                            ),
                          ),
                          const SizedBox(height: 5),
                          row.indicator,
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: row.value,
                            style: AscentTextStyles.value.copyWith(
                              color: row.value == '–'
                                  ? t.labelTertiary
                                  : row.color,
                            ),
                          ),
                          TextSpan(
                            text: row.unit,
                            style: AscentTextStyles.meta.copyWith(
                              color: t.labelTertiary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 6),
                    AnimatedRotation(
                      turns: open ? 0.25 : 0,
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      child: AscentIcon(
                        AscentGlyph.chevron,
                        size: 14,
                        color: t.labelTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: duration,
            curve: Curves.easeOutCubic,
            alignment: Alignment.topCenter,
            child: open
                ? Padding(
                    padding: const EdgeInsets.only(left: 40, bottom: 12),
                    child: row.body,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

/// An open row: optional chart, detail lines, a note, a warning in amber,
/// then small actions.
class _Body extends StatelessWidget {
  const _Body({
    this.chart,
    this.rows = const [],
    this.note,
    this.warning,
    this.actions = const [],
  });
  final _Bars? chart;
  final List<Widget> rows;
  final String? note, warning;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (chart case final _Bars c when c.values.any((v) => v > 0)) ...[
          c,
          const SizedBox(height: 6),
        ],
        ...rows,
        if (note != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              note!,
              style: AscentTextStyles.meta.copyWith(color: t.labelSecondary),
            ),
          ),
        if (warning != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              warning!,
              style: AscentTextStyles.meta.copyWith(
                color: t.warning,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        if (actions.isNotEmpty) Wrap(spacing: 6, children: actions),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.progress, required this.color});
  final double progress;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(3),
      child: SizedBox(
        height: 4,
        child: LinearProgressIndicator(
          value: progress.clamp(0.0, 1.0),
          color: color,
          backgroundColor: context.tokens.lineFaint,
        ),
      ),
    );
  }
}

class _Note extends StatelessWidget {
  const _Note(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: AscentTextStyles.meta.copyWith(color: context.tokens.labelTertiary),
  );
}

enum _DotState { done, missed, open }

class _Dots extends StatelessWidget {
  const _Dots({required this.states});
  final List<_DotState> states;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (states.isEmpty) return const _Note('Nothing due today');
    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final s in states)
          Container(
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: switch (s) {
                _DotState.done => t.success,
                _DotState.missed => t.danger,
                _DotState.open => Colors.transparent,
              },
              border: s == _DotState.open
                  ? Border.all(color: t.labelTertiary, width: 1.4)
                  : null,
            ),
          ),
      ],
    );
  }
}

/// Nine two-hour bars from 6:00 to midnight, in the feature colour, with
/// four hour marks under them.
class _Bars extends StatelessWidget {
  const _Bars({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final max = values.fold<double>(0, (a, b) => b > a ? b : a);
    return Semantics(
      label: 'Today by time of day',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            height: 44,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final (i, v) in values.indexed) ...[
                  if (i > 0) const SizedBox(width: 5),
                  Expanded(
                    child: Container(
                      height: max == 0 ? 4 : 4 + 40 * (v / max),
                      decoration: BoxDecoration(
                        color: v == 0 ? t.lineFaint : color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 3),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (final h in const ['6', '12', '18', '24'])
                Text(
                  h,
                  style: AscentTextStyles.meta.copyWith(
                    color: t.labelTertiary,
                    fontSize: 9.5,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DoseLine extends StatelessWidget {
  const _DoseLine({
    super.key,
    required this.name,
    required this.dosage,
    required this.when,
    required this.taken,
    required this.missed,
  });
  final String name, dosage, when;
  final bool taken, missed;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 30),
      child: Row(
        children: [
          Expanded(
            child: Text(
              dosage.isEmpty ? name : '$name · $dosage',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AscentTextStyles.row.copyWith(
                fontSize: 13.5,
                color: taken ? t.labelTertiary : t.label,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            when,
            style: AscentTextStyles.meta.copyWith(
              color: taken
                  ? t.success
                  : missed
                  ? t.danger
                  : t.labelTertiary,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoneyLine extends StatelessWidget {
  const _MoneyLine({
    super.key,
    required this.title,
    required this.when,
    required this.amount,
    required this.income,
  });
  final String title, when, amount;
  final bool income;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 30),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AscentTextStyles.row.copyWith(
                fontSize: 13.5,
                color: t.label,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            when,
            style: AscentTextStyles.meta.copyWith(color: t.labelTertiary),
          ),
          const SizedBox(width: 10),
          Text(
            amount,
            style: AscentTextStyles.meta.copyWith(
              color: income ? t.success : t.label,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _PromiseAnswered extends ConsumerWidget {
  const _PromiseAnswered({required this.view, required this.line});
  final PromiseView view;
  final String line;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final kept = view.progress.keptToday;
    return Row(
      children: [
        Expanded(
          child: Text(
            line,
            style: AscentTextStyles.row.copyWith(
              fontSize: 13.5,
              color: kept ? t.success : t.labelSecondary,
            ),
          ),
        ),
        AscentSmallButton.ghost(
          key: const ValueKey('promise_undo'),
          label: 'Undo',
          onPressed: () {
            HapticFeedback.selectionClick();
            ref
                .read(promiseServiceProvider)
                .clearCheckIn(view.id, DateTime.now());
          },
        ),
      ],
    );
  }
}
