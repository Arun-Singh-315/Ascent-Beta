import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/widgets/app_surfaces.dart';
import '../../shared/widgets/ascent_dialog.dart';
import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/shared_control_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';

/// Opens the modernized, zero-scroll smart medicine editor dialog.
/// Centered on screen with a frosted background freeze blur so user can comfortably
/// see and action it without bottom-screen button cramping.
Future<void> showMedicineEditor(BuildContext context, {Medicine? medicine}) =>
    showAscentFrostedDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      builder: (_) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
            child: MedicineEditorSheet(medicine: medicine, isDialog: true),
          ),
        ),
      ),
    );

enum MedicineCategory {
  general,
  homeopathy,
  ayurveda,
  supplement,
}

class MedicineEditorSheet extends ConsumerStatefulWidget {
  const MedicineEditorSheet({super.key, this.medicine, this.isDialog = true});
  final Medicine? medicine;
  final bool isDialog;

  @override
  ConsumerState<MedicineEditorSheet> createState() => _MedicineEditorSheetState();
}

class _MedicineEditorSheetState extends ConsumerState<MedicineEditorSheet> {
  late final TextEditingController _nameController;
  late final TextEditingController _dosageController;
  late final TextEditingController _instructionsController;

  MedicineCategory _category = MedicineCategory.general;
  String _selectedTiming = 'Morning (9 AM)';
  String _selectedMeal = 'After food';
  bool _saving = false;
  String? _error;

  static const _presets = <MedicineCategory, _CategoryConfig>{
    MedicineCategory.general: _CategoryConfig(
      label: 'General',
      icon: Icons.medical_services_outlined,
      suggestions: ['Paracetamol', 'Cetirizine', 'Pantocid', 'Amoxicillin'],
      defaultDosages: ['1 tablet', '2 tablets', '5 ml syrup', '1 capsule'],
      timings: ['Morning (9 AM)', 'Twice (9 AM & 9 PM)', 'Night (10 PM)', 'SOS / As needed'],
      meals: ['After food', 'Before food', 'With water'],
      dbType: 'tablet',
    ),
    MedicineCategory.homeopathy: _CategoryConfig(
      label: 'Homeo',
      icon: Icons.grain_rounded,
      suggestions: ['Arnica 30C', 'Nux Vomica', 'Rhus Tox', 'Bryonia'],
      defaultDosages: ['4 sugar pills', '6 sugar pills', '10 drops in water'],
      timings: ['Twice (9 AM & 9 PM)', 'Morning (9 AM)', 'Thrice (3x daily)'],
      meals: ['15m before/after food', 'Empty stomach', 'No strong flavors'],
      dbType: 'tablet',
    ),
    MedicineCategory.ayurveda: _CategoryConfig(
      label: 'Ayurveda',
      icon: Icons.eco_outlined,
      suggestions: ['Ashwagandha', 'Triphala', 'Brahmi', 'Chyawanprash'],
      defaultDosages: ['1 tablet (Vati)', '1 tsp with warm water', '15 ml with water'],
      timings: ['Morning (9 AM)', 'Twice (9 AM & 9 PM)', 'Bedtime (10 PM)'],
      meals: ['With warm water', 'After meals', 'Bedtime with milk'],
      dbType: 'tablet',
    ),
    MedicineCategory.supplement: _CategoryConfig(
      label: 'Supplement',
      icon: Icons.wb_sunny_outlined,
      suggestions: ['Vitamin D3', 'Multivitamin', 'Omega-3', 'Zinc'],
      defaultDosages: ['1 capsule', '1 tablet', '1 gummy'],
      timings: ['Morning (9 AM)', 'With lunch', 'Night (10 PM)'],
      meals: ['With breakfast', 'With meals'],
      dbType: 'capsule',
    ),
  };

  @override
  void initState() {
    super.initState();
    final med = widget.medicine;
    if (med != null) {
      _nameController = TextEditingController(text: med.name);
      _dosageController = TextEditingController(text: med.dosage);
      _instructionsController = TextEditingController(text: med.instructions);
    } else {
      _nameController = TextEditingController();
      _dosageController = TextEditingController(text: _presets[_category]!.defaultDosages.first);
      _instructionsController = TextEditingController(text: _presets[_category]!.meals.first);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _dosageController.dispose();
    _instructionsController.dispose();
    super.dispose();
  }

  void _onCategoryChanged(MedicineCategory category) {
    if (_category == category) return;
    HapticFeedback.selectionClick();
    setState(() {
      _category = category;
      final config = _presets[category]!;
      _dosageController.text = config.defaultDosages.first;
      _selectedMeal = config.meals.first;
      _instructionsController.text = _selectedMeal;
      _selectedTiming = config.timings.first;
      _error = null;
    });
  }

  List<String> _resolveTimes() {
    switch (_selectedTiming) {
      case 'Twice (9 AM & 9 PM)':
        return ['09:00', '21:00'];
      case 'Night (10 PM)':
      case 'Bedtime (10 PM)':
        return ['22:00'];
      case 'With lunch':
        return ['13:00'];
      case 'Thrice (3x daily)':
        return ['09:00', '14:00', '21:00'];
      case 'SOS / As needed':
      case 'Morning (9 AM)':
      default:
        return ['09:00'];
    }
  }

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'Please enter or select a medicine name.');
      HapticFeedback.heavyImpact();
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final service = ref.read(medicineServiceProvider);
      final times = _resolveTimes();
      final dosage = _dosageController.text.trim().isEmpty
          ? _presets[_category]!.defaultDosages.first
          : _dosageController.text.trim();
      final instructions = _instructionsController.text.trim().isEmpty
          ? _selectedMeal
          : _instructionsController.text.trim();
      final type = _presets[_category]!.dbType;
      final duration = _category == MedicineCategory.supplement ? 30 : 7;

      if (widget.medicine == null) {
        await service.addMedicine(
          name: name,
          dosage: dosage,
          scheduledTimes: times,
          durationDays: duration,
          startDate: DateTime.now(),
          instructions: instructions,
          type: type,
        );
      } else {
        await service.updateMedicine(
          widget.medicine!.id,
          name: name,
          dosage: dosage,
          scheduledTimes: times,
          durationDays: duration,
          startDate: widget.medicine!.startDate,
          instructions: instructions,
          type: type,
        );
      }

      if (!mounted) return;
      HapticFeedback.mediumImpact();
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Added $name ($dosage) · $instructions',
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Unable to save schedule. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final config = _presets[_category]!;

    final shapeBorderRadius = widget.isDialog
        ? BorderRadius.circular(24)
        : const BorderRadius.vertical(top: AscentRadii.xxl);
    final border = widget.isDialog
        ? Border.all(color: g.line.withValues(alpha: 0.8), width: 1.0)
        : Border(top: BorderSide(color: g.line, width: 1.0));

    return PopScope(
      canPop: !_saving,
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: shapeBorderRadius,
            border: border,
            boxShadow: widget.isDialog
                ? [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.28),
                      blurRadius: 28,
                      offset: const Offset(0, 10),
                    ),
                  ]
                : null,
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: 18,
            bottom: widget.isDialog
                ? 20
                : MediaQuery.viewInsetsOf(context).bottom + 20,
          ),
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.medicine == null ? 'Add Medicine' : 'Edit Medicine',
                          style: AscentTextStyles.homeTitle.copyWith(
                            color: g.ink,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Personalized dosage & timing defaults',
                          style: TextStyle(
                            color: g.inkMuted,
                            fontSize: 12.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: g.inkMuted, size: 22),
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),
              const SizedBox(height: 14),

              // 1. Medicine Category Selector (4 Smart Types)
              Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  color: g.fill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: g.line, width: 0.8),
                ),
                child: Row(
                  children: MedicineCategory.values.map((cat) {
                    final c = _presets[cat]!;
                    final isSelected = _category == cat;
                    return Expanded(
                      child: InkWell(
                        onTap: _saving ? null : () => _onCategoryChanged(cat),
                        borderRadius: BorderRadius.circular(11),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 7),
                          decoration: BoxDecoration(
                            color: isSelected ? SharedControlColors.actionBlue : Colors.transparent,
                            borderRadius: BorderRadius.circular(11),
                          ),
                          alignment: Alignment.center,
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                c.icon,
                                size: 13,
                                color: isSelected ? Colors.white : g.inkMuted,
                              ),
                              const SizedBox(width: 4),
                              Flexible(
                                child: Text(
                                  c.label,
                                  style: TextStyle(
                                    color: isSelected ? Colors.white : g.ink,
                                    fontSize: 11.5,
                                    fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 12),

              // 2. Medicine Name Input (Single Glass Enclosure)
              Container(
                decoration: BoxDecoration(
                  color: g.fill,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: g.line, width: 0.8),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                child: TextField(
                  key: const ValueKey('medicine_name_field'),
                  controller: _nameController,
                  enabled: !_saving,
                  textCapitalization: TextCapitalization.words,
                  style: TextStyle(color: g.ink, fontSize: 14.5, fontWeight: FontWeight.w600),
                  decoration: InputDecoration(
                    hintText: 'Medicine or remedy name…',
                    hintStyle: TextStyle(color: g.inkMuted, fontSize: 13.5),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.search_rounded, size: 18, color: g.clay),
                    prefixIconConstraints: const BoxConstraints(minWidth: 28, maxHeight: 20),
                  ),
                ),
              ),
              const SizedBox(height: 8),

              // Smart Remedy Suggestions based on Category
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: config.suggestions.map((suggestion) {
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _nameController.text = suggestion;
                        _error = null;
                      });
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                      decoration: BoxDecoration(
                        color: _nameController.text == suggestion
                            ? g.clay.withValues(alpha: 0.15)
                            : g.fill,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _nameController.text == suggestion ? g.clay : g.line,
                          width: 0.7,
                        ),
                      ),
                      child: Text(
                        suggestion,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: _nameController.text == suggestion ? g.clay : g.inkSecondary,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // 3. Smart Dosage Preset Row
              Text(
                'Dosage',
                style: TextStyle(color: g.inkMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: config.defaultDosages.map((dosage) {
                  final isSelected = _dosageController.text == dosage;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _dosageController.text = dosage);
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: isSelected ? SharedControlColors.actionBlue.withValues(alpha: 0.12) : g.fill,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: isSelected ? SharedControlColors.actionBlue : g.line,
                          width: isSelected ? 1.2 : 0.8,
                        ),
                      ),
                      child: Text(
                        dosage,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? SharedControlColors.actionBlue : g.ink,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // 4. Frequency & Times
              Text(
                'When to take',
                style: TextStyle(color: g.inkMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: config.timings.map((timing) {
                  final isSelected = _selectedTiming == timing;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedTiming = timing);
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: isSelected ? SharedControlColors.actionBlue.withValues(alpha: 0.12) : g.fill,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: isSelected ? SharedControlColors.actionBlue : g.line,
                          width: isSelected ? 1.2 : 0.8,
                        ),
                      ),
                      child: Text(
                        timing,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? SharedControlColors.actionBlue : g.ink,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 12),

              // 5. Meal Relation & Instructions
              Text(
                'Instructions',
                style: TextStyle(color: g.inkMuted, fontSize: 11.5, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: 5,
                children: config.meals.map((meal) {
                  final isSelected = _selectedMeal == meal;
                  return InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _selectedMeal = meal;
                        _instructionsController.text = meal;
                      });
                    },
                    borderRadius: BorderRadius.circular(9),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4.5),
                      decoration: BoxDecoration(
                        color: isSelected ? SharedControlColors.actionBlue.withValues(alpha: 0.12) : g.fill,
                        borderRadius: BorderRadius.circular(9),
                        border: Border.all(
                          color: isSelected ? SharedControlColors.actionBlue : g.line,
                          width: isSelected ? 1.2 : 0.8,
                        ),
                      ),
                      child: Text(
                        meal,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                          color: isSelected ? SharedControlColors.actionBlue : g.ink,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),

              if (_error != null) ...[
                const SizedBox(height: 10),
                Text(
                  _error!,
                  style: TextStyle(
                    color: SharedControlColors.dueRed,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 16),

              // 6. Action Button (Add to Schedule)
              FilledButton(
                onPressed: _saving ? null : _save,
                style: FilledButton.styleFrom(
                  backgroundColor: SharedControlColors.actionBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  elevation: 0,
                ),
                child: _saving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.check_rounded, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            widget.medicine == null ? 'Add to Schedule' : 'Save Changes',
                            style: const TextStyle(
                              fontSize: 14.5,
                              fontWeight: FontWeight.w700,
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
  );
  }
}

class _CategoryConfig {
  const _CategoryConfig({
    required this.label,
    required this.icon,
    required this.suggestions,
    required this.defaultDosages,
    required this.timings,
    required this.meals,
    required this.dbType,
  });

  final String label;
  final IconData icon;
  final List<String> suggestions;
  final List<String> defaultDosages;
  final List<String> timings;
  final List<String> meals;
  final String dbType;
}
