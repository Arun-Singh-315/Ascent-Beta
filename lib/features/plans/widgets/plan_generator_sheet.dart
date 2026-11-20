import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../../shared/widgets/ascent_sheet.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../../core/services/plan_generator.dart';
import '../planning_providers.dart';

enum PlanKind { study, meals }

/// "Let Ascent make one": pick a subject or a goal, see the plan, create it.
/// Returns the new plan's id, or null.
Future<String?> showPlanGeneratorSheet(
  BuildContext context,
  PlanKind kind, {
  String? subject,
  MealGoal? goal,
  int? days,
}) => showAscentSheet<String>(
  context: context,
  builder: (_) => PlanGeneratorSheet(
    kind: kind,
    initialSubject: subject,
    initialGoal: goal,
    initialDays: days,
  ),
);

/// Riya's wording for a diet ("High-Protein Vitality") as a meal goal.
MealGoal mealGoalFrom(String? text) {
  final t = (text ?? '').toLowerCase();
  if (t.contains('protein') || t.contains('muscle')) return MealGoal.protein;
  if (t.contains('veg')) return MealGoal.veg;
  if (t.contains('calorie') || t.contains('loss') || t.contains('light')) {
    return MealGoal.light;
  }
  return MealGoal.balanced;
}

class PlanGeneratorSheet extends ConsumerStatefulWidget {
  const PlanGeneratorSheet({
    super.key,
    required this.kind,
    this.clock,
    this.initialSubject,
    this.initialGoal,
    this.initialDays,
  });
  final PlanKind kind;
  final DateTime Function()? clock;
  final String? initialSubject;
  final MealGoal? initialGoal;
  final int? initialDays;

  @override
  ConsumerState<PlanGeneratorSheet> createState() => _PlanGeneratorSheetState();
}

class _PlanGeneratorSheetState extends ConsumerState<PlanGeneratorSheet> {
  late final _subject = TextEditingController(text: widget.initialSubject);
  int _days = 14;
  int _minutes = 60;
  TimeOfDay _time = const TimeOfDay(hour: 7, minute: 0);
  late MealGoal _goal = widget.initialGoal ?? MealGoal.balanced;
  bool _saving = false;

  DateTime get _now => (widget.clock ?? DateTime.now)();
  bool get _study => widget.kind == PlanKind.study;

  @override
  void initState() {
    super.initState();
    if (!_study) _days = 7;
    final d = widget.initialDays;
    if (d != null) {
      _days = _study
          ? (d <= 7 ? 7 : (d <= 14 ? 14 : 30))
          : (d <= 7 ? 7 : 14);
    }
    _subject.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _subject.dispose();
    super.dispose();
  }

  GeneratedPlan _plan() => _study
      ? generateStudyPlan(
          subject: _subject.text,
          days: _days,
          minutes: _minutes,
          time: _time,
          now: _now,
        )
      : generateMealPlan(goal: _goal, days: _days, now: _now);

  Future<void> _create() async {
    final plan = _plan();
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(planCollectionServiceProvider)
          .save(
            title: plan.title,
            description: _study ? 'study plan' : 'meal plan',
            items: [for (final i in plan.items) i.toDraft()],
            requestId:
                'generated_${widget.kind.name}_${_now.microsecondsSinceEpoch}',
          );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      Navigator.of(context).pop(id);
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      AscentSnackBar.error(
        context,
        message: e is ArgumentError
            ? '${e.message}'
            : 'Could not create the plan. Try again.',
      );
    }
  }

  Future<void> _pickTime() async {
    final t = await showTimePicker(context: context, initialTime: _time);
    if (t != null && mounted) setState(() => _time = t);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final plan = _plan();
    final preview = plan.items.take(_study ? 6 : 6).toList();
    final more = plan.items.length - preview.length;
    final day = DateFormat('EEE d');
    Widget label(String text) => Padding(
      padding: const EdgeInsets.only(top: AppSpace.s16, bottom: AppSpace.s8),
      child: Text(
        text,
        style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
      ),
    );

    return SingleChildScrollView(
      key: ValueKey('plan_generator_${widget.kind.name}'),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        0,
        AppSpace.s16,
        AppSpace.s16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              AscentButton.ghost(
                label: 'Cancel',
                compact: true,
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
              ),
              Expanded(
                child: Text(
                  _study ? 'Study plan' : 'Meal plan',
                  textAlign: TextAlign.center,
                  style: AscentTextStyles.dialogTitle.copyWith(color: g.ink),
                ),
              ),
              const SizedBox(width: 72),
            ],
          ),
          if (_study) ...[
            label('Subject'),
            AppTextField(
              key: const ValueKey('plan_generator_subject'),
              controller: _subject,
              autofocus: widget.initialSubject == null,
              hintText: 'e.g. DSA, Python, Physics',
              textCapitalization: TextCapitalization.words,
            ),
            label('How long'),
            AscentSegmentedControl<int>(
              selected: _days,
              onChanged: (d) => setState(() => _days = d),
              segments: const [
                AscentSegment(value: 7, label: '7 days'),
                AscentSegment(value: 14, label: '14 days'),
                AscentSegment(value: 30, label: '30 days'),
              ],
            ),
            label('Each day'),
            Row(
              children: [
                Expanded(
                  child: AscentSegmentedControl<int>(
                    selected: _minutes,
                    onChanged: (m) => setState(() => _minutes = m),
                    segments: const [
                      AscentSegment(value: 30, label: '30 min'),
                      AscentSegment(value: 60, label: '1 h'),
                      AscentSegment(value: 90, label: '1.5 h'),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s8),
                AscentButton.secondary(
                  key: const ValueKey('plan_generator_time'),
                  label: _time.format(context),
                  icon: Icons.schedule_rounded,
                  onPressed: _pickTime,
                ),
              ],
            ),
          ] else ...[
            label('Goal'),
            Wrap(
              spacing: AppSpace.s8,
              runSpacing: AppSpace.s8,
              children: [
                for (final goal in MealGoal.values)
                  AppChip(
                    key: ValueKey('plan_goal_${goal.name}'),
                    label: goal.label,
                    isSelected: _goal == goal,
                    onTap: () => setState(() => _goal = goal),
                  ),
              ],
            ),
            label('How long'),
            AscentSegmentedControl<int>(
              selected: _days,
              onChanged: (d) => setState(() => _days = d),
              segments: const [
                AscentSegment(value: 7, label: '1 week'),
                AscentSegment(value: 14, label: '2 weeks'),
              ],
            ),
          ],
          label('Ascent made this for you'),
          for (final item in preview)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: AppSpace.s4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 64,
                    child: Text(
                      day.format(item.at),
                      style: AscentTextStyles.caption.copyWith(
                        color: g.inkMuted,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.title,
                      style: AscentTextStyles.bodyMedium.copyWith(color: g.ink),
                    ),
                  ),
                ],
              ),
            ),
          if (more > 0)
            Padding(
              padding: const EdgeInsets.only(top: AppSpace.s4),
              child: Text(
                '+ $more more · each one shows up in Things on its day',
                key: const ValueKey('plan_generator_more'),
                style: AscentTextStyles.caption.copyWith(color: g.inkSecondary),
              ),
            ),
          const SizedBox(height: AppSpace.s16),
          AscentButton.primary(
            key: const ValueKey('plan_generator_create'),
            label: 'Create plan',
            expanded: true,
            loading: _saving,
            onPressed: _saving || plan.items.isEmpty ? null : _create,
          ),
        ],
      ),
    );
  }
}
