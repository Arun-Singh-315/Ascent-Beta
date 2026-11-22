import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/brand_palette.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/medicine/medicine_service.dart';
import '../../shared/widgets/ascent_button.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/widgets/glass_card.dart';
import '../../shared/widgets/group_header.dart';

/// Where a dose stands right now.
enum DoseState {
  /// Taken.
  taken,

  /// More than an hour past its time and not taken.
  late,

  /// Its time has come (within the last hour).
  due,

  /// Still ahead.
  later,
}

int _minutes(String slot) {
  final parts = slot.split(':');
  return (int.tryParse(parts.first) ?? 0) * 60 +
      (parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0);
}

DoseState doseState(MedicineLog log, DateTime now) {
  if (log.isTaken) return DoseState.taken;
  final diff = now.hour * 60 + now.minute - _minutes(log.timeSlot);
  if (diff < 0) return DoseState.later;
  return diff > 60 ? DoseState.late : DoseState.due;
}

/// The dose to act on now: the earliest late or due one, else the next.
MedicineLog? nextDose(List<MedicineLog> logs, DateTime now) {
  final open = logs.where((l) => !l.isTaken).toList()
    ..sort((a, b) => a.timeSlot.compareTo(b.timeSlot));
  return open.firstOrNull;
}

Color medicineTint(BuildContext context) =>
    BrandPalette.pillarTint('medicine', dark: context.glass.isDark);

/// The big Today card (the Promise style): the dose to take now in large
/// type, a dot per dose today, and one Take button.
class MedicineTodayHero extends StatelessWidget {
  const MedicineTodayHero({
    super.key,
    required this.logs,
    required this.byId,
    required this.updating,
    required this.onTake,
    required this.onSnooze,
  });
  final List<MedicineLog> logs;
  final Map<int, Medicine> byId;
  final Set<int> updating;
  final ValueChanged<MedicineLog> onTake;
  final ValueChanged<MedicineLog> onSnooze;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final tint = medicineTint(context);
    final now = DateTime.now();
    final taken = logs.where((l) => l.isTaken).length;
    final late = logs.where((l) => doseState(l, now) == DoseState.late).length;
    final next = nextDose(logs, now);
    final med = next == null ? null : byId[next.medicineId];
    final state = next == null ? DoseState.taken : doseState(next, now);
    final String title;
    final String line;
    Color lineColor = g.inkSecondary;
    if (logs.isEmpty) {
      title = 'No doses today';
      line = 'Your medicines rest today.';
    } else if (next == null || med == null) {
      title = 'All doses taken';
      line = 'Well done. See you tomorrow.';
    } else {
      final time = MedicineService.formatTimeSlot(next.timeSlot);
      title = state == DoseState.later ? 'Next: ${med.name}' : med.name;
      switch (state) {
        case DoseState.late:
          line = 'Late · $time · ${med.dosage}';
          lineColor = g.warningInk;
        case DoseState.due:
          line = 'Due now · $time · ${med.dosage}';
          lineColor = g.actionInk;
        default:
          line = '$time · ${med.dosage}';
      }
    }
    final canTake =
        next != null &&
        med != null &&
        (state == DoseState.due || state == DoseState.late);
    final busy = next != null && updating.contains(next.id);
    return GlassCard(
      key: const ValueKey('medicine_hero'),
      padding: const EdgeInsets.all(AppSpace.s20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: .12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(Icons.medication_outlined, size: 18, color: tint),
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  logs.isEmpty
                      ? 'Today'
                      : 'Today · $taken of ${logs.length} taken',
                  style: AscentTextStyles.caption.copyWith(
                    color: g.inkSecondary,
                  ),
                ),
              ),
              if (late > 0)
                Text(
                  '$late late',
                  style: AscentTextStyles.caption.copyWith(color: g.warningInk),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          Text(
            title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AscentTextStyles.pageTitle.copyWith(color: g.ink),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            line,
            style: AscentTextStyles.supportingText.copyWith(color: lineColor),
          ),
          if (logs.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s16),
            Semantics(
              label: '$taken of ${logs.length} doses taken today',
              child: ExcludeSemantics(
                child: Wrap(
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [
                    for (final l in logs)
                      _DoseDot(state: doseState(l, now), isNext: l == next),
                  ],
                ),
              ),
            ),
          ],
          if (canTake) ...[
            const SizedBox(height: AppSpace.s16),
            _Buttons(
              take: AscentButton.primary(
                key: const ValueKey('medicine_hero_take'),
                label: 'Take',
                icon: Icons.check_rounded,
                expanded: true,
                loading: busy,
                onPressed: busy ? null : () => onTake(next),
              ),
              snooze: AscentButton.secondary(
                key: const ValueKey('medicine_hero_snooze'),
                label: 'Snooze',
                expanded: true,
                onPressed: busy ? null : () => onSnooze(next),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Buttons extends StatelessWidget {
  const _Buttons({required this.take, required this.snooze});
  final Widget take, snooze;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(10) > 13) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          take,
          const SizedBox(height: AppSpace.s8),
          snooze,
        ],
      );
    }
    return Row(
      children: [
        Expanded(flex: 3, child: take),
        const SizedBox(width: AppSpace.s8),
        Expanded(flex: 2, child: snooze),
      ],
    );
  }
}

class _DoseDot extends StatelessWidget {
  const _DoseDot({required this.state, required this.isNext});
  final DoseState state;
  final bool isNext;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final tint = medicineTint(context);
    final (Color fill, Color? ring) = switch (state) {
      DoseState.taken => (tint, null),
      DoseState.late => (Colors.transparent, g.warningInk),
      DoseState.due => (Colors.transparent, g.actionInk),
      DoseState.later => (
        g.inkMuted.withValues(alpha: isNext ? .0 : .16),
        isNext ? g.inkMuted : null,
      ),
    };
    return Container(
      width: 14,
      height: 14,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: ring == null ? null : Border.all(color: ring, width: 1.6),
      ),
    );
  }
}

/// All of today's doses in one card, grouped by part of the day. Each row
/// has a round check: tap to take (or undo). Late and due doses also get a
/// small menu for Snooze and Skip.
class MedicineDoseList extends StatelessWidget {
  const MedicineDoseList({
    super.key,
    required this.logs,
    required this.byId,
    required this.updating,
    required this.onToggle,
    required this.onMore,
    this.careLine,
  });
  final List<MedicineLog> logs;
  final Map<int, Medicine> byId;
  final Set<int> updating;
  final ValueChanged<MedicineLog> onToggle;
  final void Function(MedicineLog, Medicine) onMore;
  final String? Function(Medicine)? careLine;

  static const parts = ['Morning', 'Afternoon', 'Evening', 'Night'];

  static String partOf(String slot) {
    final h = int.tryParse(slot.split(':').first) ?? 0;
    if (h >= 5 && h < 12) return 'Morning';
    if (h >= 12 && h < 17) return 'Afternoon';
    if (h >= 17 && h < 21) return 'Evening';
    return 'Night';
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    IconData icon(String p) => switch (p) {
      'Morning' => Icons.wb_twilight_rounded,
      'Afternoon' => Icons.wb_sunny_outlined,
      'Evening' => Icons.nightlight_outlined,
      _ => Icons.bedtime_outlined,
    };
    Color tint(String p) => switch (p) {
      'Morning' => g.amber,
      'Afternoon' => g.actionInk,
      'Evening' => BrandPalette.pillarTint('mind', dark: g.isDark),
      _ => BrandPalette.pillarTint('assistant', dark: g.isDark),
    };
    final groups = [
      for (final p in parts)
        (p, logs.where((l) => partOf(l.timeSlot) == p).toList()),
    ].where((x) => x.$2.isNotEmpty).toList();
    return GlassCard(
      key: const ValueKey('medicine_today_board'),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s12,
        AppSpace.s8,
        AppSpace.s8,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (gi, (part, items)) in groups.indexed) ...[
            if (gi > 0)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
                child: Divider(height: 1, color: g.line),
              ),
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpace.s4,
                bottom: AppSpace.s4,
                right: AppSpace.s8,
              ),
              child: GroupHeader(
                key: ValueKey('dose_group_$part'),
                icon: icon(part),
                tint: tint(part),
                title: part,
                count: items.length,
              ),
            ),
            for (final log in items)
              if (byId[log.medicineId] case final m?)
                _DoseRow(
                  key: ValueKey('medicine_dose_${log.id}'),
                  log: log,
                  medicine: m,
                  busy: updating.contains(log.id),
                  careLine: careLine?.call(m),
                  onToggle: () => onToggle(log),
                  onMore: () => onMore(log, m),
                ),
          ],
        ],
      ),
    );
  }
}

class _DoseRow extends StatelessWidget {
  const _DoseRow({
    super.key,
    required this.log,
    required this.medicine,
    required this.busy,
    required this.onToggle,
    required this.onMore,
    this.careLine,
  });
  final MedicineLog log;
  final Medicine medicine;
  final bool busy;
  final String? careLine;
  final VoidCallback onToggle, onMore;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final tint = medicineTint(context);
    final state = doseState(log, DateTime.now());
    final time = MedicineService.formatTimeSlot(log.timeSlot);
    final (String status, Color statusColor) = switch (state) {
      DoseState.taken => (
        log.takenAt == null
            ? 'Taken'
            : 'Taken ${MaterialLocalizations.of(context).formatTimeOfDay(TimeOfDay.fromDateTime(log.takenAt!))}',
        g.successInk,
      ),
      DoseState.late => ('Late', g.warningInk),
      DoseState.due => ('Due now', g.actionInk),
      DoseState.later => ('', g.inkSecondary),
    };
    final ring = switch (state) {
      DoseState.taken => tint,
      DoseState.late => g.warningInk,
      DoseState.due => g.actionInk,
      DoseState.later => g.inkMuted.withValues(alpha: .6),
    };
    return Padding(
      padding: const EdgeInsets.only(left: 42),
      child: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    medicine.name,
                    style: AscentTextStyles.listRowTitle.copyWith(
                      color: state == DoseState.taken ? g.inkSecondary : g.ink,
                    ),
                  ),
                  if (careLine != null)
                    Text(
                      careLine!,
                      style: AscentTextStyles.caption.copyWith(
                        color: g.inkMuted,
                      ),
                    ),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: '$time · ${medicine.dosage}'),
                        if (status.isNotEmpty)
                          TextSpan(
                            text: ' · $status',
                            style: TextStyle(color: statusColor),
                          ),
                      ],
                    ),
                    style: AscentTextStyles.caption.copyWith(
                      color: g.inkSecondary,
                    ),
                  ),
                  if (medicine.instructions.isNotEmpty)
                    Text(
                      medicine.instructions,
                      style: AscentTextStyles.caption.copyWith(
                        color: g.inkMuted,
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (state == DoseState.late || state == DoseState.due)
            IconButton(
              key: ValueKey('medicine_dose_more_${log.id}'),
              tooltip: 'Snooze or skip',
              icon: Icon(Icons.more_horiz_rounded, color: g.inkMuted),
              onPressed: onMore,
            ),
          Semantics(
            button: true,
            checked: state == DoseState.taken,
            label: state == DoseState.taken
                ? '${medicine.name} taken, undo'
                : 'Mark ${medicine.name} taken',
            child: InkResponse(
              key: ValueKey('medicine_dose_check_${log.id}'),
              radius: 24,
              onTap: busy
                  ? null
                  : state == DoseState.later
                  ? () {
                      HapticFeedback.selectionClick();
                      AscentSnackBar.show(
                        context,
                        message: 'Scheduled for $time. You can take it then.',
                        icon: Icons.schedule_rounded,
                      );
                    }
                  : onToggle,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: state == DoseState.taken
                          ? tint
                          : Colors.transparent,
                      border: Border.all(color: ring, width: 1.6),
                    ),
                    child: state == DoseState.taken
                        ? const Icon(
                            Icons.check_rounded,
                            size: 18,
                            color: Colors.white,
                          )
                        : state == DoseState.later
                        ? Icon(
                            Icons.schedule_rounded,
                            size: 14,
                            color: g.inkMuted,
                          )
                        : null,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
