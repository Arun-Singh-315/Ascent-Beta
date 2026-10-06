import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../../features/study_plan/lecture_focus_player_sheet.dart';
import 'ascent_button.dart';
import 'chat_bubble_card.dart';

Color parseHexColor(String? hex, {Color fallback = const Color(0xFF5FA070)}) {
  if (hex == null || hex.isEmpty) return fallback;
  try {
    final clean = hex.replaceAll('#', '');
    if (clean.length == 6) {
      return Color(int.parse('FF$clean', radix: 16));
    } else if (clean.length == 8) {
      return Color(int.parse(clean, radix: 16));
    }
  } catch (_) {}
  return fallback;
}

/// The persistent live session bar pinned in MainScaffold above the bottom navigation.
/// Shows live ticking elapsed time, category color, controls, and opens the details sheet.
class LiveSessionBar extends ConsumerWidget {
  const LiveSessionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trackingState = ref.watch(timeTrackingProvider);
    final learningState = ref.watch(learningHubProvider);
    final session = trackingState.activeSession;

    // Check if learning hub lecture is active
    if (session == null &&
        (learningState.isPlaying || learningState.isLiveFocusActive) &&
        !learningState.isFloatingDismissed) {
      final activeLec = learningState.activeLecture;
      final curCourse = learningState.course;
      final curModule = learningState.activeModule;

      return Dismissible(
        key: ValueKey('floating_lecture_${activeLec.id}'),
        direction: DismissDirection.horizontal,
        onDismissed: (_) {
          HapticFeedback.lightImpact();
          ref.read(learningHubProvider.notifier).dismissFloatingPlayer();
        },
        background: Container(
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.only(left: 20),
          color: Colors.transparent,
        ),
        secondaryBackground: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          color: Colors.transparent,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.bgSurface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: context.accentSecondary.withValues(alpha: 0.5),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.06),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: InkWell(
              onTap: () => LectureFocusPlayerSheet.show(context),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.accentSecondary.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.school_rounded, color: context.accentSecondary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${curCourse.title} • ${curModule.title}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10.5,
                            color: context.textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Row(
                          children: [
                            Container(
                              width: 7,
                              height: 7,
                              decoration: BoxDecoration(
                                color: learningState.isPlaying ? context.accentSecondary : Colors.orange,
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Lecture ${activeLec.id}: ${activeLec.title}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AscentTextStyles.labelMedium.copyWith(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(
                              learningState.formattedElapsed,
                              style: AscentTextStyles.monoCode.copyWith(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: learningState.isPlaying
                                    ? context.accentSecondary
                                    : context.textMuted,
                              ),
                            ),
                            Text(
                              ' / ${activeLec.formattedDuration}',
                              style: AscentTextStyles.monoCode.copyWith(
                                fontSize: 11,
                                color: context.textMuted,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              learningState.isPlaying ? '• Live Focus' : '• Paused',
                              style: AscentTextStyles.captionMedium.copyWith(
                                color: learningState.isPlaying
                                    ? context.accentSecondary
                                    : context.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      learningState.isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      color: context.textPrimary,
                      size: 24,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(learningHubProvider.notifier).togglePlayPause();
                    },
                  ),
                  IconButton(
                    icon: Icon(
                      Icons.stop_rounded,
                      color: context.stateDangerBright,
                      size: 24,
                    ),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      ref.read(learningHubProvider.notifier).pause();
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    if (session == null) {
      return const SizedBox.shrink();
    }

    final isStudy = session.activityType.toLowerCase() == 'study';
    final categoryColor = trackingState.activeCategory != null
        ? parseHexColor(trackingState.activeCategory!.colorHex)
        : (isStudy ? context.accentPrimaryBright : context.accentSecondaryBright);

    final iconData = isStudy
        ? Icons.school_rounded
        : Icons.sports_esports_rounded;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: ChatBubbleCard(
        tailPosition: BubbleTailPosition.bottomLeft,
        isPulsing: trackingState.isRunning,
        borderColor: categoryColor.withValues(alpha: 0.5),
        accentTint: categoryColor,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        onTap: () => _showActiveSessionSheet(context, ref, session, trackingState),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: categoryColor.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(iconData, color: categoryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: categoryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          session.label.isNotEmpty ? session.label : 'Active Session',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AscentTextStyles.labelMedium.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Row(
                    children: [
                      Text(
                        trackingState.formattedTime,
                        style: AscentTextStyles.monoCode.copyWith(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: trackingState.isRunning
                              ? context.accentPrimaryBright
                              : context.textMuted,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        trackingState.isRunning ? '• Live Focus' : '• Paused',
                        style: AscentTextStyles.captionMedium.copyWith(
                          color: trackingState.isRunning
                              ? context.accentPrimaryBright
                              : context.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            // Play / Pause button
            IconButton(
              icon: Icon(
                trackingState.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                color: context.textPrimary,
                size: 24,
              ),
              onPressed: () {
                if (trackingState.isRunning) {
                  ref.read(timeTrackingProvider.notifier).pauseSession();
                } else {
                  ref.read(timeTrackingProvider.notifier).resumeSession();
                }
              },
            ),
            // Stop button
            IconButton(
              icon: Icon(
                Icons.stop_rounded,
                color: context.stateDangerBright,
                size: 24,
              ),
              onPressed: () => _confirmCompleteSession(context, ref, session.label),
            ),
          ],
        ),
      ),
    );
  }

  static void _confirmCompleteSession(BuildContext context, WidgetRef ref, [String? label]) {
    final taskLabel = label ?? ref.read(timeTrackingProvider).activeSession?.label ?? 'session';
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.bgSurface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Complete Session?',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: context.textPrimary,
          ),
        ),
        content: Text(
          'Finish tracking \'$taskLabel\'?',
          style: TextStyle(fontSize: 14, color: context.textMuted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: context.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: context.accentSecondary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await ref.read(timeTrackingProvider.notifier).completeSession();
            },
            child: const Text('Complete', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }

  static void _showActiveSessionSheet(
    BuildContext context,
    WidgetRef ref,
    TimeSession session,
    TimeTrackingState trackingState,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: context.bgSurface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) {
        final categoryColor = trackingState.activeCategory != null
            ? parseHexColor(trackingState.activeCategory!.colorHex)
            : (session.activityType == 'study'
                ? context.accentPrimaryBright
                : context.accentSecondaryBright);

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Active Session',
                      style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: categoryColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: categoryColor.withValues(alpha: 0.3)),
                      ),
                      child: Text(
                        session.activityType.toUpperCase(),
                        style: AscentTextStyles.captionMedium.copyWith(
                          color: categoryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                ChatBubbleCard(
                  tailPosition: BubbleTailPosition.bottomLeft,
                  accentTint: categoryColor,
                  isPulsing: trackingState.isRunning,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.label,
                        style: AscentTextStyles.labelLarge.copyWith(color: context.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Elapsed Duration: ${trackingState.formattedTime}',
                        style: AscentTextStyles.monoCode.copyWith(
                          color: context.accentPrimaryBright,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      if (session.linkedTaskId != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          'Linked to Task #${session.linkedTaskId}',
                          style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: AscentButton.secondary(
                        label: trackingState.isRunning ? 'Pause' : 'Resume',
                        icon: trackingState.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                        onPressed: () {
                          Navigator.pop(ctx);
                          if (trackingState.isRunning) {
                            ref.read(timeTrackingProvider.notifier).pauseSession();
                          } else {
                            ref.read(timeTrackingProvider.notifier).resumeSession();
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AscentButton.primary(
                        label: 'Complete',
                        icon: Icons.check_circle_rounded,
                        onPressed: () async {
                          Navigator.pop(ctx);
                          await ref.read(timeTrackingProvider.notifier).completeSession();
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Session completed and saved.'),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AscentButton.destructive(
                  label: 'Abandon Session',
                  icon: Icons.delete_outline_rounded,
                  expanded: true,
                  onPressed: () async {
                    Navigator.pop(ctx);
                    await ref.read(timeTrackingProvider.notifier).abandonSession();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Session abandoned.'),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                ),
                const SizedBox(height: 8),
                AscentButton.outlined(
                  label: 'Cancel',
                  compact: true,
                  expanded: true,
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Helper to trigger the start session flow with §6 mid-session switch prompt.
Future<void> showStartSessionSheet(
  BuildContext context,
  WidgetRef ref, {
  String? defaultLabel,
  int? defaultTaskId,
  String defaultActivityType = 'study',
}) async {
  final current = ref.read(timeTrackingProvider);
  if (current.activeSession != null) {
    // §6 Mid-session switch prompt
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: context.bgSurface,
        title: Text(
          'Session Already Active',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
        content: Text(
          'Active session: "${current.activeSession!.label}" (${current.formattedTime}).\nHow would you like to proceed?',
          style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
        ),
        actions: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              AscentButton.secondary(
                label: 'Pause & Switch',
                expanded: true,
                onPressed: () => Navigator.pop(ctx, 'pause'),
              ),
              const SizedBox(height: 8),
              AscentButton.primary(
                label: 'Stop & Switch',
                expanded: true,
                onPressed: () => Navigator.pop(ctx, 'stop'),
              ),
              const SizedBox(height: 8),
              AscentButton.outlined(
                label: 'Cancel',
                compact: true,
                expanded: true,
                onPressed: () => Navigator.pop(ctx, 'cancel'),
              ),
            ],
          ),
        ],
      ),
    );

    if (action == null || action == 'cancel') {
      return;
    }

    if (action == 'pause') {
      await ref.read(timeTrackingProvider.notifier).pauseSession();
    } else if (action == 'stop') {
      await ref.read(timeTrackingProvider.notifier).completeSession();
    }
  }

  if (!context.mounted) return;

  // Open the new session starter modal
  _openStarterModal(
    context,
    ref,
    defaultLabel: defaultLabel,
    defaultTaskId: defaultTaskId,
    defaultActivityType: defaultActivityType,
  );
}

void _openStarterModal(
  BuildContext context,
  WidgetRef ref, {
  String? defaultLabel,
  int? defaultTaskId,
  String defaultActivityType = 'study',
}) {
  final labelController = TextEditingController(text: defaultLabel ?? '');
  String activityType = defaultActivityType;
  int? selectedCategoryId;
  int? linkedTaskId = defaultTaskId;

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.bgSurface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) {
      final bottomInset = MediaQuery.of(ctx).viewInsets.bottom;
      final categoriesAsync = ref.watch(activeSessionCategoriesProvider);

      return StatefulBuilder(
        builder: (ctx, setModalState) {
          final categories = categoriesAsync.value ?? [];
          if (selectedCategoryId == null && categories.isNotEmpty) {
            final match = categories.firstWhere(
              (c) => c.name.toLowerCase() == activityType.toLowerCase(),
              orElse: () => categories.first,
            );
            selectedCategoryId = match.id;
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(24, 24, 24, 24 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Start Focus Session',
                  style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
                ),
                const SizedBox(height: 16),
                // Activity Type selector
                Row(
                  children: [
                    Expanded(
                      child: ChoiceChip(
                        label: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.school_rounded, size: 16,
                                  color: activityType == 'study' ? Colors.white : context.textPrimary),
                              const SizedBox(width: 6),
                              const Text('Study'),
                            ],
                          ),
                        ),
                        selected: activityType == 'study',
                        selectedColor: context.accentPrimary,
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              activityType = 'study';
                              final studyCat = categories.where((c) => c.name.toLowerCase() == 'study');
                              if (studyCat.isNotEmpty) {
                                selectedCategoryId = studyCat.first.id;
                              }
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ChoiceChip(
                        label: Center(
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.sports_esports_rounded, size: 16,
                                  color: activityType == 'entertainment' ? Colors.white : context.textPrimary),
                              const SizedBox(width: 6),
                              const Text('Entertainment'),
                            ],
                          ),
                        ),
                        selected: activityType == 'entertainment',
                        selectedColor: context.accentSecondary,
                        onSelected: (selected) {
                          if (selected) {
                            setModalState(() {
                              activityType = 'entertainment';
                              final entCat = categories.where((c) => c.name.toLowerCase() == 'entertainment');
                              if (entCat.isNotEmpty) {
                                selectedCategoryId = entCat.first.id;
                              }
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                // Label input
                TextField(
                  controller: labelController,
                  autofocus: true,
                  style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Session Label',
                    hintText: activityType == 'study'
                        ? 'e.g. System Design Practice, DSA Problem'
                        : 'e.g. Quick Gaming Break, Reading',
                    hintStyle: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                    filled: true,
                    fillColor: context.bgBase,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                // Category Pills
                if (categories.isNotEmpty) ...[
                  Text(
                    'Category',
                    style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: categories.map((cat) {
                      final isSelected = selectedCategoryId == cat.id;
                      final cColor = parseHexColor(cat.colorHex);
                      return ChoiceChip(
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(width: 8, height: 8, decoration: BoxDecoration(color: cColor, shape: BoxShape.circle)),
                            const SizedBox(width: 6),
                            Text(cat.name),
                          ],
                        ),
                        selected: isSelected,
                        selectedColor: cColor.withValues(alpha: 0.25),
                        onSelected: (val) {
                          if (val) {
                            setModalState(() => selectedCategoryId = cat.id);
                          }
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 20),
                ],
                Row(
                  children: [
                    Expanded(
                      child: AscentButton.outlined(
                        label: 'Cancel',
                        compact: true,
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: AscentButton.primary(
                        label: 'Start Session',
                        onPressed: () async {
                          final label = labelController.text.trim();
                          if (label.isEmpty) return;
                          final catId = selectedCategoryId ?? (categories.isNotEmpty ? categories.first.id : 1);
                          Navigator.pop(ctx);
                          await ref.read(timeTrackingProvider.notifier).startSession(
                            label: label,
                            categoryId: catId,
                            activityType: activityType,
                            linkedTaskId: linkedTaskId,
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      );
    },
  );
}
