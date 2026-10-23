import '../../shared/widgets/music_companion_card.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/color_tokens.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import 'module_lecture_editor_sheets.dart';

class LectureFocusPlayerSheet extends ConsumerStatefulWidget {
  const LectureFocusPlayerSheet({super.key});

  static bool isSheetOpen = false;

  static Future<void> show(BuildContext context) async {
    if (isSheetOpen) return;
    isSheetOpen = true;
    try {
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: AppPalette.transparent,
        builder: (ctx) => const LectureFocusPlayerSheet(),
      );
    } finally {
      isSheetOpen = false;
    }
  }

  @override
  ConsumerState<LectureFocusPlayerSheet> createState() =>
      _LectureFocusPlayerSheetState();
}

class _LectureFocusPlayerSheetState
    extends ConsumerState<LectureFocusPlayerSheet> {
  bool _switcherExpanded = false;
  String _lectureQuery = '';

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(learningHubProvider);
    final notifier = ref.read(learningHubProvider.notifier);
    final active = state.activeLecture;
    final activeMod = state.activeModule;
    final lectures = state.course.modules
        .expand((module) => module.lectures)
        .where(
          (lecture) =>
              _lectureQuery.isEmpty ||
              '${lecture.title} ${lecture.moduleTitle}'.toLowerCase().contains(
                _lectureQuery,
              ),
        )
        .toList();

    return AppCard(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.92,
      ),
      nightDecoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: const BorderRadius.vertical(top: AppGeometry.radiusr28),
        boxShadow: const [
          BoxShadow(
            color: AppPalette.black26,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: true,
        bottom: true,
        child: Column(
          children: [
            // Drag handle
            Padding(
              padding: const EdgeInsets.only(
                top: AppSpace.s8,
                bottom: AppSpace.s4,
              ),
              child: Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: context.divider,
                  borderRadius: AppGeometry.roundedr2,
                ),
              ),
            ),
            // 1. Top Header Handle + Title
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s16,
                AppSpace.s4,
                AppSpace.s16,
                AppSpace.s4,
              ),
              child: AppResponsiveRow(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: 28,
                    ),
                    onPressed: () => Navigator.pop(context),
                    color: context.textPrimary,
                  ),
                  Text(
                    'Lecture Focus Player',
                    style: AppTypography.plusJakartaSans16W70012(
                      color: context.textPrimary,
                    ),
                  ),
                  AppTag(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s10,
                      vertical: AppSpace.s4,
                    ),
                    nightDecoration: BoxDecoration(
                      color: state.isPlaying
                          ? context.accentSecondary.withValues(alpha: 0.15)
                          : AppPalette.orange.withValues(alpha: 0.15),
                      borderRadius: AppGeometry.roundedr20,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: state.isPlaying
                                ? context.accentSecondary
                                : AppPalette.orange,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          state.isPlaying ? 'LIVE FOCUS' : 'PAUSED',
                          style: AppTypography.jetBrainsMono105W70034(
                            color: state.isPlaying
                                ? context.accentSecondary
                                : AppPalette.orange,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            AppDivider(height: 1, color: context.divider),

            // Main scrollable player content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s20,
                  vertical: AppSpace.s12,
                ),
                children: [
                  // Breadcrumbs
                  Text(
                    '${state.course.title.toUpperCase()} / ${activeMod.title}',
                    style: AppTypography.jetBrainsMono11W60052(
                      color: context.accentPrimary,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 8),

                  // Lecture Title
                  Text(
                    'Lecture ${active.id}: ${active.title}',
                    style: AppTypography.plusJakartaSans18W70053(
                      color: active.isCompleted
                          ? context.textMuted
                          : context.textPrimary,
                      decoration: active.isCompleted
                          ? TextDecoration.lineThrough
                          : null,
                      decorationColor: context.textMuted,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 14),

                  // Progress slider
                  Column(
                    children: [
                      SliderTheme(
                        data: SliderTheme.of(context).copyWith(
                          activeTrackColor: context.accentSecondary,
                          inactiveTrackColor: context.divider,
                          thumbColor: context.accentSecondary,
                          thumbShape: const RoundSliderThumbShape(
                            enabledThumbRadius: 6,
                          ),
                          trackHeight: 3.5,
                        ),
                        child: Slider(
                          value: state.progressFraction,
                          onChanged: (val) => notifier.seekTo(val),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s16,
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              state.formattedElapsed,
                              style: AppTypography.jetBrainsMono11Regular36(
                                color: context.textMuted,
                              ),
                            ),
                            Text(
                              active.formattedDuration,
                              style: AppTypography.jetBrainsMono11Regular36(
                                color: context.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Circular countdown ring
                  Center(
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox(
                          width: 170,
                          height: 170,
                          child: CircularProgressIndicator(
                            value: state.progressFraction,
                            semanticsLabel: 'Lecture progress',
                            strokeWidth: 9,
                            backgroundColor: context.divider,
                            color: context.accentSecondary,
                            strokeCap: StrokeCap.round,
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            SizedBox(
                              width: 150,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  state.formattedRemaining,
                                  semanticsLabel:
                                      '${state.formattedRemaining} remaining',
                                  style: AppTypography.jetBrainsMono32W80054(
                                    color: context.textPrimary,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'REMAINING',
                              style: AppTypography.jetBrainsMono11W70055(
                                color: context.textMuted,
                              ),
                            ),
                            const SizedBox(height: 4),
                            AppTag(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.s8,
                                vertical: AppSpace.s2,
                              ),
                              nightDecoration: BoxDecoration(
                                color: context.accentSecondary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: AppGeometry.roundedr10,
                              ),
                              child: Text(
                                '${state.progressPercent}% Completed',
                                style: AppTypeRoles.typeRole33.copyWith(
                                  color: context.accentSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Playback Controls (-10s, Play/Pause, +10s)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      IconButton(
                        iconSize: 34,
                        icon: const Icon(Icons.replay_10_rounded),
                        color: context.textPrimary,
                        onPressed: () => notifier.seekBy(-10),
                      ),
                      const SizedBox(width: 20),
                      AppTapArea(
                        onTap: () => notifier.togglePlayPause(),
                        borderRadius: AppGeometry.roundedr40,
                        child: AppTag(
                          width: 68,
                          height: 68,
                          nightDecoration: BoxDecoration(
                            color: context.accentPrimary.withValues(
                              alpha: 0.12,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: context.accentPrimary.withValues(
                                alpha: 0.45,
                              ),
                              width: AppBorderScale.w1point5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: AppPalette.black.withValues(alpha: 0.08),
                                blurRadius: 14,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Icon(
                            state.isPlaying
                                ? Icons.pause_rounded
                                : Icons.play_arrow_rounded,
                            size: 38,
                            color: context.accentPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 20),
                      IconButton(
                        iconSize: 34,
                        icon: const Icon(Icons.forward_10_rounded),
                        color: context.textPrimary,
                        onPressed: () => notifier.seekBy(10),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Mark Lecture Completed
                  Center(
                    child: OutlinedButton.icon(
                      style: context.surfaces.buttonStyle(
                        OutlinedButton.styleFrom(
                          side: BorderSide(
                            color: active.isCompleted
                                ? context.accentSecondary
                                : context.divider,
                            width: AppBorderScale.w1point5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: AppGeometry.roundedr20,
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s20,
                            vertical: AppSpace.s12,
                          ),
                        ),
                        filled: false,
                        icon: false,
                      ),
                      onPressed:
                          active.isCompleted ||
                              !active.canComplete ||
                              state.isSavingCompletion
                          ? null
                          : () async {
                              final completed = await notifier
                                  .markLectureCompleted(active.id);
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    completed
                                        ? 'Lecture completed. Progress saved.'
                                        : 'Could not complete this lecture. Your progress is unchanged.',
                                  ),
                                  duration: const Duration(seconds: 2),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                      icon: Icon(
                        active.isCompleted
                            ? Icons.check_circle_rounded
                            : Icons.check_rounded,
                        color: active.isCompleted
                            ? context.accentSecondary
                            : context.textPrimary,
                        size: 20,
                      ),
                      label: Text(
                        active.isCompleted
                            ? 'Lecture Completed'
                            : state.isSavingCompletion
                            ? 'Saving…'
                            : 'Mark Lecture Completed',
                        style: AppTypography.plusJakartaSans135W60056(
                          color: active.isCompleted
                              ? context.accentSecondary
                              : context.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    active.isCompleted
                        ? 'Completion saved'
                        : 'Study time: ${active.studyProgressPercent}% · ${active.completionThresholdPercent}% required',
                    textAlign: TextAlign.center,
                    style: AppTypography.plusJakartaSans12Regular57(
                      color: context.textMuted,
                    ),
                  ),
                  if (!active.isCompleted) ...[
                    if (active.durationSeconds <= 0)
                      TextButton.icon(
                        onPressed: () => showEditLectureSheet(
                          context,
                          ref,
                          state.course.id,
                          active,
                        ),
                        icon: const Icon(Icons.timer_outlined),
                        label: const Text('Set lecture duration'),
                      ),
                    const SizedBox(height: 4),
                    Text(
                      'Seeking changes your place, not your study credit. External video watching is not verified.',
                      textAlign: TextAlign.center,
                      style: AppTypography.plusJakartaSans11Regular58(
                        color: context.textMuted,
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),

                  // Study Soundtrack Companion Deck
                  const MusicCompanionCard(),

                  const SizedBox(height: 18),

                  // Swift Lecture Switcher Card
                  AppCard.materialSurface(
                    color: context.bgBase,
                    shape: RoundedRectangleBorder(
                      borderRadius: AppGeometry.roundedr18,
                      side: BorderSide(
                        color: context.divider.withValues(alpha: 0.8),
                      ),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Header
                        AppTapArea(
                          onTap: () {
                            setState(() {
                              _switcherExpanded = !_switcherExpanded;
                            });
                          },
                          borderRadius: const BorderRadius.vertical(
                            top: AppGeometry.radiusr18,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(AppSpace.s14),
                            child: AppResponsiveRow(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                AppResponsiveRow(
                                  children: [
                                    const Icon(
                                      Icons.playlist_play_rounded,
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Lecture queue',
                                      style:
                                          AppTypography.plusJakartaSans14W70021(
                                            color: context.textPrimary,
                                          ),
                                    ),
                                    const SizedBox(width: 8),
                                    AppTag(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: AppSpace.s7,
                                        vertical: AppSpace.s2,
                                      ),
                                      nightDecoration: BoxDecoration(
                                        color: context.bgSurface,
                                        borderRadius: AppGeometry.roundedr12,
                                      ),
                                      child: Text(
                                        '${state.course.totalLectures} Total',
                                        style:
                                            AppTypography.jetBrainsMono105W60041(
                                              color: context.textMuted,
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                                Icon(
                                  _switcherExpanded
                                      ? Icons.keyboard_arrow_up_rounded
                                      : Icons.keyboard_arrow_down_rounded,
                                  color: context.textMuted,
                                ),
                              ],
                            ),
                          ),
                        ),

                        if (_switcherExpanded) ...[
                          AppDivider(height: 1, color: context.divider),
                          Padding(
                            padding: const EdgeInsets.all(12),
                            child: TextField(
                              key: const ValueKey('lecture_queue_search'),
                              onChanged: (value) => setState(
                                () =>
                                    _lectureQuery = value.trim().toLowerCase(),
                              ),
                              decoration: const InputDecoration(
                                hintText: 'Find in lecture queue',
                                prefixIcon: Icon(Icons.search_rounded),
                              ),
                            ),
                          ),
                          if (lectures.isEmpty)
                            const Padding(
                              padding: EdgeInsets.all(16),
                              child: Text('No lectures match your search.'),
                            ),
                          SizedBox(
                            height: (MediaQuery.sizeOf(context).height * .35)
                                .clamp(180.0, 320.0),
                            child: ListView.builder(
                              key: const ValueKey('lecture_queue_list'),
                              primary: false,
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpace.s6,
                              ),
                              itemCount: lectures.length,
                              itemBuilder: (context, index) {
                                final lec = lectures[index];
                                final isCurrent =
                                    lec.id == state.activeLectureId;

                                return Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpace.s10,
                                    vertical: AppSpace.s3,
                                  ),
                                  child: Material(
                                    color: isCurrent
                                        ? context.accentSecondary.withValues(
                                            alpha: 0.12,
                                          )
                                        : AppPalette.transparent,
                                    shape: isCurrent
                                        ? RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                            side: BorderSide(
                                              color: context.accentSecondary
                                                  .withValues(alpha: 0.4),
                                            ),
                                          )
                                        : RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                    child: ListTile(
                                      dense: true,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                            horizontal: AppSpace.s10,
                                            vertical: AppSpace.s2,
                                          ),
                                      leading: AppTag(
                                        width: 26,
                                        height: 26,
                                        nightDecoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          color: isCurrent
                                              ? context.accentSecondary
                                              : (lec.isCompleted
                                                    ? context.accentPrimary
                                                          .withValues(
                                                            alpha: 0.2,
                                                          )
                                                    : context.divider
                                                          .withValues(
                                                            alpha: 0.6,
                                                          )),
                                        ),
                                        child: Center(
                                          child: lec.isCompleted
                                              ? Icon(
                                                  Icons.check,
                                                  size: 14,
                                                  color: context.accentPrimary,
                                                )
                                              : Text(
                                                  '${lec.id}',
                                                  style:
                                                      AppTypography.jetBrainsMono11W7002(
                                                        color: isCurrent
                                                            ? AppPalette.white
                                                            : context
                                                                  .textPrimary,
                                                      ),
                                                ),
                                        ),
                                      ),
                                      title: Text(
                                        lec.title,
                                        style: AppStateTypography.stateType16(
                                          state0: isCurrent,
                                          color: lec.isCompleted
                                              ? context.textMuted
                                              : context.textPrimary,
                                          decoration: lec.isCompleted
                                              ? TextDecoration.lineThrough
                                              : null,
                                          decorationColor: context.textMuted,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      trailing: Row(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Text(
                                            lec.formattedDuration,
                                            style:
                                                AppStateTypography.stateType17(
                                                  state0: isCurrent,
                                                  color: isCurrent
                                                      ? context.accentSecondary
                                                      : context.textMuted,
                                                ),
                                          ),
                                          const SizedBox(width: 4),
                                          Icon(
                                            Icons.chevron_right_rounded,
                                            size: 16,
                                            color: isCurrent
                                                ? context.accentSecondary
                                                : context.textMuted,
                                          ),
                                        ],
                                      ),
                                      onTap: () {
                                        notifier.selectLecture(
                                          lec.id,
                                          autoPlay: true,
                                        );
                                      },
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
