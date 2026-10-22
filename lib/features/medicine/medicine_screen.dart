import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/medicine/medicine_service.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import 'medicine_editor_sheet.dart';

class MedicineScreen extends ConsumerStatefulWidget {
  const MedicineScreen({super.key});
  @override
  ConsumerState<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends ConsumerState<MedicineScreen>
    with WidgetsBindingObserver {
  final _updating = <int>{};
  bool _showMedicines = false;
  Timer? _dayTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDayChange();
  }

  void _scheduleDayChange() {
    _dayTimer?.cancel();
    final now = DateTime.now();
    _dayTimer = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      () {
        if (mounted) {
          setState(() {});
          ref.invalidate(todayMedicineLogsStreamProvider);
          _scheduleDayChange();
        }
      },
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      ref.invalidate(todayMedicineLogsStreamProvider);
      _scheduleDayChange();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayTimer?.cancel();
    super.dispose();
  }

  Future<void> _toggleDose(MedicineLog log) async {
    if (_updating.contains(log.id)) return;
    setState(() => _updating.add(log.id));
    try {
      await ref.read(medicineServiceProvider).toggleDose(log.id, !log.isTaken);
      HapticFeedback.selectionClick();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not update this dose. Try again.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _updating.remove(log.id));
    }
  }

  Future<void> _delete(Medicine medicine) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Remove ${medicine.name}?'),
        content: const Text(
          'This removes the medicine, dose history, and its linked reminders and tasks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep medicine'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    try {
      await ref.read(medicineServiceProvider).deleteMedicine(medicine.id);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not remove this medicine. Try again.'),
          ),
        );
      }
    }
  }

  Widget _surface({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) => Container(
    padding: padding,
    decoration: BoxDecoration(
      color: context.bgSurface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.glass.edge),
    ),
    child: child,
  );

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Widget _tag(String text, {IconData? icon}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: context.bgSurfaceElevated,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: context.glass.line),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 15, color: context.glass.inkSecondary),
          const SizedBox(width: 6),
        ],
        Flexible(
          child: Text(
            text,
            style: TextStyle(color: context.glass.inkSecondary),
          ),
        ),
      ],
    ),
  );

  Widget _summary(List<MedicineLog> logs) {
    final g = context.glass;
    final taken = logs.where((log) => log.isTaken).length;
    final now = DateTime.now();
    final currentTime = DateFormat('HH:mm').format(now);
    final next = logs
        .where(
          (log) => !log.isTaken && log.timeSlot.compareTo(currentTime) >= 0,
        )
        .firstOrNull;
    return _surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: context.bgSurfaceElevated,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  Icons.medication_outlined,
                  color: g.inkSecondary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your daily care',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      DateFormat('EEEE, MMM d').format(now),
                      style: TextStyle(color: g.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            logs.isEmpty
                ? 'No doses scheduled today'
                : '$taken of ${logs.length} doses taken',
            style: TextStyle(
              color: g.inkSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: logs.isEmpty ? 0 : taken / logs.length,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
            color: g.sage,
            backgroundColor: g.track,
          ),
          if (next != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(
                'Next scheduled dose · ${MedicineService.formatTimeSlot(next.timeSlot)}',
                style: TextStyle(color: g.inkMuted),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dose(MedicineLog log, Medicine medicine) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              medicine.name,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: g.ink,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              medicine.dosage,
              style: TextStyle(color: g.inkSecondary, height: 1.4),
            ),
            if (medicine.instructions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  medicine.instructions,
                  style: TextStyle(color: g.inkMuted, height: 1.4),
                ),
              ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: log.isTaken
                  ? OutlinedButton.icon(
                      onPressed: _updating.contains(log.id)
                          ? null
                          : () => _toggleDose(log),
                      icon: Icon(Icons.check_circle_rounded, color: g.sage),
                      label: Text(
                        log.takenAt == null
                            ? 'Taken · Undo'
                            : 'Taken ${DateFormat('h:mm a').format(log.takenAt!)} · Undo',
                        textAlign: TextAlign.center,
                      ),
                    )
                  : FilledButton.icon(
                      onPressed: _updating.contains(log.id)
                          ? null
                          : () => _toggleDose(log),
                      icon: const Icon(Icons.check_rounded),
                      label: Text(
                        _updating.contains(log.id) ? 'Saving…' : 'Mark taken',
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _medicine(Medicine medicine) {
    final g = context.glass;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final start = DateTime(
      medicine.startDate.year,
      medicine.startDate.month,
      medicine.startDate.day,
    );
    final end = DateTime(
      start.year,
      start.month,
      start.day + medicine.durationDays - 1,
    );
    final day = (today.difference(start).inDays + 1).clamp(
      0,
      medicine.durationDays,
    );
    final status = !medicine.isActive
        ? 'Paused'
        : today.isBefore(start)
        ? 'Starts ${DateFormat.MMMd().format(start)}'
        : today.isAfter(end)
        ? 'Course complete'
        : 'Day $day of ${medicine.durationDays}';
    List<String> times = [];
    try {
      times = (jsonDecode(medicine.scheduledTimes) as List).cast<String>()
        ..sort();
    } catch (_) {
      /* Keep a damaged schedule editable. */
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _surface(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _tag(
                  '${medicine.type[0].toUpperCase()}${medicine.type.substring(1)}',
                  icon: Icons.medication_outlined,
                ),
                _tag(status),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              medicine.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: g.ink,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(medicine.dosage, style: TextStyle(color: g.inkSecondary)),
            if (medicine.instructions.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  medicine.instructions,
                  style: TextStyle(color: g.inkMuted, height: 1.4),
                ),
              ),
            const SizedBox(height: 16),
            Text(
              '${times.length} daily dose${times.length == 1 ? '' : 's'}',
              style: TextStyle(color: g.inkMuted),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final time in times)
                  _tag(
                    MedicineService.formatTimeSlot(time),
                    icon: Icons.schedule_rounded,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              '${DateFormat.MMMd().format(start)} – ${DateFormat.yMMMd().format(end)}',
              style: TextStyle(color: g.inkMuted),
            ),
            const SizedBox(height: 10),
            LinearProgressIndicator(
              value: day / medicine.durationDays,
              minHeight: 4,
              borderRadius: BorderRadius.circular(4),
              color: g.sage,
              backgroundColor: g.track,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.end,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Tooltip(
                  message: 'Edit Prescription',
                  child: TextButton.icon(
                    onPressed: () =>
                        showMedicineEditor(context, medicine: medicine),
                    icon: const Icon(Icons.edit_outlined, size: 18),
                    label: const Text('Edit schedule'),
                  ),
                ),
                IconButton(
                  tooltip: 'Delete Prescription',
                  onPressed: () => _delete(medicine),
                  icon: Icon(Icons.delete_outline_rounded, color: g.inkMuted),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tab(String label, bool medicines) {
    final selected = _showMedicines == medicines;
    return Expanded(
      child: Semantics(
        selected: selected,
        child: TextButton(
          key: ValueKey(
            medicines ? 'medicine_view_medicines' : 'medicine_view_today',
          ),
          onPressed: () => setState(() => _showMedicines = medicines),
          style: TextButton.styleFrom(
            backgroundColor: selected
                ? Theme.of(context).colorScheme.primary
                : Colors.transparent,
            foregroundColor: selected
                ? Theme.of(context).colorScheme.onPrimary
                : context.glass.inkSecondary,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
          child: Text(label, textAlign: TextAlign.center),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final medicines = ref.watch(allMedicinesStreamProvider);
    final today = ref.watch(todayMedicineLogsStreamProvider);
    return AscentScaffold(
      title: 'Medicines',
      subtitle: 'Daily care',
      showFeatureHelp: false,
      actions: [
        IconButton(
          tooltip: 'Add Medicine',
          onPressed: () => showMedicineEditor(context),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      body: medicines.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: TextButton(
            onPressed: () => ref.invalidate(allMedicinesStreamProvider),
            child: const Text('Could not load medicines. Tap to retry.'),
          ),
        ),
        data: (medicines) {
          final byId = {
            for (final medicine in medicines) medicine.id: medicine,
          };
          final logs =
              (today.value ?? [])
                  .where((log) => byId[log.medicineId]?.isActive == true)
                  .toList()
                ..sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: _surface(
                  padding: const EdgeInsets.all(4),
                  child: Row(
                    children: [_tab('Today', false), _tab('My meds', true)],
                  ),
                ),
              ),
              Expanded(
                child: ListView(
                  key: ValueKey(_showMedicines),
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    if (!_showMedicines) ...[
                      if (today.hasValue) _summary(logs),
                      if (today.hasError)
                        TextButton(
                          onPressed: () =>
                              ref.invalidate(todayMedicineLogsStreamProvider),
                          child: const Text(
                            'Could not load today’s doses. Tap to retry.',
                          ),
                        ),
                      if (today.isLoading) const LinearProgressIndicator(),
                      if (logs.isNotEmpty) ...[
                        _label('Today’s schedule'),
                        for (var i = 0; i < logs.length; i++) ...[
                          if (i == 0 ||
                              logs[i - 1].timeSlot != logs[i].timeSlot)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(4, 8, 4, 10),
                              child: Text(
                                MedicineService.formatTimeSlot(
                                  logs[i].timeSlot,
                                ),
                                style: TextStyle(
                                  color: context.glass.inkSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          _dose(logs[i], byId[logs[i].medicineId]!),
                        ],
                      ],
                    ],
                    if (_showMedicines) _label('Your medicines'),
                    if (medicines.isEmpty)
                      _surface(
                        child: Column(
                          children: [
                            Icon(
                              Icons.medication_outlined,
                              size: 40,
                              color: context.glass.inkSecondary,
                            ),
                            const SizedBox(height: 12),
                            Text(
                              'A place for your medicines',
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Keep the dose, exact times, and course together. Follow each day’s schedule here.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: context.glass.inkMuted,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 20),
                            FilledButton.icon(
                              onPressed: () => showMedicineEditor(context),
                              icon: const Icon(Icons.add_rounded),
                              label: const Text('Add First Medicine'),
                            ),
                          ],
                        ),
                      )
                    else if (_showMedicines)
                      ...medicines.map(_medicine),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
