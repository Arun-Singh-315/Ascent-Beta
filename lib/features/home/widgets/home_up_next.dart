import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/home_capture_service.dart';
import '../../../core/notifications/reminder_alert_sync.dart';
import '../../../shared/widgets/app_surfaces.dart';
import '../../../shared/widgets/ascent_button.dart';

final homePlansProvider = StreamProvider<List<HomePlan>>(
  (ref) => HomeCaptureService(ref.watch(databaseProvider)).watchPlans(),
);

class HomeUpNext extends ConsumerStatefulWidget {
  const HomeUpNext({super.key, this.notificationUri});
  final Uri? notificationUri;
  @override
  ConsumerState<HomeUpNext> createState() => _HomeUpNextState();
}

class _HomeUpNextState extends ConsumerState<HomeUpNext> {
  Timer? _clock;
  final _busy = <int>{};
  String? _handled;
  @override
  void initState() {
    super.initState();
    // UI clock only; scheduling and answers live in the database/OS.
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() {});
    });
    _notification();
  }

  @override
  void didUpdateWidget(covariant HomeUpNext oldWidget) {
    super.didUpdateWidget(oldWidget);
    _notification();
  }

  void _notification() {
    final uri = widget.notificationUri;
    if (uri == null || uri.toString() == _handled) return;
    final id = int.tryParse(uri.queryParameters['checkin'] ?? '');
    final epoch = int.tryParse(uri.queryParameters['at'] ?? '');
    final answer = uri.queryParameters['answer'];
    if (id == null || epoch == null || answer == null) return;
    _handled = uri.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await _answer(id, DateTime.fromMillisecondsSinceEpoch(epoch), answer);
      if (mounted) context.go('/home');
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  Future<void> _answer(
    int id,
    DateTime at,
    String answer, {
    Duration? delay,
  }) async {
    if (_busy.contains(id)) return;
    setState(() => _busy.add(id));
    try {
      final db = ref.read(databaseProvider);
      final accepted = await HomeCaptureService(
        db,
      ).answer(id, at, answer, delay: delay ?? const Duration(minutes: 30));
      if (!mounted) return;
      if (!accepted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('This check-in changed or was already handled.'),
          ),
        );
      } else {
        try {
          await ReminderAlertSync.device(db).sync(onlyPending: true);
        } catch (_) {}
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              answer == 'done'
                  ? 'Done. Linked reminders stopped.'
                  : answer == 'skip'
                  ? 'Check-in skipped. Your Todo stays unfinished.'
                  : 'Check-in moved. Your Todo stays unfinished.',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              e is StateError
                  ? e.message.toString()
                  : 'Could not update. Please retry.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(id));
    }
  }

  Future<void> _later(HomePlan plan) async {
    final delay = await showModalBottomSheet<Duration>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                plan.checkIn!.scheduledAt.isAfter(DateTime.now())
                    ? 'Delay check-in by…'
                    : 'Ask me again in…',
              ),
            ),
            for (final minutes in [15, 30, 60])
              ListTile(
                title: Text('$minutes minutes'),
                onTap: () => Navigator.pop(context, Duration(minutes: minutes)),
              ),
          ],
        ),
      ),
    );
    if (delay != null && mounted) {
      await _answer(
        plan.checkIn!.id,
        plan.checkIn!.scheduledAt,
        'later',
        delay: delay,
      );
    }
  }

  Future<void> _move(HomePlan plan) async {
    final now = DateTime.now();
    final date = await showDatePicker(
      context: context,
      initialDate: plan.reminder.scheduledAt.isAfter(now)
          ? plan.reminder.scheduledAt
          : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(plan.reminder.scheduledAt),
    );
    if (time == null || !mounted) return;
    final at = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );
    setState(() => _busy.add(plan.reminder.id));
    try {
      final db = ref.read(databaseProvider);
      final delay = plan.checkIn?.scheduledAt.difference(
        plan.reminder.scheduledAt,
      );
      await HomeCaptureService(db).reschedule(
        plan,
        at,
        delay == null
            ? null
            : at.add(delay.isNegative ? const Duration(minutes: 20) : delay),
      );
      await ReminderAlertSync.device(db).sync(
        onlyPending: true,
        ids: [plan.reminder.id, if (plan.checkIn != null) plan.checkIn!.id],
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not move this plan. Choose a future time or refresh Home.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy.remove(plan.reminder.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    final rows = ref.watch(homePlansProvider);
    return rows.when(
      loading: () => const SizedBox.shrink(),
      error: (_, _) => ListTile(
        title: const Text('Could not load your plans'),
        trailing: TextButton(
          onPressed: () => ref.invalidate(homePlansProvider),
          child: const Text('Retry'),
        ),
      ),
      data: (plans) {
        if (plans.isEmpty) return const SizedBox.shrink();
        final target = int.tryParse(
          widget.notificationUri?.queryParameters['checkin'] ?? '',
        );
        final ordered = [...plans]
          ..sort(
            (a, b) => a.checkIn?.id == target && target != null
                ? -1
                : b.checkIn?.id == target && target != null
                ? 1
                : a.needsAnswer == b.needsAnswer
                ? a.reminder.scheduledAt.compareTo(b.reminder.scheduledAt)
                : a.needsAnswer
                ? -1
                : 1,
          );
        return Padding(
          padding: const EdgeInsets.only(top: 16, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Up next', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              for (final plan in ordered.take(4))
                AppCard(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            plan.needsAnswer
                                ? Icons.chat_bubble_outline
                                : Icons.schedule,
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              plan.task?.title ?? plan.reminder.title,
                              style: Theme.of(context).textTheme.titleSmall,
                            ),
                          ),
                          IconButton(
                            tooltip:
                                'Open ${plan.task == null ? 'reminders' : 'Todo'}',
                            onPressed: () => context.push(
                              plan.task == null ? '/reminders' : '/today',
                            ),
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                        ],
                      ),
                      Text(
                        DateFormat(
                          'EEE, d MMM · h:mm a',
                        ).format(plan.reminder.scheduledAt),
                      ),
                      if (plan.checkIn?.isActive == true)
                        Text(
                          plan.needsAnswer
                              ? 'Did you do it?'
                              : 'Check-in ${DateFormat('d MMM · h:mm a').format(plan.checkIn!.scheduledAt)}',
                        ),
                      if (plan.reminder.alertSyncPending ||
                          plan.checkIn?.alertSyncPending == true)
                        Wrap(
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            const Text('Alerts need permission or retry'),
                            TextButton(
                              onPressed: _busy.contains(plan.reminder.id)
                                  ? null
                                  : () async {
                                      setState(
                                        () => _busy.add(plan.reminder.id),
                                      );
                                      try {
                                        final result =
                                            await ReminderAlertSync.device(
                                              ref.read(databaseProvider),
                                            ).sync(
                                              onlyPending: true,
                                              ids: [
                                                plan.reminder.id,
                                                if (plan.checkIn != null)
                                                  plan.checkIn!.id,
                                              ],
                                            );
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            SnackBar(
                                              content: Text(result.message),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(
                                            () =>
                                                _busy.remove(plan.reminder.id),
                                          );
                                        }
                                      }
                                    },
                              child: const Text('Retry'),
                            ),
                          ],
                        ),
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          if (plan.reminder.isActive &&
                              plan.reminder.id != plan.checkIn?.id)
                            AscentButton.ghost(
                              label: 'Change time',
                              compact: true,
                              onPressed: _busy.contains(plan.reminder.id)
                                  ? null
                                  : () => _move(plan),
                            ),
                          if (plan.checkIn?.isActive != true)
                            AscentButton.tonal(
                              label: 'Done',
                              compact: true,
                              onPressed: _busy.contains(plan.reminder.id)
                                  ? null
                                  : () async {
                                      setState(
                                        () => _busy.add(plan.reminder.id),
                                      );
                                      try {
                                        final db = ref.read(databaseProvider);
                                        await HomeCaptureService(
                                          db,
                                        ).complete(plan);
                                        await ReminderAlertSync.device(
                                          db,
                                        ).sync(onlyPending: true);
                                      } catch (_) {
                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Could not complete this activity. Open its Todo controls.',
                                              ),
                                            ),
                                          );
                                        }
                                      } finally {
                                        if (mounted) {
                                          setState(
                                            () =>
                                                _busy.remove(plan.reminder.id),
                                          );
                                        }
                                      }
                                    },
                            ),
                        ],
                      ),
                      if (plan.checkIn?.isActive == true)
                        Wrap(
                          spacing: 8,
                          runSpacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            AscentButton.tonal(
                              label: 'Done',
                              compact: true,
                              onPressed: _busy.contains(plan.checkIn!.id)
                                  ? null
                                  : () => _answer(
                                      plan.checkIn!.id,
                                      plan.checkIn!.scheduledAt,
                                      'done',
                                    ),
                            ),
                            AscentButton.ghost(
                              label: 'Later',
                              compact: true,
                              onPressed: _busy.contains(plan.checkIn!.id)
                                  ? null
                                  : () => _later(plan),
                            ),
                            TextButton(
                              onPressed: _busy.contains(plan.checkIn!.id)
                                  ? null
                                  : () => _answer(
                                      plan.checkIn!.id,
                                      plan.checkIn!.scheduledAt,
                                      'skip',
                                    ),
                              style: TextButton.styleFrom(
                                foregroundColor: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                minimumSize: const Size(40, 32),
                              ),
                              child: const Text('Skip check-in'),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              if (plans.length > 4)
                TextButton(
                  onPressed: () => context.push('/reminders'),
                  child: const Text('View all plans'),
                ),
            ],
          ),
        );
      },
    );
  }
}
