import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/app_navigation.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/travel/travel_providers.dart';
import '../../core/travel/travel_service.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_sheet.dart';
import '../../shared/widgets/ascent_snack_bar.dart';

/// New trip (or edit when [editing] is set). Only the name is needed:
/// it starts today, and people can be added any time.
Future<void> showTripSheet(BuildContext context, {TripView? editing}) =>
    showAscentSheet<void>(
      context: context,
      builder: (_) => TripSheet(editing: editing),
    );

class TripSheet extends ConsumerStatefulWidget {
  const TripSheet({super.key, this.editing});
  final TripView? editing;

  @override
  ConsumerState<TripSheet> createState() => _TripSheetState();
}

class _TripSheetState extends ConsumerState<TripSheet> {
  late final TextEditingController _name;
  final _person = TextEditingController();
  final _people = <String>[];
  DateTimeRange? _dates;
  String? _error;

  bool get _isEdit => widget.editing != null;

  @override
  void initState() {
    super.initState();
    final t = widget.editing?.trip;
    _name = TextEditingController(text: t?.name ?? '');
    if (t?.startDay != null) {
      _dates = DateTimeRange(start: t!.startDay!, end: t.endDay ?? t.startDay!);
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _person.dispose();
    super.dispose();
  }

  void _addPerson() {
    final n = _person.text.trim();
    if (n.isEmpty) return;
    HapticFeedback.selectionClick();
    setState(() {
      for (final part in n.split(',')) {
        if (part.trim().isNotEmpty) _people.add(part.trim());
      }
      _person.clear();
    });
  }

  Future<void> _pickDates() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 3),
      initialDateRange:
          _dates ??
          DateTimeRange(start: now, end: now.add(const Duration(days: 3))),
      helpText: 'Trip dates',
    );
    if (picked != null && mounted) setState(() => _dates = picked);
  }

  Future<void> _save() async {
    if (_name.text.trim().isEmpty) {
      setState(() => _error = 'Give the trip a name, e.g. Goa.');
      return;
    }
    _addPerson();
    final travel = ref.read(travelServiceProvider);
    try {
      if (_isEdit) {
        final id = widget.editing!.id;
        await travel.editTrip(
          id,
          name: _name.text,
          start: Value(_dates?.start ?? widget.editing!.trip.startDay),
          end: Value(_dates?.end),
        );
        for (final p in _people) {
          await travel.addPerson(id, p);
        }
        if (mounted) Navigator.of(context).pop();
        return;
      }
      final id = await travel.createTrip(
        name: _name.text,
        start: _dates?.start,
        end: _dates?.end,
        people: _people,
      );
      HapticFeedback.lightImpact();
      if (!mounted) return;
      final root = Navigator.of(context, rootNavigator: true).context;
      Navigator.of(context).pop();
      if (root.mounted) {
        root.open('/travel/trip?id=$id');
        AscentSnackBar.undo(
          root,
          message: 'Trip made. Tap I’m here wherever you go.',
          onUndo: () => travel.deleteTrip(id),
        );
      }
    } on ArgumentError catch (e) {
      if (mounted) setState(() => _error = '${e.message}');
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final fmt = DateFormat('d MMM');
    final existing = widget.editing?.people.where((p) => !p.isMe) ?? const [];
    return SingleChildScrollView(
      primary: true,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        0,
        AppSpace.s16,
        AppSpace.s24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              AscentButton.ghost(
                label: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  _isEdit ? 'Edit trip' : 'New trip',
                  textAlign: TextAlign.center,
                  style: AscentTextStyles.cardTitle.copyWith(color: g.ink),
                ),
              ),
              AscentButton.ghost(
                key: const ValueKey('trip_save'),
                label: _isEdit ? 'Save' : 'Create',
                onPressed: _save,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          AppTextField(
            key: const ValueKey('trip_name'),
            controller: _name,
            autofocus: !_isEdit,
            hintText: 'Where to? e.g. Goa',
            textCapitalization: TextCapitalization.words,
            onChanged: (_) {
              if (_error != null) setState(() => _error = null);
            },
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpace.s8),
            Text(
              _error!,
              style: AscentTextStyles.caption.copyWith(color: g.errorInk),
            ),
          ],
          const SizedBox(height: AppSpace.s16),
          Align(
            alignment: Alignment.centerLeft,
            child: AppChip(
              key: const ValueKey('trip_dates'),
              icon: Icons.calendar_month_outlined,
              label: _dates == null
                  ? 'Starts today · add dates'
                  : '${fmt.format(_dates!.start)} to ${fmt.format(_dates!.end)}',
              isSelected: _dates != null,
              onTap: _pickDates,
            ),
          ),
          const SizedBox(height: AppSpace.s20),
          Text(
            'Who’s coming? (for splitting bills)',
            style: AscentTextStyles.caption.copyWith(color: g.ink),
          ),
          const SizedBox(height: AppSpace.s8),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              const AppChip(label: 'You', isSelected: true),
              for (final p in existing) AppChip(label: p.name),
              for (final (i, p) in _people.indexed)
                AppChip(
                  key: ValueKey('trip_person_$p'),
                  label: p,
                  icon: Icons.close_rounded,
                  onTap: () => setState(() => _people.removeAt(i)),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          AppTextField(
            key: const ValueKey('trip_person'),
            controller: _person,
            hintText: 'Add a name, e.g. Ravi',
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _addPerson(),
            suffixIcon: IconButton(
              tooltip: 'Add person',
              icon: Icon(Icons.add_rounded, color: g.actionInk),
              onPressed: _addPerson,
            ),
          ),
        ],
      ),
    );
  }
}
