import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../today/add_activity_sheet.dart';
import 'activity_row_item.dart';
export '../model/now_focus.dart';
import '../model/now_focus.dart';


/// Home's "what should I do now?" card. One focus, one primary action.
class HomeNowCard extends ConsumerStatefulWidget {
  const HomeNowCard({super.key});

  @override
  ConsumerState<HomeNowCard> createState() => _HomeNowCardState();
}

class _HomeNowCardState extends ConsumerState<HomeNowCard> {
  bool _busy = false;

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    HapticFeedback.lightImpact();
    try {
      await action();
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: 'Something went wrong. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final activities = ref.watch(todayActivitiesProvider).value ?? const [];
    final reminders = ref.watch(homeVisibleRemindersProvider);
    final hasLiveSession = ref.watch(
      timeTrackingProvider.select(
        (s) => s.activeSession != null && (s.isRunning || s.isPaused),
      ),
    );
    final focus = resolveNowFocus(
      activities: activities,
      reminders: reminders,
      hasLiveSession: hasLiveSession,
      now: DateTime.now(),
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
      child: AnimatedSwitcher(
        duration: Duration(
          milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 280,
        ),
        switchInCurve: Curves.easeOutCubic,
        switchOutCurve: Curves.easeInCubic,
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: KeyedSubtree(
          key: ValueKey(
            '${focus.kind}-${focus.activity?.id}-${focus.reminder?.id}',
          ),
          child: switch (focus.kind) {
            NowFocusKind.session => const _SessionNow(),
            NowFocusKind.overdueReminder => _reminderNow(context, focus),
            NowFocusKind.activity => _activityNow(context, focus),
            NowFocusKind.allDone => _NowShell(
              eyebrow: 'Today',
              icon: Icons.verified_rounded,
              tone: _Tone.success,
              title: 'All done for today',
              meta: 'Nice work. Add something else or enjoy the time.',
              primary: AscentButton.tonal(
                label: 'Add something',
                icon: Icons.add_rounded,
                compact: true,
                onPressed: () => AddActivitySheet.show(context),
              ),
            ),
            NowFocusKind.empty => _NowShell(
              eyebrow: 'Now',
              icon: Icons.wb_twilight_rounded,
              tone: _Tone.action,
              title: 'Your day is wide open',
              meta: 'Add one thing and Ascent will keep it here for you.',
              primary: AscentButton.primary(
                label: 'Plan your day',
                icon: Icons.add_rounded,
                compact: true,
                onPressed: () => AddActivitySheet.show(context),
              ),
            ),
          },
        ),
      ),
    );
  }

  Widget _reminderNow(BuildContext context, NowFocus focus) {
    final r = focus.reminder!;
    return _NowShell(
      eyebrow: 'Overdue',
      icon: Icons.notifications_active_outlined,
      tone: _Tone.danger,
      title: r.title,
      meta: 'Was due ${_time(r.scheduledAt)}',
      next: focus.next,
      primary: AscentButton.primary(
        label: 'Review',
        compact: true,
        onPressed: () => context.push('/reminders'),
      ),
    );
  }

  Widget _activityNow(BuildContext context, NowFocus focus) {
    final a = focus.activity!;
    final lecture = a.sourceType == 'lecture';
    final medicine = a.sourceType == 'medicine';
    final timed =
        !lecture && (a.kind != ActivityKind.todo || (a.targetMinutes ?? 0) > 0);

    final eyebrow = a.isOverdue
        ? 'Overdue'
        : focus.isLater
        ? 'Up next'
        : 'Now';
    final metaParts = <String>[
      if (a.scheduledTime != null) _time(a.scheduledTime!),
      if (a.targetMinutes != null && a.targetMinutes! > 0)
        _duration(a.targetMinutes!),
      if (medicine) 'Medicine',
      if (lecture) 'Lecture',
    ];

    final Widget primary;
    // Lectures come from the retired Learning screens; their old sessions
    // can still appear, so they open their actions instead of a dead route.
    if (lecture || (focus.isLater && !timed)) {
      primary = AscentButton.tonal(
        label: 'Details',
        compact: true,
        onPressed: () => showActivityActions(context, ref, a),
      );
    } else if (timed) {
      primary = AscentButton.primary(
        label: a.status == TodayActivityStatus.paused ? 'Resume' : 'Start',
        icon: Icons.play_arrow_rounded,
        compact: true,
        loading: _busy,
        onPressed: () => _run(
          () => ref
              .read(timeTrackingProvider.notifier)
              .switchToTask(
                title: a.title,
                taskId: a.linkedTaskId,
                sourceType: a.sourceType,
                autoStart: true,
              ),
        ),
      );
    } else {
      primary = AscentButton.primary(
        label: medicine ? 'Taken' : 'Done',
        icon: Icons.check_rounded,
        compact: true,
        loading: _busy,
        onPressed: () => _run(() => completeActivityWithUndo(context, ref, a)),
      );
    }

    return _NowShell(
      eyebrow: eyebrow,
      icon: medicine
          ? Icons.medication_outlined
          : lecture
          ? Icons.school_outlined
          : timed
          ? Icons.timer_outlined
          : Icons.radio_button_unchecked_rounded,
      tone: a.isOverdue ? _Tone.danger : _Tone.action,
      title: a.title,
      meta: metaParts.isEmpty ? null : metaParts.join(' · '),
      next: focus.next,
      primary: primary,
      onMore: () => showActivityActions(context, ref, a),
    );
  }
}

/// Live running/paused session: ticks every second, scoped to this widget.
class _SessionNow extends ConsumerWidget {
  const _SessionNow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(timeTrackingProvider);
    final tracker = ref.read(timeTrackingProvider.notifier);
    final title = s.activeSession?.label ?? 'Focus session';
    return _NowShell(
      eyebrow: s.isPaused ? 'Paused' : 'In progress',
      icon: s.isPaused
          ? Icons.pause_circle_outline_rounded
          : Icons.timelapse_rounded,
      tone: _Tone.action,
      title: title,
      meta: s.formattedTime,
      metaTabular: true,
      primary: AscentButton.primary(
        label: s.isPaused ? 'Resume' : 'Pause',
        icon: s.isPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
        compact: true,
        onPressed: () {
          HapticFeedback.lightImpact();
          s.isPaused ? tracker.resumeSession() : tracker.pauseSession();
        },
      ),
    );
  }
}

enum _Tone { action, danger, success }

class _NowShell extends StatelessWidget {
  const _NowShell({
    required this.eyebrow,
    required this.icon,
    required this.tone,
    required this.title,
    required this.primary,
    this.meta,
    this.metaTabular = false,
    this.next,
    this.onMore,
  });

  final String eyebrow;
  final IconData icon;
  final _Tone tone;
  final String title;
  final String? meta;
  final bool metaTabular;
  final TodayActivityItem? next;
  final Widget primary;
  final VoidCallback? onMore;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final accent = switch (tone) {
      _Tone.action => c.primary,
      _Tone.danger => c.alert,
      _Tone.success => c.ok,
    };
    final metaStyle = AscentTextStyles.supportingText.copyWith(
      color: c.textSecondary,
    );
    return Semantics(
      container: true,
      label: '$eyebrow: $title',
      child: Container(
        key: const ValueKey('home_now_card'),
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 14),
        decoration: ShapeDecoration(
          color: c.surface,
          shape: ContinuousRectangleBorder(
            borderRadius: BorderRadius.circular(40),
            side: BorderSide(color: c.border.withValues(alpha: 0.7)),
          ),
          shadows: [
            BoxShadow(
              color: c.warmShadow,
              blurRadius: 12,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: ShapeDecoration(
                    color: accent.withValues(alpha: 0.12),
                    shape: ContinuousRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Icon(icon, color: accent, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eyebrow.toUpperCase(),
                        style: AscentTextStyles.caption.copyWith(
                          color: accent,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AscentTextStyles.cardTitle.copyWith(
                          color: c.textPrimary,
                        ),
                      ),
                      if (meta != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          meta!,
                          style: metaTabular
                              ? AscentTextStyles.tabular(metaStyle)
                              : metaStyle,
                        ),
                      ],
                    ],
                  ),
                ),
                if (onMore != null)
                  AscentButton.icon(
                    icon: Icons.more_horiz_rounded,
                    tooltip: 'More actions',
                    semanticLabel: 'More actions',
                    onPressed: onMore,
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                primary,
                if (next != null)
                  Text(
                    'Then: ${next!.title}'
                    '${next!.scheduledTime != null ? ' · ${_time(next!.scheduledTime!)}' : ''}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AscentTextStyles.caption.copyWith(color: c.textHint),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

String _time(DateTime t) => DateFormat('h:mm a').format(t);

String _duration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}
