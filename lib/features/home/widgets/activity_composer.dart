import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../../shared/widgets/ascent_star_button.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../shared/widgets/schedule_picker.dart';
import '../../../shared/widgets/note_list_button.dart';
import '../../../core/services/plan_collection_service.dart';
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
  final _inputFocus = FocusNode();
  ActivityKind _kind = ActivityKind.todo;
  int _minutes = 30;
  DateTime? _date;
  TimeOfDay? _reminder;
  bool _saving = false;
  bool _starred = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _text.addListener(_changed);
    _inputFocus.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _text.removeListener(_changed);
    _inputFocus.removeListener(_changed);
    _inputFocus.dispose();
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
    final now = DateTime.now();
    final selected = _reminder == null
        ? null
        : DateTime(
            _day.year,
            _day.month,
            _day.day,
            _reminder!.hour,
            _reminder!.minute,
          );
    final picked = await pickFutureSchedule(
      context,
      purpose: 'Reminder',
      initial:
          selected ??
          DateTime(_day.year, _day.month, _day.day, now.hour, now.minute + 30),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _date = DateTime(picked.year, picked.month, picked.day);
      _reminder = TimeOfDay.fromDateTime(picked);
    });
    await NotificationService.instance.requestPermissions();
  }

  Future<void> _send() async {
    final entries = PlanItemDraft.parseList(_text.text);
    if (entries.isEmpty) {
      setState(() => _error = 'Please enter an activity title');
      HapticFeedback.lightImpact();
      return;
    }
    if (_saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final db = ref.read(databaseProvider);
    try {
      final date = _day;
      final entries = PlanItemDraft.parseList(_text.text);
      final results = await ActivityEntryService(db).saveMany(
        titles: entries,
        date: date,
        priority: _starred ? 'high' : 'low',
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
      final reminderIds = results.expand((r) => r.reminderIds).toList();
      // Persistence succeeded. Never repeat creation because device alerts fail.
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _text.clear();
      _inputFocus.unfocus();
      setState(() {
        _kind = ActivityKind.todo;
        _date = null;
        _reminder = null;
        _minutes = 30;
        _starred = false;
      });
      var message = results.length == 1
          ? 'Activity added'
          : '${results.length} to-dos added';
      if (reminderIds.isNotEmpty) {
        try {
          final sync = await ReminderAlertSync.device(
            db,
          ).sync(ids: reminderIds, onlyPending: true);
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

  Future<void> _options() async {
    _inputFocus.unfocus();
    await showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, refresh) {
          final g = ctx.glass;
          Future<void> edit(Future<void> Function() action) async {
            await action();
            if (ctx.mounted) refresh(() {});
          }

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Activity options',
                        style: TextStyle(
                          color: g.ink,
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => Navigator.pop(sheetContext),
                      child: const Text('Done'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                AscentSegmentedControl<ActivityKind>(
                  segments: const [
                    AscentSegment(value: ActivityKind.todo, label: 'To-do'),
                    AscentSegment(value: ActivityKind.duration, label: 'Timer'),
                    AscentSegment(
                      value: ActivityKind.flexible,
                      label: 'Flexible',
                    ),
                  ],
                  selected: _kind,
                  onChanged: (value) {
                    setState(() => _kind = value);
                    refresh(() {});
                  },
                ),
                if (_kind == ActivityKind.duration)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Duration'),
                    trailing: Text('$_minutes min'),
                    onTap: () => edit(_duration),
                  ),
                PopupMenuButton<String>(
                  tooltip: 'Activity date',
                  onSelected: (value) => edit(() => _pickDate(value)),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'today', child: Text('Today')),
                    PopupMenuItem(value: 'tomorrow', child: Text('Tomorrow')),
                    PopupMenuItem(value: 'date', child: Text('Choose date')),
                  ],
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.calendar_today_outlined,
                      size: 20,
                    ),
                    title: const Text('Schedule'),
                    trailing: Text(
                      _date == null
                          ? 'Today'
                          : DateFormat('d MMM').format(_day),
                    ),
                  ),
                ),
                PopupMenuButton<String>(
                  tooltip: 'Activity reminder',
                  onSelected: (value) => edit(() => _pickReminder(value)),
                  itemBuilder: (_) => const [
                    PopupMenuItem(value: 'off', child: Text('Off')),
                    PopupMenuItem(value: 'time', child: Text('Choose time')),
                  ],
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.notifications_none_rounded,
                      size: 20,
                    ),
                    title: const Text('Reminder'),
                    trailing: Text(_reminder?.format(context) ?? 'Off'),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Star this activity'),
                  trailing: AscentStarButton(
                    selected: _starred,
                    onChanged: (value) {
                      setState(() => _starred = value);
                      refresh(() {});
                    },
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final hasText = PlanItemDraft.parseList(_text.text).isNotEmpty;
    final customized =
        _kind != ActivityKind.todo ||
        _date != null ||
        _reminder != null ||
        _starred;
    final summary = [
      if (_kind == ActivityKind.duration) 'Timer · $_minutes min',
      if (_kind == ActivityKind.flexible) 'Flexible timer',
      if (_date != null) DateFormat('d MMM').format(_day),
      if (_reminder != null) _reminder!.format(context),
      if (_starred) 'Starred',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: g.line, width: .75),
          ),
          padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              InlineListAddButton(
                controller: _text,
                focusNode: _inputFocus,
                enabled: !_saving,
              ),
              Expanded(
                child: TextField(
                  key: const ValueKey('activity_quick_input'),
                  controller: _text,
                  focusNode: _inputFocus,
                  enabled: !_saving,
                  minLines: 1,
                  maxLines: 4,
                  maxLength: 20000,
                  textCapitalization: TextCapitalization.sentences,
                  style: TextStyle(color: g.ink, fontSize: 15, height: 1.4),
                  decoration: InputDecoration(
                    hintText: 'Add a thing…',
                    hintStyle: TextStyle(color: g.inkMuted),
                    counterText: '',
                    filled: false,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 12,
                    ),
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    disabledBorder: InputBorder.none,
                  ),
                ),
              ),
              IconButton.filled(
                tooltip: 'Add activity',
                onPressed: _saving || !hasText ? null : _send,
                style: IconButton.styleFrom(
                  backgroundColor: SharedControlColors.actionBlue,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: g.ink.withValues(alpha: .08),
                  disabledForegroundColor: g.inkMuted,
                ),
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.arrow_upward_rounded, size: 20),
              ),
            ],
          ),
        ),
        if (_inputFocus.hasFocus || hasText || customized)
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              key: const ValueKey('activity_options'),
              onPressed: _saving ? null : _options,
              icon: const Icon(Icons.tune_rounded, size: 16),
              label: Text(
                summary.isEmpty ? 'Options' : summary,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _error!,
              style: const TextStyle(
                color: SharedControlColors.dueRed,
                fontSize: 12,
              ),
            ),
          ),
      ],
    );
  }
}
