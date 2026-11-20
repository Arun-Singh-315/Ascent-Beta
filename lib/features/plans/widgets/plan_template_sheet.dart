import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../../shared/widgets/ascent_sheet.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../../shared/widgets/ascent_switch.dart';
import '../plan_templates.dart';
import '../planning_providers.dart';

/// Opens [template] ready to start: everything has a default, so one tap on
/// "Start plan" is enough. Returns the new plan's id, or null.
Future<String?> showPlanTemplateSheet(
  BuildContext context,
  PlanTemplate template,
) => showAscentSheet<String>(
  context: context,
  builder: (_) => PlanTemplateSheet(template: template),
);

class PlanTemplateSheet extends ConsumerStatefulWidget {
  const PlanTemplateSheet({super.key, required this.template, this.clock});
  final PlanTemplate template;

  /// For tests.
  final DateTime Function()? clock;

  @override
  ConsumerState<PlanTemplateSheet> createState() => _PlanTemplateSheetState();
}

class _PlanTemplateSheetState extends ConsumerState<PlanTemplateSheet> {
  late final _name = TextEditingController(text: widget.template.title);
  late final List<PlanStep> _steps = [...widget.template.steps];
  late int _weeks = widget.template.weeks;
  bool _saving = false;

  DateTime get _now => (widget.clock ?? DateTime.now)();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickTime(int i) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _steps[i].time,
    );
    if (picked == null || !mounted) return;
    HapticFeedback.selectionClick();
    setState(() => _steps[i] = _steps[i].copyWith(time: picked));
  }

  void _toggleRepeat(int i) {
    HapticFeedback.selectionClick();
    final s = _steps[i];
    setState(
      () => _steps[i] = s.copyWith(
        repeat: s.repeat == PlanRepeat.daily
            ? PlanRepeat.weekdays
            : PlanRepeat.daily,
      ),
    );
  }

  Future<void> _start() async {
    final now = _now;
    final drafts = draftsFor(_steps, start: now, weeks: _weeks, now: now);
    if (drafts.isEmpty) {
      AscentSnackBar.error(context, message: 'Turn on at least one step.');
      return;
    }
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(planCollectionServiceProvider)
          .save(
            title: _name.text.trim().isEmpty
                ? widget.template.title
                : _name.text.trim(),
            description: '${widget.template.id} template',
            items: drafts,
            requestId:
                'template_${widget.template.id}_${now.microsecondsSinceEpoch}',
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
            : 'Could not start the plan. Try again.',
      );
    }
  }

  String _preview() {
    final on = _steps.where((s) => s.enabled).toList();
    if (on.isEmpty) return 'Turn on at least one step';
    final now = _now;
    final first = on
        .map((s) => firstSession(s, now, now))
        .reduce((a, b) => a.isBefore(b) ? a : b);
    final today = DateTime(now.year, now.month, now.day);
    final firstDay = DateTime(first.year, first.month, first.day);
    final when = firstDay == today
        ? 'today'
        : firstDay == today.add(const Duration(days: 1))
        ? 'tomorrow'
        : DateFormat('EEE d MMM').format(first);
    final perWeek = sessionsPerWeek(on);
    return '$perWeek sessions a week · first one $when '
        '${TimeOfDay.fromDateTime(first).format(context)} · '
        'shows up in Things';
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return SingleChildScrollView(
      key: const ValueKey('plan_template_sheet'),
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
                  widget.template.title,
                  textAlign: TextAlign.center,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.dialogTitle.copyWith(color: g.ink),
                ),
              ),
              const SizedBox(width: 72),
            ],
          ),
          const SizedBox(height: AppSpace.s8),
          AppTextField(
            key: const ValueKey('plan_template_name'),
            controller: _name,
            hintText: 'e.g. DSA prep',
            textCapitalization: TextCapitalization.sentences,
          ),
          const SizedBox(height: AppSpace.s16),
          Text(
            'For',
            style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
          ),
          const SizedBox(height: AppSpace.s8),
          AscentSegmentedControl<int>(
            key: const ValueKey('plan_template_weeks'),
            selected: _weeks,
            onChanged: (w) => setState(() => _weeks = w),
            segments: const [
              AscentSegment(value: 2, label: '2 weeks'),
              AscentSegment(value: 4, label: '4 weeks'),
              AscentSegment(value: 8, label: '8 weeks'),
            ],
          ),
          const SizedBox(height: AppSpace.s16),
          Text(
            'Steps',
            style: AscentTextStyles.caption.copyWith(color: g.inkMuted),
          ),
          const SizedBox(height: AppSpace.s4),
          for (var i = 0; i < _steps.length; i++) _stepRow(g, i),
          const SizedBox(height: AppSpace.s12),
          Text(
            _preview(),
            key: const ValueKey('plan_template_preview'),
            style: AscentTextStyles.bodySmall.copyWith(color: g.inkSecondary),
          ),
          const SizedBox(height: AppSpace.s16),
          AscentButton.primary(
            key: const ValueKey('plan_template_start'),
            label: 'Start plan',
            expanded: true,
            loading: _saving,
            onPressed: _saving ? null : _start,
          ),
        ],
      ),
    );
  }

  Widget _stepRow(AscentGlass g, int i) {
    final s = _steps[i];
    final detail = [
      s.repeat.label,
      if (s.minutes != null) '${s.minutes} min',
    ].join(' · ');
    return Opacity(
      opacity: s.enabled ? 1 : .5,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    s.title,
                    style: AscentTextStyles.body.copyWith(color: g.ink),
                  ),
                  Semantics(
                    button: true,
                    label: 'Repeat: ${s.repeat.label}. Tap to change',
                    child: InkWell(
                      key: ValueKey('plan_step_repeat_$i'),
                      onTap: s.enabled ? () => _toggleRepeat(i) : null,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.s4,
                        ),
                        child: Text(
                          detail,
                          style: AscentTextStyles.caption.copyWith(
                            color: g.actionInk,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            AscentButton.ghost(
              key: ValueKey('plan_step_time_$i'),
              label: s.time.format(context),
              compact: true,
              onPressed: s.enabled ? () => _pickTime(i) : null,
            ),
            AscentSwitch(
              key: ValueKey('plan_step_on_$i'),
              value: s.enabled,
              onChanged: (v) {
                HapticFeedback.selectionClick();
                setState(() => _steps[i] = s.copyWith(enabled: v));
              },
            ),
          ],
        ),
      ),
    );
  }
}
