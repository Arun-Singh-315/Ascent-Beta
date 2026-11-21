import 'dart:math' as math;

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

/// "Your day": one big glass card that closes the feed. Water, Medicine,
/// Money and Focus sit in a grid divided by hairline borders; an odd last
/// cell spans the full width.
class HomeLifeTiles extends ConsumerWidget {
  const HomeLifeTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final on = ref.watch(unlockedFeaturesProvider);
    final cells = <Widget>[
      if (on.contains(AscentFeature.care)) const _WaterTile(),
      if (on.contains(AscentFeature.care)) const _MedicineTile(),
      if (on.contains(AscentFeature.money)) const _MoneyTile(),
      if (on.contains(AscentFeature.focus)) const _FocusTile(),
    ];
    if (cells.isEmpty) return const SizedBox.shrink();
    final line = BorderSide(
      color: g.ink.withValues(alpha: g.isDark ? .14 : .10),
    );
    final oneColumn = MediaQuery.textScalerOf(context).scale(14) > 22;
    final rows = <List<Widget>>[];
    for (var i = 0; i < cells.length; i += oneColumn ? 1 : 2) {
      rows.add(
        cells.sublist(i, math.min(i + (oneColumn ? 1 : 2), cells.length)),
      );
    }
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
                AppSpace.s8,
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
            for (var r = 0; r < rows.length; r++)
              DecoratedBox(
                decoration: BoxDecoration(border: Border(top: line)),
                child: IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var c = 0; c < rows[r].length; c++)
                        Expanded(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              border: c > 0
                                  ? Border(left: line)
                                  : const Border(),
                            ),
                            child: rows[r][c],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _FocusTile extends ConsumerWidget {
  const _FocusTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final minutes = ref.watch(studyStreakProvider).todaySeconds ~/ 60;
    final tint = BrandPalette.pillarTint('focus', dark: g.isDark);
    return _Tile(
      key: const ValueKey('home_bento_focus'),
      route: '/focus',
      tint: tint,
      action: _QuickAction(
        key: const ValueKey('home_bento_focus_start'),
        icon: Icons.play_arrow_rounded,
        tooltip: 'Start focus',
        tint: tint,
        onPressed: () => context.open('/focus'),
      ),
      semantics: minutes == 0
          ? 'Focus: no session yet'
          : 'Focus: $minutes minutes today',
      child: _Stat(
        icon: Icons.timer_outlined,
        tint: tint,
        label: 'Focus',
        value: minutes == 0
            ? '–'
            : minutes >= 60
            ? '${minutes ~/ 60}h ${minutes % 60}m'
            : '${minutes}m',
        detail: minutes == 0 ? 'Start a session' : 'focused today',
      ),
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

class _WaterTile extends ConsumerStatefulWidget {
  const _WaterTile();

  @override
  ConsumerState<_WaterTile> createState() => _WaterTileState();
}

class _WaterTileState extends ConsumerState<_WaterTile> {
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
    final behind = hydrationBehindMl(
      now: DateTime.now(),
      drankMl: ml,
      goalMl: goal,
    );
    final tint = BrandPalette.pillarTint('hydration', dark: g.isDark);
    return _Tile(
      key: const ValueKey('home_bento_water'),
      route: '/hydration',
      tint: tint,
      semantics: 'Water: ${ml == 0 ? 'none yet' : '$ml ml'}',
      action: _QuickAction(
        key: const ValueKey('home_bento_water_add'),
        icon: Icons.add_rounded,
        tooltip: 'Log 250 ml',
        tint: tint,
        onPressed: _saving ? null : _log,
      ),
      child: _Stat(
        icon: Icons.water_drop_outlined,
        tint: tint,
        label: 'Water',
        value: ml == 0 ? '–' : '${(ml / 1000).toStringAsFixed(1)} L',
        detail: behind != null
            ? '$behind ml behind'
            : 'of ${(goal / 1000).toStringAsFixed(1)} L',
        nudge: behind != null,
        progress: goal <= 0 ? null : (ml / goal).clamp(0, 1).toDouble(),
      ),
    );
  }
}

class _MedicineTile extends ConsumerWidget {
  const _MedicineTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final doses = ref.watch(todayMedicineLogsStreamProvider).value ?? const [];
    final taken = doses.where((d) => d.isTaken).length;
    final pending = doses.where((d) => !d.isTaken).toList()
      ..sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
    final tint = BrandPalette.pillarTint('medicine', dark: g.isDark);
    String at(String slot) {
      final p = slot.split(':');
      if (p.length != 2) return slot;
      final t = DateTime(
        2000,
        1,
        1,
        int.tryParse(p[0]) ?? 0,
        int.tryParse(p[1]) ?? 0,
      );
      return DateFormat('h:mm a').format(t);
    }

    return _Tile(
      key: const ValueKey('home_bento_medicine'),
      route: '/medicine',
      tint: tint,
      action: pending.isEmpty
          ? null
          : _QuickAction(
              key: const ValueKey('home_bento_medicine_take'),
              icon: Icons.check_rounded,
              tooltip: 'Take next dose',
              tint: tint,
              onPressed: () => context.open('/medicine'),
            ),
      semantics: doses.isEmpty
          ? 'Medicine: nothing due'
          : 'Medicine: $taken of ${doses.length} taken',
      child: _Stat(
        icon: Icons.medication_outlined,
        tint: tint,
        label: 'Medicine',
        value: doses.isEmpty ? '–' : '$taken/${doses.length}',
        detail: doses.isEmpty
            ? 'Nothing due'
            : pending.isEmpty
            ? 'All taken'
            : 'Next ${at(pending.first.timeSlot)}',
      ),
    );
  }
}

class _MoneyTile extends ConsumerWidget {
  const _MoneyTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final spent = ref.watch(todaySpendingStreamProvider).value ?? 0;
    final tint = BrandPalette.pillarTint('money', dark: g.isDark);
    return _Tile(
      key: const ValueKey('home_bento_money'),
      route: '/money',
      tint: tint,
      action: _QuickAction(
        key: const ValueKey('home_bento_money_add'),
        icon: Icons.add_rounded,
        tooltip: 'Add an expense',
        tint: tint,
        onPressed: () => context.open('/money'),
      ),
      semantics: spent == 0 ? 'Money: nothing spent' : 'Money: spent $spent',
      child: _Stat(
        icon: Icons.account_balance_wallet_outlined,
        tint: tint,
        label: 'Spent',
        value: spent == 0 ? '–' : '₹${NumberFormat.compact().format(spent)}',
        detail: spent == 0 ? 'Nothing yet' : 'today',
      ),
    );
  }
}

// Building blocks -------------------------------------------------------------

/// One cell of the "Your day" grid: opens its screen, optional corner
/// action. The grid's hairlines frame it; the big card supplies the glass.
class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.route,
    required this.semantics,
    required this.child,
    this.action,
    this.tint,
  });
  final String route;
  final String semantics;
  final Widget child;
  final Widget? action;

  /// The cell's colour, washed softly in from its top corner.
  final Color? tint;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: semantics,
    child: InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.open(route);
      },
      child: Ink(
        decoration: tint == null
            ? null
            : BoxDecoration(
                gradient: RadialGradient(
                  center: AlignmentDirectional.topStart.resolve(
                    Directionality.of(context),
                  ),
                  radius: 1.2,
                  colors: [
                    tint!.withValues(alpha: context.glass.isDark ? .14 : .10),
                    tint!.withValues(alpha: 0),
                  ],
                ),
              ),
        child: Padding(
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Stack(
            children: [
              ExcludeSemantics(child: child),
              if (action != null)
                PositionedDirectional(top: -8, end: -8, child: action!),
            ],
          ),
        ),
      ),
    ),
  );
}

class _Stat extends StatelessWidget {
  const _Stat({
    required this.icon,
    required this.tint,
    required this.label,
    required this.value,
    required this.detail,
    this.nudge = false,
    this.progress,
  });
  final IconData icon;
  final Color tint;
  final String label, value, detail;
  final bool nudge;
  final double? progress;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _IconChip(icon: icon, tint: tint, size: 34),
        const SizedBox(height: AppSpace.s12),
        Text(
          label,
          style: AscentTextStyles.caption.copyWith(color: g.inkSecondary),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            style: AscentTextStyles.interfaceTitle.copyWith(
              color: g.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        Text(
          detail,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: AscentTextStyles.caption.copyWith(
            color: nudge ? g.warningInk : g.inkMuted,
            fontWeight: nudge ? FontWeight.w600 : null,
          ),
        ),
        if (progress != null) ...[
          const SizedBox(height: AppSpace.s8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 4,
              color: tint,
              backgroundColor: tint.withValues(alpha: .14),
            ),
          ),
        ],
      ],
    );
  }
}

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
