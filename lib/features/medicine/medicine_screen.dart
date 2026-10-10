import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
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
    final nameController = TextEditingController(text: existing?.name ?? '');
    final dosageController = TextEditingController(text: existing?.dosage ?? '1 Tablet');
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

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: context.glass.bg,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.of(context).viewInsets.bottom;
            final g = context.glass;

            final maxHeight = MediaQuery.of(context).size.height * 0.88;

            return ConstrainedBox(
              constraints: BoxConstraints(maxHeight: maxHeight),
              child: Padding(
                padding: EdgeInsets.only(
                  left: 20,
                  right: 20,
                  top: 20,
                  bottom: bottomInset + 16,
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
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Pinned Header Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          existing == null ? 'Add Medicine' : 'Edit Medicine',
                          style: AscentTextStyles.displaySmall.copyWith(
                            color: g.ink,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.close_rounded, color: g.inkMuted),
                          onPressed: () => Navigator.pop(sheetContext),
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
                      style: TextStyle(color: g.ink, fontSize: 14),
                      decoration: InputDecoration(
                        labelText: 'Medicine Name',
                        hintText: 'e.g. Paracetamol 500mg, Vitamin C',
                        labelStyle: TextStyle(color: g.inkSecondary, fontSize: 13),
                        hintStyle: TextStyle(color: g.inkMuted, fontSize: 13),
                        filled: true,
                        fillColor: g.claySoft,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: g.line),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: g.line),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: BorderSide(color: g.clay, width: 1.5),
                        ),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // Quick name suggestion chips
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: ['Paracetamol', 'Vitamin D3', 'Amoxicillin', 'Omega-3', 'Cetirizine']
                          .map((chip) => ActionChip(
                                label: Text(chip, style: TextStyle(fontSize: 11, color: g.inkSecondary)),
                                backgroundColor: g.fill,
                                side: BorderSide(color: g.line),
                                onPressed: () {
                                  nameController.text = chip;
                                  setSheetState(() {});
                                },
                              ))
                          .toList(),
                    ),
                    const SizedBox(height: 14),

                    // Dosage & Form Factor Row
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: dosageController,
                            style: TextStyle(color: g.ink, fontSize: 14),
                            decoration: InputDecoration(
                              labelText: 'Dosage',
                              hintText: '1 Tablet, 5ml',
                              labelStyle: TextStyle(color: g.inkSecondary, fontSize: 13),
                              hintStyle: TextStyle(color: g.inkMuted, fontSize: 13),
                              filled: true,
                              fillColor: g.claySoft,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: g.line),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: g.line),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          flex: 2,
                          child: DropdownButtonFormField<String>(
                            initialValue: type,
                            dropdownColor: g.bg,
                            style: TextStyle(color: g.ink, fontSize: 13),
                            decoration: InputDecoration(
                              labelText: 'Form',
                              labelStyle: TextStyle(color: g.inkSecondary, fontSize: 13),
                              filled: true,
                              fillColor: g.claySoft,
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(14),
                                borderSide: BorderSide(color: g.line),
                              ),
                              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                            ),
                            items: const [
                              DropdownMenuItem(value: 'tablet', child: Text('Tablet')),
                              DropdownMenuItem(value: 'capsule', child: Text('Capsule')),
                              DropdownMenuItem(value: 'syrup', child: Text('Syrup')),
                              DropdownMenuItem(value: 'drops', child: Text('Drops')),
                              DropdownMenuItem(value: 'injection', child: Text('Injection')),
                            ],
                            onChanged: (val) {
                              if (val != null) setSheetState(() => type = val);
                            },
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),

                    // Food Condition
                    Text(
                      'Instructions / Meal Timing',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: g.ink),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: ['After food', 'Before meal', 'With water', 'Empty stomach'].map((opt) {
                        final isSel = instructions == opt;
                        return ChoiceChip(
                          label: Text(opt, style: TextStyle(fontSize: 12, color: isSel ? Colors.white : g.inkSecondary)),
                          selected: isSel,
                          selectedColor: g.clay,
                          backgroundColor: g.fill,
                          side: BorderSide(color: isSel ? g.clay : g.line),
                          onSelected: (val) {
                            if (val) setSheetState(() => instructions = opt);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 16),

                    // Daily Schedule Timings
                    Text(
                      'Daily Doses & Timing Slots',
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: g.ink),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildTimeChip(
                          label: 'Morning',
                          time: '08:00',
                          isSelected: selectedTimes.contains('08:00'),
                          g: g,
                          onToggle: () {
                            setSheetState(() {
                              if (selectedTimes.contains('08:00')) {
                                if (selectedTimes.length > 1) selectedTimes.remove('08:00');
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
                          isSelected: selectedTimes.contains('13:00'),
                          g: g,
                          onToggle: () {
                            setSheetState(() {
                              if (selectedTimes.contains('13:00')) {
                                if (selectedTimes.length > 1) selectedTimes.remove('13:00');
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
                          isSelected: selectedTimes.contains('20:00'),
                          g: g,
                          onToggle: () {
                            setSheetState(() {
                              if (selectedTimes.contains('20:00')) {
                                if (selectedTimes.length > 1) selectedTimes.remove('20:00');
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
                      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: g.ink),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [3, 5, 7, 14, 30].map((d) {
                        final isSel = durationDays == d;
                        return ChoiceChip(
                          label: Text('$d Days', style: TextStyle(fontSize: 12, color: isSel ? Colors.white : g.inkSecondary)),
                          selected: isSel,
                          selectedColor: g.clay,
                          backgroundColor: g.fill,
                          side: BorderSide(color: isSel ? g.clay : g.line),
                          onSelected: (val) {
                            if (val) setSheetState(() => durationDays = d);
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 14),

                    // Info banner explaining the automated sync
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: g.claySoft,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: g.line),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.sync_rounded, color: g.clay, size: 20),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Sync Guarantee: Automatically creates daily To-dos and reminders for all $durationDays days.',
                              style: TextStyle(fontSize: 11, color: g.inkSecondary, height: 1.3),
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
                      padding: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        border: Border(top: BorderSide(color: g.line)),
                      ),
                      child: AscentButton.primary(
                        label: existing == null ? 'Save Prescription & Schedule' : 'Update Prescription',
                        expanded: true,
                        onPressed: () async {
                          if (nameController.text.trim().isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter medicine name')),
                            );
                            return;
                          }

                          HapticFeedback.mediumImpact();
                          Navigator.pop(sheetContext);

                          final sortedTimes = selectedTimes.toList()..sort();
                          await ref.read(medicineServiceProvider).addMedicine(
                                name: nameController.text.trim(),
                                dosage: dosageController.text.trim(),
                                scheduledTimes: sortedTimes,
                                durationDays: durationDays,
                                startDate: startDate,
                                instructions: instructions,
                                type: type,
                              );

                          if (mounted && context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Scheduled ${nameController.text} for $durationDays days with reminders & tasks!'),
                                backgroundColor: g.clay,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
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
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onToggle();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? g.clay : g.fill,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isSelected ? g.clay : g.line),
          ),
          child: Column(
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : g.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                MedicineService.formatTimeSlot(time),
                style: TextStyle(
                  fontSize: 10,
                  color: isSelected ? Colors.white70 : g.inkMuted,
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
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: g.line),
        ),
        title: Row(
          children: [
            Icon(Icons.delete_outline_rounded, color: g.coral, size: 24),
            const SizedBox(width: 8),
            Text('Delete ${medicine.name}', style: TextStyle(color: g.ink, fontSize: 16)),
          ],
        ),
        content: Text(
          'Cascading Deletion: This will remove this medicine and cleanly cancel all associated daily dose reminders and Today tasks across the entire course.\n\nAre you sure?',
          style: TextStyle(color: g.inkSecondary, fontSize: 13, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dlgContext),
            child: Text('Cancel', style: TextStyle(color: g.inkMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: g.coral,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            onPressed: () async {
              HapticFeedback.mediumImpact();
              Navigator.pop(dlgContext);
              await ref.read(medicineServiceProvider).deleteMedicine(medicine.id);
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Removed ${medicine.name} and cancelled future reminders.')),
                );
              }
            },
            child: const Text('Delete & Cancel Reminders', style: TextStyle(color: Colors.white, fontSize: 12)),
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        children: [
          // ── 1. TODAY'S DOSE COMPLIANCE CARD ────────────────────────────────
          todayLogsAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (todayLogs) {
              final total = todayLogs.length;
              final taken = todayLogs.where((l) => l.isTaken).length;
              final progress = total > 0 ? (taken / total).clamp(0.0, 1.0) : 0.0;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  GlassSurface(
                    radius: 20,
                    padding: const EdgeInsets.all(18),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: g.claySoft,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(Icons.medication_rounded, color: g.clay, size: 20),
                                ),
                                const SizedBox(width: 10),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Today\'s Doses',
                                      style: TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.bold,
                                        color: g.ink,
                                      ),
                                    ),
                                    Text(
                                      '$taken of $total doses taken',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: g.inkSecondary,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            Text(
                              '${(progress * 100).toInt()}%',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: g.clay,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
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
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
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
                              padding: const EdgeInsets.all(16),
                              child: Center(
                                child: Text(
                                  'No doses scheduled for today.',
                                  style: TextStyle(color: g.inkMuted, fontSize: 13),
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
                          final med = meds.where((m) => m.id == log.medicineId).firstOrNull;
                          final medName = med?.name ?? 'Medicine';
                          final medDosage = med?.dosage ?? '';
                          final instructions = med?.instructions ?? '';
                          final timeStr = MedicineService.formatTimeSlot(log.timeSlot);

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            child: GlassSurface(
                              radius: 16,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                              child: Row(
                                children: [
                                  // Time badge
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: log.isTaken ? g.sage.withValues(alpha: 0.15) : g.claySoft,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      timeStr,
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: log.isTaken ? g.sage : g.clay,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 14),

                                  // Details
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          medName,
                                          style: TextStyle(
                                            fontSize: 14,
                                            fontWeight: FontWeight.w600,
                                            color: g.ink,
                                            decoration: log.isTaken ? TextDecoration.lineThrough : null,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '$medDosage • $instructions',
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: g.inkSecondary,
                                          ),
                                        ),
                                        if (log.isTaken && log.takenAt != null) ...[
                                          const SizedBox(height: 2),
                                          Text(
                                            'Taken at ${DateFormat('h:mm a').format(log.takenAt!)}',
                                            style: TextStyle(fontSize: 10, color: g.sage, fontWeight: FontWeight.w500),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),

                                  // Check/Take action button
                                  InkWell(
                                    onTap: () async {
                                      HapticFeedback.lightImpact();
                                      await ref.read(medicineServiceProvider).toggleDose(log.id, !log.isTaken);
                                    },
                                    borderRadius: BorderRadius.circular(20),
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                      decoration: BoxDecoration(
                                        color: log.isTaken ? g.sage : g.clay,
                                        borderRadius: BorderRadius.circular(20),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            log.isTaken ? Icons.check_rounded : Icons.radio_button_unchecked_rounded,
                                            size: 14,
                                            color: Colors.white,
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            log.isTaken ? 'Taken' : 'Take',
                                            style: const TextStyle(
                                              fontSize: 11,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
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
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: g.inkMuted,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          medicinesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (err, _) => Center(child: Text('Error: $err', style: TextStyle(color: g.inkMuted))),
            data: (medicines) {
              if (medicines.isEmpty) {
                return GlassSurface(
                  radius: 20,
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Icon(Icons.medication_rounded, size: 48, color: g.inkMuted),
                      const SizedBox(height: 12),
                      Text(
                        'No Medicines Added Yet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: g.ink),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Add your prescriptions with dosage & duration.\nReminders & daily to-dos will sync automatically.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 12, color: g.inkSecondary, height: 1.4),
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
                  final start = DateTime(med.startDate.year, med.startDate.month, med.startDate.day);
                  final elapsedDays = today.difference(start).inDays + 1;
                  final clampedDay = elapsedDays.clamp(1, med.durationDays);
                  final remainingDays = (med.durationDays - clampedDay).clamp(0, med.durationDays);
                  final progress = (clampedDay / med.durationDays).clamp(0.0, 1.0);

                  List<String> timesList = [];
                  try {
                    final decoded = jsonDecode(med.scheduledTimes) as List<dynamic>;
                    timesList = decoded.map((e) => MedicineService.formatTimeSlot(e.toString())).toList();
                  } catch (_) {}

                  return Container(
                    margin: const EdgeInsets.only(bottom: 14),
                    child: GlassSurface(
                      radius: 20,
                      padding: const EdgeInsets.all(16),
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
                                    Row(
                                      children: [
                                        Text(
                                          med.name,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: g.ink,
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(
                                            color: g.claySoft,
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Text(
                                            med.type.toUpperCase(),
                                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold, color: g.clay),
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      '${med.dosage} • ${med.instructions}',
                                      style: TextStyle(fontSize: 12, color: g.inkSecondary),
                                    ),
                                  ],
                                ),
                              ),

                              IconButton(
                                tooltip: 'Delete Prescription',
                                icon: Icon(Icons.delete_outline_rounded, color: g.coral, size: 20),
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
                                .map((t) => Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: g.fill,
                                        borderRadius: BorderRadius.circular(6),
                                        border: Border.all(color: g.line),
                                      ),
                                      child: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(Icons.access_time_rounded, size: 11, color: g.inkMuted),
                                          const SizedBox(width: 4),
                                          Text(t, style: TextStyle(fontSize: 10, color: g.inkSecondary, fontWeight: FontWeight.w500)),
                                        ],
                                      ),
                                    ))
                                .toList(),
                          ),

                          const SizedBox(height: 14),

                          // Course Duration Progress
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Day $clampedDay of ${med.durationDays}',
                                style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: g.ink),
                              ),
                              Text(
                                remainingDays == 0 ? 'Course complete' : '$remainingDays days left',
                                style: TextStyle(fontSize: 11, color: g.inkMuted),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(3),
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
