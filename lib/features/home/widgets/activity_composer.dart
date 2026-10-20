import '../../../core/copy/app_copy.dart';
import '../../../shared/widgets/ascent_option_tile.dart';
import '../../../shared/widgets/schedule_picker.dart';
import '../../../shared/widgets/note_list_button.dart';
import '../../../core/services/plan_collection_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/merlot_palette.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
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
    if (_saving || PlanItemDraft.parseList(_text.text).isEmpty) return;
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
      setState(() {
        _kind = ActivityKind.todo;
        _date = null;
        _reminder = null;
        _minutes = 30;
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

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final now = DateTime.now();
    final label = _date == null || DateUtils.isSameDay(_day, now)
        ? 'Today'
        : DateUtils.isSameDay(_day, DateTime(now.year, now.month, now.day + 1))
        ? 'Tomorrow'
        : DateFormat('d MMM').format(_day);
    // Equal-size tiles: the popup menu owns the tap, the tile only draws.
    Widget option(
      String text,
      IconData icon, {
      String? value,
      bool selected = false,
    }) => AscentOptionTile(
      icon: icon,
      label: text,
      value: value,
      selected: selected,
      enabled: !_saving,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: isDark
                ? g.fill
                : (g.merlot ? MerlotPalette.surface : context.bgSurfaceElevated),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? g.edge
                  : (g.merlot
                      ? MerlotPalette.line
                      : g.edge.withValues(alpha: 0.35)),
              width: g.merlot ? 0.75 : 1.0,
            ),
          ),
          padding: const EdgeInsets.fromLTRB(8, 4, 4, 4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
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
                      onTap: () {
                        try {
                          InlineListAddButton.maybeShowFirstTimeDiscovery(
                            context,
                            prefs: ref.read(sharedPreferencesProvider),
                          );
                        } catch (_) {}
                      },
                      minLines: 1,
                      maxLines: 3,
                      maxLength: 20000,
                      textCapitalization: TextCapitalization.sentences,
                      style: TextStyle(color: g.ink, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: AppCopy.activityHint,
                        hintStyle: TextStyle(
                          color: g.inkMuted,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
                        counterText: '',
                        filled: false,
                        isDense: true,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 8,
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
                    style: IconButton.styleFrom(
                      backgroundColor: isDark
                          ? g.clay
                          : (g.merlot ? MerlotPalette.action : g.claySoft),
                      disabledBackgroundColor: isDark
                          ? g.clay.withValues(alpha: 0.3)
                          : (g.merlot
                              ? MerlotPalette.action.withValues(alpha: 0.15)
                              : g.edge.withValues(alpha: 0.2)),
                      foregroundColor: isDark
                          ? Colors.white
                          : (g.merlot ? Colors.white : g.clay),
                      disabledForegroundColor: isDark
                          ? Colors.white.withValues(alpha: 0.4)
                          : (g.merlot
                              ? MerlotPalette.mutedInk.withValues(alpha: 0.4)
                              : g.inkMuted.withValues(alpha: 0.4)),
                      side: isDark || g.merlot
                          ? null
                          : BorderSide(
                              color: g.clay.withValues(alpha: 0.25),
                              width: 1,
                            ),
                      minimumSize: const Size(40, 40),
                    ),
                    onPressed:
                        _saving || PlanItemDraft.parseList(_text.text).isEmpty
                        ? null
                        : _send,
                    icon: _saving
                        ? SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: isDark ? Colors.white : (g.merlot ? Colors.white : g.clay),
                              strokeWidth: 2,
                            ),
                          )
                        : Icon(
                            Icons.arrow_upward_rounded,
                            size: 20,
                            color: isDark ? Colors.white : (g.merlot ? Colors.white : g.clay),
                          ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 4, right: 4),
                child: AscentOptionRow(
                  children: [
                    PopupMenuButton<ActivityKind>(
                      tooltip: 'Activity type',
                      enabled: !_saving,
                      onSelected: (kind) {
                        setState(() => _kind = kind);
                        if (kind == ActivityKind.duration) _duration();
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: ActivityKind.todo,
                          child: Text(AppCopy.typeTodo),
                        ),
                        PopupMenuItem(
                          value: ActivityKind.duration,
                          child: Text(AppCopy.typeTimer),
                        ),
                        PopupMenuItem(
                          value: ActivityKind.flexible,
                          child: Text(AppCopy.typeFlexible),
                        ),
                      ],
                      child: option(
                        _kind == ActivityKind.todo
                            ? AppCopy.typeTodo
                            : _kind == ActivityKind.duration
                            ? AppCopy.typeTimer
                            : AppCopy.typeFlexible,
                        _kind == ActivityKind.todo
                            ? Icons.check_circle_outline
                            : Icons.timer_outlined,
                        value: _kind == ActivityKind.duration
                            ? '$_minutes min'
                            : null,
                      ),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Activity date',
                      enabled: !_saving,
                      onSelected: _pickDate,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'today',
                          child: Text(AppCopy.dateToday),
                        ),
                        PopupMenuItem(
                          value: 'tomorrow',
                          child: Text(AppCopy.dateTomorrow),
                        ),
                        PopupMenuItem(value: 'pick', child: Text('Pick date')),
                      ],
                      child: option(label, Icons.calendar_today_outlined),
                    ),
                    PopupMenuButton<String>(
                      tooltip: 'Activity reminder',
                      enabled: !_saving,
                      onSelected: _pickReminder,
                      itemBuilder: (_) => const [
                        PopupMenuItem(
                          value: 'off',
                          child: Text(AppCopy.reminderOff),
                        ),
                        PopupMenuItem(
                          value: 'time',
                          child: Text('Choose time'),
                        ),
                      ],
                      child: option(
                        _reminder == null
                            ? AppCopy.reminderOff
                            : _reminder!.format(context),
                        Icons.notifications_none,
                        selected: _reminder != null,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
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
