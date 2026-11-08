import 'care_design.dart';
import 'care_forms.dart';
import 'care_plans_view.dart';
import 'dose_history_screen.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/widgets/history_action.dart';
import '../../shared/widgets/glass_chip.dart';
import '../../shared/widgets/glass_surface.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/medicine/medicine_service.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';
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
  int _view = 0;
  bool get _showMedicines => _view == 1;
  bool _showTaken = false;
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
        AscentSnackBar.error(
          context,
          message: 'Could not update this dose. Try again.',
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
          'This removes the medicine, dose history, and linked reminders and tasks. You can undo immediately afterwards. Archive the schedule if you want to keep its history long term.',
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
      final restore = await ref
          .read(medicineServiceProvider)
          .removeWithUndo(medicine.id);
      if (mounted) {
        AscentSnackBar.undo(
          context,
          message: '${medicine.name} removed',
          onUndo: () async {
            try {
              await restore();
            } catch (_) {
              if (mounted) {
                AscentSnackBar.error(
                  context,
                  message: 'Could not restore this medicine.',
                );
              }
            }
          },
        );
      }
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: 'Could not remove this medicine. Try again.',
        );
      }
    }
  }

  Widget _surface({
    required Widget child,
    EdgeInsets padding = const EdgeInsets.all(18),
  }) => GlassSurface(radius: 20, padding: padding, child: child);

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
    ),
  );

  Widget _tag(String text, {IconData? icon}) => CarePill(text, icon: icon);

  Widget _summary(List<MedicineLog> logs, {required bool hasMedicines}) {
    final g = context.glass;
    final taken = logs.where((log) => log.isTaken).length;
    final now = DateTime.now();
    final currentTime = DateFormat('HH:mm').format(now);
    final next = logs
        .where(
          (log) => !log.isTaken && log.timeSlot.compareTo(currentTime) >= 0,
        )
        .firstOrNull;
    return CareHero(
      eyebrow: DateFormat('EEEE, MMM d').format(now),
      title: 'One dose\nat a time.',
      child: hasMedicines
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: g.surface.withValues(alpha: .7),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SizedBox.square(
                        dimension: 44,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CircularProgressIndicator(
                              value: logs.isEmpty ? 0 : taken / logs.length,
                              strokeWidth: 4,
                              color: g.actionInk,
                              backgroundColor: g.track,
                            ),
                            Icon(
                              taken == logs.length && logs.isNotEmpty
                                  ? Icons.check_rounded
                                  : Icons.medication_outlined,
                              size: 20,
                              color: g.actionInk,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          logs.isEmpty
                              ? 'No doses scheduled today'
                              : '$taken of ${logs.length} doses taken',
                          style: TextStyle(
                            color: g.ink,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ],
                  ),
                  if (next != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      'Next scheduled dose · ${MedicineService.formatTimeSlot(next.timeSlot)}',
                      style: TextStyle(
                        color: g.inkSecondary,
                        fontSize: 12,
                        height: 1.5,
                      ),
                    ),
                  ],
                ],
              ),
            )
          : Text(
              'A little structure for the care that matters.',
              style: TextStyle(
                color: g.inkSecondary,
                fontSize: 14,
                height: 1.6,
              ),
            ),
    );
  }

  Widget _careContext(Medicine medicine) {
    final plan = ref
        .watch(carePlansProvider)
        .value
        ?.where((p) => p.id == medicine.carePlanId)
        .firstOrNull;
    if (plan == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        '${plan.person} · ${plan.title}',
        style: TextStyle(
          color: context.glass.inkMuted,
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }

  Widget _dose(MedicineLog log, Medicine medicine, {bool isLast = true}) {
    final g = context.glass;
    final now = DateTime.now();
    final currentTime = DateFormat('HH:mm').format(now);
    final isFuture = !log.isTaken && log.timeSlot.compareTo(currentTime) > 0;

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          medicine.name,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 17,
            color: g.ink,
          ),
        ),
        _careContext(medicine),
        const SizedBox(height: 2),
        Text(
          medicine.dosage,
          style: TextStyle(color: g.inkSecondary, fontSize: 13),
        ),
      ],
    );
    final action = isFuture
        ? GlassChip(
            label: 'Scheduled',
            icon: Icons.lock_outline_rounded,
            tooltip:
                'Scheduled for ${MedicineService.formatTimeSlot(log.timeSlot)}. Available once time arrives.',
            onTap: () {
              HapticFeedback.lightImpact();
              AscentSnackBar.show(
                context,
                message:
                    'Scheduled for ${MedicineService.formatTimeSlot(log.timeSlot)}. Available once time arrives.',
                icon: Icons.schedule_rounded,
              );
            },
          )
        : GlassChip(
            label: _updating.contains(log.id)
                ? 'Saving…'
                : log.isTaken
                ? 'Taken'
                : 'Take',
            tooltip: log.isTaken ? 'Undo taken dose' : 'Mark taken',
            success: log.isTaken,
            onTap: _updating.contains(log.id) ? null : () => _toggleDose(log),
          );
    return Container(
      key: ValueKey('medicine_dose_${log.id}'),
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: g.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(14) > 18) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [details, const SizedBox(height: 10), action],
                );
              }
              return Row(
                children: [
                  Expanded(child: details),
                  const SizedBox(width: 12),
                  action,
                ],
              );
            },
          ),
          if (medicine.instructions.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              medicine.instructions,
              style: TextStyle(color: g.inkMuted, fontSize: 12, height: 1.35),
            ),
          ],
          if (log.isTaken && log.takenAt != null) ...[
            const SizedBox(height: 6),
            Text(
              'Taken at ${DateFormat.jm().format(log.takenAt!)} · Tap to undo',
              style: Theme.of(
                context,
              ).textTheme.labelSmall?.copyWith(color: g.inkMuted),
            ),
          ],
        ],
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
        ? 'Archived'
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
      padding: const EdgeInsets.only(bottom: 14),
      child: CarePanel(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 6,
              alignment: WrapAlignment.spaceBetween,
              children: [
                _tag(
                  medicine.type.isEmpty
                      ? 'Medicine'
                      : '${medicine.type[0].toUpperCase()}${medicine.type.substring(1)}',
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
            _careContext(medicine),
            const SizedBox(height: 6),
            Text(medicine.dosage, style: TextStyle(color: g.inkSecondary)),
            if (medicine.purpose.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  medicine.purpose,
                  style: TextStyle(color: g.inkSecondary, height: 1.5),
                ),
              ),
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
              color: g.actionInk,
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
                  tooltip: medicine.isActive
                      ? 'Archive schedule, keep history'
                      : 'Restore schedule',
                  onPressed: () async {
                    final service = ref.read(medicineServiceProvider);
                    final revision = service.db.workspaceRevision;
                    try {
                      await service.updateMedicine(
                        medicine.id,
                        active: !medicine.isActive,
                      );
                      if (mounted) {
                        AscentSnackBar.undo(
                          context,
                          message: medicine.isActive
                              ? 'Schedule archived. Dose history kept.'
                              : 'Schedule restored',
                          onUndo: () async {
                            try {
                              if (revision != service.db.workspaceRevision) {
                                throw StateError('Workspace changed');
                              }
                              await service.updateMedicine(
                                medicine.id,
                                active: medicine.isActive,
                              );
                            } catch (_) {
                              if (mounted) {
                                AscentSnackBar.error(
                                  context,
                                  message:
                                      'Could not restore this schedule state.',
                                );
                              }
                            }
                          },
                        );
                      }
                    } catch (_) {
                      if (mounted) {
                        AscentSnackBar.error(
                          context,
                          message: 'Could not update this schedule.',
                        );
                      }
                    }
                  },
                  icon: Icon(
                    medicine.isActive
                        ? Icons.archive_outlined
                        : Icons.unarchive_outlined,
                    color: g.primaryButtonBg,
                  ),
                ),
                IconButton(
                  tooltip: 'Dose history',
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute<void>(
                      builder: (_) => DoseHistoryScreen(medicine: medicine),
                    ),
                  ),
                  icon: Icon(Icons.history_rounded, color: g.actionInk),
                ),
                IconButton(
                  tooltip: 'Delete prescription and history permanently',
                  onPressed: () => _delete(medicine),
                  icon: Icon(Icons.delete_outline_rounded, color: g.errorInk),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _emptyMedicines() => Column(
    children: [
      Text(
        'No medicines added',
        textAlign: TextAlign.center,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: context.glass.ink,
        ),
      ),
      const SizedBox(height: 6),
      Text(
        'Start with your prescription. Add a care plan when you want to keep reports and notes together.',
        textAlign: TextAlign.center,
        style: TextStyle(color: context.glass.inkMuted, height: 1.4),
      ),
      const SizedBox(height: 16),
      AscentButton.outlined(
        label: 'Add Medicine',
        icon: Icons.add_rounded,
        expanded: false,
        onPressed: () => showMedicineEditor(context),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final medicines = ref.watch(allMedicinesStreamProvider);
    final today = ref.watch(todayMedicineLogsStreamProvider);
    return AscentScaffold(
      title: 'Your care',
      subtitle: 'Medicines, plans & your health story',
      showFeatureHelp: false,
      actions: [
        const HistoryAction(module: 'medicines'),
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
                child: AscentSegmentedControl<int>(
                  selected: _view,
                  accented: true,
                  segments: const [
                    AscentSegment(
                      value: 0,
                      label: 'Today',
                      key: ValueKey('medicine_view_today'),
                    ),
                    AscentSegment(
                      value: 1,
                      label: 'Medicines',
                      key: ValueKey('medicine_view_medicines'),
                    ),
                    AscentSegment(
                      value: 2,
                      label: 'Care plans',
                      key: ValueKey('medicine_view_plans'),
                    ),
                  ],
                  onChanged: (view) => setState(() => _view = view),
                ),
              ),
              Expanded(
                child: _view == 2
                    ? const CarePlansView()
                    : ListView(
                        key: ValueKey(_showMedicines),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        children: [
                          if (!_showMedicines)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (today.hasValue)
                                  _summary(
                                    logs,
                                    hasMedicines: medicines.isNotEmpty,
                                  ),
                                if (today.hasError)
                                  TextButton(
                                    onPressed: () => ref.invalidate(
                                      todayMedicineLogsStreamProvider,
                                    ),
                                    child: const Text(
                                      'Could not load today’s doses. Tap to retry.',
                                    ),
                                  ),
                                if (today.isLoading)
                                  const LinearProgressIndicator(),
                                if (logs.isNotEmpty) ...[
                                  Padding(
                                    padding: const EdgeInsets.only(top: 18),
                                    child: AscentSegmentedControl<bool>(
                                      selected: _showTaken,
                                      accented: true,
                                      segments: [
                                        AscentSegment(
                                          value: false,
                                          label:
                                              '${logs.where((l) => !l.isTaken).length} pending',
                                          icon: Icons.schedule_rounded,
                                        ),
                                        AscentSegment(
                                          value: true,
                                          label:
                                              '${logs.where((l) => l.isTaken).length} taken',
                                          icon: Icons.check_rounded,
                                        ),
                                      ],
                                      onChanged: (value) =>
                                          setState(() => _showTaken = value),
                                    ),
                                  ),
                                  _label(
                                    _showTaken
                                        ? 'Taken today'
                                        : 'Today’s schedule',
                                  ),
                                  for (final slot
                                      in logs
                                          .where((l) => l.isTaken == _showTaken)
                                          .map((l) => l.timeSlot)
                                          .toSet())
                                    Builder(
                                      builder: (context) {
                                        final slotLogs = logs
                                            .where(
                                              (l) =>
                                                  l.timeSlot == slot &&
                                                  l.isTaken == _showTaken,
                                            )
                                            .toList();
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 12,
                                          ),
                                          child: CarePanel(
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Wrap(
                                                  spacing: 12,
                                                  runSpacing: 8,
                                                  crossAxisAlignment:
                                                      WrapCrossAlignment.center,
                                                  children: [
                                                    Row(
                                                      mainAxisSize:
                                                          MainAxisSize.min,
                                                      children: [
                                                        Icon(
                                                          Icons
                                                              .schedule_rounded,
                                                          size: 15,
                                                          color: context
                                                              .glass
                                                              .inkSecondary,
                                                        ),
                                                        const SizedBox(
                                                          width: 6,
                                                        ),
                                                        Text(
                                                          MedicineService.formatTimeSlot(
                                                            slot,
                                                          ),
                                                          style: TextStyle(
                                                            fontSize: 13.5,
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            color: context
                                                                .glass
                                                                .ink,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                    Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 3,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: context.glass.ink
                                                            .withValues(
                                                              alpha: 0.06,
                                                            ),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              8,
                                                            ),
                                                      ),
                                                      child: Text(
                                                        '${slotLogs.length} dose${slotLogs.length == 1 ? '' : 's'}',
                                                        style: TextStyle(
                                                          fontSize: 11.5,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                          color: context
                                                              .glass
                                                              .inkSecondary,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 12),
                                                for (
                                                  int i = 0;
                                                  i < slotLogs.length;
                                                  i++
                                                )
                                                  _dose(
                                                    slotLogs[i],
                                                    byId[slotLogs[i]
                                                        .medicineId]!,
                                                    isLast:
                                                        i ==
                                                        slotLogs.length - 1,
                                                  ),
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    ),
                                  if (!logs.any((l) => l.isTaken == _showTaken))
                                    Text(
                                      _showTaken
                                          ? 'No doses taken yet today.'
                                          : 'All scheduled doses taken. Your history is under Taken.',
                                      style: TextStyle(
                                        color: context.glass.inkMuted,
                                      ),
                                    ),
                                ],
                                if (medicines.isEmpty) ...[
                                  const SizedBox(height: 20),
                                  Divider(color: context.glass.line, height: 1),
                                  const SizedBox(height: 20),
                                  _emptyMedicines(),
                                ],
                              ],
                            ),
                          if (_showMedicines) ...[
                            CareHero(
                              compact: true,
                              eyebrow: 'Your medicine shelf',
                              title: 'A routine,\nwith room for you.',
                            ),
                            const CareSectionHeading(
                              'Your medicines',
                              icon: Icons.medication_outlined,
                            ),
                            if (medicines.isEmpty)
                              _surface(child: _emptyMedicines())
                            else
                              for (final medicine in medicines)
                                _medicine(medicine),
                          ],
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
