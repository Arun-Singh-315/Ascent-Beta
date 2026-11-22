import 'care_design.dart';
import 'care_forms.dart';
import '../../core/medicine/medicine_catalog.dart';
import 'care_plans_view.dart';
import 'dose_history_screen.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/widgets/undo_snackbar.dart';
import '../../shared/widgets/history_action.dart';
import '../../shared/widgets/glass_surface.dart';
import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/ascent_dialog.dart';
import '../../shared/widgets/ascent_action_menu.dart';
import '../../core/medicine/refill.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/medicine/medicine_service.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/app_chip.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import 'medicine_editor_sheet.dart';
import 'medicine_quick_add_sheet.dart';
import 'medicine_today.dart';
import 'package:ascent/shared/widgets/skeleton_shimmer.dart';

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

  /// Show only one person's medicines; null shows everyone.
  String? _person;
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
      final service = ref.read(medicineServiceProvider);
      await service.toggleDose(log.id, !log.isTaken);
      HapticFeedback.selectionClick();
      if (!log.isTaken && mounted) {
        showUndoSnackbar(
          context,
          message: 'Dose taken',
          onUndo: () => service.toggleDose(log.id, false),
        );
      }
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

  Future<void> _snoozeDose(MedicineLog log, Duration duration) async {
    try {
      await ref
          .read(medicineServiceProvider)
          .snoozeDose(log.id, duration: duration);
      HapticFeedback.lightImpact();
      if (mounted) {
        AscentSnackBar.show(
          context,
          message: 'Dose snoozed for ${duration.inMinutes} minutes',
          icon: Icons.snooze_rounded,
        );
      }
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(context, message: 'Could not snooze dose.');
      }
    }
  }

  Future<void> _skipDose(MedicineLog log, Medicine medicine) async {
    final reasons = [
      'Fasting / Empty stomach constraint',
      'Physician advised pause',
      'Side effect / Discomfort',
      'Feeling recovered',
      'Other',
    ];
    final selectedReason = await showAscentActionMenu<String>(
      context: context,
      title: 'Skip ${medicine.name}? Why?',
      actions: [
        for (final r in reasons)
          AscentAction(r, r, Icons.chevron_right_rounded),
      ],
    );

    if (selectedReason == null || !mounted) return;

    if (_updating.contains(log.id)) return;
    setState(() => _updating.add(log.id));
    try {
      await ref
          .read(medicineServiceProvider)
          .skipDose(log.id, reason: selectedReason);
      HapticFeedback.mediumImpact();
      if (mounted) {
        AscentSnackBar.show(
          context,
          message: 'Dose marked skipped ($selectedReason)',
          icon: Icons.skip_next_rounded,
        );
      }
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: 'Could not skip dose. Try again.',
        );
      }
    } finally {
      if (mounted) setState(() => _updating.remove(log.id));
    }
  }

  Future<void> _delete(Medicine medicine) async {
    final confirmed = await AscentDialog.confirm(
      context: context,
      title: 'Remove ${medicine.name}?',
      content:
          'This removes the medicine, dose history, and linked reminders and tasks. You can undo immediately afterwards. Archive the schedule if you want to keep its history long term.',
      confirmLabel: 'Remove',
      cancelLabel: 'Keep medicine',
      isDestructive: true,
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

  Widget _tag(String text, {IconData? icon}) => CarePill(text, icon: icon);

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
        plan.title == 'Medicines for ${plan.person}'
            ? 'For ${plan.person}'
            : '${plan.person} · ${plan.title}',
        style: TextStyle(
          color: context.glass.inkMuted,
          fontSize: 12,
          height: 1.5,
        ),
      ),
    );
  }

  /// "For Mum" or "Mum · Heart care" under a medicine, when it has a plan.
  String? _careLine(Medicine medicine) {
    final plan = ref
        .watch(carePlansProvider)
        .value
        ?.where((p) => p.id == medicine.carePlanId)
        .firstOrNull;
    if (plan == null) return null;
    return plan.title == 'Medicines for ${plan.person}'
        ? 'For ${plan.person}'
        : '${plan.person} · ${plan.title}';
  }

  Future<void> _doseMenu(MedicineLog log, Medicine medicine) async {
    final choice = await showAscentActionMenu<String>(
      context: context,
      title: medicine.name,
      actions: const [
        AscentAction('snooze', 'Snooze 30 minutes', Icons.snooze_rounded),
        AscentAction('skip', 'Skip this dose', Icons.skip_next_rounded),
      ],
    );
    if (!mounted) return;
    if (choice == 'snooze') {
      await _snoozeDose(log, const Duration(minutes: 30));
    } else if (choice == 'skip') {
      await _skipDose(log, medicine);
    }
  }

  /// Stock line: how much is left, how long it lasts, restock and refill.
  Widget _stock(Medicine medicine) {
    final g = context.glass;
    final info = refillInfo(medicine, DateTime.now());
    Future<void> setCount({required bool add}) async {
      final n = await showAscentFrostedDialog<int>(
        context: context,
        builder: (_) => _StockDialog(
          title: add ? 'How many did you get?' : 'How many do you have?',
          unit: medicine.type,
        ),
      );
      if (n == null || !mounted) return;
      final service = ref.read(medicineServiceProvider);
      final before = medicine.stockCount;
      await service.setStock(medicine.id, add ? (before ?? 0) + n : n);
      if (!mounted) return;
      showUndoSnackbar(
        context,
        message: add ? 'Restocked $n' : 'Tracking stock',
        onUndo: () => service.setStock(medicine.id, before),
      );
    }

    if (info == null) {
      return Padding(
        padding: const EdgeInsets.only(top: AppSpace.s8),
        child: Align(
          alignment: Alignment.centerLeft,
          child: AscentButton.ghost(
            key: ValueKey('medicine_track_stock_${medicine.id}'),
            label: 'Track stock',
            icon: Icons.inventory_2_outlined,
            compact: true,
            onPressed: () => setCount(add: false),
          ),
        ),
      );
    }
    final unit = switch (medicine.type) {
      'syrup' || 'kadha' => 'ml',
      'globules' => 'pills',
      'churna' || 'powder' => 'servings',
      final t when t.endsWith('s') => t,
      final t => '${t}s',
    };
    final line = info.coversCourse
        ? '${info.left} $unit left · enough for this course'
        : info.daysLeft == 0
        ? 'Out of stock · refill today'
        : '${info.left} $unit left · lasts ${info.daysLeft} day${info.daysLeft == 1 ? '' : 's'} (until ${DateFormat.E().format(info.runsOut)})';
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.inventory_2_outlined,
                size: 16,
                color: info.low ? g.coral : g.inkSecondary,
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  line,
                  key: ValueKey('medicine_stock_${medicine.id}'),
                  style: AscentTextStyles.caption.copyWith(
                    color: info.low ? g.coral : g.inkSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              AscentButton.secondary(
                key: ValueKey('medicine_restock_${medicine.id}'),
                label: 'Restock',
                icon: Icons.add_rounded,
                onPressed: () => setCount(add: true),
              ),
              if (info.low)
                AscentButton.tonal(
                  key: ValueKey('medicine_refill_${medicine.id}'),
                  label: 'Remind me to refill',
                  icon: Icons.alarm_add_rounded,
                  compact: true,
                  onPressed: () async {
                    try {
                      await ref
                          .read(medicineServiceProvider)
                          .scheduleRefillReminder(medicine);
                      if (mounted) {
                        AscentSnackBar.show(
                          context,
                          message: 'Refill reminder set for ${medicine.name}',
                          icon: Icons.notifications_active_rounded,
                        );
                      }
                    } catch (_) {
                      if (mounted) {
                        AscentSnackBar.error(
                          context,
                          message: 'Could not set the refill reminder',
                        );
                      }
                    }
                  },
                ),
            ],
          ),
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
                Builder(
                  builder: (_) {
                    final system = MedicineSystem.from(medicine.system);
                    final form = medicine.type.isEmpty
                        ? ''
                        : '${medicine.type[0].toUpperCase()}${medicine.type.substring(1)}';
                    return _tag(
                      system == MedicineSystem.allopathy
                          ? (form.isEmpty ? 'Medicine' : form)
                          : form.isEmpty
                          ? system.label
                          : '${system.label} · $form',
                      icon: system.icon,
                    );
                  },
                ),
                _tag(status),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              medicine.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                color: g.ink,
                fontWeight: FontWeight.w600,
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
            Text(switch (medicine.everyDays) {
              7 =>
                times.length == 1
                    ? 'Once a week'
                    : '${times.length} doses, once a week',
              2 =>
                '${times.length} dose${times.length == 1 ? '' : 's'}, every other day',
              _ => '${times.length} daily dose${times.length == 1 ? '' : 's'}',
            }, style: TextStyle(color: g.inkMuted)),
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
            if (medicine.isActive) _stock(medicine),
            if (medicine.isActive &&
                medicine.durationDays - day <= 3 &&
                medicine.durationDays - day >= 0) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: g.amberSoft.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: g.amber.withValues(alpha: 0.3),
                    width: 1,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.inventory_2_outlined,
                          size: 16,
                          color: g.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            medicine.durationDays - day == 0
                                ? 'Course finishes today · Refill if continued'
                                : '${medicine.durationDays - day} days left · Refill soon',
                            style: TextStyle(
                              color: g.ink,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    AscentButton.outlined(
                      label: 'Set Refill Reminder',
                      icon: Icons.alarm_add_rounded,
                      compact: true,
                      expanded: false,
                      onPressed: () async {
                        try {
                          await ref
                              .read(medicineServiceProvider)
                              .scheduleRefillReminder(medicine);
                          if (mounted) {
                            AscentSnackBar.show(
                              context,
                              message:
                                  'Refill reminder scheduled for ${medicine.name}',
                              icon: Icons.notifications_active_rounded,
                            );
                          }
                        } catch (_) {
                          if (mounted) {
                            AscentSnackBar.error(
                              context,
                              message: 'Could not schedule refill reminder',
                            );
                          }
                        }
                      },
                    ),
                  ],
                ),
              ),
            ],
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
          fontWeight: FontWeight.w600,
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
        onPressed: () => showMedicineQuickAdd(context),
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
          onPressed: () => showMedicineQuickAdd(context),
          icon: const Icon(Icons.add_rounded),
        ),
      ],
      body: medicines.when(
        loading: () => const ListSkeleton(),
        error: (_, _) => Center(
          child: AscentButton.ghost(
            label: 'Couldn’t load medicines. Try again',
            onPressed: () => ref.invalidate(allMedicinesStreamProvider),
          ),
        ),
        data: (allMedicines) {
          // Whose medicine is it? Medicines without a care plan are "Me".
          final plans = {
            for (final p in ref.watch(carePlansProvider).value ?? const [])
              p.id: p,
          };
          String personOf(Medicine m) {
            final who = plans[m.carePlanId]?.person;
            return who == null || who == 'My care' ? 'Me' : who;
          }

          final people = {for (final m in allMedicines) personOf(m)}.toList()
            ..sort((a, b) => a == 'Me' ? -1 : (b == 'Me' ? 1 : a.compareTo(b)));
          final person = people.contains(_person) ? _person : null;
          final medicines = person == null
              ? allMedicines
              : allMedicines.where((m) => personOf(m) == person).toList();
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
              if (people.length > 1 && _view != 2)
                SizedBox(
                  height: 52,
                  child: ListView(
                    key: const ValueKey('medicine_people'),
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(
                      AppSpace.s16,
                      AppSpace.s8,
                      AppSpace.s16,
                      0,
                    ),
                    children: [
                      for (final p in [null, ...people]) ...[
                        AppChip(
                          key: ValueKey('medicine_filter_${p ?? 'everyone'}'),
                          label: p ?? 'Everyone',
                          isSelected: person == p,
                          onTap: () => setState(() => _person = p),
                        ),
                        const SizedBox(width: AppSpace.s8),
                      ],
                    ],
                  ),
                ),
              Expanded(
                child: _view == 2
                    ? const CarePlansView()
                    : ListView(
                        key: ValueKey(_showMedicines),
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        children: [
                          if (!_showMedicines) ...[
                            if (today.hasError)
                              AscentButton.ghost(
                                label: 'Couldn’t load today’s doses. Try again',
                                onPressed: () => ref.invalidate(
                                  todayMedicineLogsStreamProvider,
                                ),
                              ),
                            if (medicines.isNotEmpty && today.hasValue) ...[
                              MedicineTodayHero(
                                logs: logs,
                                byId: byId,
                                updating: _updating,
                                onTake: _toggleDose,
                                onSnooze: (log) => _snoozeDose(
                                  log,
                                  const Duration(minutes: 30),
                                ),
                              ),
                              if (logs.isNotEmpty) ...[
                                const SizedBox(height: 28),
                                MedicineDoseList(
                                  logs: logs,
                                  byId: byId,
                                  updating: _updating,
                                  onToggle: _toggleDose,
                                  onMore: _doseMenu,
                                  careLine: _careLine,
                                ),
                              ],
                            ],
                            if (medicines.isEmpty) _emptyMedicines(),
                          ],
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

/// "Morning", "Afternoon", "Evening" or "Night" for an "HH:mm" slot, so the
/// day reads in a few calm groups instead of one card per clock time.
String partOfDay(String slot) {
  final h = int.tryParse(slot.split(':').first) ?? 0;
  if (h >= 5 && h < 12) return 'Morning';
  if (h >= 12 && h < 17) return 'Afternoon';
  if (h >= 17 && h < 21) return 'Evening';
  return 'Night';
}

/// Asks for a whole number of units (tablets, ml…).
class _StockDialog extends StatefulWidget {
  const _StockDialog({required this.title, required this.unit});
  final String title;
  final String unit;

  @override
  State<_StockDialog> createState() => _StockDialogState();
}

class _StockDialogState extends State<_StockDialog> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  int? get _value {
    final n = int.tryParse(_c.text.trim());
    return n == null || n < 0 || n > 100000 ? null : n;
  }

  @override
  Widget build(BuildContext context) => AscentDialog(
    title: widget.title,
    contentWidget: AppTextField(
      key: const ValueKey('medicine_stock_field'),
      controller: _c,
      autofocus: true,
      keyboardType: TextInputType.number,
      hintText: widget.unit == 'syrup' ? 'e.g. 100 ml' : 'e.g. 15',
      onChanged: (_) => setState(() {}),
      onSubmitted: (_) {
        if (_value != null) Navigator.pop(context, _value);
      },
    ),
    actions: [
      Wrap(
        alignment: WrapAlignment.end,
        spacing: AppSpace.s8,
        children: [
          AscentButton.secondary(
            label: 'Cancel',
            onPressed: () => Navigator.pop(context),
          ),
          AscentButton.tonal(
            key: const ValueKey('medicine_stock_save'),
            label: 'Save',
            compact: true,
            onPressed: _value == null
                ? null
                : () => Navigator.pop(context, _value),
          ),
        ],
      ),
    ],
  );
}
