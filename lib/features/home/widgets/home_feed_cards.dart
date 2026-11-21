import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/app_navigation.dart';
import '../../../app/theme/brand_palette.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/features/feature_registry.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../core/streak/study_streak_provider.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/widgets/ascent_composer.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../../shared/widgets/glass_card.dart';
import 'activity_actions.dart';
import 'activity_composer.dart';
import '../../hydration/hydration_pace.dart';
import '../../thought_wall/board/board_logic.dart' show displayContent;

/// Home's hero cards, in feed order (CLAUDE.md §5.1): Things and Mind are
/// live summaries with their own inline input (see, add, leave), then one
/// big "Your day" card that closes the feed. Every card is iOS glass over the [AscentBackdrop], and
/// each feature appears once.

/// Things today: progress, the next four items with tap-to-complete, and
/// the natural-language quick add right in the card.
class HomeThingsCard extends ConsumerWidget {
  const HomeThingsCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(unlockedFeaturesProvider).contains(AscentFeature.things)) {
      return const SizedBox.shrink();
    }
    final g = context.glass;
    final items = ref.watch(todayActivitiesProvider).value ?? const [];
    // Medicine doses live in "Your day", not in the Things list.
    final today = items
        .where(
          (a) =>
              a.sourceType != 'medicine' &&
              (a.plannedDate != null || a.isDailyStanding),
        )
        .toList();
    final done = today
        .where((a) => a.status == TodayActivityStatus.done)
        .length;
    final pending =
        today.where((a) => a.status != TodayActivityStatus.done).toList()
          ..sort((a, b) {
            final at = a.scheduledTime, bt = b.scheduledTime;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return at.compareTo(bt);
          });
    final tint = BrandPalette.pillarTint('things', dark: g.isDark);
    final total = today.length;
    final progress = total == 0 ? 0.0 : done / total;
    return _FeedCard(
      key: const ValueKey('home_things_card'),
      header: _CardHeader(
        icon: Icons.checklist_rtl_rounded,
        tint: tint,
        title: 'Things',
        subtitle: total == 0
            ? 'Nothing planned yet'
            : pending.isEmpty
            ? 'All done today'
            : '${pending.length} left · $done done',
        route: '/things',
        trailing: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(
            value: progress,
            strokeWidth: 3.5,
            strokeCap: StrokeCap.round,
            color: progress == 1 ? g.successInk : tint,
            backgroundColor: tint.withValues(alpha: .16),
          ),
        ),
      ),
      children: [
        for (final a in pending.take(4))
          _ThingRow(key: ValueKey('home_thing_${a.id}'), item: a),
        if (pending.length > 4)
          TextButton(
            onPressed: () => context.open('/things'),
            child: Text('Show all ${pending.length}'),
          ),
        const SizedBox(height: AppSpace.s8),
        const ActivityComposer(),
      ],
    );
  }
}

class _ThingRow extends ConsumerWidget {
  const _ThingRow({super.key, required this.item});
  final TodayActivityItem item;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final locked = item.isLockedUntilScheduled;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => context.open('/things'),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 44),
        child: Row(
          children: [
            Semantics(
              button: true,
              label: 'Complete ${item.title}',
              child: InkResponse(
                radius: 20,
                onTap: locked
                    ? null
                    : () {
                        HapticFeedback.lightImpact();
                        completeActivityWithUndo(context, ref, item);
                      },
                child: SizedBox(
                  width: 40,
                  height: 44,
                  child: Icon(
                    locked
                        ? Icons.schedule_rounded
                        : Icons.radio_button_unchecked_rounded,
                    size: 22,
                    color: g.inkMuted,
                  ),
                ),
              ),
            ),
            Expanded(
              child: Text(
                item.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AscentTextStyles.body.copyWith(color: g.ink),
              ),
            ),
            if (item.scheduledTime != null)
              Text(
                DateFormat('h:mm a').format(item.scheduledTime!),
                style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
              ),
          ],
        ),
      ),
    );
  }
}

/// Mind: the latest thoughts as small bubbles and a capture field, so a
/// thought goes in without leaving Home.
class HomeMindCard extends ConsumerStatefulWidget {
  const HomeMindCard({super.key});

  @override
  ConsumerState<HomeMindCard> createState() => _HomeMindCardState();
}

class _HomeMindCardState extends ConsumerState<HomeMindCard> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    final dao = ref.read(thoughtDaoProvider);
    try {
      final id = await dao.insertThought(
        ThoughtTableCompanion.insert(content: text),
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _text.clear();
      AscentSnackBar.show(
        context,
        message: 'Thought saved',
        actionLabel: 'Undo',
        onAction: () => dao.deleteThought(id),
      );
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: 'Could not save. Your text is still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(unlockedFeaturesProvider).contains(AscentFeature.mind)) {
      return const SizedBox.shrink();
    }
    final g = context.glass;
    final count = ref.watch(todayThoughtsCountStreamProvider).value ?? 0;
    final recent = (ref.watch(recentThoughtsStreamProvider).value ?? const [])
        .where((t) => !t.isArchived)
        .take(3)
        .toList();
    final tint = BrandPalette.pillarTint('mind', dark: g.isDark);
    return _FeedCard(
      key: const ValueKey('home_mind_card'),
      header: _CardHeader(
        icon: Icons.lightbulb_outline_rounded,
        tint: tint,
        title: 'Mind',
        subtitle: count == 0
            ? 'Nothing captured today'
            : count == 1
            ? '1 thought today'
            : '$count thoughts today',
        route: '/thought-wall',
      ),
      children: [
        for (final t in recent)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpace.s8),
            child: InkWell(
              key: ValueKey('home_thought_${t.id}'),
              borderRadius: BorderRadius.circular(16),
              onTap: () => context.open('/thought-wall?thought=${t.id}'),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s12,
                  vertical: AppSpace.s10,
                ),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: g.isDark ? .14 : .08),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  displayContent(t.content).trim(),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.body.copyWith(color: g.ink),
                ),
              ),
            ),
          ),
        AscentComposer(
          key: const ValueKey('home_mind_composer'),
          controller: _text,
          focusNode: _focus,
          hint: 'What\u2019s on your mind?',
          maxLines: 4,
          busy: _saving,
          fieldKey: const ValueKey('home_mind_field'),
          sendKey: const ValueKey('home_mind_send'),
          sendTooltip: 'Save thought',
          onSend: _save,
        ),
      ],
    );
  }
}

/// A hero feed card: glass, a header that opens the screen, then content.
class _FeedCard extends StatelessWidget {
  const _FeedCard({super.key, required this.header, required this.children});
  final Widget header;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.s16,
      0,
      AppSpace.s16,
      AppSpace.s20,
    ),
    child: GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          header,
          const SizedBox(height: AppSpace.s8),
          ...children,
        ],
      ),
    ),
  );
}

class _CardHeader extends StatelessWidget {
  const _CardHeader({
    required this.icon,
    required this.tint,
    required this.title,
    required this.subtitle,
    required this.route,
    this.trailing,
  });
  final IconData icon;
  final Color tint;
  final String title, subtitle, route;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      button: true,
      label: 'Open $title. $subtitle',
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () {
          HapticFeedback.selectionClick();
          context.open(route);
        },
        child: ExcludeSemantics(
          child: Row(
            children: [
              _IconChip(icon: icon, tint: tint, size: 40),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AscentTextStyles.homeTitle.copyWith(color: g.ink),
                    ),
                    Text(
                      subtitle,
                      style: AscentTextStyles.caption.copyWith(
                        color: g.inkSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              ?trailing,
              const SizedBox(width: AppSpace.s4),
              Icon(Icons.chevron_right_rounded, color: g.inkMuted),
            ],
          ),
        ),
      ),
    );
  }
}

// Building blocks -------------------------------------------------------------

/// Outlined ring icon: a tinted 1.5 px ring with a nearly see-through
/// inside and an outlined glyph, so icons feel light on glass.
class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, required this.tint, this.size = 40});
  final IconData icon;
  final Color tint;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      color: tint.withValues(alpha: context.glass.isDark ? .10 : .06),
      border: Border.all(
        color: tint.withValues(alpha: context.glass.isDark ? .70 : .55),
        width: 1.5,
      ),
    ),
    child: Icon(icon, size: size * .5, color: tint),
  );
}

/// Small round quick action in a tile's corner (44 pt hit area).
class _QuickAction extends StatelessWidget {
  const _QuickAction({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.tint,
    required this.onPressed,
  });
  final IconData icon;
  final String tooltip;
  final Color tint;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => Tooltip(
    message: tooltip,
    child: Semantics(
      button: true,
      label: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: 22,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(shape: BoxShape.circle, color: tint),
              child: Icon(icon, size: 18, color: context.glass.primaryButtonFg),
            ),
          ),
        ),
      ),
    ),
  );
}

// "Your day" -----------------------------------------------------------------

/// "Your day": one big glass card that closes the feed. Each feature is a
/// full-width row with real detail (what's next, what's left, the last
/// entry), not just a number, separated by hairlines.
class HomeLifeTiles extends ConsumerWidget {
  const HomeLifeTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final on = ref.watch(unlockedFeaturesProvider);
    final rows = <Widget>[
      if (on.contains(AscentFeature.care)) const _WaterRow(),
      if (on.contains(AscentFeature.care)) const _MedicineRow(),
      if (on.contains(AscentFeature.money)) const _MoneyRow(),
      if (on.contains(AscentFeature.focus)) const _FocusRow(),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    return Padding(
      key: const ValueKey('home_day_card'),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        0,
        AppSpace.s16,
        AppSpace.s20,
      ),
      child: GlassCard(
        padding: EdgeInsets.zero,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s16,
                AppSpace.s16,
                AppSpace.s16,
                AppSpace.s4,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: Text(
                        'Your day',
                        style: AscentTextStyles.homeTitle.copyWith(
                          color: g.ink,
                        ),
                      ),
                    ),
                  ),
                  Text(
                    DateFormat('EEE d MMM').format(DateTime.now()),
                    style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
                  ),
                ],
              ),
            ),
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0)
                Divider(
                  height: 1,
                  indent: 72,
                  color: g.ink.withValues(alpha: g.isDark ? .12 : .08),
                ),
              rows[i],
            ],
            const SizedBox(height: AppSpace.s4),
          ],
        ),
      ),
    );
  }
}

/// One "Your day" row: ring icon, a title with its main value, detail
/// lines, and an action button that always fits inside the row.
class _DayRow extends StatelessWidget {
  const _DayRow({
    super.key,
    required this.icon,
    required this.tint,
    required this.title,
    required this.value,
    required this.route,
    required this.semantics,
    this.details = const [],
    this.action,
  });
  final IconData icon;
  final Color tint;
  final String title, value, route, semantics;
  final List<Widget> details;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      button: true,
      label: semantics,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          context.open(route);
        },
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: AlignmentDirectional.centerStart.resolve(
                Directionality.of(context),
              ),
              end: AlignmentDirectional.centerEnd.resolve(
                Directionality.of(context),
              ),
              colors: [
                tint.withValues(alpha: g.isDark ? .10 : .06),
                tint.withValues(alpha: 0),
              ],
            ),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s16,
            AppSpace.s12,
            AppSpace.s8,
            AppSpace.s12,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconChip(icon: icon, tint: tint, size: 44),
              const SizedBox(width: AppSpace.s12),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Text(
                            title,
                            style: AscentTextStyles.caption.copyWith(
                              color: g.inkSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: AppSpace.s8),
                          Flexible(
                            child: Text(
                              value,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AscentTextStyles.listRowTitle.copyWith(
                                color: g.ink,
                                fontFeatures: const [
                                  FontFeature.tabularFigures(),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      for (final d in details) ...[
                        const SizedBox(height: AppSpace.s4),
                        d,
                      ],
                    ],
                  ),
                ),
              ),
              ?action,
            ],
          ),
        ),
      ),
    );
  }
}

Widget _detail(
  BuildContext context,
  String text, {
  Color? color,
  bool strong = false,
}) => Text(
  text,
  maxLines: 2,
  overflow: TextOverflow.ellipsis,
  style: AscentTextStyles.caption.copyWith(
    color: color ?? context.glass.inkMuted,
    fontWeight: strong ? FontWeight.w600 : null,
  ),
);

Widget _bar(double value, Color tint) => ClipRRect(
  borderRadius: BorderRadius.circular(999),
  child: LinearProgressIndicator(
    value: value.clamp(0, 1).toDouble(),
    minHeight: 5,
    color: tint,
    backgroundColor: tint.withValues(alpha: .14),
  ),
);

class _WaterRow extends ConsumerStatefulWidget {
  const _WaterRow();

  @override
  ConsumerState<_WaterRow> createState() => _WaterRowState();
}

class _WaterRowState extends ConsumerState<_WaterRow> {
  bool _saving = false;

  Future<void> _log() async {
    if (_saving) return;
    setState(() => _saving = true);
    HapticFeedback.lightImpact();
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

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final ml = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final goal = ref.watch(dailyWaterGoalStreamProvider).value ?? 2000;
    final glasses = (ml / 250).floor();
    final behind = hydrationBehindMl(
      now: DateTime.now(),
      drankMl: ml,
      goalMl: goal,
    );
    final tint = BrandPalette.pillarTint('hydration', dark: g.isDark);
    String l(int v) => (v / 1000).toStringAsFixed(1);
    return _DayRow(
      key: const ValueKey('home_bento_water'),
      icon: Icons.water_drop_outlined,
      tint: tint,
      title: 'Water',
      value: '${l(ml)} of ${l(goal)} L',
      route: '/hydration',
      semantics: 'Water: ${l(ml)} of ${l(goal)} litres',
      details: [
        _detail(
          context,
          behind != null
              ? '$behind ml behind pace · $glasses glass${glasses == 1 ? '' : 'es'} so far'
              : ml == 0
              ? 'No water logged yet'
              : '$glasses glass${glasses == 1 ? '' : 'es'} so far · on track',
          color: behind != null ? g.warningInk : null,
          strong: behind != null,
        ),
        _bar(goal <= 0 ? 0 : ml / goal, tint),
      ],
      action: _QuickAction(
        key: const ValueKey('home_bento_water_add'),
        icon: Icons.add_rounded,
        tooltip: 'Log 250 ml',
        tint: tint,
        onPressed: _saving ? null : _log,
      ),
    );
  }
}

class _MedicineRow extends ConsumerWidget {
  const _MedicineRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final doses = [
      ...(ref.watch(todayMedicineLogsStreamProvider).value ?? const []),
    ]..sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
    final meds = {
      for (final m
          in ref.watch(activeMedicinesStreamProvider).value ?? const [])
        m.id: m.name,
    };
    final taken = doses.where((d) => d.isTaken).length;
    final next = doses.where((d) => !d.isTaken).firstOrNull;
    final tint = BrandPalette.pillarTint('medicine', dark: g.isDark);
    String at(String slot) {
      final p = slot.split(':');
      if (p.length != 2) return slot;
      return DateFormat('h:mm a').format(
        DateTime(2000, 1, 1, int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0),
      );
    }

    return _DayRow(
      key: const ValueKey('home_bento_medicine'),
      icon: Icons.medication_outlined,
      tint: tint,
      title: 'Medicine',
      value: doses.isEmpty ? 'Nothing due' : '$taken of ${doses.length} taken',
      route: '/medicine',
      semantics: doses.isEmpty
          ? 'Medicine: nothing due today'
          : 'Medicine: $taken of ${doses.length} taken',
      details: [
        if (next != null)
          _detail(
            context,
            'Next: ${meds[next.medicineId] ?? 'Medicine'} · ${at(next.timeSlot)}',
            color: g.ink,
            strong: true,
          )
        else if (doses.isNotEmpty)
          _detail(context, 'All doses taken today', color: g.successInk),
        if (doses.isNotEmpty)
          Wrap(
            spacing: 6,
            runSpacing: 4,
            children: [
              for (final d in doses.take(8))
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      d.isTaken
                          ? Icons.check_circle_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 13,
                      color: d.isTaken ? g.successInk : tint,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      at(d.timeSlot).replaceAll(':00', ''),
                      style: AscentTextStyles.caption.copyWith(
                        color: g.inkMuted,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
            ],
          ),
      ],
      action: next == null
          ? null
          : _QuickAction(
              key: const ValueKey('home_bento_medicine_take'),
              icon: Icons.check_rounded,
              tooltip: 'Take next dose',
              tint: tint,
              onPressed: () => context.open('/medicine'),
            ),
    );
  }
}

class _MoneyRow extends ConsumerWidget {
  const _MoneyRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final today = ref.watch(todaySpendingStreamProvider).value ?? 0;
    final month = ref.watch(currentMonthSpendingStreamProvider).value ?? 0;
    final budget = ref.watch(overallBudgetStreamProvider).value;
    final last = (ref.watch(recentTransactionsStreamProvider).value ?? const [])
        .where((t) => t.type == 'expense')
        .firstOrNull;
    final tint = BrandPalette.pillarTint('money', dark: g.isDark);
    final f = NumberFormat.compactCurrency(symbol: '₹', decimalDigits: 0);
    return _DayRow(
      key: const ValueKey('home_bento_money'),
      icon: Icons.account_balance_wallet_outlined,
      tint: tint,
      title: 'Spent',
      value: today == 0 ? 'Nothing today' : '${f.format(today)} today',
      route: '/money',
      semantics: 'Money: spent ${f.format(today)} today',
      details: [
        if (last != null)
          _detail(
            context,
            'Last: ${last.title} · ${f.format(last.amount)}',
            color: g.ink,
          ),
        _detail(
          context,
          budget != null && budget.monthlyLimit > 0
              ? 'This month ${f.format(month)} of ${f.format(budget.monthlyLimit)}'
              : 'This month ${f.format(month)}',
        ),
        if (budget != null && budget.monthlyLimit > 0)
          _bar(month / budget.monthlyLimit, tint),
      ],
      action: _QuickAction(
        key: const ValueKey('home_bento_money_add'),
        icon: Icons.add_rounded,
        tooltip: 'Add an expense',
        tint: tint,
        onPressed: () => context.open('/money'),
      ),
    );
  }
}

class _FocusRow extends ConsumerWidget {
  const _FocusRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final minutes = ref.watch(studyStreakProvider).todaySeconds ~/ 60;
    final tint = BrandPalette.pillarTint('focus', dark: g.isDark);
    final value = minutes == 0
        ? 'Not started'
        : minutes >= 60
        ? '${minutes ~/ 60}h ${minutes % 60}m today'
        : '${minutes}m today';
    return _DayRow(
      key: const ValueKey('home_bento_focus'),
      icon: Icons.timer_outlined,
      tint: tint,
      title: 'Focus',
      value: value,
      route: '/focus',
      semantics: 'Focus: $value',
      details: [
        _detail(
          context,
          minutes == 0
              ? 'A 25-minute session is a good start'
              : 'Keep it going with another session',
        ),
      ],
      action: _QuickAction(
        key: const ValueKey('home_bento_focus_start'),
        icon: Icons.play_arrow_rounded,
        tooltip: 'Start focus',
        tint: tint,
        onPressed: () => context.open('/focus'),
      ),
    );
  }
}
