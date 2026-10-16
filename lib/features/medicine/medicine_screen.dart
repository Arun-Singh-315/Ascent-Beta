import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
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
import '../../shared/widgets/glass_surface.dart';

class MedicineScreen extends ConsumerStatefulWidget {
  const MedicineScreen({super.key});

  @override
  ConsumerState<MedicineScreen> createState() => _MedicineScreenState();
}

class _MedicineScreenState extends ConsumerState<MedicineScreen> {
  void _openAddMedicineSheet([Medicine? existing]) {
    String instructions = existing?.instructions ?? 'After food';
    String type = existing?.type ?? 'tablet';
    int durationDays = existing?.durationDays ?? 7;
    DateTime startDate = existing?.startDate ?? DateTime.now();

    // Default time slots
    final selectedTimes = <String>{'08:00', '20:00'};
    if (existing != null) {
      try {
        final decoded = jsonDecode(existing.scheduledTimes) as List<dynamic>;
        selectedTimes.clear();
        selectedTimes.addAll(decoded.map((e) => e.toString()));
      } catch (_) {}
    }

    bool saving = false;
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      isScrollControlled: true,
      backgroundColor: context.glass.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: AppGeometry.radiusr24),
      ),
      builder: (sheetContext) {
        return _MedicineSheetControllers(
          name: existing?.name ?? '',
          dosage: existing?.dosage ?? '1 Tablet',
          builder: (nameController, dosageController) => StatefulBuilder(
            builder: (context, setSheetState) {
              final bottomInset = MediaQuery.of(context).viewInsets.bottom;
              final g = context.glass;

              final maxHeight = MediaQuery.of(context).size.height * 0.88;

              return PopScope(
                canPop: !saving,
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: maxHeight),
                  child: Padding(
                    padding: EdgeInsets.only(
                      left: AppSpace.s20,
                      right: AppSpace.s20,
                      top: AppSpace.s20,
                      bottom: bottomInset + AppSpace.s16,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Pinned Drag Handle
                        Center(
                          child: Container(
                            width: 40,
                            height: 4,
                            decoration: BoxDecoration(
                              color: g.line,
                              borderRadius: AppGeometry.roundedr2,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Pinned Header Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                existing == null
                                    ? 'Add Medicine'
                                    : 'Edit Medicine',
                                style: AscentTextStyles.displaySmall
                                    .copyWith(color: g.ink)
                                    .merge(AppTypeRoles.typeRole21),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                color: g.inkMuted,
                              ),
                              onPressed: saving
                                  ? null
                                  : () => Navigator.pop(sheetContext),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Scrollable Fields Body
                        Flexible(
                          child: SingleChildScrollView(
                            physics: const BouncingScrollPhysics(),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Medicine Name Input
                                TextField(
                                  controller: nameController,
                                  autofocus: existing == null,
                                  style: AppTypeRoles.typeRole59.copyWith(
                                    color: g.ink,
                                  ),
                                  decoration: InputDecoration(
                                    labelText: 'Medicine Name',
                                    hintText:
                                        'e.g. Paracetamol 500mg, Vitamin C',
                                    labelStyle: AppTypeRoles.typeRole58
                                        .copyWith(color: g.inkSecondary),
                                    hintStyle: AppTypeRoles.typeRole58.copyWith(
                                      color: g.inkMuted,
                                    ),
                                    filled: true,
                                    fillColor: g.claySoft,
                                    border: OutlineInputBorder(
                                      borderRadius: AppGeometry.roundedr14,
                                      borderSide: BorderSide(color: g.line),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: AppGeometry.roundedr14,
                                      borderSide: BorderSide(color: g.line),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: AppGeometry.roundedr14,
                                      borderSide: BorderSide(
                                        color: g.clay,
                                        width: AppBorderScale.w1point5,
                                      ),
                                    ),
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: AppSpace.s14,
                                      vertical: AppSpace.s12,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 8),

                                // Quick name suggestion chips
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 4,
                                  children:
                                      [
                                            'Paracetamol',
                                            'Vitamin D3',
                                            'Amoxicillin',
                                            'Omega-3',
                                            'Cetirizine',
                                          ]
                                          .map(
                                            (chip) => AppPill.action(
                                              label: Text(
                                                chip,
                                                style: AppTypeRoles.typeRole4
                                                    .copyWith(
                                                      color: g.inkSecondary,
                                                    ),
                                              ),
                                              backgroundColor: g.fill,
                                              side: BorderSide(color: g.line),
                                              onPressed: () {
                                                nameController.text = chip;
                                                setSheetState(() {});
                                              },
                                            ),
                                          )
                                          .toList(),
                                ),
                                const SizedBox(height: 14),

                                // Dosage & Form Factor Row
                                Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.stretch,
                                  children: [
                                    SizedBox(
                                      width: double.infinity,
                                      child: TextField(
                                        controller: dosageController,
                                        style: AppTypeRoles.typeRole59.copyWith(
                                          color: g.ink,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'Dosage',
                                          hintText: '1 Tablet, 5ml',
                                          labelStyle: AppTypeRoles.typeRole58
                                              .copyWith(color: g.inkSecondary),
                                          hintStyle: AppTypeRoles.typeRole58
                                              .copyWith(color: g.inkMuted),
                                          filled: true,
                                          fillColor: g.claySoft,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: g.line,
                                            ),
                                          ),
                                          enabledBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: g.line,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: AppSpace.s14,
                                                vertical: AppSpace.s12,
                                              ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    SizedBox(
                                      width: double.infinity,
                                      child: DropdownButtonFormField<String>(
                                        isExpanded: true,
                                        initialValue: type,
                                        dropdownColor: g.bg,
                                        style: AppTypeRoles.typeRole58.copyWith(
                                          color: g.ink,
                                        ),
                                        decoration: InputDecoration(
                                          labelText: 'Form',
                                          labelStyle: AppTypeRoles.typeRole58
                                              .copyWith(color: g.inkSecondary),
                                          filled: true,
                                          fillColor: g.claySoft,
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              14,
                                            ),
                                            borderSide: BorderSide(
                                              color: g.line,
                                            ),
                                          ),
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                horizontal: AppSpace.s12,
                                                vertical: AppSpace.s12,
                                              ),
                                        ),
                                        items: const [
                                          DropdownMenuItem(
                                            value: 'tablet',
                                            child: Text('Tablet'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'capsule',
                                            child: Text('Capsule'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'syrup',
                                            child: Text('Syrup'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'drops',
                                            child: Text('Drops'),
                                          ),
                                          DropdownMenuItem(
                                            value: 'injection',
                                            child: Text('Injection'),
                                          ),
                                        ],
                                        onChanged: (val) {
                                          if (val != null) {
                                            setSheetState(() => type = val);
                                          }
                                        },
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Food Condition
                                Text(
                                  'Instructions / Meal Timing',
                                  style: AppTypeRoles.typeRole17.copyWith(
                                    color: g.ink,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children:
                                      [
                                        'After food',
                                        'Before meal',
                                        'With water',
                                        'Empty stomach',
                                      ].map((opt) {
                                        final isSel = instructions == opt;
                                        return AppPill.choice(
                                          label: Text(
                                            opt,
                                            style: AppTypeRoles.typeRole27
                                                .copyWith(
                                                  color: isSel
                                                      ? AppPalette.white
                                                      : g.inkSecondary,
                                                ),
                                          ),
                                          selected: isSel,
                                          selectedColor: g.clay,
                                          backgroundColor: g.fill,
                                          side: BorderSide(
                                            color: isSel ? g.clay : g.line,
                                          ),
                                          onSelected: (val) {
                                            if (val) {
                                              setSheetState(
                                                () => instructions = opt,
                                              );
                                            }
                                          },
                                        );
                                      }).toList(),
                                ),
                                const SizedBox(height: 16),

                                // Daily Schedule Timings
                                Text(
                                  'Daily Doses & Timing Slots',
                                  style: AppTypeRoles.typeRole17.copyWith(
                                    color: g.ink,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  children: [
                                    _buildTimeChip(
                                      label: 'Morning',
                                      time: '08:00',
                                      isSelected: selectedTimes.contains(
                                        '08:00',
                                      ),
                                      g: g,
                                      onToggle: () {
                                        setSheetState(() {
                                          if (selectedTimes.contains('08:00')) {
                                            if (selectedTimes.length > 1) {
                                              selectedTimes.remove('08:00');
                                            }
                                          } else {
                                            selectedTimes.add('08:00');
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    _buildTimeChip(
                                      label: 'Afternoon',
                                      time: '13:00',
                                      isSelected: selectedTimes.contains(
                                        '13:00',
                                      ),
                                      g: g,
                                      onToggle: () {
                                        setSheetState(() {
                                          if (selectedTimes.contains('13:00')) {
                                            if (selectedTimes.length > 1) {
                                              selectedTimes.remove('13:00');
                                            }
                                          } else {
                                            selectedTimes.add('13:00');
                                          }
                                        });
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    _buildTimeChip(
                                      label: 'Night',
                                      time: '20:00',
                                      isSelected: selectedTimes.contains(
                                        '20:00',
                                      ),
                                      g: g,
                                      onToggle: () {
                                        setSheetState(() {
                                          if (selectedTimes.contains('20:00')) {
                                            if (selectedTimes.length > 1) {
                                              selectedTimes.remove('20:00');
                                            }
                                          } else {
                                            selectedTimes.add('20:00');
                                          }
                                        });
                                      },
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Duration (How many days)
                                Text(
                                  'Course Duration (Days)',
                                  style: AppTypeRoles.typeRole17.copyWith(
                                    color: g.ink,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 8,
                                  children: [3, 5, 7, 14, 30].map((d) {
                                    final isSel = durationDays == d;
                                    return AppPill.choice(
                                      label: Text(
                                        '$d Days',
                                        style: AppTypeRoles.typeRole27.copyWith(
                                          color: isSel
                                              ? AppPalette.white
                                              : g.inkSecondary,
                                        ),
                                      ),
                                      selected: isSel,
                                      selectedColor: g.clay,
                                      backgroundColor: g.fill,
                                      side: BorderSide(
                                        color: isSel ? g.clay : g.line,
                                      ),
                                      onSelected: (val) {
                                        if (val) {
                                          setSheetState(() => durationDays = d);
                                        }
                                      },
                                    );
                                  }).toList(),
                                ),
                                const SizedBox(height: 14),

                                // Info banner explaining the automated sync
                                AppCard(
                                  padding: const EdgeInsets.all(AppSpace.s12),
                                  nightDecoration: BoxDecoration(
                                    color: g.claySoft,
                                    borderRadius: AppGeometry.roundedr14,
                                    border: Border.all(color: g.line),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.sync_rounded,
                                        color: g.clay,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Text(
                                          'Sync Guarantee: Automatically creates daily To-dos and reminders for all $durationDays days.',
                                          style: AppTypeRoles.typeRole4
                                              .copyWith(
                                                color: g.inkSecondary,
                                                height: 1.3,
                                              ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ALWAYS IN FRAME: Pinned Save Action Button
                        Container(
                          padding: const EdgeInsets.only(top: AppSpace.s8),
                          decoration: BoxDecoration(
                            border: Border(top: BorderSide(color: g.line)),
                          ),
                          child: AscentButton.primary(
                            label: saving
                                ? 'Saving…'
                                : existing == null
                                ? 'Save Prescription & Schedule'
                                : 'Update Prescription',
                            expanded: true,
                            onPressed: saving
                                ? null
                                : () async {
                                    final service = ref.read(
                                      medicineServiceProvider,
                                    );
                                    final name = nameController.text.trim();
                                    final dosage = dosageController.text.trim();
                                    final sortedTimes = selectedTimes.toList()
                                      ..sort();
                                    setSheetState(() => saving = true);
                                    HapticFeedback.mediumImpact();
                                    try {
                                      if (existing == null) {
                                        await service.addMedicine(
                                          name: name,
                                          dosage: dosage,
                                          scheduledTimes: sortedTimes,
                                          durationDays: durationDays,
                                          startDate: startDate,
                                          instructions: instructions,
                                          type: type,
                                        );
                                      } else {
                                        await service.updateMedicine(
                                          existing.id,
                                          name: name,
                                          dosage: dosage,
                                          scheduledTimes: sortedTimes,
                                          durationDays: durationDays,
                                          startDate: startDate,
                                          instructions: instructions,
                                          type: type,
                                        );
                                      }
                                      if (!mounted || !sheetContext.mounted) {
                                        return;
                                      }
                                      setSheetState(() => saving = false);
                                      Navigator.pop(sheetContext);
                                      ScaffoldMessenger.of(
                                        this.context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            'Saved $name. Reminder delivery depends on device permissions.',
                                          ),
                                        ),
                                      );
                                    } catch (error) {
                                      if (sheetContext.mounted) {
                                        setSheetState(() => saving = false);
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text(
                                              'Could not save schedule: $error',
                                            ),
                                          ),
                                        );
                                      }
                                    }
                                  },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildTimeChip({
    required String label,
    required String time,
    required bool isSelected,
    required dynamic g,
    required VoidCallback onToggle,
  }) {
    return Expanded(
      child: AppTapArea(
        onTap: () {
          HapticFeedback.selectionClick();
          onToggle();
        },
        borderRadius: AppGeometry.roundedr12,
        child: AppCard(
          selected: isSelected,
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s10),
          nightDecoration: BoxDecoration(
            color: isSelected ? g.clay : g.fill,
            borderRadius: AppGeometry.roundedr12,
            border: Border.all(color: isSelected ? g.clay : g.line),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: AppTypeRoles.typeRole34.copyWith(
                  color: context.surfaces.contentForeground(isSelected, isSelected ? AppPalette.white : g.ink),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                MedicineService.formatTimeSlot(time),
                style: AppTypeRoles.typeRole18.copyWith(
                  color: context.surfaces.contentForeground(isSelected, isSelected ? AppPalette.white70 : g.inkMuted),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDeleteMedicine(Medicine medicine) {
    final g = context.glass;
    showDialog(
      context: context,
      builder: (dlgContext) => AlertDialog(
        backgroundColor: g.bg,
        shape: RoundedRectangleBorder(
          borderRadius: AppGeometry.roundedr20,
          side: BorderSide(color: g.line),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: g.coral, size: 24),
            const SizedBox(width: 8),
            Text(
              'Delete ${medicine.name}',
              style: AppTypeRoles.typeRole10.copyWith(color: g.ink),
            ),
          ],
        ),
        content: Text(
          'Cascading Deletion: This will remove this medicine and cleanly cancel all associated daily dose reminders and Today tasks across the entire course.\n\nAre you sure?',
          style: AppTypeRoles.typeRole58.copyWith(
            color: g.inkSecondary,
            height: 1.4,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgContext),
            child: Text('Cancel', style: TextStyle(color: g.inkMuted)),
          ),
          ElevatedButton(
            style: context.surfaces.buttonStyle(
              ElevatedButton.styleFrom(
                backgroundColor: g.coral,
                shape: RoundedRectangleBorder(
                  borderRadius: AppGeometry.roundedr10,
                ),
              ),
              filled: true,
              icon: false,
            ),
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(dlgContext);
              await ref
                  .read(medicineServiceProvider)
                  .deleteMedicine(medicine.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Removed ${medicine.name}. Alert cancellation will retry if needed.',
                    ),
                  ),
                );
              }
            },
            child: Text(
              'Delete & Cancel Reminders',
              style: AppTypeRoles.typeRole27.copyWith(color: AppPalette.white),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final medicinesAsync = ref.watch(allMedicinesStreamProvider);
    final todayLogsAsync = ref.watch(todayMedicineLogsStreamProvider);

    return AscentScaffold(
      title: 'Medicine & Health',
      subtitle: 'Prescriptions & Dose Reminders',
      actions: [
        IconButton(
          tooltip: 'Add Medicine',
          icon: Icon(Icons.add_circle_outline_rounded, color: g.clay),
          onPressed: () {
            HapticFeedback.lightImpact();
            _openAddMedicineSheet();
          },
        ),
      ],
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s20,
          vertical: AppSpace.s16,
        ),
        children: [
          // ── 1. TODAY'S DOSE COMPLIANCE CARD ────────────────────────────────
          todayLogsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (todayLogs) {
              final total = todayLogs.length;
              final taken = todayLogs.where((l) => l.isTaken).length;
              final progress = total > 0
                  ? (taken / total).clamp(0.0, 1.0)
                  : 0.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassSurface(
                    radius: 20,
                    padding: const EdgeInsets.all(AppSpace.s18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            AppTag(
                              padding: const EdgeInsets.all(AppSpace.s8),
                              nightDecoration: BoxDecoration(
                                color: g.claySoft,
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.medication_rounded,
                                color: g.clay,
                                size: 20,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Today's Doses",
                                    style: AppTypeRoles.typeRole60.copyWith(
                                      color: g.ink,
                                    ),
                                  ),
                                  Text(
                                    '$taken of $total doses taken',
                                    style: AppTypeRoles.typeRole27.copyWith(
                                      color: g.inkSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: AppTypeRoles.typeRole21.copyWith(
                                color: g.clay,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: AppGeometry.roundedr4,
                          child: LinearProgressIndicator(
                            value: progress,
                            minHeight: 6,
                            backgroundColor: g.track,
                            valueColor: AlwaysStoppedAnimation<Color>(g.clay),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Today's Scheduled Dose Items
                  Text(
                    'TODAY\'S SCHEDULE',
                    style: AppTypeRoles.typeRole22.copyWith(
                      color: g.inkMuted,
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 10),

                  if (todayLogs.isEmpty)
                    medicinesAsync.when(
                      data: (meds) => meds.isEmpty
                          ? const SizedBox.shrink()
                          : GlassSurface(
                              radius: 16,
                              padding: const EdgeInsets.all(AppSpace.s16),
                              child: Center(
                                child: Text(
                                  'No doses scheduled for today.',
                                  style: AppTypeRoles.typeRole58.copyWith(
                                    color: g.inkMuted,
                                  ),
                                ),
                              ),
                            ),
                      loading: () => const SizedBox.shrink(),
                      error: (_, _) => const SizedBox.shrink(),
                    )
                  else
                    ...todayLogs.map((log) {
                      return medicinesAsync.when(
                        loading: () => const SizedBox.shrink(),
                        error: (_, _) => const SizedBox.shrink(),
                        data: (meds) {
                          final med = meds
                              .where((m) => m.id == log.medicineId)
                              .firstOrNull;
                          final medName = med?.name ?? 'Medicine';
                          final medDosage = med?.dosage ?? '';
                          final instructions = med?.instructions ?? '';
                          final timeStr = MedicineService.formatTimeSlot(
                            log.timeSlot,
                          );

                          return Container(
                            margin: const EdgeInsets.only(bottom: AppSpace.s10),
                            child: GlassSurface(
                              radius: 16,
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.s16,
                                vertical: AppSpace.s12,
                              ),
                              child: Row(
                                children: [
                                  // Time badge
                                  AppTag(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpace.s10,
                                      vertical: AppSpace.s6,
                                    ),
                                    nightDecoration: BoxDecoration(
                                      color: log.isTaken
                                          ? g.sage.withValues(alpha: 0.15)
                                          : g.claySoft,
                                      borderRadius: AppGeometry.roundedr8,
                                    ),
                                    child: Text(
                                      timeStr,
                                      style: AppTypeRoles.typeRole34.copyWith(
                                        color: log.isTaken ? g.sage : g.clay,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          medName,
                                          style: AppTypeRoles.typeRole61
                                              .copyWith(
                                                color: g.ink,
                                                decoration: log.isTaken
                                                    ? TextDecoration.lineThrough
                                                    : null,
                                              ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$medDosage • $instructions',
                                          style: AppTypeRoles.typeRole4
                                              .copyWith(color: g.inkSecondary),
                                        ),
                                        if (log.isTaken &&
                                            log.takenAt != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Taken at ${DateFormat('h:mm a').format(log.takenAt!)}',
                                            style: AppTypeRoles.typeRole44
                                                .copyWith(color: g.sage),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Check/Take action button
                                  AppTapArea(
                                    onTap: () async {
                                      HapticFeedback.lightImpact();
                                      await ref
                                          .read(medicineServiceProvider)
                                          .toggleDose(log.id, !log.isTaken);
                                    },
                                    borderRadius: AppGeometry.roundedr20,
                                    child: AppCard(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpace.s12,
                                        vertical: AppSpace.s8,
                                      ),
                                      nightDecoration: BoxDecoration(
                                        color: log.isTaken ? g.sage : g.clay,
                                        borderRadius: AppGeometry.roundedr20,
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            log.isTaken
                                                ? Icons.check_rounded
                                                : Icons
                                                      .radio_button_unchecked_rounded,
                                            size: 14,
                                            color: AppPalette.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            log.isTaken ? 'Taken' : 'Take',
                                            style: AppStateTypography
                                                .stateType21
                                                .copyWith(
                                                  color: AppPalette.white,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      );
                    }),
                  const SizedBox(height: 24),
                ],
              );
            },
          ),

          // ── 2. ACTIVE COURSES & PRESCRIPTIONS ──────────────────────────────
          Text(
            'ACTIVE PRESCRIPTIONS',
            style: AppTypeRoles.typeRole22.copyWith(
              color: g.inkMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          medicinesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(
              child: Text('Error: $err', style: TextStyle(color: g.inkMuted)),
            ),
            data: (medicines) {
              if (medicines.isEmpty) {
                return GlassSurface(
                  radius: 20,
                  padding: const EdgeInsets.all(AppSpace.s28),
                  child: Column(
                    children: [
                      Icon(
                        Icons.medication_rounded,
                        size: 48,
                        color: g.inkMuted,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'No Medicines Added Yet',
                        style: AppTypeRoles.typeRole30.copyWith(color: g.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add your prescriptions with dosage & duration.\nReminders & daily to-dos will sync automatically.',
                        textAlign: TextAlign.center,
                        style: AppTypeRoles.typeRole27.copyWith(
                          color: g.inkSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 16),
                      AscentButton.primary(
                        label: 'Add First Medicine',
                        icon: Icons.add_rounded,
                        onPressed: _openAddMedicineSheet,
                      ),
                    ],
                  ),
                );
              }

              return Column(
                children: medicines.map((med) {
                  final now = DateTime.now();
                  final today = DateTime(now.year, now.month, now.day);
                  final start = DateTime(
                    med.startDate.year,
                    med.startDate.month,
                    med.startDate.day,
                  );
                  final elapsedDays = today.difference(start).inDays + 1;
                  final clampedDay = elapsedDays.clamp(1, med.durationDays);
                  final remainingDays = (med.durationDays - clampedDay).clamp(
                    0,
                    med.durationDays,
                  );
                  final progress = (clampedDay / med.durationDays).clamp(
                    0.0,
                    1.0,
                  );

                  List<String> timesList = [];
                  try {
                    final decoded =
                        jsonDecode(med.scheduledTimes) as List<dynamic>;
                    timesList = decoded
                        .map(
                          (e) => MedicineService.formatTimeSlot(e.toString()),
                        )
                        .toList();
                  } catch (_) {}

                  return Container(
                    margin: const EdgeInsets.only(bottom: AppSpace.s14),
                    child: GlassSurface(
                      radius: 20,
                      padding: const EdgeInsets.all(AppSpace.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Wrap(
                                      spacing: 8,
                                      runSpacing: 6,
                                      children: [
                                        Text(
                                          med.name,
                                          style: AppTypeRoles.typeRole30
                                              .copyWith(color: g.ink),
                                        ),
                                        AppCard(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: AppSpace.s8,
                                            vertical: AppSpace.s3,
                                          ),
                                          nightDecoration: BoxDecoration(
                                            color: g.claySoft,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Text(
                                            med.type.toUpperCase(),
                                            style: AppTypeRoles.typeRole55
                                                .copyWith(color: g.clay),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${med.dosage} • ${med.instructions}',
                                      style: AppTypeRoles.typeRole27.copyWith(
                                        color: g.inkSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              IconButton(
                                tooltip: 'Edit Prescription',
                                icon: Icon(
                                  Icons.edit_outlined,
                                  color: g.inkMuted,
                                ),
                                onPressed: () {
                                  HapticFeedback.selectionClick();
                                  _openAddMedicineSheet(med);
                                },
                              ),
                              IconButton(
                                tooltip: 'Delete Prescription',
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  color: g.coral,
                                  size: 20,
                                ),
                                onPressed: () => _confirmDeleteMedicine(med),
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          // Times badges
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: timesList
                                .map(
                                  (t) => AppTag(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpace.s8,
                                      vertical: AppSpace.s4,
                                    ),
                                    nightDecoration: BoxDecoration(
                                      color: g.fill,
                                      borderRadius: AppGeometry.roundedr6,
                                      border: Border.all(color: g.line),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.access_time_rounded,
                                          size: 11,
                                          color: g.inkMuted,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          t,
                                          style: AppTypeRoles.typeRole44
                                              .copyWith(color: g.inkSecondary),
                                        ),
                                      ],
                                    ),
                                  ),
                                )
                                .toList(),
                          ),

                          const SizedBox(height: 14),

                          // Course Duration Progress
                          Wrap(
                            alignment: WrapAlignment.spaceBetween,
                            spacing: 12,
                            runSpacing: 6,
                            children: [
                              Text(
                                'Day $clampedDay of ${med.durationDays}',
                                style: AppTypeRoles.typeRole34.copyWith(
                                  color: g.ink,
                                ),
                              ),
                              Text(
                                remainingDays == 0
                                    ? 'Course complete'
                                    : '$remainingDays days left',
                                style: AppTypeRoles.typeRole4.copyWith(
                                  color: g.inkMuted,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: AppGeometry.roundedr3,
                            child: LinearProgressIndicator(
                              value: progress,
                              minHeight: 5,
                              backgroundColor: g.track,
                              valueColor: AlwaysStoppedAnimation<Color>(g.clay),
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              );
            },
          ),

          const SizedBox(height: 40),
        ],
      ),
    );
  }
}

class _MedicineSheetControllers extends StatefulWidget {
  const _MedicineSheetControllers({
    required this.name,
    required this.dosage,
    required this.builder,
  });
  final String name, dosage;
  final Widget Function(TextEditingController, TextEditingController) builder;
  @override
  State<_MedicineSheetControllers> createState() =>
      _MedicineSheetControllersState();
}

class _MedicineSheetControllersState extends State<_MedicineSheetControllers> {
  late final name = TextEditingController(text: widget.name);
  late final dosage = TextEditingController(text: widget.dosage);
  @override
  Widget build(BuildContext context) => widget.builder(name, dosage);
  @override
  void dispose() {
    name.dispose();
    dosage.dispose();
    super.dispose();
  }
}
