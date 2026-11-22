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
import '../../../core/utils/human_time.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import 'activity_actions.dart';
import '../../capture/capture_sheet.dart';
import '../../hydration/hydration_pace.dart';
import '../../thought_wall/board/board_logic.dart' show displayContent;
import '../../thought_wall/board/thought_lines.dart';

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
            strokeWidth: 2,
            strokeCap: StrokeCap.round,
            color: progress == 1 ? g.successInk : g.actionInk,
            backgroundColor: g.line,
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
        if (pending.isEmpty)
          _EmptyRow(
            key: const ValueKey('home_things_empty'),
            text: total == 0 ? 'Your day is wide open' : 'All clear',
            onAdd: () => showCaptureSheet(context),
          ),
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

/// Mind: the latest thoughts as quiet bubbles. New thoughts come in
/// through the Capture card at the top of Home.
class HomeMindCard extends ConsumerWidget {
  const HomeMindCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
            child: _ThoughtBubble(
              key: ValueKey('home_thought_${t.id}'),
              thought: t,
            ),
          ),
        if (recent.isEmpty)
          _EmptyRow(
            key: const ValueKey('home_mind_empty'),
            text: 'Nothing on your mind yet',
            onAdd: () => showCaptureSheet(context),
          ),
      ],
    );
  }
}

/// "Just now", "12 min ago", then "Today at 9:10 AM" style.
String _ago(DateTime at) {
  final mins = DateTime.now().difference(at).inMinutes;
  if (mins < 1) return 'Just now';
  if (mins < 60) return '$mins min ago';
  final s = humanWhen(at);
  return '${s[0].toUpperCase()}${s.substring(1)}';
}

/// A thought as a quiet speech bubble: hairline outline, one squared
/// corner like a chat bubble, the words first and a small "when" below.
class _ThoughtBubble extends StatelessWidget {
  const _ThoughtBubble({super.key, required this.thought});
  final Thought thought;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    const radius = BorderRadius.only(
      topLeft: AppGeometry.radiusr18,
      topRight: AppGeometry.radiusr18,
      bottomRight: AppGeometry.radiusr18,
      bottomLeft: AppGeometry.radiusr4,
    );
    final content = displayContent(thought.content).trim();
    final lines = parseThoughtLines(content);
    final shown = lines.take(3).toList();
    final progress = progressLabel(content);
    final spoken = lines.map((l) => l.text).join(', ');
    return Semantics(
      button: true,
      label: 'Thought: $spoken',
      excludeSemantics: true,
      // Its own Material, so the outline and ripple paint above the card's
      // surface instead of under it.
      child: Material(
        color: g.surface,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: BorderSide(color: g.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () => context.open('/thought-wall?thought=${thought.id}'),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s14,
              AppSpace.s10,
              AppSpace.s14,
              AppSpace.s8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in shown)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s2),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (l.isItem) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: AppSpace.s3),
                            child: Icon(
                              l.isDone
                                  ? Icons.check_circle_outline_rounded
                                  : Icons.radio_button_unchecked_rounded,
                              size: 16,
                              color: l.isDone ? g.successInk : g.inkMuted,
                            ),
                          ),
                          const SizedBox(width: AppSpace.s8),
                        ],
                        Expanded(
                          child: Text(
                            l.text,
                            maxLines: shown.length == 1 ? 3 : 1,
                            overflow: TextOverflow.ellipsis,
                            style: AscentTextStyles.body.copyWith(
                              color: l.isDone ? g.inkSecondary : g.ink,
                              height: 1.35,
                              decoration: l.isDone
                                  ? TextDecoration.lineThrough
                                  : null,
                              decorationColor: g.inkSecondary,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: AppSpace.s2),
                Text(
                  [
                    if (thought.isPinned) 'Pinned',
                    if (progress != null) '$progress done',
                    if (lines.length > shown.length)
                      '+${lines.length - shown.length} more',
                    _ago(thought.createdAt),
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.caption.copyWith(
                    color: g.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One quiet line for an empty card: what's missing and an Add action.
class _EmptyRow extends StatelessWidget {
  const _EmptyRow({super.key, required this.text, required this.onAdd});
  final String text;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Row(
      children: [
        Expanded(
          child: Text(
            text,
            style: AscentTextStyles.body.copyWith(color: g.inkSecondary),
          ),
        ),
        AscentButton.ghost(label: 'Add', compact: true, onPressed: onAdd),
      ],
    );
  }
}

/// A hero feed card: 1 px bordered surface, a header that opens the
/// screen, then content.
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
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: context.glass.surface,
        borderRadius: AppGeometry.roundedr20,
        border: Border.all(color: context.glass.line),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppSpace.s16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            header,
            const SizedBox(height: AppSpace.s12),
            ...children,
          ],
        ),
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
              _IconChip(icon: icon, size: 40),
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

/// Monochrome line icon in a thin 1 px ring: calm, and the same on every
/// card. Colour is kept for meaning (warnings, done), never decoration.
class _IconChip extends StatelessWidget {
  const _IconChip({required this.icon, this.size = 40});
  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: g.line),
      ),
      child: Icon(icon, size: size * .48, color: g.inkSecondary),
    );
  }
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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: context.glass.line),
              ),
              child: Icon(icon, size: 18, color: context.glass.actionInk),
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
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: g.surface,
          borderRadius: AppGeometry.roundedr20,
          border: Border.all(color: g.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s16,
                AppSpace.s16,
                AppSpace.s16,
                AppSpace.s12,
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
              Divider(height: 1, thickness: 1, color: g.line),
              rows[i],
            ],
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
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s16,
            AppSpace.s16,
            AppSpace.s8,
            AppSpace.s16,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconChip(icon: icon, size: 36),
              const SizedBox(width: AppSpace.s16),
              Expanded(
                child: ExcludeSemantics(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Label above a large value, then roomy detail lines.
                      Text(
                        title,
                        style: AscentTextStyles.caption.copyWith(
                          color: g.inkMuted,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        value,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AscentTextStyles.tabular(
                          AscentTextStyles.body,
                        ).copyWith(color: g.ink),
                      ),
                      for (final d in details) ...[
                        const SizedBox(height: AppSpace.s6),
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
    color: color ?? context.glass.inkSecondary,
    fontWeight: strong ? FontWeight.w500 : FontWeight.w400,
  ),
);

/// A thin progress line in the one action colour on a hairline track.
Widget _bar(BuildContext context, double value) {
  final g = context.glass;
  return ClipRRect(
    borderRadius: BorderRadius.circular(999),
    child: TweenAnimationBuilder<double>(
      tween: Tween(end: value.clamp(0, 1).toDouble()),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, v, _) => LinearProgressIndicator(
        value: v,
        minHeight: 3,
        color: g.actionInk,
        backgroundColor: g.line,
      ),
    ),
  );
}

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
        _bar(context, goal <= 0 ? 0 : ml / goal),
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
                          ? Icons.check_circle_outline_rounded
                          : Icons.radio_button_unchecked_rounded,
                      size: 13,
                      color: d.isTaken ? g.successInk : g.inkMuted,
                    ),
                    const SizedBox(width: 2),
                    Text(
                      at(d.timeSlot).replaceAll(':00', ''),
                      style: AscentTextStyles.caption.copyWith(
                        color: g.inkMuted,
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
          _bar(context, month / budget.monthlyLimit),
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
