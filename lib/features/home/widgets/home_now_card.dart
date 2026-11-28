import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/theme/ascent_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../shared/widgets/ascent_small_button.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../model/home_day_provider.dart';
import '../v7/home_region.dart';
import '../../today/add_activity_sheet.dart';
import 'activity_row_item.dart';
export '../model/now_focus.dart';

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

    final now = DateTime.now();
    return HomeRegion(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AnimatedSwitcher(
            duration: Duration(
              milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 280,
            ),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
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
                NowFocusKind.activity => _activityNow(context, focus, now),
                NowFocusKind.allDone => _NowShell(
                  eyebrow: 'All done',
                  tone: _Tone.success,
                  title: 'Everything for today is done',
                  meta: 'Add something else, or enjoy the time.',
                  primary: AscentSmallButton(
                    label: 'Add something',
                    onPressed: () => AddActivitySheet.show(context),
                  ),
                ),
                NowFocusKind.empty => _NowShell(
                  eyebrow: 'Now',
                  tone: _Tone.action,
                  title: 'Your day is wide open',
                  meta: 'Add one thing and it waits here for you.',
                  primary: AscentSmallButton.filled(
                    label: 'Plan your day',
                    onPressed: () => AddActivitySheet.show(context),
                  ),
                ),
              },
            ),
          ),
          const SizedBox(height: 10),
          const _DayRail(),
        ],
      ),
    );
  }

  Widget _reminderNow(BuildContext context, NowFocus focus) {
    final r = focus.reminder!;
    return _NowShell(
      eyebrow: 'Overdue · ${_time(r.scheduledAt)}',
      tone: _Tone.danger,
      title: r.title,
      meta: 'Reminder',
      next: focus.next,
      primary: AscentSmallButton.filled(
        label: 'Review',
        onPressed: () => context.push('/reminders'),
      ),
    );
  }

  Widget _activityNow(BuildContext context, NowFocus focus, DateTime now) {
    final a = focus.activity!;
    final lecture = a.sourceType == 'lecture';
    final medicine = a.sourceType == 'medicine';
    final timed =
        !lecture && (a.kind != ActivityKind.todo || (a.targetMinutes ?? 0) > 0);
    final at = a.scheduledTime;

    final head = a.isOverdue
        ? 'Overdue'
        : focus.isLater
        ? 'Up next'
        : 'Now';
    final metaParts = <String>[
      if (a.targetMinutes != null && a.targetMinutes! > 0)
        _duration(a.targetMinutes!),
      if (medicine) 'Medicine',
      if (lecture) 'Lecture',
      if (!medicine && !lecture && a.categoryTag.isNotEmpty)
        _titleCase(a.categoryTag),
    ];

    final Widget primary;
    // Lectures come from the retired Learning screens; their old sessions
    // can still appear, so they open their actions instead of a dead route.
    if (lecture || (focus.isLater && !timed)) {
      primary = AscentSmallButton(
        label: 'Details',
        onPressed: () => showActivityActions(context, ref, a),
      );
    } else if (timed) {
      primary = AscentSmallButton.filled(
        label: a.status == TodayActivityStatus.paused ? 'Resume' : 'Start',
        onPressed: _busy
            ? null
            : () => _run(
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
      primary = AscentSmallButton.filled(
        label: medicine ? 'Taken' : 'Done',
        onPressed: _busy
            ? null
            : () => _run(() => completeActivityWithUndo(context, ref, a)),
      );
    }

    return _NowShell(
      eyebrow: at == null ? head : '$head · ${_time(at)}',
      tone: a.isOverdue
          ? _Tone.danger
          : focus.isLater
          ? _Tone.soon
          : _Tone.action,
      title: a.title,
      meta: metaParts.isEmpty ? null : metaParts.join(' · '),
      countdown: at != null && at.isAfter(now) ? _countdown(at, now) : null,
      next: focus.next,
      primary: primary,
      secondary: AscentSmallButton(
        label: 'More',
        semanticLabel: 'More actions for ${a.title}',
        onPressed: () => showActivityActions(context, ref, a),
      ),
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
      eyebrow: s.isPaused ? 'Paused' : 'Focusing',
      tone: _Tone.action,
      title: title,
      meta: 'Notifications stay quiet until it ends',
      countdown: (s.formattedTime, s.isPaused ? 'paused' : 'so far'),
      primary: AscentSmallButton.filled(
        label: s.isPaused ? 'Resume' : 'Pause',
        onPressed: () {
          HapticFeedback.lightImpact();
          s.isPaused ? tracker.resumeSession() : tracker.pauseSession();
        },
      ),
      secondary: AscentSmallButton(
        label: 'Open',
        onPressed: () => context.push('/focus'),
      ),
    );
  }
}

enum _Tone { action, soon, danger, success }

/// The hero's content: eyebrow, title, meta, an optional big countdown on
/// the right, then small actions and a quiet "Then …" line.
class _NowShell extends StatelessWidget {
  const _NowShell({
    required this.eyebrow,
    required this.tone,
    required this.title,
    required this.primary,
    this.secondary,
    this.meta,
    this.countdown,
    this.next,
  });

  final String eyebrow;
  final _Tone tone;
  final String title;
  final String? meta;
  final (String, String)? countdown;
  final TodayActivityItem? next;
  final Widget primary;
  final Widget? secondary;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final accent = switch (tone) {
      _Tone.action => t.action,
      _Tone.soon => t.warning,
      _Tone.danger => t.danger,
      _Tone.success => t.success,
    };
    return Semantics(
      container: true,
      label: '$eyebrow: $title',
      child: Column(
        key: const ValueKey('home_now_card'),
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      eyebrow.toUpperCase(),
                      style: AscentTextStyles.eyebrow.copyWith(color: accent),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AscentTextStyles.nowTitle.copyWith(color: t.label),
                    ),
                    if (meta != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        meta!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AscentTextStyles.meta.copyWith(
                          color: t.labelTertiary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (countdown case (final value, final unit)) ...[
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      value,
                      key: const ValueKey('home_now_countdown'),
                      style: AscentTextStyles.bigNumber.copyWith(color: accent),
                    ),
                    Text(
                      unit.toUpperCase(),
                      style: AscentTextStyles.eyebrow.copyWith(
                        color: t.labelTertiary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              primary,
              if (secondary != null) ...[const SizedBox(width: 6), secondary!],
              const SizedBox(width: 8),
              Expanded(
                child: next == null
                    ? const SizedBox.shrink()
                    : Text(
                        'Then ${next!.title}'
                        '${next!.scheduledTime != null ? ', ${_time(next!.scheduledTime!)}' : ''}',
                        maxLines: 1,
                        textAlign: TextAlign.end,
                        overflow: TextOverflow.ellipsis,
                        style: AscentTextStyles.meta.copyWith(
                          color: t.labelTertiary,
                        ),
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Today from 6:00 to midnight: a line filled up to now, a dot for every
/// timed thing (green done, red overdue, amber the next one) and four hour
/// marks.
class _DayRail extends ConsumerWidget {
  const _DayRail();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final rail = ref.watch(homeRailProvider);
    final t = context.tokens;
    final nextIndex = rail.marks.indexWhere(
      (m) => !m.done && !m.overdue && m.at >= rail.now,
    );
    return Semantics(
      label: 'Day timeline',
      excludeSemantics: true,
      child: SizedBox(
        height: 26,
        child: CustomPaint(
          painter: _RailPainter(
            rail: rail,
            nextIndex: nextIndex,
            track: t.lineFaint,
            fill: t.actionFill,
            done: t.success,
            overdue: t.danger,
            soon: t.warning,
            open: t.line,
            hole: t.canvas,
            labelStyle: AscentTextStyles.meta.copyWith(
              color: t.labelTertiary,
              fontSize: 9.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _RailPainter extends CustomPainter {
  _RailPainter({
    required this.rail,
    required this.nextIndex,
    required this.track,
    required this.fill,
    required this.done,
    required this.overdue,
    required this.soon,
    required this.open,
    required this.hole,
    required this.labelStyle,
  });

  final DayRail rail;
  final int nextIndex;
  final Color track, fill, done, overdue, soon, open, hole;
  final TextStyle labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    const y = 7.5, r = 4.0;
    final w = size.width;
    final line = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(const Offset(0, y), Offset(w, y), line..color = track);
    if (rail.now > 0) {
      canvas.drawLine(
        const Offset(0, y),
        Offset(w * rail.now, y),
        line..color = fill,
      );
    }
    for (final (i, m) in rail.marks.indexed) {
      final c = Offset((w * m.at).clamp(r, w - r), y);
      final color = m.done
          ? done
          : m.overdue
          ? overdue
          : i == nextIndex
          ? soon
          : null;
      if (i == nextIndex) {
        canvas.drawCircle(
          c,
          r + 3,
          Paint()..color = soon.withValues(alpha: .22),
        );
      }
      if (color != null) {
        canvas.drawCircle(c, r, Paint()..color = color);
      } else {
        canvas.drawCircle(c, r, Paint()..color = hole);
        canvas.drawCircle(
          c,
          r - 1,
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2
            ..color = open,
        );
      }
    }
    for (final (h, at) in const [
      (6, 0.0),
      (12, 1 / 3),
      (18, 2 / 3),
      (24, 1.0),
    ]) {
      final tp = TextPainter(
        text: TextSpan(text: '$h', style: labelStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      final x = (w * at - tp.width / 2).clamp(0.0, w - tp.width);
      tp.paint(canvas, Offset(x, 14));
    }
  }

  @override
  bool shouldRepaint(_RailPainter old) =>
      old.rail != rail ||
      old.nextIndex != nextIndex ||
      old.fill != fill ||
      old.track != track;
}

String _time(DateTime t) => DateFormat('h:mm a').format(t);

String _duration(int minutes) {
  if (minutes < 60) return '$minutes min';
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h h' : '$h h $m min';
}

/// "42m" or "1h 20m" to go, with its unit line.
(String, String) _countdown(DateTime at, DateTime now) {
  final mins = at.difference(now).inMinutes.clamp(1, 1 << 20);
  if (mins < 60) return ('${mins}m', 'to go');
  final h = mins ~/ 60, m = mins % 60;
  return (m == 0 ? '${h}h' : '${h}h ${m}m', 'to go');
}

String _titleCase(String s) => s
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}')
    .join(' ');
