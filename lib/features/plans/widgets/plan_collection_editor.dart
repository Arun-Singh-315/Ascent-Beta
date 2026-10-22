import '../../../shared/widgets/note_list_button.dart';
import '../../../shared/widgets/schedule_picker.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/color_tokens.dart';
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
  bool dailyTimes = false,
}) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  backgroundColor: Colors.transparent,
  builder: (ctx) => Container(
    decoration: BoxDecoration(
      color: ctx.bgSurfaceElevated,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      border: Border.all(color: ctx.glass.line),
    ),
    child: PlanCollectionEditor(
      source: source,
      initialText: initialText,
      collectionId: collectionId,
      draftKey: draftKey,
      editing: editing,
      scheduling: scheduling,
      dailyTimes: dailyTimes,
    ),
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
  }) : title = TextEditingController(text: title),
       focusNode = FocusNode();

  final TextEditingController title;
  final FocusNode focusNode;
  String notes, alert, recurrence;
  DateTime? at, endDate;
  int? minutes;
  bool checkIn, dateOnly;

  void dispose() {
    title.dispose();
    focusNode.dispose();
  }

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
    this.dailyTimes = false,
  });
  final bool dailyTimes;
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
  // Items whose time came from a "When" chip, so another chip can re-time them
  // without touching times the person set by hand.
  final _presetItems = <_Item>{};
  String _preset = 'none';
  DateTime? _presetStart;
  int _presetSpacing = 30;
  String _presetAlert = 'reminder';
  late String _request;
  String? _destination, _error;
  bool _busy = false;
  late String _draftKey;
  Future<void> _writes = Future.value();
  @override
  void initState() {
    super.initState();
    if (widget.dailyTimes) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _items.length == 1) _repeatDaily();
      });
    }
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
          _preset = saved['preset'] as String? ?? 'none';
          _presetStart = DateTime.tryParse(
            saved['presetStart'] as String? ?? '',
          );
          _presetSpacing = saved['presetSpacing'] as int? ?? 30;
          _presetAlert = saved['presetAlert'] as String? ?? 'reminder';
          for (final i in _items) {
            i.dispose();
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
          for (final position in (saved['presetPositions'] as List? ?? [])) {
            if (position is int && position >= 0 && position < _items.length) {
              _presetItems.add(_items[position]);
            }
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
      'preset': _preset,
      'presetStart': _presetStart?.toIso8601String(),
      'presetSpacing': _presetSpacing,
      'presetAlert': _presetAlert,
      'presetPositions': [
        for (var n = 0; n < _items.length; n++)
          if (_presetItems.contains(_items[n])) n,
      ],
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
      i.dispose();
    }
    super.dispose();
  }

  void _changed() {
    setState(() {});
    _persist();
  }

  void _addItem([String text = '']) {
    if (_items.length >= 200) {
      setState(() => _error = 'A plan can hold up to 200 items.');
      return;
    }
    final item = _Item(text);
    setState(() {
      _items.add(item);
    });
    if (_preset != 'none' && _presetStart != null) {
      _applySchedule(_presetStart!, _presetSpacing, _presetAlert);
    } else {
      _changed();
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) item.focusNode.requestFocus();
    });
  }

  DateTime _today() {
    final now = DateTime.now();
    final candidate = DateTime(now.year, now.month, now.day, now.hour + 1, 0);
    return candidate.isAfter(now)
        ? candidate
        : now.add(const Duration(minutes: 30));
  }

  DateTime _morning() {
    final p = ref.read(sharedPreferencesProvider);
    final now = DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day + 1,
      p.getInt('planning_default_hour') ?? 7,
      p.getInt('planning_default_minute') ?? 0,
    );
  }

  DateTime _evening() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day, 18);
    return today.isAfter(now.add(const Duration(minutes: 30)))
        ? today
        : DateTime(now.year, now.month, now.day + 1, 18);
  }

  Future<bool> _settings(int index) async {
    FocusScope.of(context).unfocus();
    final item = _items[index];
    final result = await showModalBottomSheet<PlanItemDraft>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _ItemSettings(
        initial: item.draft,
        morning: _morning(),
        evening: _evening(),
      ),
    );
    if (result == null || !mounted) return false;
    item.title.text = result.title;
    item.notes = result.notes;
    item.at = result.at;
    item.alert = result.alert;
    item.minutes = result.minutes;
    item.recurrence = result.recurrence;
    item.endDate = result.endDate;
    item.checkIn = result.checkIn;
    item.dateOnly = result.dateOnly;
    // A hand-set time is pinned: presets no longer overwrite it.
    _presetItems.remove(item);
    _changed();
    return true;
  }

  Future<void> _chooseItemDuration(int index) async {
    FocusScope.of(context).unfocus();
    final item = _items[index];
    final current = item.minutes;
    final result = await showModalBottomSheet<int?>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpace.s20),
        decoration: BoxDecoration(
          color: ctx.bgSurfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: ctx.glass.line),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Set Focus Duration',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: ctx.textPrimary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.of(ctx).pop(current),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'How long do you want to spend on "${item.title.text.isNotEmpty ? item.title.text : 'this item'}":',
                style: TextStyle(fontSize: 13, color: ctx.textMuted),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  ChoiceChip(
                    label: const Text('None (To-do)'),
                    selected: current == null,
                    onSelected: (_) => Navigator.of(ctx).pop(null),
                  ),
                  for (final m in const [10, 15, 20, 25, 30, 45, 60, 90, 120])
                    ChoiceChip(
                      label: Text('$m min'),
                      selected: current == m,
                      onSelected: (_) => Navigator.of(ctx).pop(m),
                    ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    HapticFeedback.lightImpact();
    setState(() {
      item.minutes = result;
    });
    _changed();
  }

  void _setAllDurations(int? mins) {
    HapticFeedback.lightImpact();
    setState(() {
      for (final item in _items) {
        item.minutes = mins;
      }
    });
    _changed();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          mins != null
              ? 'Set all items to ${mins}m duration'
              : 'Cleared durations for all items',
        ),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Gives untimed (or preset-timed) items consecutive times starting at
  /// [start]. Items the user timed by hand stay where they are.
  void _applySchedule(DateTime start, int spacing, String alert) {
    _presetStart = start;
    _presetSpacing = spacing;
    _presetAlert = alert;
    var at = start;
    for (final item in _items) {
      if (item.at == null || _presetItems.contains(item)) {
        item.at = at;
        item.dateOnly = false;
        item.alert = alert;
        _presetItems.add(item);
      }
      final next = (item.at ?? at).add(
        Duration(minutes: item.minutes == null ? spacing : item.minutes! + 10),
      );
      if (next.isAfter(at)) at = next;
    }
    _changed();
  }

  void _pickPreset(String key) {
    final p = ref.read(sharedPreferencesProvider);
    final spacing = p.getInt('planning_default_spacing') ?? 30;
    final alert = p.getString('planning_default_alert') ?? 'reminder';
    _preset = key;
    final start = key == 'today'
        ? _today()
        : key == 'evening'
        ? _evening()
        : _morning();
    _applySchedule(start, spacing, alert);
  }

  Future<void> _repeatDaily() async {
    FocusScope.of(context).unfocus();
    final times = <TimeOfDay?>[null, null, null, null];
    String? error;
    DateTime? endDate;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, update) => AlertDialog(
          title: const Text('Several times a day'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Choose each time from your own schedule. Each reminder repeats daily.',
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  children: [
                    for (final count in [2, 3, 4])
                      ChoiceChip(
                        label: Text('$count times'),
                        selected: times.length == count,
                        onSelected: (_) => update(() {
                          while (times.length < count) {
                            times.add(null);
                          }
                          if (times.length > count) {
                            times.removeRange(count, times.length);
                          }
                          error = null;
                        }),
                      ),
                  ],
                ),
                for (var i = 0; i < times.length; i++)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Time ${i + 1}'),
                    trailing: Text(times[i]?.format(ctx) ?? 'Choose time'),
                    onTap: () async {
                      final picked = await showTimePicker(
                        context: ctx,
                        initialTime: times[i] ?? TimeOfDay.now(),
                      );
                      if (picked != null && ctx.mounted) {
                        update(() {
                          times[i] = picked;
                          error = null;
                        });
                      }
                    },
                  ),
                TextButton.icon(
                  icon: const Icon(Icons.event_outlined),
                  label: Text(
                    endDate == null
                        ? 'Choose end date'
                        : 'Until ${DateFormat.yMMMd().format(endDate!)}',
                  ),
                  onPressed: () async {
                    final now = DateTime.now();
                    final first = DateTime(now.year, now.month, now.day + 1);
                    final picked = await showDatePicker(
                      context: ctx,
                      initialDate: endDate ?? first,
                      firstDate: first,
                      lastDate: DateTime(now.year + 5),
                    );
                    if (picked != null && ctx.mounted) {
                      update(() {
                        endDate = picked;
                        error = null;
                      });
                    }
                  },
                ),
                if (error != null)
                  Text(
                    error!,
                    style: TextStyle(color: Theme.of(ctx).colorScheme.error),
                  ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () {
                final minutes = times
                    .whereType<TimeOfDay>()
                    .map((t) => t.hour * 60 + t.minute)
                    .toSet();
                if (minutes.length != times.length || endDate == null) {
                  update(
                    () => error = 'Choose distinct times and an end date.',
                  );
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: const Text('Use these times'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true || !mounted) return;
    final source = _items.single;
    final now = DateTime.now();
    final sorted = times.whereType<TimeOfDay>().toList()
      ..sort(
        (a, b) => (a.hour * 60 + a.minute).compareTo(b.hour * 60 + b.minute),
      );
    final repeated = sorted.map((time) {
      var at = DateTime(now.year, now.month, now.day, time.hour, time.minute);
      if (!at.isAfter(now)) {
        at = DateTime(now.year, now.month, now.day + 1, time.hour, time.minute);
      }
      return _Item(
        source.title.text,
        notes: source.notes,
        at: at,
        recurrence: 'daily',
        endDate: endDate,
        alert: 'reminder',
        minutes: source.minutes,
      );
    }).toList();
    _items
      ..clear()
      ..addAll(repeated);
    _presetItems.clear();
    _preset = 'none';
    _presetStart = null;
    source.dispose();
    _changed();
  }

  void _clearTimes() {
    for (final i in _items) {
      i.at = null;
      i.recurrence = 'once';
      i.checkIn = false;
      i.dateOnly = false;
    }
    _presetItems.clear();
    _preset = 'none';
    _presetStart = null;
    _changed();
  }

  Future<void> _customSchedule() async {
    FocusScope.of(context).unfocus();
    final prefs = ref.read(sharedPreferencesProvider);
    final now = DateTime.now();
    final initial = DateTime(
      now.year,
      now.month,
      now.day + 1,
      prefs.getInt('planning_default_hour') ?? 7,
      prefs.getInt('planning_default_minute') ?? 0,
    );
    final start = await pickFutureSchedule(
      context,
      purpose: 'Schedule',
      initial: initial,
    );
    if (start == null || !mounted) return;
    final result = await showModalBottomSheet<_Defaults>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _DefaultsSheet(initialAt: start),
    );
    if (result == null || !mounted) return;
    _preset = 'custom';
    _applySchedule(result.at, result.spacing, result.alert);
  }

  void _setAlertForAll(String alert) {
    _presetAlert = alert;
    for (final i in _items) {
      if (i.at != null && !i.dateOnly) i.alert = alert;
    }
    _changed();
  }

  Future<void> _pasteList() async {
    final g = context.glass;
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
        child: Container(
          padding: const EdgeInsets.all(AppSpace.s20),
          decoration: BoxDecoration(
            color: ctx.bgSurfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: g.line),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpace.s16),
                    decoration: BoxDecoration(
                      color: g.inkMuted.withValues(alpha: 0.3),
                      borderRadius: AppGeometry.roundedr4,
                    ),
                  ),
                ),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpace.s8),
                      decoration: BoxDecoration(
                        color: g.clay.withValues(alpha: 0.12),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.playlist_add_rounded,
                        color: g.clay,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Add multiple items',
                            style: Theme.of(ctx).textTheme.titleMedium
                                ?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: g.ink,
                                ),
                          ),
                          Text(
                            'Type or paste items (one per line). Bullets and numbers are cleaned.',
                            style: TextStyle(
                              color: g.inkSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpace.s16),
                TextField(
                  controller: _paste,
                  minLines: 4,
                  maxLines: 10,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'First item\nSecond item\nThird item…',
                    hintStyle: TextStyle(color: g.inkMuted),
                    filled: true,
                    fillColor: g.fill,
                    border: OutlineInputBorder(
                      borderRadius: AppGeometry.roundedr16,
                      borderSide: BorderSide(color: g.edge),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppGeometry.roundedr16,
                      borderSide: BorderSide(color: g.edge),
                    ),
                  ),
                ),
                const SizedBox(height: AppSpace.s16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: Text(
                        'Cancel',
                        style: TextStyle(color: g.inkMuted),
                      ),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: g.clay,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppGeometry.roundedr12,
                        ),
                      ),
                      onPressed: () => Navigator.pop(ctx, _paste.text),
                      child: const Text('Review items'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (text == null || !mounted) return;
    final lines = PlanItemDraft.parseList(text);
    if (lines.length + _items.length > 200) {
      setState(() => _error = 'A plan can hold up to 200 items.');
      return;
    }
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
    _paste.clear();
    if (_preset != 'none' && _presetStart != null) {
      _applySchedule(_presetStart!, _presetSpacing, _presetAlert);
    } else {
      _changed();
    }
  }

  /// Named after the first item when the person leaves the name empty, so a
  /// quick list never needs a typed title.
  String _planTitle() {
    if (_title.text.trim().isNotEmpty) return _title.text;
    if (_destination != null) return 'Existing plan';
    for (final i in _items) {
      final t = i.title.text.trim();
      if (t.isNotEmpty) {
        return t.length > 40 ? '${t.substring(0, 40).trim()}…' : t;
      }
    }
    return _title.text;
  }

  Future<void> _save() async {
    if (_busy) return;
    if (_items.isEmpty || _items.any((i) => i.title.text.trim().isEmpty)) {
      setState(() => _error = 'Name each item, or remove its empty row.');
      return;
    }
    for (var n = 0; n < _items.length; n++) {
      final i = _items[n];
      if ((i.at != null && !i.dateOnly && !i.at!.isAfter(DateTime.now())) ||
          (i.recurrence != 'once' &&
              (i.at == null ||
                  i.endDate == null ||
                  i.endDate!.isBefore(
                    DateTime(i.at!.year, i.at!.month, i.at!.day),
                  )))) {
        if (!await _settings(n) || !mounted) return;
      }
    }

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
          title: _planTitle(),
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

  String _timeLabel(_Item item) {
    final at = item.at;
    if (at == null) return 'Add time';
    final when = DateFormat(
      item.dateOnly ? 'EEE, d MMM' : 'EEE, d MMM · h:mm a',
    ).format(at);
    return switch (item.recurrence) {
      'daily' => '$when · Daily',
      'weekdays' => '$when · Weekdays',
      _ => when,
    };
  }

  Widget _sectionLabel(BuildContext context, String text) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s16, bottom: AppSpace.s8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.labelLarge?.copyWith(color: g.inkSecondary),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final collections = ref.watch(planCollectionsProvider).value ?? [];
    final activePlans = collections.where((c) => c.status == 'active').toList();
    final scheduled = _items.where((i) => i.at != null).length;
    final alarms = _items
        .where((i) => i.at != null && !i.dateOnly && i.alert == 'alarm')
        .length;
    final reminders = _items
        .where((i) => i.at != null && !i.dateOnly && i.alert == 'reminder')
        .length;
    final times = _items.where((i) => i.at != null).map((i) => i.at!).toList();
    final overlap = times.toSet().length != times.length;
    final timed = _items.where((i) => i.at != null && !i.dateOnly).toList();
    final alertChoice =
        timed.isNotEmpty && timed.every((i) => i.alert == timed.first.alert)
        ? timed.first.alert
        : null;
    final isNewPlan = widget.editing == null && widget.scheduling == null;
    final summary = <String>[
      '${_items.length} ${_items.length == 1 ? 'item' : 'items'}',
      if (scheduled > 0) '$scheduled scheduled',
      if (reminders > 0)
        '$reminders ${reminders == 1 ? 'reminder' : 'reminders'}',
      if (alarms > 0) '$alarms ${alarms == 1 ? 'alarm' : 'alarms'}',
    ].join(' · ');
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
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  margin: const EdgeInsets.only(
                    top: AppSpace.s12,
                    bottom: AppSpace.s4,
                  ),
                  decoration: BoxDecoration(
                    color: g.inkMuted.withValues(alpha: 0.3),
                    borderRadius: AppGeometry.roundedr4,
                  ),
                ),
              ),
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
                    if (isNewPlan) ...[
                      if (widget.collectionId == null &&
                          activePlans.isNotEmpty) ...[
                        SingleChildScrollView(
                          scrollDirection: Axis.horizontal,
                          child: Row(
                            children: [
                              ChoiceChip(
                                label: const Text('New plan'),
                                selected: _destination == null,
                                onSelected: _busy
                                    ? null
                                    : (_) {
                                        _destination = null;
                                        _changed();
                                      },
                              ),
                              for (final c in activePlans)
                                Padding(
                                  padding: const EdgeInsets.only(
                                    left: AppSpace.s8,
                                  ),
                                  child: ChoiceChip(
                                    label: ConstrainedBox(
                                      constraints: const BoxConstraints(
                                        maxWidth: 160,
                                      ),
                                      child: Text(
                                        c.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    selected: _destination == c.id,
                                    onSelected: _busy
                                        ? null
                                        : (_) {
                                            _destination = c.id;
                                            _changed();
                                          },
                                  ),
                                ),
                            ],
                          ),
                        ),
                        const SizedBox(height: AppSpace.s8),
                      ],
                      if (_destination == null) ...[
                        _sectionLabel(context, 'Plan name'),
                        TextField(
                          key: const ValueKey('plan_name_field'),
                          controller: _title,
                          minLines: 1,
                          maxLines: 3,
                          maxLength: 300,
                          enabled: !_busy,
                          onChanged: (_) => _persist(),
                          scrollPadding: const EdgeInsets.all(AppSpace.s24),
                          decoration: InputDecoration(
                            hintText: 'e.g. Interview preparation',
                            counterText: '',
                            contentPadding: const EdgeInsets.all(AppSpace.s14),
                            border: OutlineInputBorder(
                              borderRadius: AppGeometry.roundedr12,
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: AppSpace.s4),
                          child: Text(
                            'Optional — leave blank to use your first item.',
                            style: TextStyle(color: g.inkMuted),
                          ),
                        ),
                      ],
                    ],
                    if (widget.editing == null) ...[
                      _sectionLabel(context, 'When'),
                      Wrap(
                        spacing: AppSpace.s8,
                        runSpacing: AppSpace.s8,
                        children: [
                          ChoiceChip(
                            label: const Text('No times'),
                            selected: scheduled == 0,
                            onSelected: _busy ? null : (_) => _clearTimes(),
                          ),
                          ChoiceChip(
                            label: const Text('Today'),
                            selected: scheduled > 0 && _preset == 'today',
                            onSelected: _busy
                                ? null
                                : (_) => _pickPreset('today'),
                          ),
                          ChoiceChip(
                            label: const Text('Tomorrow morning'),
                            selected: scheduled > 0 && _preset == 'morning',
                            onSelected: _busy
                                ? null
                                : (_) => _pickPreset('morning'),
                          ),
                          ChoiceChip(
                            label: const Text('Evening'),
                            selected: scheduled > 0 && _preset == 'evening',
                            onSelected: _busy
                                ? null
                                : (_) => _pickPreset('evening'),
                          ),
                          if (_items.length == 1)
                            ActionChip(
                              label: const Text('Several times a day'),
                              avatar: const Icon(
                                Icons.repeat_rounded,
                                size: 18,
                              ),
                              onPressed: _busy ? null : _repeatDaily,
                            ),
                          ChoiceChip(
                            label: const Text('Custom'),
                            selected: scheduled > 0 && _preset == 'custom',
                            onSelected: _busy ? null : (_) => _customSchedule(),
                          ),
                        ],
                      ),
                      if (timed.isNotEmpty) ...[
                        _sectionLabel(context, 'Alert'),
                        Wrap(
                          spacing: AppSpace.s8,
                          runSpacing: AppSpace.s8,
                          children: [
                            for (final a in const ['reminder', 'alarm', 'none'])
                              ChoiceChip(
                                label: Text(_alertNames[a]!),
                                selected: alertChoice == a,
                                onSelected: _busy
                                    ? null
                                    : (_) => _setAlertForAll(a),
                              ),
                          ],
                        ),
                      ],
                      const SizedBox(height: AppSpace.s8),
                      Text(
                        summary,
                        style: TextStyle(color: g.inkSecondary, fontSize: 13),
                      ),
                      if (overlap)
                        Text(
                          'Some items share a time. You can keep them or edit their times.',
                          style: TextStyle(color: g.clay, fontSize: 12),
                        ),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(
                        top: AppSpace.s16,
                        bottom: AppSpace.s8,
                      ),
                      child: Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: AppSpace.s8,
                        runSpacing: AppSpace.s6,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Items',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: g.inkSecondary,
                                      fontWeight: FontWeight.w600,
                                    ),
                              ),
                              if (_items.isNotEmpty) ...[
                                const SizedBox(width: AppSpace.s6),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: g.fill,
                                    borderRadius: AppGeometry.roundedr6,
                                    border: Border.all(color: g.edge),
                                  ),
                                  child: Text(
                                    '${_items.length}',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                      color: g.inkMuted,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpace.s8),
                      child: Text(
                        'One row = one to-do. Tap Add item to create the next row.',
                        style: TextStyle(color: g.inkMuted),
                      ),
                    ),
                    if (_items.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpace.s10),
                        child: Wrap(
                          spacing: AppSpace.s6,
                          runSpacing: AppSpace.s6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              'Set all durations:',
                              style: TextStyle(
                                fontSize: 12,
                                color: g.inkMuted,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            for (final dur in [15, 25, 30, 45, 60])
                              ActionChip(
                                padding: EdgeInsets.zero,
                                visualDensity: VisualDensity.compact,
                                label: Text(
                                  '${dur}m',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: g.clay,
                                  ),
                                ),
                                onPressed: _busy
                                    ? null
                                    : () => _setAllDurations(dur),
                              ),
                            ActionChip(
                              padding: EdgeInsets.zero,
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                'Clear all',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: g.inkMuted,
                                ),
                              ),
                              onPressed: _busy
                                  ? null
                                  : () => _setAllDurations(null),
                            ),
                          ],
                        ),
                      ),
                    for (var n = 0; n < _items.length; n++)
                      Padding(
                        key: ObjectKey(_items[n]),
                        padding: const EdgeInsets.only(bottom: AppSpace.s8),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: g.fill,
                            border: Border.all(color: g.edge),
                            borderRadius: AppGeometry.roundedr16,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpace.s12,
                              AppSpace.s4,
                              AppSpace.s4,
                              AppSpace.s8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: _items[n].title,
                                        focusNode: _items[n].focusNode,
                                        maxLength: 300,
                                        minLines: 1,
                                        maxLines: 4,
                                        enabled: !_busy,
                                        textInputAction: TextInputAction.next,
                                        onChanged: (_) => _persist(),
                                        onSubmitted: (_) {
                                          if (n < _items.length - 1) {
                                            _items[n + 1].focusNode
                                                .requestFocus();
                                          } else if (widget.editing == null) {
                                            _addItem();
                                          }
                                        },
                                        decoration: const InputDecoration(
                                          hintText: 'What needs doing?',
                                          counterText: '',
                                          border: InputBorder.none,
                                          enabledBorder: InputBorder.none,
                                          focusedBorder: InputBorder.none,
                                          filled: false,
                                        ),
                                      ),
                                    ),
                                    if (isNewPlan && _items.length > 1)
                                      IconButton(
                                        tooltip: 'Remove item',
                                        onPressed: _busy
                                            ? null
                                            : () {
                                                final removed = _items.removeAt(
                                                  n,
                                                );
                                                _presetItems.remove(removed);
                                                setState(() {});
                                                _persist();
                                                // Dispose after the TextField has unmounted.
                                                WidgetsBinding.instance
                                                    .addPostFrameCallback((_) {
                                                      removed.dispose();
                                                    });
                                              },
                                        icon: const Icon(Icons.close, size: 18),
                                      ),
                                  ],
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(
                                    right: AppSpace.s8,
                                  ),
                                  child: Wrap(
                                    spacing: AppSpace.s8,
                                    runSpacing: AppSpace.s4,
                                    crossAxisAlignment:
                                        WrapCrossAlignment.center,
                                    children: [
                                      ActionChip(
                                        avatar: Icon(
                                          _items[n].at == null
                                              ? Icons.add_alarm
                                              : Icons.schedule,
                                          size: 18,
                                        ),
                                        label: Text(_timeLabel(_items[n])),
                                        onPressed: _busy
                                            ? null
                                            : () => _settings(n),
                                      ),
                                      if (_items[n].at != null)
                                        IconButton(
                                          tooltip: 'Clear time',
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                          onPressed: _busy
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _items[n].at = null;
                                                    _items[n].recurrence =
                                                        'once';
                                                    _items[n].dateOnly = false;
                                                    _items[n].checkIn = false;
                                                    _presetItems.remove(
                                                      _items[n],
                                                    );
                                                  });
                                                  _changed();
                                                },
                                          icon: Icon(
                                            Icons.close_rounded,
                                            size: 16,
                                            color: g.inkMuted,
                                          ),
                                        ),
                                      ActionChip(
                                        avatar: Icon(
                                          Icons.timer_outlined,
                                          size: 16,
                                          color:
                                              (_items[n].minutes != null &&
                                                  _items[n].minutes! > 0)
                                              ? g.clay
                                              : g.inkMuted,
                                        ),
                                        label: Text(
                                          (_items[n].minutes != null &&
                                                  _items[n].minutes! > 0)
                                              ? '${_items[n].minutes}m duration'
                                              : 'Set duration',
                                          style: TextStyle(
                                            color:
                                                (_items[n].minutes != null &&
                                                    _items[n].minutes! > 0)
                                                ? g.clay
                                                : g.inkMuted,
                                            fontWeight:
                                                (_items[n].minutes != null &&
                                                    _items[n].minutes! > 0)
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                            fontSize: 12,
                                          ),
                                        ),
                                        onPressed: _busy
                                            ? null
                                            : () => _chooseItemDuration(n),
                                      ),
                                      if (_items[n].minutes != null &&
                                          _items[n].minutes! > 0)
                                        IconButton(
                                          tooltip: 'Clear duration',
                                          visualDensity: VisualDensity.compact,
                                          padding: EdgeInsets.zero,
                                          constraints: const BoxConstraints(
                                            minWidth: 28,
                                            minHeight: 28,
                                          ),
                                          onPressed: _busy
                                              ? null
                                              : () {
                                                  setState(() {
                                                    _items[n].minutes = null;
                                                  });
                                                  _changed();
                                                },
                                          icon: Icon(
                                            Icons.close_rounded,
                                            size: 16,
                                            color: g.inkMuted,
                                          ),
                                        ),
                                      if (n > 0 && widget.editing == null)
                                        IconButton(
                                          tooltip: 'Move item up',
                                          visualDensity: VisualDensity.compact,
                                          onPressed: _busy
                                              ? null
                                              : () {
                                                  final item = _items.removeAt(
                                                    n,
                                                  );
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
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    if (isNewPlan) ...[
                      const SizedBox(height: AppSpace.s4),
                      Wrap(
                        spacing: AppSpace.s8,
                        runSpacing: AppSpace.s8,
                        children: [
                          OutlinedButton.icon(
                            onPressed: _busy || _items.length >= 200
                                ? null
                                : () => _addItem(),
                            icon: const Icon(Icons.add_rounded, size: 18),
                            label: const Text('Add item'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: AppGeometry.roundedr12,
                              ),
                            ),
                          ),
                          OutlinedButton.icon(
                            onPressed: _busy ? null : _pasteList,
                            icon: const Icon(
                              Icons.playlist_add_rounded,
                              size: 18,
                            ),
                            label: const Text('Paste list'),
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: AppGeometry.roundedr12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
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

const _alertNames = {
  'none': 'Silent',
  'reminder': 'Reminder',
  'alarm': 'Alarm',
};

class _ItemSettings extends StatefulWidget {
  const _ItemSettings({
    required this.initial,
    required this.morning,
    required this.evening,
  });
  final PlanItemDraft initial;
  final DateTime morning, evening;
  @override
  State<_ItemSettings> createState() => _SettingsState();
}

class _SettingsState extends State<_ItemSettings> {
  DateTime? _at, _end;
  String _alert = 'none', _repeat = 'once';
  bool _check = false, _dateOnly = false, _choosing = false;
  String? _notice;
  int? _minutes;
  late final List<int> _durations;
  late final TextEditingController _notes;
  final _notesFocus = FocusNode();
  @override
  void initState() {
    super.initState();
    final d = widget.initial;
    _at = d.at;
    _dateOnly = d.dateOnly;
    _minutes = d.minutes;
    _alert = d.at == null || d.dateOnly ? 'none' : d.alert;
    _repeat = d.recurrence;
    _end = d.endDate;
    _check = d.checkIn;
    _notes = TextEditingController(text: d.notes);
    _durations = {
      15,
      25,
      45,
      60,
      if (d.minutes != null && d.minutes! > 0) d.minutes!,
    }.toList()..sort();
    if ((_repeat != 'once' && (_at == null || _end == null)) ||
        (_check && (_at == null || _dateOnly))) {
      final intendedRepeat = _repeat;
      _repeat = 'once';
      _check = false;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && intendedRepeat != 'once') _chooseRepeat(intendedRepeat);
      });
    }
  }

  @override
  void dispose() {
    _notesFocus.dispose();
    _notes.dispose();
    super.dispose();
  }

  void _inform(String message) {
    if (mounted) setState(() => _notice = message);
  }

  DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);
  bool get _validTime =>
      _at != null && !_dateOnly && _at!.isAfter(DateTime.now());

  Future<DateTime?> _date(
    String help, {
    DateTime? initial,
    DateTime? first,
    DateTime? last,
  }) async {
    final lower = _day(first ?? DateTime.now());
    final upper = _day(last ?? DateTime(DateTime.now().year + 3));
    var suggested = _day(initial ?? _at ?? DateTime.now());
    if (suggested.isBefore(lower)) suggested = lower;
    if (suggested.isAfter(upper)) suggested = upper;
    return showDatePicker(
      context: context,
      helpText: help,
      initialDate: suggested,
      firstDate: lower,
      lastDate: upper,
    );
  }

  Future<DateTime?> _time(String purpose, {DateTime? initial}) =>
      pickFutureSchedule(
        context,
        purpose: purpose,
        initial: initial ?? (_validTime ? _at : null),
        onInvalid: _inform,
      );

  Future<DateTime?> _until(DateTime start) => _date(
    'Repeat until',
    initial: _end ?? start.add(const Duration(days: 14)),
    first: start,
    last: start.add(const Duration(days: 90)),
  );

  Future<void> _chooseAlert(String alert) async {
    if (_choosing) return;
    if (alert == 'none') {
      setState(() {
        _alert = alert;
        _notice = null;
      });
      return;
    }
    setState(() {
      _choosing = true;
      _notice = null;
    });
    final value = _validTime
        ? _at
        : await _time(alert == 'alarm' ? 'Alarm' : 'Reminder');
    if (!mounted) return;
    setState(() {
      _choosing = false;
      if (value != null) {
        _at = value;
        _dateOnly = false;
        _alert = alert;
        _notice = null;
      } else {
        _notice ??=
            '${alert == 'alarm' ? 'Alarm' : 'Reminder'} was left unchanged. Choose a date and time to turn it on.';
      }
    });
  }

  Future<void> _chooseRepeat(String repeat) async {
    if (_choosing) return;
    if (repeat == 'once') {
      setState(() {
        _repeat = repeat;
        _end = null;
        _notice = null;
      });
      return;
    }
    setState(() {
      _choosing = true;
      _notice = null;
    });
    final start = _validTime ? _at : await _time('Start');
    final end = start == null || !mounted ? null : await _until(start);
    if (!mounted) return;
    setState(() {
      _choosing = false;
      if (start != null && end != null) {
        _at = start;
        _end = end;
        _repeat = repeat;
        _dateOnly = false;
        _notice = null;
      } else {
        _notice ??=
            'Repeat was left unchanged. Set the start and end dates to turn it on.';
      }
    });
  }

  Future<void> _chooseDateOnly(bool value) async {
    if (_choosing) return;
    if (!value) {
      await _chooseStart();
      return;
    }
    setState(() {
      _choosing = true;
      _notice = null;
    });
    final date = await _date('Activity date');
    if (!mounted) return;
    setState(() {
      _choosing = false;
      if (date != null) {
        _at = date;
        _dateOnly = true;
        _alert = 'none';
        _repeat = 'once';
        _end = null;
        _check = false;
        _notice = null;
      }
    });
  }

  Future<void> _chooseStart({DateTime? preset}) async {
    if (_choosing) return;
    setState(() {
      _choosing = true;
      _notice = null;
    });
    final value = preset ?? await _time('Activity');
    var end = _end;
    if (value != null &&
        _repeat != 'once' &&
        (end == null || _day(end).isBefore(_day(value))) &&
        mounted) {
      end = await _until(value);
    }
    if (!mounted) return;
    setState(() {
      _choosing = false;
      if (value != null && (_repeat == 'once' || end != null)) {
        _at = value;
        _dateOnly = false;
        _end = end;
        _notice = null;
      }
    });
  }

  Future<void> _chooseCheck(bool value) async {
    if (_choosing) return;
    if (!value) {
      setState(() => _check = false);
      return;
    }
    setState(() {
      _choosing = true;
      _notice = null;
    });
    final start = _validTime ? _at : await _time('Check-in start');
    if (!mounted) return;
    setState(() {
      _choosing = false;
      if (start != null) {
        _at = start;
        _dateOnly = false;
        _check = true;
        _notice = null;
      } else {
        _notice = 'Check-in was left off. Choose a start date and time first.';
      }
    });
  }

  Future<void> _apply() async {
    if (_choosing) return;
    if (_at != null && !_dateOnly && !_validTime) {
      await _chooseStart();
      if (!_validTime) return;
    }
    if (_repeat != 'once' &&
        (_end == null || _day(_end!).isBefore(_day(_at!)))) {
      await _chooseRepeat(_repeat);
      if (_end == null) return;
    }
    if (!mounted) return;
    Navigator.pop(
      context,
      PlanItemDraft(
        title: widget.initial.title,
        notes: _notes.text,
        at: _at,
        alert: _dateOnly || _at == null ? 'none' : _alert,
        recurrence: _repeat,
        endDate: _end,
        minutes: _minutes,
        checkIn: _check,
        dateOnly: _dateOnly,
      ),
    );
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.s16, bottom: AppSpace.s8),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );
  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dateFormat = DateFormat(
      _dateOnly ? 'EEE, d MMM' : 'EEE, d MMM · h:mm a',
    );
    final checkAt = _at?.add(Duration(minutes: (_minutes ?? 30) + 10));
    return Material(
      color: context.bgSurfaceElevated,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(
            left: AppSpace.s16,
            right: AppSpace.s16,
            top: AppSpace.s16,
            bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.s16,
          ),
          child: SingleChildScrollView(
            key: const ValueKey('item_settings_scroll'),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Item details',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close item details',
                      onPressed: _choosing
                          ? null
                          : () => Navigator.pop(context),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                Text(
                  widget.initial.title,
                  style: Theme.of(context).textTheme.bodyLarge,
                ),
                _label('When'),
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [
                    ChoiceChip(
                      label: const Text('No time'),
                      selected: _at == null,
                      onSelected: _choosing
                          ? null
                          : (_) => setState(() {
                              _at = null;
                              _end = null;
                              _alert = 'none';
                              _repeat = 'once';
                              _dateOnly = false;
                              _check = false;
                              _notice = null;
                            }),
                    ),
                    ChoiceChip(
                      label: const Text('Tomorrow morning'),
                      selected: _at == widget.morning && !_dateOnly,
                      onSelected: _choosing
                          ? null
                          : (_) => _chooseStart(preset: widget.morning),
                    ),
                    ChoiceChip(
                      label: const Text('Evening'),
                      selected: _at == widget.evening && !_dateOnly,
                      onSelected: _choosing
                          ? null
                          : (_) => _chooseStart(preset: widget.evening),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.schedule, size: 18),
                      label: Text(
                        _at == null
                            ? 'Pick date & time'
                            : dateFormat.format(_at!),
                      ),
                      onPressed: _choosing
                          ? null
                          : () => _dateOnly
                                ? _chooseDateOnly(true)
                                : _chooseStart(),
                    ),
                    FilterChip(
                      label: const Text('Date only · no alert'),
                      selected: _dateOnly,
                      onSelected: _choosing ? null : _chooseDateOnly,
                    ),
                  ],
                ),
                _label('Alert'),
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [
                    for (final a in ['none', 'reminder', 'alarm'])
                      ChoiceChip(
                        label: Text(_alertNames[a]!),
                        selected: _alert == a,
                        onSelected: _choosing ? null : (_) => _chooseAlert(a),
                      ),
                  ],
                ),
                Text(
                  _alert == 'none'
                      ? 'No start notification.'
                      : _alert == 'alarm'
                      ? 'An alarm will ring at the selected time.'
                      : 'A notification will appear at the selected time.',
                  style: TextStyle(color: g.inkSecondary),
                ),
                _label('Repeat'),
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [
                    for (final r in ['once', 'daily', 'weekdays'])
                      ChoiceChip(
                        label: Text(
                          r == 'once'
                              ? 'Once'
                              : r == 'daily'
                              ? 'Every day'
                              : 'Weekdays',
                        ),
                        selected: _repeat == r,
                        onSelected: _choosing ? null : (_) => _chooseRepeat(r),
                      ),
                  ],
                ),
                if (_repeat != 'once' && _end != null)
                  TextButton(
                    onPressed: _choosing ? null : () => _chooseRepeat(_repeat),
                    child: Text(
                      'Repeats ${_repeat == 'daily' ? 'daily' : 'on weekdays'} until ${DateFormat.yMMMd().format(_end!)}',
                    ),
                  ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Check in afterwards'),
                  subtitle: Text(
                    _check && checkAt != null
                        ? 'Next check-in: ${DateFormat('EEE, h:mm a').format(checkAt)}'
                        : 'Optional notification to check whether you finished.',
                  ),
                  value: _check,
                  onChanged: _choosing ? null : _chooseCheck,
                ),
                const SizedBox(height: AppSpace.s8),
                _label('Focus duration'),
                Text(
                  'Set how long to focus on this item. Enables countdown timer and play controls.',
                  style: TextStyle(fontSize: 12, color: g.inkMuted),
                ),
                const SizedBox(height: AppSpace.s6),
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [
                    ChoiceChip(
                      label: const Text('None (To-do)'),
                      selected: _minutes == null,
                      onSelected: (_) => setState(() => _minutes = null),
                    ),
                    for (final m in _durations)
                      ChoiceChip(
                        label: Text('$m min'),
                        selected: _minutes == m,
                        onSelected: (_) => setState(() => _minutes = m),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpace.s8),
                Theme(
                  data: Theme.of(
                    context,
                  ).copyWith(dividerColor: Colors.transparent),
                  child: ExpansionTile(
                    tilePadding: EdgeInsets.zero,
                    title: const Text('More options'),
                    children: [
                      _label('Notes'),
                      TextField(
                        key: const ValueKey('plan_item_notes'),
                        controller: _notes,
                        focusNode: _notesFocus,
                        minLines: 2,
                        maxLines: 5,
                        maxLength: 20000,
                        decoration: InputDecoration(
                          hintText: 'Add useful details',
                          counterText: '',
                          suffixIcon: InlineListAddButton(
                            controller: _notes,
                            focusNode: _notesFocus,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_notice != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(_notice!, style: TextStyle(color: g.clay)),
                    ),
                  ),
                const SizedBox(height: AppSpace.s12),
                Container(
                  padding: const EdgeInsets.all(AppSpace.s12),
                  decoration: BoxDecoration(
                    color: g.fill,
                    borderRadius: AppGeometry.roundedr12,
                    border: Border.all(color: g.edge),
                  ),
                  child: Text(
                    _at == null
                        ? 'Saved as a to-do. No alerts will be created.'
                        : '${dateFormat.format(_at!)} · ${_alertNames[_alert]}${_repeat != 'once' ? ' · ${_repeat == 'daily' ? 'Daily' : 'Weekdays'}' : ''}${_check ? ' · Check-in on' : ''}',
                  ),
                ),
                const SizedBox(height: AppSpace.s12),
                FilledButton(
                  onPressed: _choosing ? null : _apply,
                  child: const Text('Apply details'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Defaults {
  const _Defaults(this.at, this.spacing, this.alert);
  final DateTime at;
  final int spacing;
  final String alert;
}

class _DefaultsSheet extends ConsumerStatefulWidget {
  const _DefaultsSheet({this.initialAt});
  final DateTime? initialAt;
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
    _at =
        widget.initialAt ??
        DateTime(now.year, now.month, now.day + 1, hour, minute);
  }

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.s16, bottom: AppSpace.s8),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Material(
      color: context.bgSurfaceElevated,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: g.line),
        ),
        padding: EdgeInsets.only(
          left: AppSpace.s16,
          right: AppSpace.s16,
          top: AppSpace.s12,
          bottom: MediaQuery.viewInsetsOf(context).bottom + AppSpace.s16,
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    margin: const EdgeInsets.only(bottom: AppSpace.s12),
                    decoration: BoxDecoration(
                      color: g.inkMuted.withValues(alpha: 0.3),
                      borderRadius: AppGeometry.roundedr4,
                    ),
                  ),
                ),
                Text(
                  'Custom schedule',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: AppSpace.s4),
                const Text(
                  'Applies to items without a time. Times you set by hand stay as they are.',
                ),
                _label('Start'),
                Align(
                  alignment: Alignment.centerLeft,
                  child: ActionChip(
                    avatar: const Icon(Icons.schedule, size: 18),
                    label: Text(DateFormat('EEE, d MMM · h:mm a').format(_at)),
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
                  ),
                ),
                _label('Gap between items'),
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [
                    for (final n in const [15, 30, 45, 60, 90, 120])
                      ChoiceChip(
                        label: Text('$n min'),
                        selected: _spacing == n,
                        onSelected: (_) => setState(() => _spacing = n),
                      ),
                  ],
                ),
                _label('Alert'),
                Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [
                    for (final a in const ['reminder', 'alarm', 'none'])
                      ChoiceChip(
                        label: Text(_alertNames[a]!),
                        selected: _alert == a,
                        onSelected: (_) => setState(() => _alert = a),
                      ),
                  ],
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
                  child: const Text('Apply'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
