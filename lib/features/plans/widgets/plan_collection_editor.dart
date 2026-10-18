import 'dart:convert';
import 'package:flutter/material.dart';
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
  // Items whose time came from a "When" chip, so another chip can re-time them
  // without touching times the person set by hand.
  final _presetItems = <_Item>{};
  String _preset = 'none';
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
    _changed();
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

  Future<void> _settings(int index) async {
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
    // A hand-set time is pinned: presets no longer overwrite it.
    _presetItems.remove(item);
    _changed();
  }

  /// Gives untimed (or preset-timed) items consecutive times starting at
  /// [start]. Items the user timed by hand stay where they are.
  void _applySchedule(DateTime start, int spacing, String alert) {
    var at = start;
    for (final item in _items) {
      if (item.at == null || _presetItems.contains(item)) {
        item.at = at;
        item.dateOnly = false;
        item.alert = alert;
        _presetItems.add(item);
      }
      at = (item.at ?? at).add(
        Duration(minutes: item.minutes == null ? spacing : item.minutes! + 10),
      );
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

  void _clearTimes() {
    for (final i in _items) {
      i.at = null;
      i.recurrence = 'once';
      i.checkIn = false;
      i.dateOnly = false;
    }
    _presetItems.clear();
    _preset = 'none';
    _changed();
  }

  Future<void> _customSchedule() async {
    FocusScope.of(context).unfocus();
    final result = await showModalBottomSheet<_Defaults>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const _DefaultsSheet(),
    );
    if (result == null || !mounted) return;
    _preset = 'custom';
    _applySchedule(result.at, result.spacing, result.alert);
  }

  void _setAlertForAll(String alert) {
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
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(ctx).bottom,
        ),
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
                            style: Theme.of(ctx).textTheme.titleMedium?.copyWith(
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
                      child: Text('Cancel', style: TextStyle(color: g.inkMuted)),
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
    _changed();
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
      if (reminders > 0) '$reminders ${reminders == 1 ? 'reminder' : 'reminders'}',
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
                  margin: const EdgeInsets.only(top: AppSpace.s12, bottom: AppSpace.s4),
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
                      if (_destination == null)
                        TextField(
                          controller: _title,
                          maxLength: 300,
                          enabled: !_busy,
                          onChanged: (_) => _persist(),
                          decoration: const InputDecoration(
                            labelText: 'Plan name',
                            hintText: 'Optional · named from your first item',
                            counterText: '',
                          ),
                        ),
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
                      Text(summary, style: TextStyle(color: g.inkSecondary, fontSize: 13)),
                      if (overlap)
                        Text(
                          'Some items share a time. You can keep them or edit their times.',
                          style: TextStyle(color: g.clay, fontSize: 12),
                        ),
                    ],
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.s16, bottom: AppSpace.s8),
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
                                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                                  color: g.inkSecondary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              if (_items.isNotEmpty) ...[
                                const SizedBox(width: AppSpace.s6),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
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
                          if (isNewPlan)
                            Wrap(
                              spacing: AppSpace.s6,
                              runSpacing: AppSpace.s4,
                              children: [
                                TextButton.icon(
                                  onPressed: _busy || _items.length >= 200
                                      ? null
                                      : () => _addItem(),
                                  icon: const Icon(Icons.add, size: 18),
                                  label: const Text('Add item'),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: _busy ? null : _pasteList,
                                  icon: const Icon(Icons.playlist_add_rounded, size: 18),
                                  label: const Text('Paste list'),
                                  style: TextButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                  ),
                                ),
                              ],
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
                                            _items[n + 1].focusNode.requestFocus();
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
                                                    _items[n].recurrence = 'once';
                                                    _items[n].dateOnly = false;
                                                    _presetItems.remove(_items[n]);
                                                  });
                                                  _changed();
                                                },
                                          icon: Icon(
                                            Icons.close_rounded,
                                            size: 16,
                                            color: g.inkMuted,
                                          ),
                                        ),
                                      if (_items[n].minutes != null && _items[n].minutes! > 0)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: g.clay.withValues(alpha: 0.12),
                                            borderRadius: AppGeometry.roundedr8,
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(Icons.timer_outlined, size: 12, color: g.clay),
                                              const SizedBox(width: 4),
                                              Text(
                                                '${_items[n].minutes}m focus',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: g.clay,
                                                ),
                                              ),
                                            ],
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
                            icon: const Icon(Icons.playlist_add_rounded, size: 18),
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
  late DateTime? _at, _end;
  late String _alert, _repeat;
  late bool _check;
  bool _dateOnly = false;
  int? _minutes;
  late final List<int> _durations;
  late TextEditingController _notes;
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
    _minutes = d.minutes;
    _notes = TextEditingController(text: d.notes);
    final extra = d.minutes;
    _durations = [
      15,
      25,
      45,
      60,
      if (extra != null && extra > 0 && ![15, 25, 45, 60].contains(extra)) extra,
    ]..sort();
  }

  @override
  void dispose() {
    _notes.dispose();
    super.dispose();
  }

  bool _is(DateTime? a, DateTime b) {
    if (a == null) return false;
    if (_dateOnly) {
      return a.year == b.year && a.month == b.month && a.day == b.day;
    }
    return a == b;
  }

  void _setAt(DateTime t) => setState(
    () => _at = _dateOnly ? DateTime(t.year, t.month, t.day) : t,
  );

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

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.s16, bottom: AppSpace.s8),
    child: Text(text, style: Theme.of(context).textTheme.labelLarge),
  );

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final custom =
        _at != null && !_is(_at, widget.morning) && !_is(_at, widget.evening);
    final timed = _at != null && !_dateOnly;
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
            Text('Item details', style: Theme.of(context).textTheme.titleLarge),
            _label('When'),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                ChoiceChip(
                  label: const Text('No time'),
                  selected: _at == null,
                  onSelected: (_) => setState(() {
                    _at = null;
                    _repeat = 'once';
                    _check = false;
                    _dateOnly = false;
                  }),
                ),
                ChoiceChip(
                  label: const Text('Tomorrow morning'),
                  selected: _is(_at, widget.morning),
                  onSelected: (_) => _setAt(widget.morning),
                ),
                ChoiceChip(
                  label: const Text('Evening'),
                  selected: _is(_at, widget.evening),
                  onSelected: (_) => _setAt(widget.evening),
                ),
                ChoiceChip(
                  label: Text(
                    custom
                        ? DateFormat(
                            _dateOnly ? 'EEE, d MMM' : 'EEE, d MMM · h:mm a',
                          ).format(_at!)
                        : (_dateOnly ? 'Pick a date' : 'Pick date & time'),
                  ),
                  selected: custom,
                  onSelected: (_) => _pick(),
                ),
                FilterChip(
                  label: const Text('Date only · no alert'),
                  selected: _dateOnly,
                  onSelected: (v) => setState(() {
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
              ],
            ),
            if (timed) ...[
              _label('Repeat'),
              Wrap(
                spacing: AppSpace.s8,
                runSpacing: AppSpace.s8,
                children: [
                  for (final r in const ['once', 'daily', 'weekdays'])
                    ChoiceChip(
                      label: Text(
                        r == 'once'
                            ? 'Once'
                            : r == 'daily'
                            ? 'Every day'
                            : 'Weekdays',
                      ),
                      selected: _repeat == r,
                      onSelected: (_) => setState(() => _repeat = r),
                    ),
                ],
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
            ],
            Theme(
              data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
              child: ExpansionTile(
                tilePadding: EdgeInsets.zero,
                childrenPadding: EdgeInsets.zero,
                title: const Text('More options'),
                children: [
                  _label('Focus time'),
                  Wrap(
                    spacing: AppSpace.s8,
                    runSpacing: AppSpace.s8,
                    children: [
                      ChoiceChip(
                        label: const Text('None'),
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
                  const SizedBox(height: AppSpace.s12),
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
                ],
              ),
            ),
            const SizedBox(height: AppSpace.s8),
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
                  minutes: _minutes,
                  checkIn: _dateOnly ? false : _check,
                  dateOnly: _dateOnly,
                ),
              ),
              child: const Text('Apply details'),
            ),
          ],
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
