import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';

/// A shared, live timer readout for Home and Things. Only this readout ticks.
class ActivityTimerProgress extends ConsumerStatefulWidget {
  const ActivityTimerProgress({super.key, required this.activity});
  final TodayActivityItem activity;
  @override
  ConsumerState<ActivityTimerProgress> createState() =>
      _ActivityTimerProgressState();
}

class _ActivityTimerProgressState extends ConsumerState<ActivityTimerProgress> {
  TodayActivityItem? _snapshot;
  int? _sessionId;
  int _baseline = 0;

  static String _clock(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final tail =
        '${minutes.toString().padLeft(2, '0')}:${(seconds % 60).toString().padLeft(2, '0')}';
    return hours > 0 ? '$hours:$tail' : tail;
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final g = context.glass;
    var elapsed = a.elapsedSecondsToday;
    var target = (a.targetMinutes ?? 0) * 60;
    if (a.sourceType == 'lecture') {
      final playback = ref.watch(
        learningHubProvider.select((s) {
          final course = s.courses
              .where((c) => c.id == a.learningCourseId)
              .firstOrNull;
          final lecture = course?.modules
              .expand((m) => m.lectures)
              .where((l) => l.id == a.learningLectureId)
              .firstOrNull;
          final active =
              s.activeCourseId == a.learningCourseId &&
              s.activeLectureId == a.learningLectureId;
          return (
            elapsed: active
                ? s.currentElapsedSeconds
                : lecture?.elapsedSeconds ?? 0,
            target: lecture?.durationSeconds ?? 0,
          );
        }),
      );
      elapsed = playback.elapsed;
      target = playback.target;
    } else if (a.status == TodayActivityStatus.inProgress ||
        a.status == TodayActivityStatus.paused) {
      final live = ref.watch(
        timeTrackingProvider.select((s) {
          final session = s.activeSession;
          final matches =
              session != null &&
              (a.linkedSessionId != null
                  ? session.id == a.linkedSessionId
                  : a.linkedTaskId != null &&
                        session.linkedTaskId == a.linkedTaskId);
          return matches ? (id: session.id, seconds: s.elapsedSeconds) : null;
        }),
      );
      if (_snapshot != a || _sessionId != live?.id) {
        _snapshot = a;
        _sessionId = live?.id;
        _baseline = live?.seconds ?? 0;
      }
      // The activity snapshot already includes the active session plus earlier
      // sessions today. Add only the ticks since that snapshot was displayed.
      if (live != null) elapsed += (live.seconds - _baseline).clamp(0, 1 << 31);
    }
    elapsed = elapsed.clamp(0, 1 << 31);
    final hasGoal = target > 0;
    final reached = hasGoal && elapsed >= target;
    final state = switch (a.status) {
      TodayActivityStatus.inProgress => 'Running',
      TodayActivityStatus.paused => 'Paused',
      TodayActivityStatus.done => 'Completed',
      _ => 'Ready',
    };
    final detail = !hasGoal
        ? '$state · Count up'
        : reached
        ? '$state · Goal reached${elapsed > target ? ' · +${_clock(elapsed - target)}' : ''}'
        : '$state · ${((target - elapsed) / 60).ceil()} min left';
    final blue = g.isDark
        ? SharedControlColors.actionBlueDark
        : SharedControlColors.actionBlue;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          hasGoal ? '${_clock(elapsed)} / ${_clock(target)}' : _clock(elapsed),
          key: ValueKey('timer_readout_${a.id}'),
          style: TextStyle(
            color: g.ink,
            fontSize: 14,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        if (hasGoal) ...[
          const SizedBox(height: 7),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: TweenAnimationBuilder<double>(
              tween: Tween(
                begin: (elapsed / target).clamp(0, 1),
                end: (elapsed / target).clamp(0, 1),
              ),
              duration: Duration(
                milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 350,
              ),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) => LinearProgressIndicator(
                key: ValueKey('timer_progress_${a.id}'),
                value: value,
                minHeight: 4,
                color: blue,
                backgroundColor: g.ink.withValues(alpha: .08),
                semanticsLabel: '${a.title} timer progress',
              ),
            ),
          ),
        ],
        const SizedBox(height: 5),
        Text(
          detail,
          style: TextStyle(color: g.inkMuted, fontSize: 11.5, height: 1.3),
        ),
      ],
    );
  }
}
