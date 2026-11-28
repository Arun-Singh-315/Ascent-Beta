import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/app_navigation.dart';
import '../../../app/theme/ascent_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/features/feature_registry.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../shared/widgets/ascent_icon.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../../shared/widgets/ascent_small_button.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../../shared/widgets/undo_snackbar.dart';
import '../../today/models/things_sections.dart';
import '../../today/things_providers.dart';
import '../model/home_things.dart';
import '../widgets/activity_actions.dart';
import '../widgets/activity_composer.dart';
import 'home_region.dart';

enum _View { today, upcoming, anytime }

/// Home v7 Things: Today / Upcoming / Anytime, today split into Morning,
/// Afternoon and Evening groups that open and close, a red line for
/// overdue things, multi-select, and a quick add at the bottom.
class HomeThingsSection extends ConsumerStatefulWidget {
  const HomeThingsSection({super.key});

  @override
  ConsumerState<HomeThingsSection> createState() => _HomeThingsSectionState();
}

class _HomeThingsSectionState extends ConsumerState<HomeThingsSection> {
  _View _view = _View.today;
  Set<DayPart>? _open;
  bool _selecting = false;
  final _picked = <String>{};

  void _toggleSelect() {
    HapticFeedback.selectionClick();
    setState(() {
      _selecting = !_selecting;
      _picked.clear();
    });
  }

  void _pick(TodayActivityItem a) {
    HapticFeedback.selectionClick();
    setState(
      () => _picked.contains(a.id) ? _picked.remove(a.id) : _picked.add(a.id),
    );
  }

  List<TodayActivityItem> _pickedItems(List<TodayActivityItem> all) => [
    for (final a in all)
      if (_picked.contains(a.id)) a,
  ];

  Future<void> _completePicked(List<TodayActivityItem> items) async {
    final dao = ref.read(taskDaoProvider);
    final undos = [];
    for (final a in items) {
      if (a.linkedTaskId == null ||
          a.isLockedUntilScheduled ||
          a.status == TodayActivityStatus.done) {
        continue;
      }
      final u = await dao.completeWithUndo(a.linkedTaskId!);
      if (u != null) undos.add(u);
    }
    if (!mounted) return;
    _finishSelection();
    if (undos.isEmpty) {
      AscentSnackBar.show(context, message: 'Nothing could be completed.');
      return;
    }
    showUndoSnackbar(
      context,
      message: '${undos.length} ${undos.length == 1 ? 'thing' : 'things'} done',
      onUndo: () async {
        for (final u in undos.reversed) {
          await dao.undoCompletion(u);
        }
      },
    );
  }

  Future<void> _movePicked(List<TodayActivityItem> items) async {
    final dao = ref.read(taskDaoProvider);
    final now = DateTime.now();
    final moved = await dao.moveManyToDay([
      for (final a in items)
        if (a.linkedTaskId != null && !a.isDailyStanding) a.linkedTaskId!,
    ], DateTime(now.year, now.month, now.day + 1));
    if (!mounted) return;
    _finishSelection();
    if (moved.isEmpty) {
      AscentSnackBar.show(context, message: 'Nothing could be moved.');
      return;
    }
    showUndoSnackbar(
      context,
      message:
          'Moved ${moved.length} ${moved.length == 1 ? 'thing' : 'things'} to tomorrow',
      onUndo: () => dao.restorePlannedDays(moved),
    );
  }

  Future<void> _deletePicked(List<TodayActivityItem> items) async {
    HapticFeedback.mediumImpact();
    final container = ProviderScope.containerOf(context, listen: false);
    final dao = ref.read(taskDaoProvider);
    for (final a in items) {
      await deleteTodayActivity(container, a);
    }
    if (!mounted) return;
    _finishSelection();
    showUndoSnackbar(
      context,
      message:
          'Deleted ${items.length} ${items.length == 1 ? 'thing' : 'things'}',
      onUndo: () async {
        for (final a in items) {
          if (a.linkedTaskId != null) {
            await dao.restoreDeletedTask(a.linkedTaskId!);
          }
          await container
              .read(dismissedTodayActivityIdsProvider.notifier)
              .unDismissActivityId(a.id);
        }
      },
    );
  }

  void _finishSelection() => setState(() {
    _selecting = false;
    _picked.clear();
  });

  Future<void> _moveOverdue(HomeThingsToday t) async {
    final dao = ref.read(taskDaoProvider);
    final now = DateTime.now();
    final moved = await dao.moveManyToDay(
      t.movableOverdue,
      DateTime(now.year, now.month, now.day),
    );
    if (!mounted || moved.isEmpty) return;
    showUndoSnackbar(
      context,
      message:
          'Moved ${moved.length} ${moved.length == 1 ? 'thing' : 'things'} to today',
      onUndo: () => dao.restorePlannedDays(moved),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(unlockedFeaturesProvider).contains(AscentFeature.things)) {
      return const SizedBox.shrink();
    }
    final tk = context.tokens;
    final items = ref.watch(todayActivitiesProvider).value ?? const [];
    final today = buildHomeThingsToday(items);
    final open = _open ?? {?defaultOpenPart(today.parts, DateTime.now())};

    final List<TodayActivityItem> shown;
    final Widget body;
    switch (_view) {
      case _View.today:
        shown = [for (final p in today.parts) ...p.$2];
        body = _TodayBody(
          today: today,
          open: open,
          onToggle: (p) {
            HapticFeedback.selectionClick();
            setState(() {
              final next = {...open};
              next.contains(p) ? next.remove(p) : next.add(p);
              _open = next;
            });
          },
          onMoveOverdue: () => _moveOverdue(today),
          row: _row,
        );
      case _View.upcoming:
        final up = ref.watch(upcomingThingsProvider).value ?? const [];
        shown = up.take(4).toList();
        body = _ListBody(
          items: shown,
          more: up.length - shown.length,
          labelFor: (a) => a.plannedDate == null
              ? null
              : upcomingDayLabel(a.plannedDate!, DateTime.now()),
          empty: 'Nothing planned after today',
          moreRoute: '/things?tab=upcoming',
          row: _row,
        );
      case _View.anytime:
        final any = anytimeThings(items);
        shown = any.take(4).toList();
        body = _ListBody(
          items: shown,
          more: any.length - shown.length,
          labelFor: (_) => null,
          empty: 'To-dos with no date wait here',
          moreRoute: '/things?tab=anytime',
          row: _row,
        );
    }
    final picked = _pickedItems(shown);

    return HomeRegion(
      key: const ValueKey('home_things_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeRegionHeader(
            glyph: AscentGlyph.things,
            title: 'Things',
            count: today.total == 0 ? null : '${today.done} of ${today.total}',
            trailing: AscentSmallButton.ghost(
              key: const ValueKey('home_things_select'),
              label: _selecting ? 'Cancel' : 'Select',
              onPressed: shown.isEmpty && !_selecting ? null : _toggleSelect,
            ),
          ),
          const SizedBox(height: 4),
          AscentSegmentedControl<_View>(
            segments: const [
              AscentSegment(value: _View.today, label: 'Today'),
              AscentSegment(value: _View.upcoming, label: 'Upcoming'),
              AscentSegment(value: _View.anytime, label: 'Anytime'),
            ],
            selected: _view,
            slim: true,
            onChanged: (v) => setState(() {
              _view = v;
              _picked.clear();
            }),
          ),
          const SizedBox(height: 4),
          body,
          if (_selecting)
            Container(
              key: const ValueKey('home_things_select_bar'),
              margin: const EdgeInsets.only(top: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                border: Border.all(color: tk.separator),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${picked.length} selected',
                      style: AscentTextStyles.label.copyWith(
                        color: tk.labelSecondary,
                      ),
                    ),
                  ),
                  AscentSmallButton.filled(
                    label: 'Done',
                    onPressed: picked.isEmpty
                        ? null
                        : () => _completePicked(picked),
                  ),
                  const SizedBox(width: 6),
                  AscentSmallButton(
                    label: 'Tomorrow',
                    semanticLabel: 'Move to tomorrow',
                    onPressed: picked.isEmpty
                        ? null
                        : () => _movePicked(picked),
                  ),
                  const SizedBox(width: 6),
                  AscentSmallButton(
                    label: 'Delete',
                    color: tk.danger,
                    onPressed: picked.isEmpty
                        ? null
                        : () => _deletePicked(picked),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 10),
          ActivityComposer(
            defaultDay: _view == _View.upcoming
                ? DateTime(
                    DateTime.now().year,
                    DateTime.now().month,
                    DateTime.now().day + 1,
                  )
                : null,
          ),
        ],
      ),
    );
  }

  Widget _row(TodayActivityItem a, {String? label}) => _ThingRow(
    key: ValueKey('home_thing_${a.id}'),
    item: a,
    label: label,
    selecting: _selecting,
    picked: _picked.contains(a.id),
    onCheck: () {
      if (_selecting) return _pick(a);
      if (a.status == TodayActivityStatus.done) return;
      HapticFeedback.lightImpact();
      completeActivityWithUndo(context, ref, a);
    },
    onTap: () => _selecting ? _pick(a) : showActivityActions(context, ref, a),
  );
}

typedef _RowBuilder = Widget Function(TodayActivityItem item, {String? label});

class _TodayBody extends StatelessWidget {
  const _TodayBody({
    required this.today,
    required this.open,
    required this.onToggle,
    required this.onMoveOverdue,
    required this.row,
  });

  final HomeThingsToday today;
  final Set<DayPart> open;
  final ValueChanged<DayPart> onToggle;
  final VoidCallback onMoveOverdue;
  final _RowBuilder row;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final n = today.overdue.length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (n > 0)
          Row(
            key: const ValueKey('home_things_overdue'),
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: t.danger,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '$n overdue from earlier',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.meta.copyWith(
                    color: t.danger,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              if (today.movableOverdue.isNotEmpty)
                AscentSmallButton.ghost(
                  label: 'Move to today',
                  onPressed: onMoveOverdue,
                )
              else
                AscentSmallButton.ghost(
                  label: 'Review',
                  onPressed: () => context.open('/things'),
                ),
            ],
          ),
        if (today.parts.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Nothing planned for today yet. Add one thing below.',
              key: const ValueKey('home_things_empty'),
              style: AscentTextStyles.row.copyWith(color: t.labelSecondary),
            ),
          ),
        for (final (part, list) in today.parts)
          _Group(
            key: ValueKey('home_things_group_${part.name}'),
            title: part == DayPart.anytime ? 'Any time today' : part.label,
            count: list.length,
            done: list
                .where((a) => a.status == TodayActivityStatus.done)
                .length,
            open: open.contains(part),
            onToggle: () => onToggle(part),
            children: [for (final a in list) row(a)],
          ),
      ],
    );
  }
}

class _ListBody extends StatelessWidget {
  const _ListBody({
    required this.items,
    required this.more,
    required this.labelFor,
    required this.empty,
    required this.moreRoute,
    required this.row,
  });

  final List<TodayActivityItem> items;
  final int more;
  final String? Function(TodayActivityItem) labelFor;
  final String empty;
  final String moreRoute;
  final _RowBuilder row;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text(
          empty,
          style: AscentTextStyles.row.copyWith(color: t.labelSecondary),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final a in items) row(a, label: labelFor(a)),
        if (more > 0)
          Align(
            alignment: Alignment.centerLeft,
            child: AscentSmallButton.ghost(
              label: 'Show all ${items.length + more}',
              onPressed: () => context.open(moreRoute),
            ),
          ),
      ],
    );
  }
}

/// A part of the day that opens and closes with a spring-like ease.
class _Group extends StatelessWidget {
  const _Group({
    super.key,
    required this.title,
    required this.count,
    required this.done,
    required this.open,
    required this.onToggle,
    required this.children,
  });

  final String title;
  final int count, done;
  final bool open;
  final VoidCallback onToggle;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final reduce = MediaQuery.disableAnimationsOf(context);
    final duration = Duration(milliseconds: reduce ? 0 : 300);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: t.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: open,
            child: InkWell(
              onTap: onToggle,
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: 44),
                child: Row(
                  children: [
                    Text(
                      title,
                      style: AscentTextStyles.label.copyWith(color: t.label),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      done == count ? 'All done' : '$done of $count',
                      style: AscentTextStyles.meta.copyWith(
                        color: done == count ? t.success : t.labelTertiary,
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: open ? -0.25 : 0.25,
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
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: children,
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _ThingRow extends StatelessWidget {
  const _ThingRow({
    super.key,
    required this.item,
    required this.selecting,
    required this.picked,
    required this.onCheck,
    required this.onTap,
    this.label,
  });

  final TodayActivityItem item;
  final bool selecting, picked;
  final VoidCallback onCheck, onTap;

  /// A day label shown before the time (Upcoming).
  final String? label;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final done = item.status == TodayActivityStatus.done;
    final at = item.scheduledTime;
    final meta = [
      ?label,
      if (at != null) DateFormat('h:mm a').format(at),
    ].join(' · ');
    final filled = selecting ? picked : done;
    final fill = selecting ? t.actionFill : t.success;
    return InkWell(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(top: BorderSide(color: t.lineFaint)),
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Row(
            children: [
              Semantics(
                button: true,
                checked: filled,
                label: selecting
                    ? 'Select ${item.title}'
                    : done
                    ? '${item.title}, done'
                    : 'Complete ${item.title}',
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onCheck,
                  child: SizedBox(
                    width: 32,
                    height: 44,
                    child: Center(
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 19,
                        height: 19,
                        decoration: BoxDecoration(
                          color: filled ? fill : Colors.transparent,
                          borderRadius: BorderRadius.circular(
                            selecting ? 5 : 10,
                          ),
                          border: Border.all(
                            color: filled ? fill : t.labelTertiary,
                            width: 2,
                          ),
                        ),
                        child: filled
                            ? AscentIcon(
                                AscentGlyph.check,
                                size: 11,
                                color: t.onAction,
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  item.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.row.copyWith(
                    color: done ? t.labelTertiary : t.label,
                    decoration: done ? TextDecoration.lineThrough : null,
                    decorationColor: t.labelTertiary,
                  ),
                ),
              ),
              if (meta.isNotEmpty) ...[
                const SizedBox(width: 8),
                Text(
                  meta,
                  style: AscentTextStyles.meta.copyWith(
                    color: item.isOverdue ? t.danger : t.labelTertiary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
