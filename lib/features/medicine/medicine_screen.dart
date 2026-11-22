import 'care_design.dart';
import 'care_forms.dart';
import '../../core/medicine/medicine_catalog.dart';
import 'care_plans_view.dart';
import 'dose_history_screen.dart';
import '../../shared/widgets/ascent_segmented_control.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/widgets/undo_snackbar.dart';
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
import '../../app/theme/surface_tokens.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/ascent_dialog.dart';
import '../../shared/widgets/ascent_action_menu.dart';
import '../../app/theme/brand_palette.dart';
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
import 'package:ascent/shared/widgets/skeleton_shimmer.dart';
import 'package:ascent/shared/widgets/ascent_progress_ring.dart';

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
      title: 'Skip dose for ${medicine.name}?',
      actions: [
        for (final r in reasons)
          AscentAction(r, r, Icons.do_not_disturb_on_outlined),
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

  Widget _label(String text) => Padding(
    padding: const EdgeInsets.only(top: 24, bottom: 12),
    child: Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
    ),
  );

  Widget _tag(String text, {IconData? icon}) => CarePill(text, icon: icon);

  Widget _summary(List<MedicineLog> logs, {required bool hasMedicines}) {
    final g = context.glass;
    final taken = logs.where((log) => log.isTaken).length;
    final now = DateTime.now();
    final currentTime = DateFormat('HH:mm').format(now);
    final overdueCount = logs
        .where((log) => !log.isTaken && log.timeSlot.compareTo(currentTime) < 0)
        .length;
    final next = logs
        .where(
          (log) => !log.isTaken && log.timeSlot.compareTo(currentTime) >= 0,
        )
        .firstOrNull;

    final String heroTitle;
    if (!hasMedicines) {
      heroTitle = 'Your Care\nCompanion';
    } else if (taken == logs.length && logs.isNotEmpty) {
      heroTitle = 'All caught up!\nRest well 🌿';
    } else if (overdueCount > 0) {
      heroTitle = 'A dose is\nwaiting for you';
    } else {
      heroTitle = 'One dose\nat a time.';
    }

    return CareHero(
      eyebrow: DateFormat('EEEE, MMM d').format(now),
      title: heroTitle,
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
                            AscentProgressRing(
                              value: logs.isEmpty ? 0 : taken / logs.length,
                              strokeWidth: 4,
                              color: g.actionInk,
                              trackColor: g.track,
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
                  if (overdueCount > 0) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: g.coral.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            size: 14,
                            color: g.coral,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              '$overdueCount pending dose${overdueCount == 1 ? '' : 's'} past scheduled time',
                              style: TextStyle(
                                color: g.coral,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
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

  /// One part of the day inside the Today card: a coloured side border,
  /// a small label with the count, then compact dose rows.
  Widget _doseSection(
    String slot,
    List<MedicineLog> slotLogs,
    Map<int, Medicine> byId,
  ) {
    final g = context.glass;
    final tint = switch (slot) {
      'Morning' => g.amber,
      'Afternoon' => g.actionInk,
      'Evening' => BrandPalette.pillarTint('mind', dark: g.isDark),
      _ => BrandPalette.pillarTint('assistant', dark: g.isDark),
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: BorderDirectional(start: BorderSide(color: tint, width: 3)),
        ),
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Text(
                    slot,
                    key: ValueKey('dose_group_$slot'),
                    style: AscentTextStyles.listRowTitle.copyWith(color: tint),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${slotLogs.length} dose${slotLogs.length == 1 ? '' : 's'}',
                    style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
                  ),
                ],
              ),
              for (var i = 0; i < slotLogs.length; i++)
                if (byId[slotLogs[i].medicineId] case final m?)
                  _dose(slotLogs[i], m, isLast: i == slotLogs.length - 1),
            ],
          ),
        ),
      ),
    );
  }

  Widget _dose(MedicineLog log, Medicine medicine, {bool isLast = true}) {
    final g = context.glass;
    final now = DateTime.now();
    final currentTime = DateFormat('HH:mm').format(now);
    final isFuture = !log.isTaken && log.timeSlot.compareTo(currentTime) > 0;
    final isOverdue = !log.isTaken && log.timeSlot.compareTo(currentTime) < 0;

    final details = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          medicine.name,
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            fontSize: 17,
            color: g.ink,
          ),
        ),
        _careContext(medicine),
        const SizedBox(height: 2),
        Text(
          '${MedicineService.formatTimeSlot(log.timeSlot)} · ${medicine.dosage}',
          style: AscentTextStyles.caption.copyWith(color: g.inkSecondary),
        ),
      ],
    );
    final Widget action;
    if (isFuture) {
      action = GlassChip(
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
      );
    } else if (log.isTaken) {
      action = GlassChip(
        label: _updating.contains(log.id) ? 'Saving…' : 'Taken',
        tooltip: 'Undo taken dose',
        success: true,
        onTap: _updating.contains(log.id) ? null : () => _toggleDose(log),
      );
    } else {
      action = Wrap(
        spacing: 6,
        runSpacing: 6,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          GlassChip(
            label: _updating.contains(log.id) ? 'Saving…' : 'Take',
            tooltip: 'Mark taken',
            success: false,
            onTap: _updating.contains(log.id) ? null : () => _toggleDose(log),
          ),
          // Late doses: Snooze and Skip live in one small menu, so each row
          // stays a single line however many doses there are.
          if (isOverdue)
            IconButton(
              key: ValueKey('medicine_dose_more_${log.id}'),
              tooltip: 'Snooze or skip',
              icon: Icon(Icons.more_horiz_rounded, color: g.inkMuted),
              onPressed: () async {
                final choice = await showAscentActionMenu<String>(
                  context: context,
                  title: medicine.name,
                  actions: const [
                    AscentAction(
                      'snooze',
                      'Snooze 30 minutes',
                      Icons.snooze_rounded,
                    ),
                    AscentAction(
                      'skip',
                      'Skip this dose',
                      Icons.skip_next_rounded,
                    ),
                  ],
                );
                if (!mounted) return;
                if (choice == 'snooze') {
                  await _snoozeDose(log, const Duration(minutes: 30));
                } else if (choice == 'skip') {
                  await _skipDose(log, medicine);
                }
              },
            ),
        ],
      );
    }
    return Container(
      key: ValueKey('medicine_dose_${log.id}'),
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: g.line)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(14) > 16) {
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
          child: TextButton(
            onPressed: () => ref.invalidate(allMedicinesStreamProvider),
            child: const Text('Could not load medicines. Tap to retry.'),
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
                                  // All of today's doses in one card,
                                  // grouped by part of day with a coloured
                                  // side border, so many medicines stay
                                  // easy to scan.
                                  if (logs.any((l) => l.isTaken == _showTaken))
                                    Padding(
                                      padding: const EdgeInsets.only(top: 12),
                                      child: CarePanel(
                                        key: const ValueKey(
                                          'medicine_today_board',
                                        ),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.stretch,
                                          children: [
                                            for (final slot
                                                in logs
                                                    .where(
                                                      (l) =>
                                                          l.isTaken ==
                                                          _showTaken,
                                                    )
                                                    .map(
                                                      (l) =>
                                                          partOfDay(l.timeSlot),
                                                    )
                                                    .toSet())
                                              _doseSection(
                                                slot,
                                                logs
                                                    .where(
                                                      (l) =>
                                                          partOfDay(
                                                                l.timeSlot,
                                                              ) ==
                                                              slot &&
                                                          l.isTaken ==
                                                              _showTaken,
                                                    )
                                                    .toList(),
                                                byId,
                                              ),
                                          ],
                                        ),
                                      ),
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
