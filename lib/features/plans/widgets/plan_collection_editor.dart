import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/plan_collection_service.dart';
import '../planning_providers.dart';

Future<void> showPlanCollectionEditor(
  BuildContext context, {
  Thought? source,
  String? initialText,
  String? collectionId,
  String? draftKey,
  PlanItemView? editing,
  List<PlanItemView>? scheduling,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (_) => PlanCollectionEditor(
    source: source,
    initialText: initialText,
    collectionId: collectionId,
    draftKey: draftKey,
    editing: editing,
    scheduling: scheduling,
  ),
);

class _Item {
  _Item(
    String title, {
    this.notes = '',
    this.at,
    this.alert = 'reminder',
    this.minutes,
    this.recurrence = 'once',
    this.endDate,
    this.checkIn = false,
    this.dateOnly = false,
  }) : title = TextEditingController(text: title);
  final TextEditingController title;
  String notes, alert, recurrence;
  DateTime? at, endDate;
  int? minutes;
  bool checkIn, dateOnly;
  Map<String, dynamic> toJson() => {
    'title': title.text,
    'notes': notes,
    'at': at?.toIso8601String(),
    'alert': alert,
    'minutes': minutes,
    'recurrence': recurrence,
    'end': endDate?.toIso8601String(),
    'check': checkIn,
    'dateOnly': dateOnly,
  };
  PlanItemDraft get draft => PlanItemDraft(
    title: title.text,
    notes: notes,
    at: at,
    alert: alert,
    minutes: minutes,
    recurrence: recurrence,
    endDate: endDate,
    checkIn: checkIn,
    dateOnly: dateOnly,
  );
}

class PlanCollectionEditor extends ConsumerStatefulWidget {
  const PlanCollectionEditor({
    super.key,
    this.source,
    this.initialText,
    this.collectionId,
    this.editing,
    this.draftKey,
    this.scheduling,
  });
  final Thought? source;
  final String? initialText, collectionId, draftKey;
  final PlanItemView? editing;
  final List<PlanItemView>? scheduling;
  @override
  ConsumerState<PlanCollectionEditor> createState() => _EditorState();
}

class _EditorState extends ConsumerState<PlanCollectionEditor> {
  final _title = TextEditingController();
  final _description = TextEditingController();
  final _paste = TextEditingController();
  final _items = <_Item>[];
  late String _request;
  String? _destination, _error;
  bool _busy = false;
  late String _draftKey;
  Future<void> _writes = Future.value();
  @override
  void initState() {
    super.initState();
    _request = planningId();
    _destination = widget.collectionId;
    _draftKey =
        widget.draftKey ??
        'planning_draft_v1:${widget.editing?.id ?? widget.collectionId ?? widget.source?.id ?? 'new'}';
    final edit = widget.editing;
    if (widget.scheduling != null) {
      _items.addAll(
        widget.scheduling!.map(
          (i) => _Item(i.title, notes: i.notes, minutes: i.minutes),
        ),
      );
      return;
    }
    if (edit != null) {
      final originalTime = edit.at;
      final next = originalTime != null && !originalTime.isAfter(DateTime.now())
          ? DateTime(
              DateTime.now().year,
              DateTime.now().month,
              DateTime.now().day + 1,
              originalTime.hour,
              originalTime.minute,
            )
          : originalTime;
      _items.add(
        _Item(
          edit.title,
          notes: edit.notes,
          at: next,
          alert: edit.alert,
          minutes: edit.minutes,
          recurrence: edit.recurrence,
          endDate: edit.endDate,
          checkIn: edit.checkIn,
          dateOnly: edit.dateOnly,
        ),
      );
    } else {
      final text = widget.initialText ?? widget.source?.content ?? '';
      _description.text = text;
      final lines = PlanItemDraft.parseList(text);
      _items.addAll(
        lines.map((l) {
          final d = PlanItemDraft.fromText(l, DateTime.now());
          return _Item(
            d.title,
            at: d.at,
            recurrence: d.recurrence,
            endDate: d.endDate,
            checkIn: d.checkIn,
          );
        }),
      );
      _title.text = lines.length == 1 ? lines.first : '';
      if (_items.isEmpty) _items.add(_Item(''));
      final raw = ref.read(sharedPreferencesProvider).getString(_draftKey);
      try {
        if (raw != null) {
          final saved = jsonDecode(raw) as Map;
          _request = saved['request'] as String;
          _title.text = saved['title'] as String;
          _description.text = saved['description'] as String;
          _destination = saved['destination'] as String?;
          for (final i in _items) {
            i.title.dispose();
          }
          _items.clear();
          for (final row in saved['items'] as List) {
            _items.add(
              _Item(
                row['title'] as String,
                notes: row['notes'] as String,
                at: DateTime.tryParse(row['at'] as String? ?? ''),
                alert: row['alert'] as String,
                minutes: row['minutes'] as int?,
                recurrence: row['recurrence'] as String,
                endDate: DateTime.tryParse(row['end'] as String? ?? ''),
                checkIn: row['check'] as bool,
                dateOnly: row['dateOnly'] as bool? ?? false,
              ),
            );
          }
        }
      } catch (_) {
        _error =
            'The saved draft could not be restored. Your source note is unchanged.';
      }
    }
  }

  void _persist() {
    if (widget.editing != null || widget.scheduling != null) return;
    final raw = jsonEncode({
      'request': _request,
      'title': _title.text,
      'description': _description.text,
      'destination': _destination,
      'sourceId': widget.source?.id,
      'updatedAt': DateTime.now().millisecondsSinceEpoch,
      'items': _items.map((i) => i.toJson()).toList(),
    });
    final prefs = ref.read(sharedPreferencesProvider);
    _writes = _writes.then((_) async {
      await prefs.setString(_draftKey, raw);
    });
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _paste.dispose();
    for (final i in _items) {
      i.title.dispose();
    }
    super.dispose();
  }

  void _changed() {
    setState(() {});
    _persist();
  }

  Future<void> _settings(int index) async {
    FocusScope.of(context).unfocus();
    final item = _items[index];
    final result = await showModalBottomSheet<PlanItemDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => _ItemSettings(initial: item.draft),
    );
    if (result == null || !mounted) return;
    item.title.text = result.title;
    item.notes = result.notes;
    item.at = result.at;
    item.alert = result.alert;
    item.minutes = result.minutes;
    item.recurrence = result.recurrence;
    item.endDate = result.endDate;
    item.checkIn = result.checkIn;
    item.dateOnly = result.dateOnly;
    _changed();
  }

  Future<void> _defaults() async {
    FocusScope.of(context).unfocus();
    final result = await showModalBottomSheet<_Defaults>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _DefaultsSheet(),
    );
    if (result == null || !mounted) return;
    var at = result.at;
    for (final item in _items) {
      // Existing explicit schedules stay pinned.
      if (item.at == null) {
        item.at = at;
        item.dateOnly = false;
        item.alert = result.alert;
      }
      at = (item.at ?? at).add(
        Duration(
          minutes: item.minutes == null ? result.spacing : item.minutes! + 10,
        ),
      );
    }
    _changed();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final service = ref.read(planCollectionServiceProvider);
    try {
      await _writes;
      if (widget.scheduling != null) {
        await service.updateItems(
          widget.scheduling!,
          _items.map((i) => i.draft).toList(),
        );
      } else if (widget.editing != null) {
        await service.updateItem(widget.editing!, _items.single.draft);
      } else {
        await service.save(
          title: _title.text.isEmpty && _destination != null
              ? 'Existing plan'
              : _title.text,
          description: _description.text,
          items: _items.map((i) => i.draft).toList(),
          requestId: _request,
          sourceThoughtId: widget.source?.id,
          collectionId: _destination,
        );
      }
      await ref.read(sharedPreferencesProvider).remove(_draftKey);
      var message = 'Plan saved.';
      try {
        final effects = ref.read(planningAlertSyncProvider);
        if (_items.any(
              (i) =>
                  i.at != null &&
                  !i.dateOnly &&
                  (i.alert != 'none' || i.checkIn),
            ) &&
            !await effects.enabled()) {
          await ref.read(planningRequestPermissionsProvider)();
        }
        final sync = await ref
            .read(planningAlertSyncProvider)
            .sync(onlyPending: true)
            .timeout(const Duration(seconds: 8));
        if (!sync.complete) {
          message = 'Saved · alerts need attention. Open the plan to retry.';
        }
      } catch (_) {
        message = 'Saved · alerts need attention. Open the plan to retry.';
      }
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(message)));
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString().replaceFirst('Invalid argument(s): ', '');
          _busy = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final collections = ref.watch(planCollectionsProvider).value ?? [];
    final scheduled = _items.where((i) => i.at != null).length;
    final alarms = _items
        .where((i) => i.at != null && !i.dateOnly && i.alert == 'alarm')
        .length;
    final reminders = _items
        .where((i) => i.at != null && !i.dateOnly && i.alert == 'reminder')
        .length;
    final times = _items.where((i) => i.at != null).map((i) => i.at!).toList();
    final overlap = times.toSet().length != times.length;
    return PopScope(
      canPop: !_busy,
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SizedBox(
          height: MediaQuery.sizeOf(context).height * .9,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSpace.s16),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        widget.scheduling != null
                            ? 'Schedule remaining'
                            : widget.editing != null
                            ? 'Edit item'
                            : _destination != null
                            ? 'Add to plan'
                            : 'Make a plan',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _busy ? null : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
                  children: [
                    if (widget.editing == null &&
                        widget.scheduling == null) ...[
                      if (widget.collectionId == null)
                        DropdownButtonFormField<String>(
                          initialValue: _destination ?? '',
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Destination',
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: '',
                              child: Text('Create a new plan'),
                            ),
                            for (final c in collections.where(
                              (c) => c.status == 'active',
                            ))
                              DropdownMenuItem(
                                value: c.id,
                                child: Text(
                                  '${c.title} · ${c.total} items',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                          ],
                          onChanged: _busy
                              ? null
                              : (v) {
                                  _destination = v == '' ? null : v;
                                  _changed();
                                },
                        ),
                      if (_destination == null) ...[
                        TextField(
                          controller: _title,
                          maxLength: 300,
                          enabled: !_busy,
                          onChanged: (_) => _persist(),
                          decoration: const InputDecoration(
                            labelText: 'Plan name',
                            hintText: 'e.g. Interview preparation',
                          ),
                        ),
                        TextField(
                          controller: _description,
                          maxLines: 2,
                          maxLength: 20000,
                          enabled: !_busy,
                          onChanged: (_) => _persist(),
                          decoration: const InputDecoration(
                            labelText: 'Notes / original thought',
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpace.s12),
                      Text(
                        'Your checklist',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const Text(
                        'Each row becomes one item. Add times now or leave items unscheduled.',
                      ),
                    ],
                    for (var n = 0; n < _items.length; n++)
                      Padding(
                        key: ObjectKey(_items[n]),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.s8,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: g.fill,
                            border: Border.all(color: g.edge),
                            borderRadius: AppGeometry.roundedr16,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpace.s12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Padding(
                                      padding: const EdgeInsets.only(
                                        top: AppSpace.s16,
                                      ),
                                      child: Text(
                                        '${n + 1}.',
                                        style: TextStyle(color: g.inkMuted),
                                      ),
                                    ),
                                    const SizedBox(width: AppSpace.s8),
                                    Expanded(
                                      child: TextField(
                                        controller: _items[n].title,
                                        maxLength: 300,
                                        minLines: 1,
                                        maxLines: 4,
                                        enabled: !_busy,
                                        textInputAction: TextInputAction.next,
                                        onChanged: (_) => _persist(),
                                        onSubmitted: (_) {
                                          if (widget.editing == null &&
                                              _items.length < 200) {
                                            setState(
                                              () => _items.add(_Item('')),
                                            );
                                            _persist();
                                          }
                                        },
                                        decoration: const InputDecoration(
                                          hintText: 'What needs doing?',
                                          counterText: '',
                                        ),
                                      ),
                                    ),
                                    if (widget.editing == null &&
                                        widget.scheduling == null)
                                      IconButton(
                                        tooltip: 'Remove item',
                                        onPressed: _busy
                                            ? null
                                            : () {
                                                final removed = _items.removeAt(
                                                  n,
                                                );
                                                setState(() {});
                                                _persist();
                                                // Dispose after the TextField has unmounted.
                                                WidgetsBinding.instance
                                                    .addPostFrameCallback((_) {
                                                      removed.title.dispose();
                                                    });
                                              },
                                        icon: const Icon(Icons.close, size: 18),
                                      ),
                                  ],
                                ),
                                Text(
                                  _items[n].at == null
                                      ? 'Not scheduled'
                                      : DateFormat(
                                          _items[n].dateOnly
                                              ? 'EEE, d MMM'
                                              : 'EEE, d MMM · h:mm a',
                                        ).format(_items[n].at!),
                                  style: TextStyle(color: g.inkSecondary),
                                ),
                                Wrap(
                                  spacing: AppSpace.s8,
                                  crossAxisAlignment: WrapCrossAlignment.center,
                                  children: [
                                    TextButton.icon(
                                      onPressed: _busy
                                          ? null
                                          : () => _settings(n),
                                      icon: const Icon(Icons.tune, size: 18),
                                      label: Text(
                                        _items[n].at == null
                                            ? 'Time & details'
                                            : '${_items[n].alert} · ${_items[n].recurrence}',
                                      ),
                                    ),
                                    if (n > 0 && widget.editing == null)
                                      IconButton(
                                        tooltip: 'Move item up',
                                        onPressed: _busy
                                            ? null
                                            : () {
                                                final item = _items.removeAt(n);
                                                _items.insert(n - 1, item);
                                                _changed();
                                              },
                                        icon: const Icon(
                                          Icons.arrow_upward,
                                          size: 18,
                                        ),
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (widget.editing == null &&
                        widget.scheduling == null) ...[
                      Wrap(
                        spacing: AppSpace.s8,
                        children: [
                          TextButton.icon(
                            onPressed: _busy || _items.length >= 200
                                ? null
                                : () {
                                    _items.add(_Item(''));
                                    _changed();
                                  },
                            icon: const Icon(Icons.playlist_add),
                            label: const Text('Add next item →'),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () async {
                                    final text = await showDialog<String>(
                                      context: context,
                                      builder: (ctx) => AlertDialog(
                                        title: const Text('Paste a list'),
                                        content: TextField(
                                          controller: _paste,
                                          minLines: 4,
                                          maxLines: 8,
                                          decoration: const InputDecoration(
                                            hintText:
                                                '-- First item\n--> Second item',
                                          ),
                                        ),
                                        actions: [
                                          TextButton(
                                            onPressed: () => Navigator.pop(ctx),
                                            child: const Text('Cancel'),
                                          ),
                                          FilledButton(
                                            onPressed: () =>
                                                Navigator.pop(ctx, _paste.text),
                                            child: const Text('Review items'),
                                          ),
                                        ],
                                      ),
                                    );
                                    if (text == null || !mounted) return;
                                    final lines = PlanItemDraft.parseList(text);
                                    if (lines.length + _items.length > 200) {
                                      setState(
                                        () => _error =
                                            'A plan can hold up to 200 items.',
                                      );
                                      return;
                                    }
                                    _items.addAll(
                                      lines.map((l) {
                                        final d = PlanItemDraft.fromText(
                                          l,
                                          DateTime.now(),
                                        );
                                        return _Item(
                                          d.title,
                                          at: d.at,
                                          recurrence: d.recurrence,
                                          endDate: d.endDate,
                                          checkIn: d.checkIn,
                                        );
                                      }),
                                    );
                                    _paste.clear();
                                    _changed();
                                  },
                            child: const Text('Paste list'),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: AppSpace.s8,
                        runSpacing: AppSpace.s8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _defaults,
                            icon: const Icon(Icons.auto_fix_high),
                            label: const Text('Use schedule defaults'),
                          ),
                          TextButton(
                            onPressed: _busy
                                ? null
                                : () {
                                    for (final i in _items) {
                                      i.at = null;
                                      i.recurrence = 'once';
                                      i.checkIn = false;
                                    }
                                    _changed();
                                  },
                            child: const Text('Save without times'),
                          ),
                        ],
                      ),
                    ],
                    if (widget.scheduling != null)
                      OutlinedButton.icon(
                        onPressed: _busy ? null : _defaults,
                        icon: const Icon(Icons.auto_fix_high),
                        label: const Text('Use schedule defaults'),
                      ),
                    const SizedBox(height: AppSpace.s12),
                    Text(
                      '${_items.length} items · $scheduled scheduled · $reminders reminders · $alarms alarms',
                      style: TextStyle(color: g.inkSecondary),
                    ),
                    if (overlap)
                      Text(
                        'Some items share a time. You can keep them or edit their times.',
                        style: TextStyle(color: g.clay),
                      ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.all(AppSpace.s8),
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: AppSpace.s16),
                  ],
                ),
              ),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.all(AppSpace.s16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _busy ? null : _save,
                      child: Text(
                        _busy
                            ? 'Saving…'
                            : widget.scheduling != null
                            ? 'Save schedules'
                            : widget.editing != null
                            ? 'Save changes'
                            : 'Save plan',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ItemSettings extends StatefulWidget {
  const _ItemSettings({required this.initial});
  final PlanItemDraft initial;
  @override
  State<_ItemSettings> createState() => _SettingsState();
}

class _SettingsState extends State<_ItemSettings> {
  late DateTime? _at, _end;
  late String _alert, _repeat;
  late bool _check;
  bool _dateOnly = false;
  late TextEditingController _notes, _minutes;
  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _at = d.at;
    _end = d.endDate;
    _alert = d.alert;
    _repeat = d.recurrence;
    _check = d.checkIn;
    _dateOnly = d.dateOnly;
    _notes = TextEditingController(text: d.notes);
    _minutes = TextEditingController(text: d.minutes?.toString() ?? '');
  }

  @override
  void dispose() {
    _notes.dispose();
    _minutes.dispose();
    super.dispose();
  }

  Future<void> _pick() async {
    final now = DateTime.now();
    final day = await showDatePicker(
      context: context,
      initialDate: (_at?.isAfter(now) ?? false) ? _at : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
    );
    if (day == null || !mounted) return;
    if (_dateOnly) {
      setState(() => _at = day);
      return;
    }
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_at ?? now),
    );
    if (time != null && mounted) {
      setState(
        () => _at = DateTime(
          day.year,
          day.month,
          day.day,
          time.hour,
          time.minute,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.only(
      left: AppSpace.s16,
      right: AppSpace.s16,
      top: AppSpace.s16,
      bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.s16,
    ),
    child: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Item details', style: Theme.of(context).textTheme.titleLarge),
          TextButton.icon(
            onPressed: _pick,
            icon: const Icon(Icons.schedule),
            label: Text(
              _at == null
                  ? 'Choose date and time'
                  : _dateOnly
                  ? DateFormat('EEE, d MMM').format(_at!)
                  : DateFormat('EEE, d MMM · h:mm a').format(_at!),
            ),
          ),
          if (_at != null)
            TextButton(
              onPressed: () => setState(() {
                _at = null;
                _repeat = 'once';
                _check = false;
              }),
              child: const Text('Remove schedule'),
            ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Date only · no alert'),
            value: _dateOnly,
            onChanged: (v) => setState(() {
              _dateOnly = v;
              if (v) {
                _repeat = 'once';
                _alert = 'none';
                if (_at != null) {
                  _at = DateTime(_at!.year, _at!.month, _at!.day);
                }
                _check = false;
              }
            }),
          ),
          DropdownButtonFormField<String>(
            initialValue: _alert,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Alert'),
            items: [
              for (final a in ['none', 'reminder', 'alarm'])
                DropdownMenuItem(
                  value: a,
                  child: Text(
                    a == 'none'
                        ? 'No alert'
                        : a == 'alarm'
                        ? 'Alarm'
                        : 'Reminder',
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _alert = v!),
          ),
          DropdownButtonFormField<String>(
            initialValue: _repeat,
            isExpanded: true,
            decoration: const InputDecoration(labelText: 'Repeat'),
            items: [
              for (final r in ['once', 'daily', 'weekdays'])
                DropdownMenuItem(
                  value: r,
                  child: Text(
                    r == 'once'
                        ? 'Does not repeat'
                        : r == 'daily'
                        ? 'Every day'
                        : 'Weekdays',
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _repeat = v!),
          ),
          if (_repeat != 'once')
            TextButton(
              onPressed: () async {
                final now = DateTime.now();
                final start = _at ?? now;
                final end = await showDatePicker(
                  context: context,
                  initialDate: _end ?? start.add(const Duration(days: 14)),
                  firstDate: start,
                  lastDate: start.add(const Duration(days: 90)),
                );
                if (end != null && mounted) setState(() => _end = end);
              },
              child: Text(
                _end == null
                    ? 'Choose repeat end date'
                    : 'Until ${DateFormat.yMMMd().format(_end!)}',
              ),
            ),
          TextField(
            controller: _minutes,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Focus duration in minutes (optional)',
              helperText: 'Leave blank for a simple checkable to-do.',
            ),
          ),
          TextField(
            controller: _notes,
            maxLines: 3,
            maxLength: 20000,
            decoration: const InputDecoration(labelText: 'Notes'),
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Check in after this activity'),
            subtitle: const Text('One follow-up; no repeated nudges.'),
            value: _check,
            onChanged: _at == null || _dateOnly
                ? null
                : (v) => setState(() => _check = v),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(
              context,
              PlanItemDraft(
                title: widget.initial.title,
                notes: _notes.text,
                at: _at,
                alert: _alert,
                recurrence: _repeat,
                endDate: _end,
                minutes: _minutes.text.trim().isEmpty
                    ? null
                    : int.tryParse(_minutes.text) ?? 0,
                checkIn: _dateOnly ? false : _check,
                dateOnly: _dateOnly,
              ),
            ),
            child: const Text('Apply details'),
          ),
        ],
      ),
    ),
  );
}

class _Defaults {
  const _Defaults(this.at, this.spacing, this.alert);
  final DateTime at;
  final int spacing;
  final String alert;
}

class _DefaultsSheet extends ConsumerStatefulWidget {
  const _DefaultsSheet();
  @override
  ConsumerState<_DefaultsSheet> createState() => _DefaultsState();
}

class _DefaultsState extends ConsumerState<_DefaultsSheet> {
  late DateTime _at;
  int _spacing = 30;
  String _alert = 'reminder';
  bool _remember = false;
  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final p = ref.read(sharedPreferencesProvider);
    final hour = p.getInt('planning_default_hour') ?? 7;
    final minute = p.getInt('planning_default_minute') ?? 0;
    _spacing = p.getInt('planning_default_spacing') ?? 30;
    _alert = p.getString('planning_default_alert') ?? 'reminder';
    _at = DateTime(now.year, now.month, now.day + 1, hour, minute);
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Schedule defaults',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Applies only to items without a time. Review every time before saving.',
            ),
            TextButton(
              onPressed: () async {
                final now = DateTime.now();
                final day = await showDatePicker(
                  context: context,
                  initialDate: _at,
                  firstDate: DateTime(now.year, now.month, now.day),
                  lastDate: DateTime(now.year + 3),
                );
                if (day == null || !context.mounted) return;
                final t = await showTimePicker(
                  context: context,
                  initialTime: TimeOfDay.fromDateTime(_at),
                );
                if (t != null && mounted) {
                  setState(
                    () => _at = DateTime(
                      day.year,
                      day.month,
                      day.day,
                      t.hour,
                      t.minute,
                    ),
                  );
                }
              },
              child: Text(
                'First item: ${DateFormat('EEE, d MMM · h:mm a').format(_at)}',
              ),
            ),
            DropdownButtonFormField<int>(
              initialValue: _spacing,
              isExpanded: true,
              decoration: const InputDecoration(
                labelText: 'Spacing between items',
              ),
              items: [
                for (final n in [15, 30, 45, 60, 90, 120])
                  DropdownMenuItem(value: n, child: Text('$n minutes')),
              ],
              onChanged: (v) => setState(() => _spacing = v!),
            ),
            DropdownButtonFormField<String>(
              initialValue: _alert,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Alert style'),
              items: [
                for (final a in ['none', 'reminder', 'alarm'])
                  DropdownMenuItem(value: a, child: Text(a)),
              ],
              onChanged: (v) => setState(() => _alert = v!),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Use for future plans'),
              value: _remember,
              onChanged: (v) => setState(() => _remember = v),
            ),
            FilledButton(
              onPressed: () async {
                if (_remember) {
                  final p = ref.read(sharedPreferencesProvider);
                  await p.setInt('planning_default_hour', _at.hour);
                  await p.setInt('planning_default_minute', _at.minute);
                  await p.setInt('planning_default_spacing', _spacing);
                  await p.setString('planning_default_alert', _alert);
                }
                if (context.mounted) {
                  Navigator.pop(context, _Defaults(_at, _spacing, _alert));
                }
              },
              child: const Text('Preview schedule'),
            ),
          ],
        ),
      ),
    ),
  );
}
