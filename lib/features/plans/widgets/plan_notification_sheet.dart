import 'package:drift/drift.dart' show Variable;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../planning_providers.dart';

final _alertOccurrenceProvider = StreamProvider.autoDispose
    .family<Map<String, dynamic>?, (String, int?)>((ref, key) {
      final db = ref.watch(databaseProvider);
      return db
          .customSelect(
            '''
    SELECT o.*,coalesce(t.title,d.title) AS title,t.estimated_minutes,d.status AS plan_status, r.scheduled_at AS alert_at,r.is_active AS alert_active
    FROM plan_occurrences o JOIN plan_definitions d ON d.id=o.plan_id
    LEFT JOIN tasks t ON t.id=o.linked_task_id
    LEFT JOIN occurrence_alert_links l ON l.occurrence_id=o.id AND l.reminder_id=?
    LEFT JOIN reminders r ON r.id=l.reminder_id WHERE o.id=?
  ''',
            variables: [Variable(key.$2 ?? -1), Variable(key.$1)],
            readsFrom: {
              db.planOccurrenceTable,
              db.planDefinitionTable,
              db.taskTable,
              db.reminderTable,
              db.occurrenceAlertLinkTable,
            },
          )
          .watch()
          .map((rows) => rows.isEmpty ? null : rows.single.data);
    });

/// Returns true when the user wants to continue into the complete plan.
Future<bool> showPlanNotificationSheet(
  BuildContext context, {
  required String occurrenceId,
  int? reminderId,
  DateTime? expectedAt,
}) async =>
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => PlanNotificationSheet(
        occurrenceId: occurrenceId,
        reminderId: reminderId,
        expectedAt: expectedAt,
      ),
    ) ??
    false;

class PlanNotificationSheet extends ConsumerStatefulWidget {
  const PlanNotificationSheet({
    super.key,
    required this.occurrenceId,
    this.reminderId,
    this.expectedAt,
  });
  final String occurrenceId;
  final int? reminderId;
  final DateTime? expectedAt;
  @override
  ConsumerState<PlanNotificationSheet> createState() => _NotificationState();
}

class _NotificationState extends ConsumerState<PlanNotificationSheet> {
  bool _busy = false, _answered = false;
  String? _message;
  Future<void> _answer(bool later) async {
    if (_busy || _answered) return;
    setState(() => _busy = true);
    try {
      final service = ref.read(planServiceProvider);
      final id = widget.reminderId, at = widget.expectedAt;
      final accepted =
          id != null &&
          at != null &&
          (later
              ? await service.snoozeReminder(id, at)
              : await service.answerReminder(id, at, 'done'));
      if (!mounted) return;
      setState(() {
        _answered = true;
        _message = accepted
            ? later
                  ? 'Reminder moved to ${DateFormat.jm().format(DateTime.now().add(const Duration(minutes: 30)))}.'
                  : 'Done. Remaining alerts for this activity are stopped.'
            : 'This alert has changed or was already handled. Open the plan for its current status.';
      });
      if (accepted) {
        final result = await ref
            .read(planningAlertSyncProvider)
            .sync(onlyPending: true)
            .timeout(const Duration(seconds: 8));
        if (!result.complete && mounted) {
          setState(
            () => _message =
                'Saved. Device alerts need attention; retry them from the plan menu.',
          );
        }
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Could not finish updating the alert. Open the plan to check its saved status.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _focus(Map<String, dynamic> item) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final id = item['linked_task_id'] as int?;
      if (id == null) throw StateError('This activity no longer exists.');
      await ref
          .read(timeTrackingProvider.notifier)
          .switchToTask(
            title: item['title'] as String,
            taskId: id,
            autoStart: true,
          );
      if (!mounted) return;
      final router = GoRouter.of(context);
      Navigator.pop(context, false);
      router.push('/focus');
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Open the plan to start or resume this activity.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final item = ref.watch(
      _alertOccurrenceProvider((widget.occurrenceId, widget.reminderId)),
    );
    final g = context.glass;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * .85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpace.s20),
          child: item.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, _) => const Text(
              'Could not load this activity. Open Plans in Things hub.',
            ),
            data: (row) {
              if (row == null) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('This activity was removed or rescheduled.'),
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Close'),
                    ),
                  ],
                );
              }
              final done = row['outcome'] == 'done';
              final snapshotMatches =
                  widget.reminderId != null &&
                  widget.expectedAt != null &&
                  row['alert_active'] == 1 &&
                  row['alert_at'] is int &&
                  (row['alert_at'] as int) * 1000 ==
                      widget.expectedAt!.millisecondsSinceEpoch;
              final active =
                  snapshotMatches &&
                  row['outcome'] == 'scheduled' &&
                  row['plan_status'] == 'active' &&
                  !_answered;
              final timed = (row['estimated_minutes'] as int? ?? 0) > 0;
              final at = DateTime.fromMillisecondsSinceEpoch(
                (row['scheduled_start_time'] as int) * 1000,
              );
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          done ? 'Completed' : 'Your activity',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close activity',
                        onPressed: _busy ? null : () => Navigator.pop(context),
                        icon: const Icon(Icons.close),
                      ),
                    ],
                  ),
                  Text(
                    row['title'] as String,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpace.s8),
                  Text(
                    DateFormat('EEE, d MMM · h:mm a').format(at),
                    style: TextStyle(color: g.inkSecondary),
                  ),
                  const SizedBox(height: AppSpace.s16),
                  if (done)
                    const Text(
                      'Already done. No further alerts for this activity.',
                    ),
                  if (!done && row['plan_status'] != 'active')
                    const Text(
                      'This plan is paused or archived. Its alerts are off.',
                    ),
                  if (!done &&
                      row['plan_status'] == 'active' &&
                      !snapshotMatches &&
                      !_answered)
                    const Text(
                      'This reminder was changed or turned off. Open the plan for its current schedule.',
                    ),
                  if (!active &&
                      !done &&
                      row['plan_status'] == 'active' &&
                      snapshotMatches &&
                      !_answered)
                    const Text(
                      'This check-in has ended. You can update the activity in the full plan.',
                    ),
                  if (_message != null)
                    Semantics(liveRegion: true, child: Text(_message!)),
                  if (active) ...[
                    Text(
                      timed
                          ? 'Focus activities complete when their timer finishes.'
                          : 'Finished it? Mark it done here, or ask for another reminder.',
                    ),
                    const SizedBox(height: AppSpace.s12),
                    FilledButton.icon(
                      onPressed: _busy
                          ? null
                          : () => timed ? _focus(row) : _answer(false),
                      icon: Icon(timed ? Icons.play_arrow : Icons.check),
                      label: Text(timed ? 'Start / resume focus' : 'Mark done'),
                    ),
                    if (widget.reminderId != null)
                      OutlinedButton(
                        onPressed: _busy ? null : () => _answer(true),
                        child: const Text('Remind me in 30 minutes'),
                      ),
                  ],
                  const SizedBox(height: AppSpace.s8),
                  TextButton(
                    onPressed: _busy
                        ? null
                        : () => Navigator.pop(context, true),
                    child: const Text('View full plan'),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
