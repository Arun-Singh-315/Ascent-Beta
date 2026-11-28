import '../../app/theme/surface_tokens.dart';
import '../../shared/widgets/ascent_button.dart';
import '../plans/widgets/plan_generator_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/router.dart';
import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/ai/ai_action_execution.dart';
import '../../core/ai/ai_service.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_snack_bar.dart';

/// Interactive Study Plan Preview & Activation Card
class RiyaStudyPlanCard extends ConsumerStatefulWidget {
  const RiyaStudyPlanCard({
    super.key,
    required this.planData,
    this.accentColor,
  });

  final Map<String, dynamic> planData;
  final Color? accentColor;

  @override
  ConsumerState<RiyaStudyPlanCard> createState() => _RiyaStudyPlanCardState();
}

class _RiyaStudyPlanCardState extends ConsumerState<RiyaStudyPlanCard> {
  bool _isSaving = false;
  bool _isSaved = false;
  bool _isExpanded = false;

  Future<void> _activatePlan() async {
    if (_isSaved || _isSaving) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final executor = AiActionExecution(db);
      final result = await executor.execute(
        AiProposedAction(
          type: AiActionType.studyPlanCreated,
          title: widget.planData['title']?.toString() ?? 'Study Plan',
          summary: widget.planData['title']?.toString() ?? '',
          payload: widget.planData,
        ),
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isSaved = true;
        });
        AscentSnackBar.show(context, message: result.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AscentSnackBar.error(
          context,
          message: 'Could not activate plan: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ?? context.accentPrimary;

    final title = widget.planData['title']?.toString() ?? 'Study Plan';
    final subject = widget.planData['subject']?.toString() ?? 'Curriculum';
    final durationDays = widget.planData['durationDays'] ?? 7;
    final dailyMinutes = widget.planData['dailyMinutes'] ?? 60;
    final items = (widget.planData['items'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    final previewItems = _isExpanded ? items : items.take(3).toList();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? g.surface.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: g.line.withValues(alpha: isDark ? 0.35 : 0.20),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.30),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(Icons.school_rounded, color: accent, size: 18),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: g.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$subject • $durationDays Days • $dailyMinutes mins/day',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: g.inkSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_isSaved)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: g.sage.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: g.sage.withValues(alpha: 0.30),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: g.sage),
                      const SizedBox(width: 4),
                      Text(
                        'Active',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: g.sage,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(
            height: 1,
            thickness: 0.7,
            color: g.line.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 10),

          // Items preview list
          for (final item in previewItems) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: accent,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title']?.toString() ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: g.ink,
                          ),
                        ),
                        if (item['notes'] != null &&
                            item['notes'].toString().isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            item['notes'].toString(),
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: g.inkSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '${item['minutes'] ?? dailyMinutes}m',
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: g.inkMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],

          if (items.length > 3) ...[
            const SizedBox(height: 4),
            GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                setState(() => _isExpanded = !_isExpanded);
              },
              child: Text(
                _isExpanded
                    ? 'Show less'
                    : 'View all ${items.length} milestones',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Action Buttons
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              if (!_isSaved)
                AscentButton.primary(
                  key: const ValueKey('riya_study_save'),
                  label: 'Save plan',
                  compact: true,
                  loading: _isSaving,
                  onPressed: _isSaving ? null : _activatePlan,
                )
              else
                AscentButton.tonal(
                  label: 'Open Plans',
                  compact: true,
                  onPressed: () => context.push(AscentRoutes.plans),
                ),
              AscentButton.secondary(
                key: const ValueKey('riya_study_customize'),
                label: 'Customize',
                icon: Icons.tune_rounded,
                onPressed: () => showPlanGeneratorSheet(
                  context,
                  PlanKind.study,
                  subject: widget.planData['subject']?.toString(),
                  days: (widget.planData['durationDays'] as num?)?.toInt(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Interactive Meal Plan Preview & Activation Card
class RiyaMealPlanCard extends ConsumerStatefulWidget {
  const RiyaMealPlanCard({super.key, required this.planData, this.accentColor});

  final Map<String, dynamic> planData;
  final Color? accentColor;

  @override
  ConsumerState<RiyaMealPlanCard> createState() => _RiyaMealPlanCardState();
}

class _RiyaMealPlanCardState extends ConsumerState<RiyaMealPlanCard> {
  bool _isSaving = false;
  bool _isSaved = false;

  Future<void> _activatePlan() async {
    if (_isSaved || _isSaving) return;
    HapticFeedback.mediumImpact();
    setState(() => _isSaving = true);

    try {
      final db = ref.read(databaseProvider);
      final executor = AiActionExecution(db);
      final result = await executor.execute(
        AiProposedAction(
          type: AiActionType.mealPlanCreated,
          title: widget.planData['title']?.toString() ?? 'Meal Plan',
          summary: widget.planData['title']?.toString() ?? '',
          payload: widget.planData,
        ),
      );

      if (mounted) {
        setState(() {
          _isSaving = false;
          _isSaved = true;
        });
        AscentSnackBar.show(context, message: result.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isSaving = false);
        AscentSnackBar.error(
          context,
          message: 'Could not activate meal plan: ${e.toString()}',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final accent = widget.accentColor ?? g.sage;

    final title = widget.planData['title']?.toString() ?? 'Meal Plan';
    final dietType = widget.planData['dietType']?.toString() ?? 'Balanced';
    final targetWater = widget.planData['targetWaterMl'] ?? 2500;
    final items = (widget.planData['items'] as List? ?? [])
        .cast<Map<String, dynamic>>();

    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isDark
            ? g.surface.withValues(alpha: 0.92)
            : Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: g.line.withValues(alpha: isDark ? 0.35 : 0.20),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.05),
            blurRadius: 12,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: accent.withValues(alpha: 0.30),
                    width: 1,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.restaurant_rounded,
                    color: accent,
                    size: 18,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: g.ink,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '$dietType • ${items.length} Meals • ${targetWater}mL Water',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                        color: g.inkSecondary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              if (_isSaved)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: g.sage.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: g.sage.withValues(alpha: 0.30),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle_rounded, size: 12, color: g.sage),
                      const SizedBox(width: 4),
                      Text(
                        'Active',
                        style: GoogleFonts.inter(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                          color: g.sage,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),

          const SizedBox(height: 12),
          Divider(
            height: 1,
            thickness: 0.7,
            color: g.line.withValues(alpha: 0.2),
          ),
          const SizedBox(height: 10),

          // 4 Meals breakdown
          for (final item in items) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    margin: const EdgeInsets.only(top: 3),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item['time']?.toString() ?? '08:00',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w600,
                        color: accent,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item['title']?.toString() ?? '',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: g.ink,
                          ),
                        ),
                        if (item['notes'] != null &&
                            item['notes'].toString().isNotEmpty) ...[
                          const SizedBox(height: 1),
                          Text(
                            item['notes'].toString(),
                            style: GoogleFonts.inter(
                              fontSize: 10.5,
                              color: g.inkSecondary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (item['calories'] != null) ...[
                    const SizedBox(width: 6),
                    Text(
                      '${item['calories']} kcal',
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w500,
                        color: g.inkMuted,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],

          const SizedBox(height: 12),

          // Action Buttons
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              if (!_isSaved)
                AscentButton.primary(
                  key: const ValueKey('riya_meal_save'),
                  label: 'Save meals',
                  compact: true,
                  loading: _isSaving,
                  onPressed: _isSaving ? null : _activatePlan,
                )
              else
                AscentButton.tonal(
                  label: 'Open Plans',
                  compact: true,
                  onPressed: () => context.push(AscentRoutes.plans),
                ),
              AscentButton.secondary(
                key: const ValueKey('riya_meal_customize'),
                label: 'Customize',
                icon: Icons.tune_rounded,
                onPressed: () => showPlanGeneratorSheet(
                  context,
                  PlanKind.meals,
                  goal: mealGoalFrom(widget.planData['dietType']?.toString()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
