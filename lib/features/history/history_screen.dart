import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/history/history_provider.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import 'package:ascent/shared/widgets/skeleton_shimmer.dart';
import 'package:ascent/shared/widgets/ascent_sheet.dart';
import 'package:ascent/shared/widgets/ascent_popup_menu.dart';

class HistoryScreen extends ConsumerStatefulWidget {
  const HistoryScreen({super.key, this.module, this.entity});
  final String? module, entity;
  @override
  ConsumerState<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends ConsumerState<HistoryScreen> {
  String _query = '', _outcome = 'all', _domainCategory = 'all';
  String? _module;
  DateTimeRange? _range;
  int _limit = 60;
  String _getDomainForModule(String module) {
    final mod = historyModule(module);
    switch (mod) {
      case 'tasks':
      case 'focus':
        return 'focus_tasks';
      case 'hydration':
      case 'routines':
      case 'medicines':
        return 'health_rhythm';
      case 'thoughts':
      case 'money':
      case 'vault':
        return 'mind_promises';
      default:
        return 'focus_tasks';
    }
  }

  String _getDomainBadgeLabel(String module) {
    final mod = historyModule(module);
    switch (mod) {
      case 'tasks':
        return 'Task';
      case 'focus':
        return 'Focus';
      case 'hydration':
        return 'Water';
      case 'routines':
        return 'Routine';
      case 'medicines':
        return 'Medicine';
      case 'thoughts':
        return 'Thought';
      case 'money':
        return 'Money';
      case 'vault':
        return 'Vault';
      default:
        return historyModules[mod] ?? 'Activity';
    }
  }

  @override
  void initState() {
    super.initState();
    _module = widget.module == null ? null : historyModule(widget.module!);
  }

  bool _matches(HistoryEvent e) =>
      (_domainCategory == 'all' ||
          _getDomainForModule(e.module) == _domainCategory) &&
      (_module == null ||
          historyModule(e.module) == _module ||
          (widget.module == 'tasks' &&
              widget.entity != null &&
              e.module == 'focus' &&
              e.parentEntityId == widget.entity)) &&
      (widget.entity == null ||
          (e.module == widget.module && e.entityId == widget.entity) ||
          (widget.module == 'tasks' &&
              e.module == 'focus' &&
              e.parentEntityId == widget.entity)) &&
      (_outcome == 'all' ||
          (_outcome == 'done'
              ? ['completed', 'taken', 'completion', 'done'].contains(e.action)
              : [
                  'archived',
                  'removed',
                  'skipped',
                  'not_confirmed',
                  'cancelled',
                ].contains(e.action))) &&
      (_range == null ||
          (!e.occurredAt.isBefore(_range!.start) &&
              e.occurredAt.isBefore(
                DateTime(
                  _range!.end.year,
                  _range!.end.month,
                  _range!.end.day + 1,
                ),
              ))) &&
      (_query.isEmpty ||
          '${e.title} ${e.detail} ${historyAction(e.action)}'
              .toLowerCase()
              .contains(_query));

  Future<void> _detail(HistoryEvent event) async {
    final sessions = event.module == 'tasks'
        ? (ref.read(historyEventsProvider).value ?? <HistoryEvent>[])
              .where(
                (e) =>
                    e.module == 'focus' &&
                    e.parentEntityId == event.entityId &&
                    e.action == 'completed',
              )
              .toList()
        : <HistoryEvent>[];
    await showAscentSheet<void>(
      context: context,
      builder: (ctx) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(event.title, style: Theme.of(ctx).textTheme.titleLarge),
            const SizedBox(height: 12),
            Text(
              '${historyAction(event.action)} · ${DateFormat.yMMMd().add_jm().format(event.occurredAt)}',
            ),
            if (event.detail.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              SelectableText(event.detail),
            ],
            if (sessions.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Focus sessions'),
              for (final session in sessions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(session.detail),
                  subtitle: Text(
                    DateFormat.yMMMd().add_jm().format(session.occurredAt),
                  ),
                ),
            ],
            if (event.imported) ...[
              const SizedBox(height: 16),
              const Text(
                'Imported from saved records. Earlier changes are unknown.',
              ),
            ],
            const SizedBox(height: 16),
            if (event.module == 'tasks' && event.action == 'archived')
              TextButton.icon(
                icon: const Icon(Icons.unarchive_outlined),
                label: const Text('Restore archived task'),
                onPressed: () async {
                  final id = int.tryParse(event.entityId);
                  if (id == null) return;
                  final restored = await ref
                      .read(taskDaoProvider)
                      .restoreArchivedTask(id);
                  if (!ctx.mounted || !mounted) return;
                  Navigator.pop(ctx);
                  AscentSnackBar.show(
                    context,
                    message: restored
                        ? 'Task restored. Past activity is unchanged.'
                        : 'This task is already active or no longer exists.',
                  );
                },
              ),
            TextButton.icon(
              icon: const Icon(Icons.timeline_rounded),
              label: const Text('This item’s history'),
              onPressed: () {
                Navigator.pop(ctx);
                context.push(
                  Uri(
                    path: '/history',
                    queryParameters: {
                      'module':
                          event.module == 'focus' &&
                              event.parentEntityId != null
                          ? 'tasks'
                          : event.module,
                      'entity':
                          event.module == 'focus' &&
                              event.parentEntityId != null
                          ? event.parentEntityId!
                          : event.entityId,
                    },
                  ).toString(),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  IconData _moduleIcon(String module) => switch (historyModule(module)) {
        'tasks' => Icons.check_circle_outline_rounded,
        'focus' => Icons.timer_outlined,
        'thoughts' => Icons.bubble_chart_outlined,
        'promises' => Icons.handshake_outlined,
        'medicines' => Icons.medication_outlined,
        'hydration' => Icons.water_drop_outlined,
        'walks' => Icons.directions_walk_rounded,
        'routines' => Icons.repeat_rounded,
        'money' => Icons.account_balance_wallet_outlined,
        'learning' => Icons.menu_book_rounded,
        'breaks' => Icons.coffee_outlined,
        _ => Icons.history_rounded,
      };

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return AscentScaffold(
      title: widget.entity == null ? 'History' : 'Item history',
      subtitle: 'Your activity, kept in one place',
      backgroundColor: context.bgSurface,
      actions: [
        if (widget.entity != null)
          IconButton(
            tooltip: 'All history',
            icon: const Icon(Icons.history_rounded),
            onPressed: () => context.push('/history'),
          ),
      ],
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
            child: Column(
              children: [
                AppTextField(
                  key: const ValueKey('history_search'),
                  hintText: 'Search your history',
                  prefixIcon: const Icon(Icons.search_rounded),
                  textInputAction: TextInputAction.search,
                  onChanged: (v) => setState(() {
                    _query = v.trim().toLowerCase();
                    _limit = 60;
                  }),
                ),
                const SizedBox(height: 12),
                AscentSegmentedControl<String>(
                  key: const ValueKey('history_domain_segments'),
                  segments: const [
                    AscentSegment(value: 'all', label: 'All'),
                    AscentSegment(value: 'focus_tasks', label: 'Focus & Tasks'),
                    AscentSegment(value: 'health_rhythm', label: 'Habits & Health'),
                    AscentSegment(value: 'mind_promises', label: 'Mind & Notes'),
                  ],
                  selected: _domainCategory,
                  onChanged: (v) => setState(() {
                    _domainCategory = v;
                    _limit = 60;
                  }),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: AscentSelectField<String>(
                        label: 'Activity',
                        value: _module ?? 'all',
                        options: [
                          const AscentSelectOption('all', 'All activities'),
                          for (final entry in historyModules.entries)
                            AscentSelectOption(entry.key, entry.value),
                        ],
                        onChanged: widget.entity != null
                            ? null
                            : (v) => setState(() {
                                _module = v == 'all' ? null : v;
                                _limit = 60;
                              }),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: _range == null
                          ? 'Choose date range'
                          : 'Change date range',
                      icon: Icon(
                        Icons.date_range_outlined,
                        color: _range == null ? g.inkMuted : g.primaryButtonBg,
                      ),
                      onPressed: () async {
                        final now = DateTime.now();
                        final result = await showDateRangePicker(
                          context: context,
                          firstDate: DateTime(2000),
                          lastDate: DateTime(now.year + 1, 12, 31),
                          initialDateRange: _range,
                        );
                        if (result != null && mounted) {
                          setState(() {
                            _range = result;
                            _limit = 60;
                          });
                        }
                      },
                    ),
                    if (_range != null)
                      IconButton(
                        tooltip: 'Clear dates',
                        icon: const Icon(Icons.close_rounded),
                        onPressed: () => setState(() => _range = null),
                      ),
                  ],
                ),
                if (_range != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Text(
                        '${DateFormat.yMMMd().format(_range!.start)} – ${DateFormat.yMMMd().format(_range!.end)}',
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                AscentSegmentedControl<String>(
                  segments: const [
                    AscentSegment(value: 'all', label: 'All'),
                    AscentSegment(value: 'done', label: 'Finished'),
                    AscentSegment(value: 'other', label: 'Archived & missed'),
                  ],
                  selected: _outcome,
                  onChanged: (v) => setState(() {
                    _outcome = v;
                    _limit = 60;
                  }),
                ),
              ],
            ),
          ),
          Expanded(
            child: ref
                .watch(historyEventsProvider)
                .when(
                  loading: () => const ListSkeleton(),
                  error: (_, _) => Center(
                    child: TextButton(
                      onPressed: () => ref.invalidate(historyEventsProvider),
                      child: const Text('Retry history'),
                    ),
                  ),
                  data: (all) {
                    final matches = all
                        .where(_matches)
                        .where(
                          (e) =>
                              !(_module == null &&
                                  widget.entity == null &&
                                  e.module == 'focus' &&
                                  e.action == 'completed' &&
                                  e.parentEntityId != null &&
                                  all.any(
                                    (t) =>
                                        t.module == 'tasks' &&
                                        t.entityId == e.parentEntityId &&
                                        t.action == 'completed' &&
                                        DateFormat(
                                              'yyyy-MM-dd',
                                            ).format(t.occurredAt) ==
                                            DateFormat(
                                              'yyyy-MM-dd',
                                            ).format(e.occurredAt),
                                  )),
                        )
                        .toList();
                    if (matches.isEmpty) {
                      return const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Text(
                            'No history in this view. Try another activity or date range.',
                          ),
                        ),
                      );
                    }
                    final visible = matches.take(_limit).toList();
                    final dayGroups = <String, List<HistoryEvent>>{};
                    final now = DateTime.now();
                    for (final e in visible) {
                      final isToday = e.occurredAt.year == now.year &&
                          e.occurredAt.month == now.month &&
                          e.occurredAt.day == now.day;
                      final yesterday = now.subtract(const Duration(days: 1));
                      final isYesterday = e.occurredAt.year == yesterday.year &&
                          e.occurredAt.month == yesterday.month &&
                          e.occurredAt.day == yesterday.day;
                      final label = isToday
                          ? 'Today'
                          : (isYesterday
                              ? 'Yesterday'
                              : DateFormat.yMMMMd().format(e.occurredAt));
                      dayGroups.putIfAbsent(label, () => []).add(e);
                    }
                    final groupEntries = dayGroups.entries.toList();

                    return ListView.builder(
                      key: const ValueKey('history_timeline'),
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                      itemCount:
                          groupEntries.length + (_limit < matches.length ? 1 : 0),
                      itemBuilder: (ctx, i) {
                        if (i == groupEntries.length) {
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            child: Center(
                              child: TextButton.icon(
                                onPressed: () => setState(() => _limit += 60),
                                icon: const Icon(Icons.arrow_downward_rounded, size: 16),
                                label: Text(
                                  'Show more · ${matches.length - _limit} remaining',
                                ),
                              ),
                            ),
                          );
                        }
                        final group = groupEntries[i];
                        final dayLabel = group.key;
                        final events = group.value;
                        final isDark = Theme.of(ctx).brightness == Brightness.dark;

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding: const EdgeInsets.fromLTRB(4, 10, 4, 8),
                                child: Row(
                                  children: [
                                    Text(
                                      dayLabel,
                                      style: TextStyle(
                                        color: g.ink,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: g.clay.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: g.line.withValues(alpha: 0.25),
                                          width: 0.5,
                                        ),
                                      ),
                                      child: Text(
                                        '${events.length} ${events.length == 1 ? "event" : "events"}',
                                        style: TextStyle(
                                          color: g.inkMuted,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? g.elevated
                                        : Theme.of(ctx).colorScheme.surface,
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: g.line.withValues(alpha: 0.35),
                                      width: 0.75,
                                    ),
                                  ),
                                  child: Column(
                                  children: [
                                    for (var j = 0; j < events.length; j++) ...[
                                      if (j > 0)
                                        Divider(
                                          height: 1,
                                          thickness: 0.5,
                                          color: g.line.withValues(alpha: 0.25),
                                          indent: 52,
                                        ),
                                      InkWell(
                                        onTap: () => _detail(events[j]),
                                        child: Padding(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 12,
                                          ),
                                          child: Row(
                                            children: [
                                              Container(
                                                width: 32,
                                                height: 32,
                                                decoration: BoxDecoration(
                                                  color: g.clay.withValues(
                                                    alpha: 0.12,
                                                  ),
                                                  shape: BoxShape.circle,
                                                ),
                                                child: Icon(
                                                  _moduleIcon(events[j].module),
                                                  size: 16,
                                                  color: g.clay,
                                                ),
                                              ),
                                              const SizedBox(width: 12),
                                              Expanded(
                                                child: Column(
                                                  crossAxisAlignment:
                                                      CrossAxisAlignment.start,
                                                  children: [
                                                    Row(
                                                      children: [
                                                        Container(
                                                          margin: const EdgeInsets.only(right: 6),
                                                          padding: const EdgeInsets.symmetric(
                                                            horizontal: 6,
                                                            vertical: 1.5,
                                                          ),
                                                          decoration: BoxDecoration(
                                                            color: g.clay.withValues(alpha: 0.12),
                                                            borderRadius: BorderRadius.circular(6),
                                                            border: Border.all(
                                                              color: g.line.withValues(alpha: 0.25),
                                                              width: 0.5,
                                                            ),
                                                          ),
                                                          child: Text(
                                                            _getDomainBadgeLabel(events[j].module),
                                                            style: TextStyle(
                                                              color: g.inkSecondary,
                                                              fontSize: 10,
                                                              fontWeight: FontWeight.w600,
                                                            ),
                                                          ),
                                                        ),
                                                        Expanded(
                                                          child: Text(
                                                            events[j].title,
                                                            maxLines: 2,
                                                            overflow:
                                                                TextOverflow.ellipsis,
                                                            style: TextStyle(
                                                              color: g.ink,
                                                              fontWeight:
                                                                  FontWeight.w600,
                                                              fontSize: 14.5,
                                                            ),
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      '${historyAction(events[j].action)} · ${DateFormat.jm().format(events[j].occurredAt)}${events[j].imported ? ' · Imported record' : ''}',
                                                      style: TextStyle(
                                                        color: g.inkMuted,
                                                        fontSize: 12,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.chevron_right_rounded,
                                                size: 16,
                                                color: g.inkMuted.withValues(
                                                  alpha: 0.6,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
          ),
        ],
      ),
    );
  }
}
