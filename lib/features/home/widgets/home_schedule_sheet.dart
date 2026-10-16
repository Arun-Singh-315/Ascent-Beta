import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/ai/riya_alert_effects.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/home_capture_service.dart';

const homePendingScheduleKey = 'ascent_home_pending_schedule';

final homeScheduleEffectsProvider = Provider<RiyaAlertEffects>(
  (ref) => RiyaAlertEffects.device(ref.watch(databaseProvider)),
);

Future<void> showHomeSchedule(BuildContext context, Thought thought) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => HomeScheduleSheet(thought: thought),
    );

class HomeScheduleSheet extends ConsumerStatefulWidget {
  const HomeScheduleSheet({super.key, required this.thought});
  final Thought thought;
  @override
  ConsumerState<HomeScheduleSheet> createState() => _HomeScheduleSheetState();
}

class _HomeScheduleSheetState extends ConsumerState<HomeScheduleSheet> {
  late final TextEditingController _title;
  DateTime? _at, _checkAt;
  int? _minutes;
  bool _follow = false, _todo = true, _busy = false;
  String? _error;
  Future<void> _writes = Future.value();
  @override
  void initState() {
    super.initState();
    final proposal = HomeCaptureProposal.parse(
      widget.thought.content,
      DateTime.now(),
    );
    _title = TextEditingController(text: proposal.title);
    _at = proposal.at;
    _minutes = proposal.minutes;
    _follow = proposal.followUp;
    if (_at != null) {
      _checkAt = _at!.add(Duration(minutes: (proposal.minutes ?? 10) + 10));
    }
    try {
      final raw = ref
          .read(sharedPreferencesProvider)
          .getString(homePendingScheduleKey);
      final saved = raw == null ? null : jsonDecode(raw) as Map;
      if (saved?['thoughtId'] == widget.thought.id) {
        _title.text = saved!['title'] as String? ?? _title.text;
        _at = DateTime.tryParse(saved['at'] as String? ?? '') ?? _at;
        _checkAt =
            DateTime.tryParse(saved['checkAt'] as String? ?? '') ?? _checkAt;
        _follow = saved['follow'] as bool? ?? _follow;
        _todo = saved['todo'] as bool? ?? _todo;
      }
    } catch (_) {
      /* Invalid draft does not prevent reviewing the source. */
    }
    _title.addListener(_persist);
    _persist();
  }

  void _persist() {
    final prefs = ref.read(sharedPreferencesProvider);
    final value = jsonEncode({
      'thoughtId': widget.thought.id,
      'title': _title.text,
      'at': _at?.toIso8601String(),
      'checkAt': _checkAt?.toIso8601String(),
      'follow': _follow,
      'todo': _todo,
    });
    _writes = _writes.catchError((_) {}).then((_) async {
      if (!await prefs.setString(homePendingScheduleKey, value)) {
        throw StateError('Could not preserve the schedule draft.');
      }
    });
    _writes.catchError((_) {});
  }

  @override
  void dispose() {
    _title.removeListener(_persist);
    _title.dispose();
    super.dispose();
  }

  Future<DateTime?> _pick(DateTime? initial) async {
    final now = DateTime.now();
    final value = initial != null && initial.isAfter(now) ? initial : now;
    final date = await showDatePicker(
      context: context,
      initialDate: value,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (date == null || !mounted) return null;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(value),
    );
    if (time == null) return null;
    return DateTime(date.year, date.month, date.day, time.hour, time.minute);
  }

  String _date(DateTime? date) => date == null
      ? 'Choose date and time'
      : '${DateFormat('EEE, d MMM y · h:mm a').format(date)} (${date.timeZoneName})';
  Future<void> _save() async {
    if (_busy) return;
    if (_at == null ||
        !_at!.isAfter(DateTime.now()) ||
        (_follow && (_checkAt == null || !_checkAt!.isAfter(_at!)))) {
      setState(
        () => _error = 'Choose a future reminder and a later check-in time.',
      );
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _writes;
      final db = ref.read(databaseProvider);
      final plan = await HomeCaptureService(db).schedule(
        source: widget.thought,
        title: _title.text,
        at: _at!,
        checkInAt: _follow ? _checkAt : null,
        linkedTodo: _todo,
      );
      // The durable receipt remains pending if the platform cannot schedule.
      bool ready = false;
      try {
        ready = await ref
            .read(homeScheduleEffectsProvider)
            .syncRequest(plan.requestId)
            .timeout(const Duration(seconds: 8), onTimeout: () => false);
      } catch (_) {}
      await ref.read(sharedPreferencesProvider).remove(homePendingScheduleKey);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ready
                ? 'Scheduled. ${_todo ? 'Todo linked. ' : ''}Reminder${_follow ? ' and check-in' : ''} ready.'
                : 'Saved. Alerts need permission or retry; check Home.',
          ),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError || e is ArgumentError
              ? e.toString().replaceFirst(
                  RegExp(r'^(Bad state|Invalid argument\(s\)): '),
                  '',
                )
              : 'Could not schedule. Your draft is still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
      ),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Make a plan', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            const Text(
              'Review once. We’ll connect the activity and its reminders.',
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _title,
              enabled: !_busy,
              maxLength: 300,
              maxLines: 3,
              minLines: 1,
              decoration: const InputDecoration(labelText: 'Activity'),
            ),
            if (_minutes != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('Planned duration: $_minutes minutes'),
              ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.schedule),
              title: const Text('Remind me'),
              subtitle: Text(_date(_at)),
              trailing: const Icon(Icons.edit_outlined),
              onTap: _busy
                  ? null
                  : () async {
                      final value = await _pick(_at);
                      if (value != null && mounted) {
                        setState(() {
                          final gap = _at != null && _checkAt != null
                              ? _checkAt!.difference(_at!)
                              : null;
                          _at = value;
                          _checkAt = value.add(
                            gap != null && !gap.isNegative
                                ? gap
                                : Duration(minutes: (_minutes ?? 10) + 10),
                          );
                        });
                        _persist();
                      }
                    },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Also add to Todo'),
              subtitle: const Text(
                'One linked activity. No separate entry needed.',
              ),
              value: _todo,
              onChanged: _busy
                  ? null
                  : (value) {
                      setState(() => _todo = value);
                      _persist();
                    },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Ask me afterwards'),
              subtitle: const Text(
                'Done, Later, or Skip. No repeated nudges unless you choose Later.',
              ),
              value: _follow,
              onChanged: _busy
                  ? null
                  : (value) {
                      setState(() => _follow = value);
                      _persist();
                    },
            ),
            if (_follow)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Check in'),
                subtitle: Text(_date(_checkAt)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _busy
                    ? null
                    : () async {
                        final value = await _pick(_checkAt);
                        if (value != null && mounted) {
                          setState(() => _checkAt = value);
                          _persist();
                        }
                      },
              ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                'Notifications need permission. This is a one-time plan. The duration sets your check-in time; it doesn’t start a timer.',
              ),
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy ? null : _save,
                icon: _busy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.check),
                label: Text(_busy ? 'Scheduling…' : 'Schedule'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
