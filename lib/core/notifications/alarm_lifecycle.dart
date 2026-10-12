import 'dart:async';
import 'package:flutter/material.dart';
import '../database/app_database.dart';
import 'reminder_alarm_bridge.dart';

class AlarmLifecycle with WidgetsBindingObserver {
  AlarmLifecycle(this.database, this.context);
  final AppDatabase Function() database;
  final BuildContext? Function() context;
  bool _refreshing = false, _showing = false;
  void start() {
    WidgetsBinding.instance.addObserver(this);
    ReminderAlarmBridge.channel.setMethodCallHandler((call) async {
      if (call.method == 'eventsChanged' || call.method == 'alarmRinging') {
        await refresh();
      }
    });
    WidgetsBinding.instance.addPostFrameCallback((_) => refresh());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(refresh());
  }

  Future<void> refresh() async {
    if (_refreshing) return;
    _refreshing = true;
    try {
      await ReminderAlarmBridge.reconcile(database());
      final active =
          await ReminderAlarmBridge.channel.invokeMethod<List>('ringing') ?? [];
      if (active.isNotEmpty &&
          !_showing &&
          WidgetsBinding.instance.lifecycleState == AppLifecycleState.resumed) {
        final ctx = context();
        if (ctx != null && ctx.mounted) {
          unawaited(_show(ctx, Map.from(active.first)));
        }
      }
    } catch (_) {
      /* Native action receipts remain available for the next retry. */
    } finally {
      _refreshing = false;
    }
  }

  Future<void> _show(BuildContext ctx, Map alarm) async {
    _showing = true;
    await showDialog<void>(
      context: ctx,
      barrierDismissible: false,
      builder: (_) => _RingingDialog(id: alarm['id'], title: alarm['title']),
    );
    _showing = false;
    await refresh();
  }
}

class _RingingDialog extends StatefulWidget {
  const _RingingDialog({required this.id, required this.title});
  final int id;
  final String title;
  @override
  State<_RingingDialog> createState() => _RingingDialogState();
}

class _RingingDialogState extends State<_RingingDialog> {
  bool _busy = false;
  String? _error;
  Future<void> act(String action) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final success = await ReminderAlarmBridge.act(widget.id, action);
      if (!success) throw StateError('Alarm action could not finish');
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = 'Could not stop the alarm. Check alarm access and retry.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: false,
    child: AlertDialog(
      title: const Text('Reminder alarm'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              widget.title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 16),
            const Text('Snooze or Done stops the ringing.'),
            if (_error != null) Text(_error!),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => act('snooze'),
          child: const Text('Snooze 10 min'),
        ),
        FilledButton(
          onPressed: _busy ? null : () => act('done'),
          child: const Text('Done'),
        ),
      ],
    ),
  );
}
