import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../study_plan/lecture_focus_player_sheet.dart';
import '../../study_plan/study_plan_screen.dart';

/// Level 2 · Secondary: Learning Hub
/// Redesigned according to Ascent Home Redesign spec:
/// - 72dp-88dp glass surface card with 24dp radius.
/// - Clear entry points to switch courses, explore catalog, and view syllabus.
/// - Inline play/pause control on disc without leaving Home.
/// - Course name header with direct "Switch Course" catalog button.
class LearningHubCard extends ConsumerWidget {
  const LearningHubCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final state = ref.watch(learningHubProvider);
    final course = state.course;
    final active = state.activeLecture;
    final activeMod = state.activeModule;
    final hasStarted = state.hasStartedLearning;

    final roomyText = MediaQuery.textScalerOf(context).scale(14) > 18;
    final playerActions = <Widget>[
      IconButton(
        tooltip: 'View Syllabus',
        icon: Icon(
          Icons.format_list_bulleted_rounded,
          size: 20,
          color: g.inkMuted,
        ),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: () {
          HapticFeedback.lightImpact();
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (ctx) => StudyPlanScreen(courseId: course.id),
            ),
          );
        },
      ),
      IconButton(
        tooltip: 'Open Player Sheet',
        icon: Icon(Icons.open_in_full_rounded, size: 17, color: g.inkMuted),
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
        onPressed: () {
          HapticFeedback.lightImpact();
          LectureFocusPlayerSheet.show(context);
        },
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── TOP COURSE CONTEXT & SWITCH COURSE CTA ────────────────────
        SizedBox(
          width: double.infinity,
          child: Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 16,
            runSpacing: 4,
            children: [
              Text(
                'Learning',
                style: AscentTextStyles.homeTitle.copyWith(
                  color: g.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              AppTapArea(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/study-plan');
                },
                borderRadius: AppGeometry.roundedr6,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s4,
                    vertical: AppSpace.s2,
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        hasStarted ? 'Switch course' : 'Catalog',
                        style: AscentTextStyles.homeSecondary
                            .copyWith(color: g.clay)
                            .merge(AppTypeRoles.typeRole8),
                      ),
                      const SizedBox(width: 2),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 16,
                        color: g.clay,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 8),

        // ── HERO GLASS SURFACE CARD ──────────────────────────────────
        GlassSurface(
          radius: 24,
          fillColor: Theme.of(context).brightness == Brightness.light
              ? Colors.transparent
              : null,
          customBorder: Theme.of(context).brightness == Brightness.light
              ? Border.all(color: Colors.black, width: 1)
              : null,
          padding: const EdgeInsets.all(AppSpace.s16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // ── 1. PROMINENT HERO PLAY / PAUSE BUTTON ───────────
                  SizedBox(
                    width: 48,
                    height: 48,
                    child: Material(
                      color: AppPalette.transparent,
                      child: AppTapArea(
                        onTap: () {
                          HapticFeedback.mediumImpact();
                          if (hasStarted) {
                            ref
                                .read(learningHubProvider.notifier)
                                .togglePlayPause();
                          } else {
                            context.push('/study-plan');
                          }
                        },
                        borderRadius: AppGeometry.roundedr24,
                        child: AppTag(
                          nightDecoration: BoxDecoration(
                            color:
                                Theme.of(context).brightness ==
                                        Brightness.light &&
                                    !state.isPlaying
                                ? g.claySoft
                                : g.clay,
                            border:
                                Theme.of(context).brightness ==
                                        Brightness.light &&
                                    !state.isPlaying
                                ? Border.all(
                                    color: g.clay.withValues(alpha: .45),
                                    width: 1,
                                  )
                                : null,
                            shape: BoxShape.circle,
                            boxShadow:
                                Theme.of(context).brightness == Brightness.light
                                ? const []
                                : [
                                    BoxShadow(
                                      color: g.clay.withValues(
                                        alpha:
                                            Theme.of(context).brightness ==
                                                Brightness.light
                                            ? .14
                                            : .35,
                                      ),
                                      blurRadius: 10,
                                      offset: const Offset(0, 3),
                                    ),
                                  ],
                          ),
                          child: Center(
                            child: Icon(
                              hasStarted
                                  ? (state.isPlaying
                                        ? Icons.pause_rounded
                                        : Icons.play_arrow_rounded)
                                  : Icons.play_arrow_rounded,
                              size: 26,
                              color:
                                  Theme.of(context).brightness ==
                                          Brightness.light &&
                                      !state.isPlaying
                                  ? g.clay
                                  : AppPalette.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 14),

                  // ── 2. LECTURE TITLE & HERO RESUME BADGE ────────────
                  Expanded(
                    child: AppTapArea(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        if (hasStarted) {
                          LectureFocusPlayerSheet.show(context);
                        } else {
                          context.push('/study-plan');
                        }
                      },
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            hasStarted
                                ? 'Lecture ${active.id}: ${active.title}'
                                : 'Start learning',
                            style: AscentTextStyles.homeHeadline
                                .copyWith(
                                  color: (hasStarted && active.isCompleted)
                                      ? g.inkMuted
                                      : g.ink,
                                  decoration: (hasStarted && active.isCompleted)
                                      ? TextDecoration.lineThrough
                                      : null,
                                  decorationColor: g.inkMuted,
                                )
                                .merge(AppTypeRoles.typeRole67)
                                .copyWith(
                                  fontSize:
                                      Theme.of(context).brightness ==
                                          Brightness.light
                                      ? 15
                                      : null,
                                ),
                            maxLines: roomyText ? 2 : 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          if (hasStarted) ...[
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                AppTag(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpace.s7,
                                    vertical: AppSpace.s2,
                                  ),
                                  nightDecoration: BoxDecoration(
                                    color: g.claySoft,
                                    borderRadius: AppGeometry.roundedr6,
                                  ),
                                  child: Text(
                                    'Resume · ${(state.remainingSeconds / 60).ceil()} min left',
                                    style: AscentTextStyles.captionMedium
                                        .copyWith(color: g.clay)
                                        .merge(AppTypeRoles.typeRole31),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  activeMod.title,
                                  style: AscentTextStyles.homeSecondary
                                      .copyWith(color: g.inkSecondary)
                                      .merge(AppTypeRoles.typeRole23),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ] else ...[
                            Text(
                              'Spring Boot, System Design or DSA',
                              style: AscentTextStyles.homeSecondary
                                  .copyWith(color: g.inkSecondary)
                                  .merge(AppTypeRoles.typeRole27),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(width: 6),

                  // ── 3. ACTION CLUSTER: SYLLABUS & FULL PLAYER ───────
                  if (hasStarted && !roomyText)
                    ...playerActions
                  else if (!hasStarted) ...[
                    IconButton(
                      tooltip: 'Explore Catalog',
                      icon: Icon(
                        Icons.chevron_right_rounded,
                        size: 22,
                        color: g.inkMuted,
                      ),
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        context.push('/study-plan');
                      },
                    ),
                  ],
                ],
              ),

              if (hasStarted) ...[
                if (roomyText)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: playerActions,
                  ),
                const SizedBox(height: 14),

                // ── 4. THICK HERO PROGRESS BAR ────────────────────────
                SizedBox(
                  height: 7,
                  child: AppProgress(
                    filled: false,
                    width: double.infinity,
                    nightDecoration: BoxDecoration(
                      color: g.track,
                      borderRadius: AppGeometry.roundedr4,
                    ),
                    alignment: Alignment.centerLeft,
                    child: FractionallySizedBox(
                      widthFactor: state.progressFraction.clamp(0.0, 1.0),
                      child: AppProgress(
                        filled: true,
                        nightDecoration: BoxDecoration(
                          color: g.clay,
                          borderRadius: AppGeometry.roundedr4,
                          boxShadow: [
                            BoxShadow(
                              color: g.clay.withValues(alpha: 0.4),
                              blurRadius: 4,
                              offset: const Offset(0, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 6),

                // ── 5. TIME STATS LABELS ──────────────────────────────
                SizedBox(
                  width: double.infinity,
                  child: Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(
                        '${state.formattedElapsed} elapsed',
                        style: AscentTextStyles.captionMedium
                            .copyWith(color: g.inkMuted)
                            .merge(AppTypeRoles.typeRole54),
                      ),
                      Text(
                        '${active.formattedDuration} total',
                        style: AscentTextStyles.captionMedium
                            .copyWith(color: g.inkMuted)
                            .merge(AppTypeRoles.typeRole54),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
