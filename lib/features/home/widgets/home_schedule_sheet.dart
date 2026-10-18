import 'dart:convert';
import 'package:drift/drift.dart' show InsertMode;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../core/ai/riya_alert_effects.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/home_capture_service.dart';
import '../../../core/services/plan_recurrence_engine.dart';
import '../../../core/notifications/reminder_alert_sync.dart';
import '../../../app/theme/frozen_palette.dart';
import '../../../app/theme/color_tokens.dart';

const homePendingScheduleKey = 'ascent_home_pending_schedule';

final homeScheduleEffectsProvider = Provider<RiyaAlertEffects>(
  (ref) => RiyaAlertEffects.device(ref.watch(databaseProvider)),
);

Future<void> showHomeSchedule(
  BuildContext context,
  Thought thought, {
  String? initialText,
}) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => HomeScheduleSheet(
        thought: thought,
        initialText: initialText,
      ),
    );

class HomeScheduleSheet extends ConsumerStatefulWidget {
  const HomeScheduleSheet({
    super.key,
    required this.thought,
    this.initialText,
  });

  final Thought thought;
  final String? initialText;

  @override
  ConsumerState<HomeScheduleSheet> createState() => _HomeScheduleSheetState();
}

class _HomeScheduleSheetState extends ConsumerState<HomeScheduleSheet> {
  late final TextEditingController _title;
  DateTime? _at, _checkAt;
  int? _minutes;
  bool _follow = false, _todo = true, _busy = false;
  final bool _remind = true;
  String _recurrenceRule = 'once';
  String _checkInPolicy = 'once';
  late DateTime _startDate;
  late DateTime _endDate;
  bool _needsEndClarification = false;
  bool _needsTimeClarification = false;
  String? _error;
  Future<void> _writes = Future.value();

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _startDate = DateTime(now.year, now.month, now.day);
    _endDate = _startDate.add(const Duration(days: 14));

    final proposal = HomeCaptureProposal.parse(
      widget.initialText ?? widget.thought.content,
      now,
    );

    _title = TextEditingController(text: proposal.title);
    _at = proposal.at;
    _minutes = proposal.minutes;
    _follow = proposal.followUp;
    _recurrenceRule = proposal.recurrenceRule;
    _checkInPolicy = proposal.checkInPolicy == 'off' ? 'once' : proposal.checkInPolicy;
    _needsEndClarification = proposal.needsEndClarification;
    _needsTimeClarification = proposal.needsTimeClarification;

    if (proposal.endDate != null) {
      try {
        _endDate = PlanRecurrenceEngine.parseDate(proposal.endDate!);
      } catch (_) {}
    }

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
        _recurrenceRule = saved['recurrenceRule'] as String? ?? _recurrenceRule;
        _checkInPolicy = saved['checkInPolicy'] as String? ?? _checkInPolicy;
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
      'recurrenceRule': _recurrenceRule,
      'checkInPolicy': _checkInPolicy,
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

  Future<DateTime?> _pickDateTime(DateTime? initial) async {
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

  String _formatTime(DateTime? date) =>
      date == null ? '7:00 am' : DateFormat('h:mm a').format(date);

  Future<void> _save() async {
    if (_busy) return;
    if (_at == null) {
      // Default to tomorrow 7 am if user hasn't tapped picker for a routine
      final now = DateTime.now();
      _at = DateTime(now.year, now.month, now.day + 1, 7, 0);
    }

    if (_follow && (_checkAt == null || !_checkAt!.isAfter(_at!))) {
      _checkAt = _at!.add(Duration(minutes: (_minutes ?? 30) + 10));
    }

    if (_at == null ||
        !_at!.isAfter(DateTime.now()) ||
        (_follow && (_checkAt == null || !_checkAt!.isAfter(_at!)))) {
      // For routines that start tomorrow, check if start is in future
      if (_recurrenceRule == 'once' && (_at == null || !_at!.isAfter(DateTime.now()))) {
        setState(
          () => _error = 'Choose a future reminder and a later check-in time.',
        );
        return;
      }
    }

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      await _writes;
      final db = ref.read(databaseProvider);
      final isRecurring = _recurrenceRule != 'once';

      if (isRecurring) {
        final planService = ref.read(planServiceProvider);

        DateTime effectiveStartDate = _startDate;
        final scheduledToday = DateTime(
          _startDate.year,
          _startDate.month,
          _startDate.day,
          _at!.hour,
          _at!.minute,
        );
        if (scheduledToday.isBefore(DateTime.now())) {
          effectiveStartDate = _startDate.add(const Duration(days: 1));
          if (_endDate.isBefore(effectiveStartDate)) {
            _endDate = effectiveStartDate.add(const Duration(days: 14));
          }
        }
        final startDateStr = PlanRecurrenceEngine.formatDate(effectiveStartDate);
        final endDateStr = PlanRecurrenceEngine.formatDate(_endDate);
        final localTimeStr =
            '${_at!.hour.toString().padLeft(2, '0')}:${_at!.minute.toString().padLeft(2, '0')}';

        final plan = await planService.createPlan(
          title: _title.text,
          startDate: startDateStr,
          endDate: endDateStr,
          recurrenceRule: _recurrenceRule,
          localTime: localTimeStr,
          sourceThoughtId: widget.thought.id,
          addTodo: _todo,
          reminderPolicy: _remind ? 'at_start' : 'none',
          checkInPolicy: _follow ? _checkInPolicy : 'off',
          expectedDurationMinutes: _minutes,
        );

        // Record receipt so Up next / Home captures recognize it
        final occurrences = await db.planDao.getOccurrencesForPlan(plan.id);
        final firstOcc = occurrences.firstOrNull;
        final links = firstOcc != null
            ? await db.planDao.getAlertLinksForOccurrence(firstOcc.id)
            : const <OccurrenceAlertLink>[];
        final startRem = links.where((l) => l.role == 'start').firstOrNull;
        final checkRem = links.where((l) => l.role == 'check_in').firstOrNull;

        if (startRem != null) {
          await db.into(db.aiCommandTable).insert(
            AiCommandTableCompanion.insert(
              requestId: 'home.schedule:${widget.thought.id}',
              capability: HomeCaptureService.capability,
              argumentsJson: jsonEncode({
                'thoughtId': widget.thought.id,
                'taskId': firstOcc?.linkedTaskId,
                'reminderId': startRem.reminderId,
                'checkInId': checkRem?.reminderId,
                'title': _title.text.trim(),
                'at': _at!.toIso8601String(),
                'checkAt': _checkAt?.toIso8601String(),
                'linkedTodo': _todo,
                'planId': plan.id,
              }),
              resultJson: jsonEncode({
                'reminderIds': [startRem.reminderId, if (checkRem != null) checkRem.reminderId],
                'taskIds': [if (firstOcc?.linkedTaskId != null) firstOcc!.linkedTaskId!],
                'alertEffectsPending': true,
              }),
            ),
            mode: InsertMode.insertOrReplace,
          );
        }

        try {
          await ReminderAlertSync.device(db).sync(onlyPending: true);
        } catch (_) {}

        await ref.read(sharedPreferencesProvider).remove(homePendingScheduleKey);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Routine created. ${_todo ? 'Activities scheduled in Today. ' : ''}Reminders ready.',
            ),
          ),
        );
        if (Navigator.canPop(context)) Navigator.pop(context);
      } else {
        // One-time plan
        final plan = await HomeCaptureService(db).schedule(
          source: widget.thought,
          title: _title.text,
          at: _at!,
          checkInAt: _follow ? _checkAt : null,
          linkedTodo: _todo,
        );

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
        if (Navigator.canPop(context)) Navigator.pop(context);
      }
    } catch (e, s) {
      debugPrint('Schedule failed: $e\n$s');
      if (mounted) {
        setState(
          () => _error = e is StateError || e is ArgumentError
              ? e.toString().replaceFirst(
                  RegExp(r'^(Bad state|Invalid argument\(s\)): '),
                  '',
                )
              : 'Could not schedule: ${e.toString().split('\n').first}',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isRecurring = _recurrenceRule != 'once';

    return PopScope(
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

              // Recurrence Selector
              const SizedBox(height: 8),
              Text(
                'Schedule',
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: Text(
                      'Once',
                      style: TextStyle(
                        color: _recurrenceRule == 'once'
                            ? (isDark ? FrozenPalette.darkCanvas : AscentColors.bgSurface)
                            : (isDark ? FrozenPalette.darkAction : FrozenPalette.action),
                        fontWeight: _recurrenceRule == 'once' ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    selected: _recurrenceRule == 'once',
                    selectedColor: isDark ? FrozenPalette.darkAction : FrozenPalette.action,
                    checkmarkColor: isDark ? FrozenPalette.darkCanvas : AscentColors.bgSurface,
                    onSelected: (selected) {
                      if (selected) setState(() => _recurrenceRule = 'once');
                      _persist();
                    },
                  ),
                  ChoiceChip(
                    label: Text(
                      'Every day',
                      style: TextStyle(
                        color: _recurrenceRule == 'daily'
                            ? (isDark ? FrozenPalette.darkCanvas : AscentColors.bgSurface)
                            : (isDark ? FrozenPalette.darkAction : FrozenPalette.action),
                        fontWeight: _recurrenceRule == 'daily' ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    selected: _recurrenceRule == 'daily',
                    selectedColor: isDark ? FrozenPalette.darkAction : FrozenPalette.action,
                    checkmarkColor: isDark ? FrozenPalette.darkCanvas : AscentColors.bgSurface,
                    onSelected: (selected) {
                      if (selected) setState(() => _recurrenceRule = 'daily');
                      _persist();
                    },
                  ),
                  ChoiceChip(
                    label: Text(
                      'Weekdays',
                      style: TextStyle(
                        color: _recurrenceRule == 'weekdays'
                            ? (isDark ? FrozenPalette.darkCanvas : AscentColors.bgSurface)
                            : (isDark ? FrozenPalette.darkAction : FrozenPalette.action),
                        fontWeight: _recurrenceRule == 'weekdays' ? FontWeight.w600 : FontWeight.w500,
                      ),
                    ),
                    selected: _recurrenceRule == 'weekdays',
                    selectedColor: isDark ? FrozenPalette.darkAction : FrozenPalette.action,
                    checkmarkColor: isDark ? FrozenPalette.darkCanvas : AscentColors.bgSurface,
                    onSelected: (selected) {
                      if (selected) setState(() => _recurrenceRule = 'weekdays');
                      _persist();
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Time Clarification prompt if ambiguous
              if (_needsTimeClarification)
                Container(
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: Colors.orange.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.help_outline_rounded, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      const Expanded(child: Text('7 am or 7 pm?')),
                      ActionChip(
                        label: const Text('7:00 am'),
                        onPressed: () {
                          setState(() {
                            final base = _at ?? DateTime.now();
                            _at = DateTime(base.year, base.month, base.day, 7, 0);
                            _needsTimeClarification = false;
                          });
                        },
                      ),
                      const SizedBox(width: 6),
                      ActionChip(
                        label: const Text('7:00 pm'),
                        onPressed: () {
                          setState(() {
                            final base = _at ?? DateTime.now();
                            _at = DateTime(base.year, base.month, base.day, 19, 0);
                            _needsTimeClarification = false;
                          });
                        },
                      ),
                    ],
                  ),
                ),

              // Date / Time picker
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.schedule),
                title: Text(isRecurring ? 'Session time' : 'Remind me'),
                subtitle: Text(isRecurring ? _formatTime(_at) : _date(_at)),
                trailing: const Icon(Icons.edit_outlined),
                onTap: _busy
                    ? null
                    : () async {
                        final value = await _pickDateTime(_at);
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
                            _needsTimeClarification = false;
                          });
                          _persist();
                        }
                      },
              ),

              // End date selection for routines
              if (isRecurring) ...[
                if (_needsEndClarification)
                  Padding(
                    padding: const EdgeInsets.only(top: 4, bottom: 4),
                    child: Text(
                      'Please confirm how long this routine should run:',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: isDark ? FrozenPalette.darkActionBright : FrozenPalette.action,
                      ),
                    ),
                  ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.calendar_today_outlined),
                  title: const Text('Until when?'),
                  subtitle: Text(DateFormat('EEE, d MMM y').format(_endDate)),
                  trailing: const Icon(Icons.edit_outlined),
                  onTap: _busy
                      ? null
                      : () async {
                          final date = await showDatePicker(
                            context: context,
                            initialDate: _endDate,
                            firstDate: _startDate,
                            lastDate: DateTime(_startDate.year + 2),
                          );
                          if (date != null && mounted) {
                            setState(() {
                              _endDate = date;
                              _needsEndClarification = false;
                            });
                            _persist();
                          }
                        },
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    ActionChip(
                      label: const Text('For 7 days'),
                      onPressed: () {
                        setState(() {
                          _endDate = _startDate.add(const Duration(days: 7));
                          _needsEndClarification = false;
                        });
                        _persist();
                      },
                    ),
                    ActionChip(
                      label: const Text('For 30 days'),
                      onPressed: () {
                        setState(() {
                          _endDate = _startDate.add(const Duration(days: 30));
                          _needsEndClarification = false;
                        });
                        _persist();
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
              ],

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

              if (_follow) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 8),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ChoiceChip(
                        label: Text(
                          'Once',
                          style: TextStyle(
                            color: _checkInPolicy == 'once'
                                ? (isDark ? FrozenPalette.darkCanvas : AscentColors.bgSurface)
                                : (isDark ? FrozenPalette.darkAction : FrozenPalette.action),
                            fontWeight: _checkInPolicy == 'once' ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        selected: _checkInPolicy == 'once',
                        selectedColor: isDark ? FrozenPalette.darkAction : FrozenPalette.action,
                        checkmarkColor: isDark ? FrozenPalette.darkCanvas : AscentColors.bgSurface,
                        onSelected: (selected) {
                          if (selected) setState(() => _checkInPolicy = 'once');
                          _persist();
                        },
                      ),
                      ChoiceChip(
                        label: Text(
                          'Gentle (Retries)',
                          style: TextStyle(
                            color: _checkInPolicy == 'gentle'
                                ? (isDark ? FrozenPalette.darkCanvas : AscentColors.bgSurface)
                                : (isDark ? FrozenPalette.darkAction : FrozenPalette.action),
                            fontWeight: _checkInPolicy == 'gentle' ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                        selected: _checkInPolicy == 'gentle',
                        selectedColor: isDark ? FrozenPalette.darkAction : FrozenPalette.action,
                        checkmarkColor: isDark ? FrozenPalette.darkCanvas : AscentColors.bgSurface,
                        onSelected: (selected) {
                          if (selected) setState(() => _checkInPolicy = 'gentle');
                          _persist();
                        },
                      ),
                    ],
                  ),
                ),
                if (!isRecurring)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Check in'),
                    subtitle: Text(_date(_checkAt)),
                    trailing: const Icon(Icons.edit_outlined),
                    onTap: _busy
                        ? null
                        : () async {
                            final value = await _pickDateTime(_checkAt);
                            if (value != null && mounted) {
                              setState(() => _checkAt = value);
                              _persist();
                            }
                          },
                  ),
                if (isRecurring && _checkInPolicy == 'gentle')
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      'Asks after expected session, then retries at +30m and +90m if unanswered.',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                    ),
                  ),
              ],

              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Notifications need permission. The duration sets your check-in time; it doesn’t start a timer.',
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
                  label: Text(_busy
                      ? 'Scheduling…'
                      : (isRecurring ? 'Create routine' : 'Schedule')),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
