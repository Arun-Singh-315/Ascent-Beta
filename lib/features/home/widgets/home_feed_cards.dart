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

// "Your day" -----------------------------------------------------------------

/// Today's focus sessions (for the Focus compartment).
final _todaySessionsProvider = StreamProvider.autoDispose<List<TimeSession>>((
  ref,
) {
  final now = DateTime.now();
  return ref
      .watch(timeSessionDaoProvider)
      .watchSessionsForDate(DateTime(now.year, now.month, now.day));
});

String _clock(DateTime t) => DateFormat('h:mm a').format(t).toLowerCase();

String _slot(String slot) {
  final p = slot.split(':');
  if (p.length != 2) return slot;
  return _clock(
    DateTime(2000, 1, 1, int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0),
  );
}

/// "Your day": one card split into bordered compartments. Small type, no
/// bars: the room goes to real detail (every dose, recent spending, the
/// last glass, today's sessions).
class HomeLifeTiles extends ConsumerWidget {
  const HomeLifeTiles({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final on = ref.watch(unlockedFeaturesProvider);
    final care = on.contains(AscentFeature.care);
    final money = on.contains(AscentFeature.money);
    final focus = on.contains(AscentFeature.focus);
    if (!care && !money && !focus) return const SizedBox.shrink();
    final pair = [if (care) const _WaterCell(), if (focus) const _FocusCell()];
    final sections = <Widget>[
      if (pair.isNotEmpty) _CellPair(cells: pair),
      if (care) const _MedicineSection(),
      if (money) const _MoneySection(),
    ];
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
        child: ClipRRect(
          borderRadius: AppGeometry.roundedr20,
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
                      style: AscentTextStyles.caption.copyWith(
                        color: g.inkMuted,
                      ),
                    ),
                  ],
                ),
              ),
              for (final section in sections) ...[
                Divider(height: 1, thickness: 1, color: g.line),
                section,
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Two compartments side by side with a hairline between them; stacked
/// when the screen is narrow or the text is large.
class _CellPair extends StatelessWidget {
  const _CellPair({required this.cells});
  final List<Widget> cells;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    if (cells.length == 1) return cells.single;
    return LayoutBuilder(
      builder: (context, box) {
        final side =
            box.maxWidth >= 300 &&
            MediaQuery.textScalerOf(context).scale(1) < 1.45;
        if (!side) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              cells[0],
              Divider(height: 1, thickness: 1, color: g.line),
              cells[1],
            ],
          );
        }
        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: cells[0]),
              VerticalDivider(width: 1, thickness: 1, color: g.line),
              Expanded(child: cells[1]),
            ],
          ),
        );
      },
    );
  }
}

/// A compartment: small label row (icon, label, optional action), then
/// content. The whole compartment opens its screen.
class _Compartment extends StatelessWidget {
  const _Compartment({
    super.key,
    required this.icon,
    required this.label,
    required this.route,
    required this.semantics,
    required this.body,
    this.trailing,
    this.action,
  });
  final IconData icon;
  final String label, route, semantics;
  final String? trailing;
  final Widget? action;
  final List<Widget> body;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        context.open(route);
      },
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s16,
          AppSpace.s12,
          AppSpace.s8,
          AppSpace.s12,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(
              button: true,
              label: semantics,
              excludeSemantics: true,
              child: Row(
                children: [
                  Icon(icon, size: 16, color: g.inkSecondary),
                  const SizedBox(width: AppSpace.s6),
                  Text(
                    label,
                    maxLines: 1,
                    style: AscentTextStyles.caption.copyWith(
                      color: g.inkSecondary,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Expanded(
                    child: Text(
                      trailing ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.end,
                      style: AscentTextStyles.tabular(
                        AscentTextStyles.caption,
                      ).copyWith(color: g.inkMuted),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                ],
              ),
            ),
            ...body,
            ?action,
          ],
        ),
      ),
    );
  }
}

/// Main value of a compartment: Subhead, regular weight, tabular.
Widget _value(BuildContext context, String text) => Padding(
  padding: const EdgeInsets.only(top: AppSpace.s6, right: AppSpace.s8),
  child: Text(
    text,
    maxLines: 1,
    overflow: TextOverflow.ellipsis,
    style: AscentTextStyles.tabular(
      AscentTextStyles.listRowTitle,
    ).copyWith(color: context.glass.ink),
  ),
);

/// One small detail line under a value.
Widget _note(BuildContext context, String text, {Color? color}) => Padding(
  padding: const EdgeInsets.only(top: AppSpace.s2, right: AppSpace.s8),
  child: Text(
    text,
    maxLines: 2,
    overflow: TextOverflow.ellipsis,
    style: AscentTextStyles.caption.copyWith(
      color: color ?? context.glass.inkSecondary,
      fontWeight: FontWeight.w400,
    ),
  ),
);

/// A small outlined action under a compartment ("+ 250 ml", "Start").
class _SmallAction extends StatelessWidget {
  const _SmallAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Align(
      alignment: AlignmentDirectional.centerStart,
      child: Padding(
        padding: const EdgeInsets.only(top: AppSpace.s8),
        child: Semantics(
          button: true,
          label: label,
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 44),
              child: Center(
                widthFactor: 1,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s10,
                    vertical: AppSpace.s4,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: g.line),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(icon, size: 14, color: g.actionInk),
                      const SizedBox(width: AppSpace.s4),
                      Text(
                        label,
                        style: AscentTextStyles.caption.copyWith(
                          color: g.actionInk,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _WaterCell extends ConsumerStatefulWidget {
  const _WaterCell();

  @override
  ConsumerState<_WaterCell> createState() => _WaterCellState();
}

class _WaterCellState extends ConsumerState<_WaterCell> {
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
    final logs = ref.watch(todayWaterLogsStreamProvider).value ?? const [];
    final last = logs.isEmpty
        ? null
        : logs.map((l) => l.timestamp).reduce((a, b) => a.isAfter(b) ? a : b);
    final behind = hydrationBehindMl(
      now: DateTime.now(),
      drankMl: ml,
      goalMl: goal,
    );
    String l(int v) => (v / 1000).toStringAsFixed(1);
    final glasses = (ml / 250).floor();
    return _Compartment(
      key: const ValueKey('home_bento_water'),
      icon: Icons.water_drop_outlined,
      label: 'Water',
      route: '/hydration',
      semantics: 'Water: ${l(ml)} of ${l(goal)} litres',
      body: [
        _value(
          context,
          ml == 0 ? '– of ${l(goal)} L' : '${l(ml)} of ${l(goal)} L',
        ),
        _note(
          context,
          ml == 0
              ? 'Nothing logged yet'
              : [
                  '$glasses glass${glasses == 1 ? '' : 'es'}',
                  if (last != null) 'last ${_clock(last)}',
                ].join(' · '),
        ),
        if (behind != null)
          _note(context, '$behind ml behind pace', color: g.warningInk),
      ],
      action: _SmallAction(
        key: const ValueKey('home_bento_water_add'),
        icon: Icons.add_rounded,
        label: '250 ml',
        onPressed: _saving ? null : _log,
      ),
    );
  }
}

class _FocusCell extends ConsumerWidget {
  const _FocusCell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final minutes = ref.watch(studyStreakProvider).todaySeconds ~/ 60;
    final sessions =
        (ref.watch(_todaySessionsProvider).value ?? const [])
            .where((s) => s.durationSeconds >= 60)
            .toList()
          ..sort((a, b) => b.startedAt.compareTo(a.startedAt));
    final value = minutes == 0
        ? 'Not started'
        : minutes >= 60
        ? '${minutes ~/ 60}h ${minutes % 60}m today'
        : '${minutes}m today';
    final n = sessions.length;
    return _Compartment(
      key: const ValueKey('home_bento_focus'),
      icon: Icons.timer_outlined,
      label: 'Focus',
      route: '/focus',
      semantics: 'Focus: $value',
      body: [
        _value(context, value),
        _note(
          context,
          n == 0
              ? 'A 25-minute session is a good start'
              : '$n session${n == 1 ? '' : 's'} · last: ${sessions.first.label}',
        ),
      ],
      action: _SmallAction(
        key: const ValueKey('home_bento_focus_start'),
        icon: Icons.play_arrow_rounded,
        label: 'Start',
        onPressed: () => context.open('/focus'),
      ),
    );
  }
}

/// Every dose today: name, dosage, time, and taken or due, with Take on
/// the next one.
class _MedicineSection extends ConsumerWidget {
  const _MedicineSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final doses = [
      ...(ref.watch(todayMedicineLogsStreamProvider).value ?? const []),
    ]..sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
    final meds = {
      for (final m
          in ref.watch(activeMedicinesStreamProvider).value ?? const [])
        m.id: m,
    };
    final taken = doses.where((d) => d.isTaken).length;
    final next = doses.where((d) => !d.isTaken).firstOrNull;
    const cap = 6;
    return _Compartment(
      key: const ValueKey('home_bento_medicine'),
      icon: Icons.medication_outlined,
      label: 'Medicine',
      trailing: doses.isEmpty ? null : '$taken of ${doses.length} taken',
      route: '/medicine',
      semantics: doses.isEmpty
          ? 'Medicine: nothing due today'
          : 'Medicine: $taken of ${doses.length} taken',
      body: [
        if (doses.isEmpty)
          _note(context, 'Nothing due today')
        else
          for (final d in doses.take(cap))
            _DoseRow(
              key: ValueKey('home_dose_${d.id}'),
              dose: d,
              medicine: meds[d.medicineId],
              isNext: d == next,
            ),
        if (doses.length > cap)
          _note(context, '+${doses.length - cap} more', color: g.inkMuted),
      ],
    );
  }
}

class _DoseRow extends ConsumerWidget {
  const _DoseRow({
    super.key,
    required this.dose,
    required this.medicine,
    required this.isNext,
  });
  final MedicineLog dose;
  final Medicine? medicine;
  final bool isNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final name = medicine?.name ?? 'Medicine';
    final dosage = medicine?.dosage.trim() ?? '';
    final when = dose.isTaken && dose.takenAt != null
        ? 'taken ${_clock(dose.takenAt!)}'
        : _slot(dose.timeSlot);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 36),
      child: Row(
        children: [
          Icon(
            dose.isTaken
                ? Icons.check_circle_outline_rounded
                : Icons.radio_button_unchecked_rounded,
            size: 16,
            color: dose.isTaken ? g.successInk : g.inkMuted,
          ),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Text(
              dosage.isEmpty ? name : '$name · $dosage',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: AscentTextStyles.supportingText.copyWith(
                color: dose.isTaken ? g.inkSecondary : g.ink,
              ),
            ),
          ),
          const SizedBox(width: AppSpace.s8),
          Text(
            when,
            style: AscentTextStyles.tabular(
              AscentTextStyles.caption,
            ).copyWith(color: g.inkMuted, fontWeight: FontWeight.w400),
          ),
          if (isNext)
            AscentButton.ghost(
              key: const ValueKey('home_bento_medicine_take'),
              label: 'Take',
              compact: true,
              onPressed: () async {
                HapticFeedback.lightImpact();
                final service = ref.read(medicineServiceProvider);
                await service.toggleDose(dose.id, true);
                if (context.mounted) {
                  AscentSnackBar.show(
                    context,
                    message: '$name taken',
                    actionLabel: 'Undo',
                    onAction: () => service.toggleDose(dose.id, false),
                  );
                }
              },
            )
          else
            const SizedBox(width: AppSpace.s8),
        ],
      ),
    );
  }
}

/// Spending today and this month, then the latest transactions.
class _MoneySection extends ConsumerWidget {
  const _MoneySection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final today = ref.watch(todaySpendingStreamProvider).value ?? 0;
    final month = ref.watch(currentMonthSpendingStreamProvider).value ?? 0;
    final budget = ref.watch(overallBudgetStreamProvider).value;
    final recent =
        (ref.watch(recentTransactionsStreamProvider).value ??
                const <FinanceTransaction>[])
            .take(3)
            .toList();
    final f = NumberFormat.compactCurrency(symbol: '₹', decimalDigits: 0);
    final exact = NumberFormat.currency(
      locale: 'en_IN',
      symbol: '₹',
      decimalDigits: 0,
    );
    final limit = budget != null && budget.monthlyLimit > 0
        ? budget.monthlyLimit
        : null;
    final now = DateTime.now();
    String when(DateTime d) =>
        d.year == now.year && d.month == now.month && d.day == now.day
        ? _clock(d)
        : DateFormat('d MMM').format(d);
    return _Compartment(
      key: const ValueKey('home_bento_money'),
      icon: Icons.account_balance_wallet_outlined,
      label: 'Money',
      trailing: limit == null
          ? 'Month ${f.format(month)}'
          : 'Month ${f.format(month)} of ${f.format(limit)}',
      route: '/money',
      semantics: 'Money: spent ${f.format(today)} today',
      body: [
        _value(
          context,
          today == 0 ? '– spent today' : '${exact.format(today)} spent today',
        ),
        if (limit != null && month > limit)
          _note(context, 'Over this month’s budget', color: g.warningInk),
        if (recent.isEmpty)
          _note(context, 'No transactions yet')
        else ...[
          const SizedBox(height: AppSpace.s6),
          for (final t in recent)
            ConstrainedBox(
              key: ValueKey('home_txn_${t.id}'),
              constraints: const BoxConstraints(minHeight: 30),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      t.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AscentTextStyles.supportingText.copyWith(
                        color: g.ink,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  Text(
                    when(t.date),
                    style: AscentTextStyles.caption.copyWith(
                      color: g.inkMuted,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(width: AppSpace.s12),
                  Text(
                    '${t.type == 'income' ? '+' : ''}${exact.format(t.amount)}',
                    style:
                        AscentTextStyles.tabular(
                          AscentTextStyles.supportingText,
                        ).copyWith(
                          color: t.type == 'income' ? g.successInk : g.ink,
                        ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                ],
              ),
            ),
        ],
      ],
      action: _SmallAction(
        key: const ValueKey('home_bento_money_add'),
        icon: Icons.add_rounded,
        label: 'Expense',
        onPressed: () => context.open('/money'),
      ),
    );
  }
}
