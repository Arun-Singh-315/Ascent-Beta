import '../today/add_activity_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/glass_surface.dart';
import '../promises/models/promise_model.dart';
import '../promises/providers/promise_providers.dart';
import '../promises/widgets/promise_detail_sheet.dart';
import '../promises/widgets/promise_session_sheet.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

final _taskCardProvider = StreamProvider.autoDispose.family<Task?, int>((
  ref,
  id,
) {
  final db = ref.watch(databaseProvider);
  return (db.select(
    db.taskTable,
  )..where((t) => t.id.equals(id))).watchSingleOrNull();
});
final _promiseCardProvider = StreamProvider.autoDispose
    .family<PromiseModel?, int>((ref, id) {
      final db = ref.watch(databaseProvider);
      final repo = ref.watch(promiseRepositoryProvider);
      return (db.select(db.thoughtTable)..where((t) => t.id.equals(id)))
          .watchSingleOrNull()
          .asyncMap((_) => repo.getPromiseById(id));
    });

/// Cards keep identity, not a stale copy of the record. Old messages reflect
/// edits/deletions and never offer actions on a record that has disappeared.
class RiyaEntityCard extends ConsumerWidget {
  const RiyaEntityCard({
    super.key,
    required this.type,
    required this.id,
    required this.onCommand,
    this.busy = false,
  });
  final String type;
  final int id;
  final bool busy;
  final ValueChanged<String> onCommand;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (type == 'promises') {
      return ref
          .watch(_promiseCardProvider(id))
          .when(
            loading: () => _pane(context, 'Loading Promise…'),
            error: (_, _) => _pane(
              context,
              'Could not load this Promise. Reopen the list to retry.',
            ),
            data: (p) {
              if (p == null) {
                return _pane(
                  context,
                  'Promise no longer available',
                  removed: true,
                );
              }
              if (p.isPrivate) {
                return _pane(
                  context,
                  'Private Promise',
                  actions: [
                    TextButton(
                      onPressed: () => context.push('/promises'),
                      child: const Text('Open Promises'),
                    ),
                  ],
                );
              }
              final targetDateStr = p.targetDate != null
                  ? DateFormat('d MMM yyyy').format(p.targetDate!)
                  : null;
              final reminderStr =
                  p.reminderEnabled && p.reminderTime != null ? p.reminderTime : null;
              return _pane(
                context,
                p.title,
                targetDate: targetDateStr,
                reminder: reminderStr,
                category: p.category,
                subtitle:
                    '${p.schedule?.summary ?? 'Once'} · ${p.isDoneToday ? 'Done today' : p.status.name}',
                actions: [
                  if (p.isActive && !p.isDoneToday)
                    TextButton(
                      onPressed: busy
                          ? null
                          : () {
                              if (p.trackingType ==
                                  PromiseTrackingType.duration) {
                                PromiseSessionSheet.show(context, p);
                              } else if (p.trackingType ==
                                      PromiseTrackingType.completion ||
                                  p.trackingType ==
                                      PromiseTrackingType.frequency) {
                                onCommand('Check in promise #$id');
                              } else {
                                PromiseDetailSheet.show(context, p);
                              }
                            },
                      child: Text(
                        p.trackingType == PromiseTrackingType.completion ||
                                p.trackingType == PromiseTrackingType.frequency
                            ? 'Check in'
                            : 'Track',
                      ),
                    ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => onCommand('Edit promise #$id'),
                    child: const Text('Edit'),
                  ),
                  TextButton(
                    onPressed: busy
                        ? null
                        : () => onCommand('Reschedule promise #$id'),
                    child: const Text('Day'),
                  ),
                  PopupMenuButton<String>(
                    enabled: !busy,
                    tooltip: 'More Promise actions',
                    onSelected: (action) {
                      if (action == 'details') {
                        PromiseDetailSheet.show(context, p);
                      } else {
                        onCommand(action);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'details',
                        child: Text('Schedule & details'),
                      ),
                      PopupMenuItem(
                        value:
                            '${p.isPaused ? 'Resume' : 'Pause'} promise #$id',
                        child: Text(p.isPaused ? 'Resume' : 'Pause'),
                      ),
                      PopupMenuItem(
                        value: 'Delete promise #$id',
                        child: const Text('Delete'),
                      ),
                    ],
                  ),
                ],
              );
            },
          );
    }
    return ref
        .watch(_taskCardProvider(id))
        .when(
          loading: () => _pane(context, 'Loading Todo…'),
          error: (_, _) => _pane(
            context,
            'Could not load this Todo. Reopen the list to retry.',
          ),
          data: (task) => task == null
              ? _pane(context, 'Todo no longer available', removed: true)
              : _pane(
                  context,
                  task.title,
                  subtitle:
                      '${task.actualCompletedDate != null ? 'Done' : 'Open'} · ${task.plannedDate == null ? 'Unscheduled' : '${task.plannedDate!.day}/${task.plannedDate!.month}'}',
                  actions: [
                    if (task.actualCompletedDate == null)
                      TextButton(
                        onPressed: busy
                            ? null
                            : () => onCommand('Complete task #$id'),
                        child: const Text('Done'),
                      ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => onCommand('Edit task #$id'),
                      child: const Text('Edit'),
                    ),
                    TextButton(
                      onPressed: busy
                          ? null
                          : () => onCommand('Reschedule task #$id'),
                      child: const Text('Reschedule'),
                    ),
                    PopupMenuButton<String>(
                      enabled: !busy,
                      tooltip: 'More Todo actions',
                      onSelected: (action) {
                        if (action == 'details') {
                          AddActivitySheet.show(context, existingTask: task);
                        } else {
                          onCommand(action);
                        }
                      },
                      itemBuilder: (_) => [
                        const PopupMenuItem(
                          value: 'details',
                          child: Text('All activity details'),
                        ),
                        PopupMenuItem(
                          value: 'Delete task #$id',
                          child: const Text('Delete'),
                        ),
                      ],
                    ),
                  ],
                ),
        );
  }

  Widget _pane(
    BuildContext context,
    String title, {
    String? subtitle,
    String? targetDate,
    String? reminder,
    String? category,
    bool removed = false,
    List<Widget> actions = const [],
  }) {
    return buildPane(
      context,
      title,
      type: type,
      key: ValueKey('riya_entity_${type}_$id'),
      subtitle: subtitle,
      targetDate: targetDate,
      reminder: reminder,
      category: category,
      removed: removed,
      actions: actions,
    );
  }

  static Widget buildPane(
    BuildContext context,
    String title, {
    String type = 'promises',
    Key? key,
    String? subtitle,
    String? targetDate,
    String? reminder,
    String? category,
    bool removed = false,
    List<Widget> actions = const [],
  }) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: GlassSurface(
        key: key,
        radius: 18,
        enableBlur: false,
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: g.clay.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    type == 'promises'
                        ? (category != null && category.isNotEmpty
                            ? 'PROMISE · ${category.toUpperCase()}'
                            : 'PROMISE')
                        : 'TODO',
                    style: TextStyle(
                      fontSize: 10.5,
                      letterSpacing: 1.0,
                      color: g.clay,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Text(
              title,
              style: TextStyle(
                color: removed ? g.inkMuted : g.ink,
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                height: 1.25,
              ),
            ),
            if (targetDate != null || reminder != null || subtitle != null) ...[
              const SizedBox(height: 6),
              if (targetDate != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Icon(Icons.event_outlined, size: 14, color: g.clay),
                      const SizedBox(width: 5),
                      Text(
                        'Target: $targetDate',
                        style: TextStyle(
                          color: g.ink,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              if (reminder != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 3),
                  child: Row(
                    children: [
                      Icon(Icons.notifications_active_outlined, size: 14, color: g.clay),
                      const SizedBox(width: 5),
                      Text(
                        'Reminder: $reminder',
                        style: TextStyle(
                          color: g.inkSecondary,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              if (subtitle != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: Row(
                    children: [
                      Icon(
                        type == 'promises'
                            ? Icons.repeat_rounded
                            : Icons.check_circle_outline_rounded,
                        size: 14,
                        color: g.inkSecondary,
                      ),
                      const SizedBox(width: 5),
                      Expanded(
                        child: Text(
                          subtitle,
                          style: TextStyle(
                            color: g.inkSecondary,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 4),
              Wrap(
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: 4,
                children: actions,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
