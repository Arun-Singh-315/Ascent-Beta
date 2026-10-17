import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/activity_entry_service.dart';
import '../../../core/notifications/reminder_alert_sync.dart';
import '../../../core/notifications/notification_service.dart';

/// Type first. Optional controls keep the normal path to a single send.
class ActivityComposer extends ConsumerStatefulWidget {
  const ActivityComposer({super.key});
  @override
  ConsumerState<ActivityComposer> createState() => _ActivityComposerState();
}

class _ActivityComposerState extends ConsumerState<ActivityComposer> {
  final _text = TextEditingController();
  ActivityKind _kind = ActivityKind.todo;
  int _minutes = 30;
  DateTime? _date;
  TimeOfDay? _reminder;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _text.removeListener(_changed);
    _text.dispose();
    super.dispose();
  }

  DateTime get _day {
    final date = _date ?? DateTime.now();
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _duration() async {
    var durationText = '$_minutes';
    final picked = await showDialog<int>(
      context: context,
      builder: (ctx) {
        String? error;
        return StatefulBuilder(
          builder: (ctx, setDialog) => AlertDialog(
            title: const Text('Timer duration'),
            content: TextFormField(
              initialValue: durationText,
              onChanged: (value) => durationText = value,
              autofocus: true,
              keyboardType: TextInputType.number,
              decoration: InputDecoration(
                labelText: 'Minutes (1–1440)',
                errorText: error,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () {
                  final value = int.tryParse(durationText.trim());
                  if (value == null || value < 1 || value > 1440) {
                    setDialog(() => error = 'Enter 1–1440 minutes.');
                    return;
                  }
                  Navigator.pop(ctx, value);
                },
                child: const Text('Apply'),
              ),
            ],
          ),
        );
      },
    );
    if (picked != null && mounted) setState(() => _minutes = picked);
  }

  Future<void> _pickDate(String choice) async {
    final now = DateTime.now();
    if (choice == 'today') {
      setState(() => _date = null);
      return;
    }
    if (choice == 'tomorrow') {
      setState(() => _date = DateTime(now.year, now.month, now.day + 1));
      return;
    }
    final picked = await showDatePicker(
      context: context,
      initialDate: _day.isBefore(DateTime(now.year, now.month, now.day))
          ? now
          : _day,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1, now.month, now.day),
    );
    if (picked != null && mounted) setState(() => _date = picked);
  }

  Future<void> _pickReminder(String choice) async {
    if (choice == 'off') {
      setState(() => _reminder = null);
      return;
    }
    final picked = await showTimePicker(
      context: context,
      initialTime:
          _reminder ??
          TimeOfDay.fromDateTime(
            DateTime.now().add(const Duration(minutes: 15)),
          ),
    );
    if (picked == null || !mounted) return;
    setState(() => _reminder = picked);
    await NotificationService.instance.requestPermissions();
  }

  Future<void> _send() async {
    if (_saving || _text.text.trim().isEmpty) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final db = ref.read(databaseProvider);
    try {
      final date = _day;
      final result = await ActivityEntryService(db).save(
        title: _text.text,
        date: date,
        estimatedMinutes: _kind == ActivityKind.duration
            ? _minutes
            : _kind == ActivityKind.flexible
            ? -1
            : null,
        reminderAt: _reminder == null
            ? null
            : DateTime(
                date.year,
                date.month,
                date.day,
                _reminder!.hour,
                _reminder!.minute,
              ),
      );
      // Persistence succeeded. Never repeat creation because device alerts fail.
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _text.clear();
      setState(() {
        _kind = ActivityKind.todo;
        _date = null;
        _reminder = null;
        _minutes = 30;
      });
      var message = 'Activity added';
      if (result.reminderIds.isNotEmpty) {
        try {
          final sync = await ReminderAlertSync.device(
            db,
          ).sync(ids: result.reminderIds, onlyPending: true);
          if (!sync.complete) {
            message =
                'Activity saved. Reminder alert pending—check notification permissions.';
          }
        } catch (_) {
          message = 'Activity saved. Reminder alert pending.';
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(message)));
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is StateError
              ? e.message.toString()
              : 'Could not save. Your text is still here—try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final now = DateTime.now();
    final label = _date == null || DateUtils.isSameDay(_day, now)
        ? 'Today'
        : DateUtils.isSameDay(_day, DateTime(now.year, now.month, now.day + 1))
        ? 'Tomorrow'
        : DateFormat('d MMM').format(_day);
    Widget option(String text, IconData icon) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: g.inkSecondary),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: g.inkSecondary, fontSize: 12)),
        ],
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: g.claySoft.withValues(alpha: .45),
            borderRadius: BorderRadius.circular(18),
          ),
          padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
          child: Row(
            children: [
              Expanded(
                child: TextField(
                  key: const ValueKey('activity_quick_input'),
                  controller: _text,
                  enabled: !_saving,
                  minLines: 1,
                  maxLines: 3,
                  maxLength: 300,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: g.ink, fontSize: 14),
                  decoration: const InputDecoration(
                    hintText: 'Add an activity…',
                    counterText: '',
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                ),
              ),
              IconButton.filled(
                tooltip: 'Add activity',
                style: IconButton.styleFrom(
                  backgroundColor: g.clay,
                  disabledBackgroundColor: g.clay,
                  foregroundColor: Colors.white,
                  disabledForegroundColor: Colors.white,
                  minimumSize: const Size(44, 44),
                ),
                onPressed: _saving || _text.text.trim().isEmpty ? null : _send,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded),
              ),
            ],
          ),
        ),
        Wrap(
          spacing: 4,
          runSpacing: 0,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            PopupMenuButton<ActivityKind>(
              tooltip: 'Activity type',
              enabled: !_saving,
              onSelected: (kind) => setState(() => _kind = kind),
              itemBuilder: (_) => const [
                PopupMenuItem(value: ActivityKind.todo, child: Text('To-do')),
                PopupMenuItem(
                  value: ActivityKind.duration,
                  child: Text('Timer'),
                ),
                PopupMenuItem(
                  value: ActivityKind.flexible,
                  child: Text('Flexible timer'),
                ),
              ],
              child: option(
                _kind == ActivityKind.todo
                    ? 'To-do'
                    : _kind == ActivityKind.duration
                    ? 'Timer'
                    : 'Flexible',
                _kind == ActivityKind.todo
                    ? Icons.check_circle_outline
                    : Icons.timer_outlined,
              ),
            ),
            if (_kind == ActivityKind.duration)
              TextButton(
                onPressed: _saving ? null : _duration,
                child: Text('$_minutes min'),
              ),
            PopupMenuButton<String>(
              tooltip: 'Activity date',
              enabled: !_saving,
              onSelected: _pickDate,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'today', child: Text('Today')),
                PopupMenuItem(value: 'tomorrow', child: Text('Tomorrow')),
                PopupMenuItem(value: 'pick', child: Text('Pick date')),
              ],
              child: option(label, Icons.calendar_today_outlined),
            ),
            PopupMenuButton<String>(
              tooltip: 'Activity reminder',
              enabled: !_saving,
              onSelected: _pickReminder,
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'off', child: Text('Reminder off')),
                PopupMenuItem(value: 'time', child: Text('Choose time')),
              ],
              child: option(
                _reminder == null ? 'Reminder off' : _reminder!.format(context),
                Icons.notifications_none,
              ),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              _error!,
              style: TextStyle(color: g.coral, fontSize: 12),
            ),
          ),
      ],
    );
  }
}
