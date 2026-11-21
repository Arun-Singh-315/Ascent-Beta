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
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../hydration/hydration_pace.dart';
import '../../thought_wall/board/board_logic.dart' show displayContent;
import '../../today/add_activity_sheet.dart';
import '../home_customization_sheet.dart';

/// Home's one "Today" block: a bento of live tiles, one per switched-on
/// feature, so each feature appears on Home exactly once.
///
/// - Things is the big filled tile (progress ring, next two items).
/// - Water and Mind are outlined tiles beside it, each with a quick action.
/// - Medicine and Money sit below as an outlined pair.
///
/// Every tile opens its screen. Empty values show "–" with a one-word start
/// (CLAUDE.md §1, §2.6). The board is plain; tiles carry the colour.
class HomeTodayBento extends ConsumerWidget {
  const HomeTodayBento({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final on = ref.watch(unlockedFeaturesProvider);
    final things = on.contains(AscentFeature.things);
    final care = on.contains(AscentFeature.care);
    final mind = on.contains(AscentFeature.mind);
    final money = on.contains(AscentFeature.money);
    if (!things && !care && !mind && !money) return const SizedBox.shrink();

    final side = [if (care) const _WaterTile(), if (mind) const _MindTile()];
    final bottom = [
      if (care) const _MedicineTile(),
      if (money) const _MoneyTile(),
    ];
    const gap = AppSpace.s12;
    final largeText = MediaQuery.textScalerOf(context).scale(14) > 22;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s8,
        AppSpace.s16,
        AppSpace.s20,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
                  header: true,
                  child: Text(
                    'Today',
                    style: AscentTextStyles.homeTitle.copyWith(color: g.ink),
                  ),
                ),
              ),
              Text(
                DateFormat('EEE d MMM').format(DateTime.now()),
                style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
              ),
              IconButton(
                key: const ValueKey('home_customize'),
                tooltip: 'Customize Home',
                icon: Icon(Icons.tune_rounded, size: 20, color: g.inkMuted),
                onPressed: () => showHomeCustomization(context),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s4),
          if (things && side.isNotEmpty && !largeText)
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Expanded(flex: 3, child: _ThingsTile()),
                  const SizedBox(width: gap),
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < side.length; i++) ...[
                          if (i > 0) const SizedBox(height: gap),
                          Expanded(child: side[i]),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            )
          else ...[
            if (things) const _ThingsTile(),
            for (final t in side) ...[
              if (things || t != side.first) const SizedBox(height: gap),
              t,
            ],
          ],
          if (bottom.isNotEmpty) ...[
            const SizedBox(height: gap),
            if (largeText)
              for (var i = 0; i < bottom.length; i++) ...[
                if (i > 0) const SizedBox(height: gap),
                bottom[i],
              ]
            else
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    for (var i = 0; i < bottom.length; i++) ...[
                      if (i > 0) const SizedBox(width: gap),
                      Expanded(child: bottom[i]),
                    ],
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }
}

// Tiles -----------------------------------------------------------------------

class _ThingsTile extends ConsumerWidget {
  const _ThingsTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final items = ref.watch(todayActivitiesProvider).value ?? const [];
    final today = items.where(
      (a) => a.plannedDate != null || a.isDailyStanding,
    );
    final total = today.length;
    final done = today
        .where((a) => a.status == TodayActivityStatus.done)
        .length;
    final next =
        today.where((a) => a.status != TodayActivityStatus.done).toList()
          ..sort((a, b) {
            final at = a.scheduledTime, bt = b.scheduledTime;
            if (at == null && bt == null) return 0;
            if (at == null) return 1;
            if (bt == null) return -1;
            return at.compareTo(bt);
          });
    final tint = BrandPalette.pillarTint('things', dark: g.isDark);
    final progress = total == 0 ? 0.0 : done / total;

    return _Tile(
      key: const ValueKey('home_bento_things'),
      filled: true,
      route: '/things',
      footer: Align(
        alignment: AlignmentDirectional.centerStart,
        child: TextButton.icon(
          key: const ValueKey('home_bento_things_add'),
          onPressed: () => AddActivitySheet.show(context),
          icon: const Icon(Icons.add_rounded, size: 18),
          label: const Text('Add a thing'),
        ),
      ),
      semantics: total == 0
          ? 'Things: nothing planned. Plan your day'
          : 'Things: $done of $total done',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconChip(icon: Icons.checklist_rounded, tint: tint),
              const Spacer(),
              SizedBox(
                width: 40,
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CircularProgressIndicator(
                      value: progress,
                      strokeWidth: 4,
                      strokeCap: StrokeCap.round,
                      color: progress == 1 ? g.successInk : tint,
                      backgroundColor: tint.withValues(alpha: .14),
                    ),
                    if (progress == 1)
                      Icon(Icons.check_rounded, size: 18, color: g.successInk),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Text(
            'Things',
            style: AscentTextStyles.caption.copyWith(color: g.inkSecondary),
          ),
          Text(
            total == 0
                ? 'Plan your day'
                : done == total
                ? 'All done'
                : '${total - done} left',
            style: AscentTextStyles.interfaceTitle.copyWith(
              color: g.ink,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
          const SizedBox(height: AppSpace.s8),
          if (next.isEmpty)
            Text(
              total == 0
                  ? 'Add one thing and it shows here.'
                  : 'Nice work. Nothing left today.',
              style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
            )
          else
            for (final a in next.take(2))
              Padding(
                padding: const EdgeInsets.only(top: AppSpace.s4),
                child: Row(
                  children: [
                    Icon(Icons.circle_outlined, size: 14, color: g.inkMuted),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text(
                        a.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AscentTextStyles.bodyMedium.copyWith(
                          color: g.ink,
                        ),
                      ),
                    ),
                    if (a.scheduledTime != null) ...[
                      const SizedBox(width: AppSpace.s4),
                      Text(
                        DateFormat('h:mm a').format(a.scheduledTime!),
                        style: AscentTextStyles.caption.copyWith(
                          color: g.inkMuted,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
        ],
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
      semantics: 'Water: ${ml == 0 ? 'none yet' : '$ml ml'}',
      action: _QuickAction(
        key: const ValueKey('home_bento_water_add'),
        icon: Icons.add_rounded,
        tooltip: 'Log 250 ml',
        tint: tint,
        onPressed: _saving ? null : _log,
      ),
      child: _Stat(
        icon: Icons.water_drop_rounded,
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

class _MindTile extends ConsumerWidget {
  const _MindTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final count = ref.watch(todayThoughtsCountStreamProvider).value ?? 0;
    final latest =
        (ref.watch(recentThoughtsStreamProvider).value ?? const []).firstOrNull;
    final tint = BrandPalette.pillarTint('mind', dark: g.isDark);
    final preview = latest == null
        ? 'Jot a thought'
        : displayContent(latest.content).trim().split('\n').first;
    return _Tile(
      key: const ValueKey('home_bento_mind'),
      route: '/thought-wall',
      semantics: 'Mind: $count today. $preview',
      action: _QuickAction(
        key: const ValueKey('home_bento_mind_add'),
        icon: Icons.edit_rounded,
        tooltip: 'Write a thought',
        tint: tint,
        onPressed: () => context.open('/thought-wall'),
      ),
      child: _Stat(
        icon: Icons.lightbulb_rounded,
        tint: tint,
        label: 'Mind',
        value: count == 0 ? '–' : '$count',
        detail: preview,
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
      semantics: doses.isEmpty
          ? 'Medicine: nothing due'
          : 'Medicine: $taken of ${doses.length} taken',
      child: _Stat(
        icon: Icons.medication_rounded,
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
      semantics: spent == 0 ? 'Money: nothing spent' : 'Money: spent $spent',
      child: _Stat(
        icon: Icons.account_balance_wallet_rounded,
        tint: tint,
        label: 'Spent',
        value: spent == 0 ? '–' : '₹${NumberFormat.compact().format(spent)}',
        detail: spent == 0 ? 'Nothing yet' : 'today',
      ),
    );
  }
}

// Building blocks -------------------------------------------------------------

/// One bento tile. Filled tiles are the solid card surface (shadow by day,
/// hairline by night); outlined tiles sit on the canvas with a crisp border.
class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.route,
    required this.semantics,
    required this.child,
    this.filled = false,
    this.action,
    this.footer,
  });
  final String route;
  final Widget? footer;
  final String semantics;
  final Widget child;
  final bool filled;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final radius = BorderRadius.circular(22);
    final border = Border.all(
      color: g.ink.withValues(alpha: g.isDark ? .16 : .12),
    );
    return Semantics(
      button: true,
      label: semantics,
      child: Material(
        type: MaterialType.transparency,
        borderRadius: radius,
        child: InkWell(
          borderRadius: radius,
          onTap: () {
            HapticFeedback.selectionClick();
            context.open(route);
          },
          child: Ink(
            // The fill sits in the same decoration as the shadow so the
            // shadow never shows through as a grey wash.
            decoration: BoxDecoration(
              color: filled ? g.surface : null,
              borderRadius: radius,
              border: filled && !g.isDark ? null : border,
              boxShadow: filled && !g.isDark
                  ? [
                      BoxShadow(
                        color: g.shadow.withValues(alpha: .10),
                        blurRadius: 12,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            padding: const EdgeInsets.all(AppSpace.s16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Stack(
                  children: [
                    ExcludeSemantics(child: child),
                    if (action != null)
                      PositionedDirectional(top: -6, end: -6, child: action!),
                  ],
                ),
                // spaceBetween pushes the footer down when the tile is
                // stretched beside others; in one column it simply follows.
                ?footer,
              ],
            ),
          ),
        ),
      ),
    );
  }
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

/// Rounded glyph in a softly tinted square (CLAUDE.md §3.3 icon tiles).
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
      color: tint.withValues(alpha: context.glass.isDark ? .18 : .12),
      borderRadius: BorderRadius.circular(size * .3),
    ),
    child: Icon(icon, size: size * .55, color: tint),
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
