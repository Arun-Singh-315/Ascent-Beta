import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_input_bar.dart';
import '../../../shared/widgets/note_list_button.dart';
import '../../../core/services/note_draft_binding.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../../shared/widgets/ascent_star_button.dart';
import '../../../shared/widgets/ascent_switch_row.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../shared/widgets/schedule_picker.dart';
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
import '../../today/models/things_intelligence.dart';
import '../../../core/services/quick_add_parser.dart';
import '../../../shared/widgets/ascent_action_menu.dart';
import '../../../shared/widgets/glass_chip.dart';
import '../../../shared/widgets/undo_snackbar.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_dialog.dart';
import '../../../shared/widgets/ascent_sheet.dart';
import '../../../app/theme/text_styles.dart';

/// Type first. Optional controls keep the normal path to a single send.
class ActivityComposer extends ConsumerStatefulWidget {
  const ActivityComposer({
    super.key,
    this.focusNode,
    this.initialTitle,
    this.notes,
    this.linkedThoughtId,
    this.onSaved,
    this.remind = false,
  });
  final FocusNode? focusNode;
  final String? initialTitle;

  /// Saved as the to-do's notes (e.g. the rest of a converted thought).
  final String? notes;

  /// The thought this to-do comes from; the two stay linked.
  final int? linkedThoughtId;

  /// Called with the new task ids after a successful save.
  final ValueChanged<List<int>>? onSaved;

  /// Start with a reminder on (as if "remind me" was typed). The user can
  /// still remove it from its chip.
  final bool remind;
  @override
  ConsumerState<ActivityComposer> createState() => _ActivityComposerState();
}

class _ActivityComposerState extends ConsumerState<ActivityComposer> {
  final _text = TextEditingController();
  NoteDraftBinding? _draft;
  FocusNode? _internalFocus;
  FocusNode get _effectiveFocus =>
      widget.focusNode ?? (_internalFocus ??= FocusNode());
  ActivityKind _kind = ActivityKind.todo;
  int _minutes = 30;
  DateTime? _date;
  TimeOfDay? _reminder;
  bool _saving = false;
  bool _starred = false;
  bool _isDailyStanding = false;
  String? _error;

  /// Time set by tapping the time chip; wins over the typed time.
  TimeOfDay? _time;

  /// Parsed details the user removed; their words stay in the title.
  final Set<QuickAddField> _ignored = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialTitle == null) {
      try {
        final prefs = ref.read(sharedPreferencesProvider);
        _draft = NoteDraftBinding(_text, prefs, 'home_activity');
      } catch (_) {}
    } else {
      _text.text = widget.initialTitle!;
    }
    _text.addListener(_changed);
    _effectiveFocus.addListener(_changed);
  }

  void _changed() {
    if (_text.text.trim().isEmpty) _ignored.clear();
    if (mounted) setState(() {});
  }

  /// Natural-language details for a single line. Lists ("- a\n- b") are
  /// saved as separate plain to-dos, as before.
  QuickAddResult? _parse() {
    final entries = PlanItemDraft.parseList(_text.text);
    if (entries.length != 1) return null;
    return parseQuickAdd(entries.single, DateTime.now(), ignore: _ignored);
  }

  /// Day: chosen in options, else typed, else today.
  DateTime _effectiveDay(QuickAddResult? parsed) {
    final d = _date ?? parsed?.day ?? DateTime.now();
    return DateTime(d.year, d.month, d.day);
  }

  TimeOfDay? _effectiveTime(QuickAddResult? parsed) =>
      _time ??
      (parsed?.hour == null
          ? null
          : TimeOfDay(hour: parsed!.hour!, minute: parsed.minute ?? 0));

  int? _effectiveMinutes(QuickAddResult? parsed) => _kind == ActivityKind.todo
      ? parsed?.durationMinutes
      : _kind == ActivityKind.duration
      ? _minutes
      : null;

  bool _effectiveStar(QuickAddResult? parsed) =>
      _starred || (parsed?.starred ?? false);

  /// "Remind me" with no time: the next half hour today, 9 am on other days.
  DateTime? _effectiveReminder(QuickAddResult? parsed) {
    final day = _effectiveDay(parsed);
    if (_reminder != null) {
      return DateTime(
        day.year,
        day.month,
        day.day,
        _reminder!.hour,
        _reminder!.minute,
      );
    }
    final wantsReminder =
        (parsed?.remind ?? false) ||
        (widget.remind && !_ignored.contains(QuickAddField.reminder));
    if (!wantsReminder) return null;
    final time = _effectiveTime(parsed);
    if (time != null) {
      return DateTime(day.year, day.month, day.day, time.hour, time.minute);
    }
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (day.isAfter(today)) return DateTime(day.year, day.month, day.day, 9);
    final next = now.add(Duration(minutes: 30 - now.minute % 30));
    return DateTime(next.year, next.month, next.day, next.hour, next.minute);
  }

  static String _dayLabel(DateTime day) {
    final now = DateTime.now();
    final diff = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
    if (diff == 0) return 'Today';
    if (diff == 1) return 'Tomorrow';
    if (diff > 1 && diff < 7) return DateFormat('EEEE').format(day);
    return DateFormat('EEE, d MMM').format(day);
  }

  static String _minutesLabel(int minutes) {
    if (minutes < 60) return '$minutes min';
    final h = minutes ~/ 60, m = minutes % 60;
    return m == 0 ? '$h h' : '$h h $m min';
  }

  /// Tap a chip to change it or remove it.
  Future<void> _editChip(QuickAddField field) async {
    final canChange =
        field == QuickAddField.day ||
        field == QuickAddField.time ||
        field == QuickAddField.duration;
    final action = await showAscentActionMenu<String>(
      context: context,
      title: switch (field) {
        QuickAddField.day => 'Day',
        QuickAddField.time => 'Time',
        QuickAddField.duration => 'Timer',
        QuickAddField.reminder => 'Reminder',
        QuickAddField.star => 'Star',
      },
      actions: [
        if (canChange)
          const AscentAction('change', 'Change', Icons.edit_outlined),
        const AscentAction(
          'remove',
          'Remove',
          Icons.close_rounded,
          destructive: true,
        ),
      ],
    );
    if (!mounted || action == null) return;
    if (action == 'remove') {
      HapticFeedback.selectionClick();
      setState(() {
        _ignored.add(field);
        switch (field) {
          case QuickAddField.day:
            _date = null;
          case QuickAddField.time:
            _time = null;
          case QuickAddField.duration:
            _kind = ActivityKind.todo;
          case QuickAddField.reminder:
            _reminder = null;
          case QuickAddField.star:
            _starred = false;
        }
      });
      return;
    }
    switch (field) {
      case QuickAddField.day:
        await _pickDate('date');
      case QuickAddField.time:
        final picked = await showTimePicker(
          context: context,
          initialTime: _effectiveTime(_parse()) ?? TimeOfDay.now(),
        );
        if (picked != null && mounted) setState(() => _time = picked);
      case QuickAddField.duration:
        final typed = _parse()?.durationMinutes;
        if (_kind == ActivityKind.todo && typed != null) _minutes = typed;
        await _duration();
        if (mounted) setState(() => _kind = ActivityKind.duration);
      case QuickAddField.reminder:
      case QuickAddField.star:
        break;
    }
  }

  List<Widget> _detailChips(QuickAddResult? parsed) {
    final fields = parsed?.fields ?? const <QuickAddField>{};
    final day = _effectiveDay(parsed);
    final time = _effectiveTime(parsed);
    final minutes = _effectiveMinutes(parsed);
    final reminder = _effectiveReminder(parsed);
    Widget chip(QuickAddField field, String label, IconData icon) => GlassChip(
      key: ValueKey('quick_add_chip_${field.name}'),
      label: label,
      icon: icon,
      selected: true,
      tooltip: 'Change or remove $label',
      onTap: _saving ? null : () => _editChip(field),
    );
    return [
      if (_date != null || fields.contains(QuickAddField.day))
        chip(QuickAddField.day, _dayLabel(day), Icons.calendar_today_outlined),
      if (time != null)
        chip(QuickAddField.time, time.format(context), Icons.schedule_rounded),
      if (minutes != null)
        chip(
          QuickAddField.duration,
          _minutesLabel(minutes),
          Icons.timer_outlined,
        ),
      if (reminder != null)
        chip(
          QuickAddField.reminder,
          'Remind ${TimeOfDay.fromDateTime(reminder).format(context)}',
          Icons.notifications_none_rounded,
        ),
      if (_effectiveStar(parsed))
        chip(QuickAddField.star, 'Starred', Icons.star_rounded),
    ];
  }

  @override
  void dispose() {
    _draft?.dispose();
    _text.removeListener(_changed);
    _effectiveFocus.removeListener(_changed);
    _internalFocus?.dispose();
    _text.dispose();
    super.dispose();
  }

  DateTime get _day {
    final date = _date ?? DateTime.now();
    return DateTime(date.year, date.month, date.day);
  }

  Future<void> _duration() async {
    final picked = await showAscentFrostedDialog<int>(
      context: context,
      builder: (_) => _MinutesDialog(initial: _minutes),
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
    final parsed = _parse();
    final day = _effectiveDay(parsed);
    final time = _effectiveTime(parsed);
    final minutes = _effectiveMinutes(parsed);
    final reminderAt = _effectiveReminder(parsed);
    final titles = parsed == null ? entries : [parsed.title];
    try {
      final results = await ActivityEntryService(db).saveMany(
        titles: titles,
        date: time == null
            ? day
            : DateTime(day.year, day.month, day.day, time.hour, time.minute),
        priority: _effectiveStar(parsed) ? 'high' : 'low',
        isDailyStanding: _isDailyStanding,
        estimatedMinutes: _kind == ActivityKind.flexible ? -1 : minutes,
        reminderAt: reminderAt,
        notes: widget.notes,
        linkedThoughtId: widget.linkedThoughtId,
      );
      final reminderIds = results.expand((r) => r.reminderIds).toList();
      // Persistence succeeded. Never repeat creation because device alerts fail.
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _text.clear();
      _effectiveFocus.unfocus();
      setState(() {
        _kind = ActivityKind.todo;
        _date = null;
        _time = null;
        _reminder = null;
        _minutes = 30;
        _starred = false;
        _isDailyStanding = false;
        _ignored.clear();
      });
      final when = [
        if (day !=
            DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day,
            ))
          _dayLabel(day),
        if (time != null) time.format(context),
      ].join(' ');
      var message = results.length == 1
          ? 'Added “${titles.single}”${when.isEmpty ? '' : ' for $when'}'
          : '${results.length} to-dos added';
      if (reminderIds.isNotEmpty) {
        try {
          final sync = await ReminderAlertSync.device(
            db,
          ).sync(ids: reminderIds, onlyPending: true);
          if (!sync.complete) {
            message =
                'Saved. Reminder alert pending—check notification permissions.';
          }
        } catch (_) {
          message = 'Saved. Reminder alert pending.';
        }
      }
      if (mounted) {
        final ids = [for (final r in results) r.taskId];
        showUndoSnackbar(
          context,
          message: message,
          onUndo: () async {
            for (final id in ids) {
              await db.taskDao.deleteTask(id);
            }
          },
        );
        widget.onSaved?.call(ids);
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
    _effectiveFocus.unfocus();
    await showAscentSheet<void>(
      context: context,
      builder: (sheetContext) => StatefulBuilder(
        builder: (ctx, refresh) {
          final g = ctx.glass;
          Future<void> edit(Future<void> Function() action) async {
            await action();
            if (ctx.mounted) refresh(() {});
          }

          Future<void> chooseDate() async {
            final choice = await showAscentActionMenu<String>(
              context: ctx,
              title: 'Day',
              actions: const [
                AscentAction('today', 'Today', Icons.today_outlined),
                AscentAction('tomorrow', 'Tomorrow', Icons.next_plan_outlined),
                AscentAction('date', 'Pick a day', Icons.event_outlined),
              ],
            );
            if (choice != null) await _pickDate(choice);
          }

          Future<void> chooseReminder() async {
            final choice = await showAscentActionMenu<String>(
              context: ctx,
              title: 'Reminder',
              actions: const [
                AscentAction(
                  'time',
                  'Choose time',
                  Icons.notifications_none_rounded,
                ),
                AscentAction('off', 'Off', Icons.notifications_off_outlined),
              ],
            );
            if (choice != null) await _pickReminder(choice);
          }

          final valueStyle = AscentTextStyles.supportingText.copyWith(
            color: g.inkMuted,
          );
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
                        style: AscentTextStyles.dialogTitle.copyWith(
                          color: g.ink,
                        ),
                      ),
                    ),
                    AscentButton.ghost(
                      label: 'Done',
                      compact: true,
                      onPressed: () => Navigator.pop(sheetContext),
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
                    trailing: Text('$_minutes min', style: valueStyle),
                    onTap: () => edit(_duration),
                  ),
                ListTile(
                  key: const ValueKey('activity_option_day'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined, size: 20),
                  title: const Text('Day'),
                  trailing: Text(
                    _date == null ? 'Today' : _dayLabel(_day),
                    style: valueStyle,
                  ),
                  onTap: () => edit(chooseDate),
                ),
                ListTile(
                  key: const ValueKey('activity_option_reminder'),
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(
                    Icons.notifications_none_rounded,
                    size: 20,
                  ),
                  title: const Text('Reminder'),
                  trailing: Text(
                    _reminder?.format(ctx) ?? 'Off',
                    style: valueStyle,
                  ),
                  onTap: () => edit(chooseReminder),
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
                AscentSwitchRow(
                  title: 'Keep on until I turn it off',
                  helper: _isDailyStanding
                      ? 'Repeats every day until you turn it off'
                      : 'One-time to-do',
                  value: _isDailyStanding,
                  onChanged: (val) {
                    setState(() => _isDailyStanding = val);
                    refresh(() {});
                  },
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
    final parsed = hasText ? _parse() : null;
    final customized =
        _kind != ActivityKind.todo ||
        _date != null ||
        _reminder != null ||
        _starred ||
        _isDailyStanding;
    // Day, time, timer, reminder and star show as chips above the field.
    final summary = [
      if (_kind == ActivityKind.flexible) 'Flexible timer',
      if (_isDailyStanding) 'Every day',
    ].join(' · ');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (hasText) ...[
          Builder(
            builder: (context) {
              final enrichment = ThingsEnrichmentEngine.analyzeText(_text.text);
              return Padding(
                padding: const EdgeInsets.only(
                  top: 6,
                  bottom: 4,
                  left: 6,
                  right: 6,
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    ..._detailChips(parsed),
                    // 3D Matte Squircle Category Tile & Label
                    Container(
                      padding: const EdgeInsets.fromLTRB(4, 2.5, 8, 2.5),
                      decoration: BoxDecoration(
                        color: enrichment.categoryColor.withValues(
                          alpha: g.isDark ? 0.12 : 0.06,
                        ),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: enrichment.categoryColor.withValues(
                            alpha: g.isDark ? 0.32 : 0.20,
                          ),
                          width: 0.75,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(5),
                              gradient: LinearGradient(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                                colors: [
                                  enrichment.categoryColor.withValues(
                                    alpha: g.isDark ? 0.40 : 0.30,
                                  ),
                                  enrichment.categoryColor.withValues(
                                    alpha: g.isDark ? 0.18 : 0.10,
                                  ),
                                ],
                              ),
                              border: Border.all(
                                color: enrichment.categoryColor.withValues(
                                  alpha: g.isDark ? 0.50 : 0.35,
                                ),
                                width: 0.75,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: enrichment.categoryColor.withValues(
                                    alpha: g.isDark ? 0.25 : 0.12,
                                  ),
                                  blurRadius: 3,
                                  offset: const Offset(0, 1),
                                ),
                              ],
                            ),
                            child: Center(
                              child: Icon(
                                enrichment.categoryIcon,
                                size: 10,
                                color: enrichment.categoryColor,
                              ),
                            ),
                          ),
                          const SizedBox(width: 5),
                          Flexible(
                            child: Text(
                              enrichment.categoryLabel,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: AscentTextStyles.labelSmall.copyWith(
                                color: g.ink,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (enrichment.smartLens != ThingsSmartLens.all)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: g.ink.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: g.line.withValues(alpha: 0.3),
                            width: 0.75,
                          ),
                        ),
                        child: Text(
                          enrichment.smartLens.label,
                          style: AscentTextStyles.labelSmall.copyWith(
                            color: g.inkMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ],
        const SizedBox(height: 8),
        AppInputBar(
          textFieldKey: const ValueKey('activity_quick_input'),
          submitTooltip: 'Add activity',
          controller: _text,
          focusNode: _effectiveFocus,
          hint: 'e.g. Gym 7am tomorrow 45m',
          leadingIcon: Icons.add,
          onLeadingTap: () {
            HapticFeedback.lightImpact();
            NoteListButton.insertNextItem(_text);
            _effectiveFocus.requestFocus();
          },
          extraAction: Tooltip(
            message: _isDailyStanding
                ? 'Repeats every day. Tap to make it one-time'
                : 'Repeat every day',
            child: Semantics(
              button: true,
              toggled: _isDailyStanding,
              label: 'Repeat every day',
              excludeSemantics: true,
              child: Material(
                color: Colors.transparent,
                shape: const CircleBorder(),
                child: InkWell(
                  customBorder: const CircleBorder(),
                  onTap: _saving
                      ? null
                      : () {
                          HapticFeedback.selectionClick();
                          setState(() => _isDailyStanding = !_isDailyStanding);
                        },
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(
                      minWidth: 44,
                      minHeight: 44,
                    ),
                    child: Icon(
                      Icons.repeat_rounded,
                      size: 20,
                      color: _isDailyStanding
                          ? context.c.accent
                          : context.c.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
          onSubmit: _saving || !hasText ? () {} : _send,
        ),
        if (_effectiveFocus.hasFocus || hasText || customized)
          Align(
            alignment: Alignment.centerRight,
            child: AscentButton.ghost(
              key: const ValueKey('activity_options'),
              label: summary.isEmpty ? 'Options' : 'Options · $summary',
              icon: Icons.settings_outlined,
              compact: true,
              onPressed: _saving ? null : _options,
            ),
          ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text(
              _error!,
              style: AscentTextStyles.caption.copyWith(
                color: context.glass.isDark
                    ? SharedControlColors.dueRedDark
                    : SharedControlColors.dueRed,
              ),
            ),
          ),
      ],
    );
  }
}

/// Asks for a timer length. Owns its controller so it is only disposed after
/// the dialog has finished animating out.
class _MinutesDialog extends StatefulWidget {
  const _MinutesDialog({required this.initial});
  final int initial;

  @override
  State<_MinutesDialog> createState() => _MinutesDialogState();
}

class _MinutesDialogState extends State<_MinutesDialog> {
  late final _controller = TextEditingController(text: '${widget.initial}');
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _apply() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < 1 || value > 1440) {
      setState(() => _error = 'Enter 1–1440 minutes.');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) => AscentDialog(
    title: 'Timer length',
    icon: Icons.timer_outlined,
    contentWidget: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTextField(
          key: const ValueKey('activity_duration_field'),
          controller: _controller,
          autofocus: true,
          keyboardType: TextInputType.number,
          hintText: 'Minutes, e.g. 25',
          onSubmitted: (_) => _apply(),
        ),
        if (_error != null) ...[
          const SizedBox(height: 6),
          Text(
            _error!,
            style: AscentTextStyles.caption.copyWith(
              color: context.glass.isDark
                  ? SharedControlColors.dueRedDark
                  : SharedControlColors.dueRed,
            ),
          ),
        ],
      ],
    ),
    actions: [
      Wrap(
        alignment: WrapAlignment.end,
        spacing: 8,
        runSpacing: 8,
        children: [
          AscentButton.secondary(
            label: 'Cancel',
            compact: true,
            onPressed: () => Navigator.pop(context),
          ),
          AscentButton.primary(
            label: 'Apply',
            compact: true,
            onPressed: _apply,
          ),
        ],
      ),
    ],
  );
}
