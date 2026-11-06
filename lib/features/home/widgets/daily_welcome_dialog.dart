import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/dimension_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../core/providers/daily_briefing_provider.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_dialog.dart';
import '../../capture/quick_capture_sheet.dart';

/// The once-a-day welcome: a centred card with three swipeable pages.
///
/// 1. Greeting and yesterday in one sentence, with morning pulse matrix and quick start.
/// 2. Today in words, with the next thing to start.
/// 3. Three short actions.
class DailyWelcomeDialog extends ConsumerStatefulWidget {
  const DailyWelcomeDialog({
    super.key,
    required this.day,
    required this.name,
    required this.host,
  });

  final DateTime day;
  final String name;

  /// Context that outlives this dialog; used to open the next screen or sheet.
  final BuildContext host;

  static Future<void> show(
    BuildContext context, {
    required DateTime day,
    required String name,
  }) {
    HapticFeedback.lightImpact();
    return showAscentFrostedDialog<void>(
      context: context,
      useRootNavigator: true,
      barrierDismissible: true,
      barrierLabel: 'Dismiss daily briefing',
      barrierColor: Colors.black.withValues(alpha: 0.18),
      transitionDuration: const Duration(milliseconds: 320),
      builder: (_) => DailyWelcomeDialog(day: day, name: name, host: context),
    );
  }

  @override
  ConsumerState<DailyWelcomeDialog> createState() => _DailyWelcomeDialogState();
}

class _DailyWelcomeDialogState extends ConsumerState<DailyWelcomeDialog> {
  static const _pages = 3;
  final _controller = PageController();
  int _page = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String get _firstName {
    final n = widget.name.trim();
    return n.isEmpty ? '' : n.split(RegExp(r'\s+')).first;
  }

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return 'Good morning';
    if (h < 17) return 'Good afternoon';
    return 'Good evening';
  }

  TextStyle _display(Color color, double size) => GoogleFonts.bricolageGrotesque(
    color: color,
    fontSize: size,
    fontWeight: FontWeight.w700,
    height: 1.08,
    letterSpacing: -0.8,
  );

  TextStyle _body(Color color, {double size = 16}) => GoogleFonts.dmSans(
    color: color,
    fontSize: size,
    fontWeight: FontWeight.w500,
    height: 1.5,
  );

  void _close() => Navigator.of(context).pop();

  void _then(VoidCallback action) {
    final host = widget.host;
    _close();
    if (host.mounted) action();
  }

  Widget _eyebrow(String text) {
    final g = context.glass;
    return Text(
      text.toUpperCase(),
      style: GoogleFonts.dmSans(
        color: g.inkMuted,
        fontSize: 11.5,
        fontWeight: FontWeight.w700,
        letterSpacing: 1.4,
      ),
    );
  }

  Widget _pageGreeting(DailyBriefing b) {
    final g = context.glass;
    final name = _firstName;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow(DateFormat('EEEE, d MMMM').format(widget.day)),
        const SizedBox(height: 12),
        Text(
          name.isEmpty ? '${_greeting()}.' : '${_greeting()},\n$name.',
          style: _display(g.ink, 34),
        ),
        const SizedBox(height: 12),
        Text(b.yesterdayStory, style: _body(g.inkSecondary, size: 15.5)),
        const SizedBox(height: 16),
        // Morning Pulse Matrix
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: g.fill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: g.line, width: 0.8),
          ),
          child: Row(
            children: [
              Expanded(
                child: _pulseItem(
                  icon: Icons.checklist_rounded,
                  label: 'Due Today',
                  value: b.dueToday > 0 ? '${b.dueToday}' : '0',
                  subtext: b.dueToday > 0 ? 'waiting' : 'Clean slate',
                  color: SharedControlColors.actionBlue,
                ),
              ),
              Container(width: 1, height: 36, color: g.line),
              Expanded(
                child: _pulseItem(
                  icon: Icons.timer_outlined,
                  label: 'Focus',
                  value: b.trackedMinutesYesterday > 0
                      ? '${b.trackedMinutesYesterday}m'
                      : '0m',
                  subtext: 'yesterday',
                  color: g.clay,
                ),
              ),
              Container(width: 1, height: 36, color: g.line),
              Expanded(
                child: _pulseItem(
                  icon: Icons.track_changes_rounded,
                  label: 'Carryover',
                  value: '${b.overdue}',
                  subtext: b.overdue > 0 ? 'overdue' : 'On track',
                  color: b.overdue > 0 ? SharedControlColors.dueRed : g.actionInk,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        AscentButton.tonal(
          label: 'Start today',
          icon: Icons.arrow_forward_rounded,
          compact: true,
          expanded: false,
          onPressed: () => _then(() => widget.host.push('/today')),
        ),
      ],
    );
  }

  Widget _pulseItem({
    required IconData icon,
    required String label,
    required String value,
    required String subtext,
    required Color color,
  }) {
    final g = context.glass;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 17, color: color),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            value,
            style: GoogleFonts.bricolageGrotesque(
              color: g.ink,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        const SizedBox(height: 2),
        FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            subtext,
            style: GoogleFonts.dmSans(
              color: g.inkMuted,
              fontSize: 10.5,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }

  Widget _pageToday(DailyBriefing b) {
    final g = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('Today'),
        const SizedBox(height: 14),
        Text(b.todayStory, style: _display(g.ink, 25).copyWith(height: 1.25)),
        const SizedBox(height: 16),
        Text(b.encouragement.replaceFirst('Bro, y', 'Y'),
            style: _body(g.inkMuted, size: 14.5)),
      ],
    );
  }

  Widget _pageLaunch(DailyBriefing b) {
    final g = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _eyebrow('Ready when you are'),
        const SizedBox(height: 14),
        Text('Where to first?', style: _display(g.ink, 30)),
        const SizedBox(height: 20),
        AscentButton.tonal(
          label: b.nextTask == null ? 'Open today' : 'Start with today’s list',
          icon: Icons.arrow_forward_rounded,
          onPressed: () => _then(() => widget.host.push('/today')),
        ),
        const SizedBox(height: 8),
        AscentButton.tonal(
          label: 'Capture something',
          icon: Icons.bolt_rounded,
          expanded: false,
          onPressed: () => _then(() => showQuickCapture(widget.host)),
        ),
        const SizedBox(height: 4),
        AscentButton.ghost(
          label: 'Plan my day',
          icon: Icons.auto_awesome_rounded,
          expanded: false,
          onPressed: () => _then(() => widget.host.push('/ai-assistant')),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final briefing = ref.watch(dailyBriefingProvider(widget.day));
    final size = MediaQuery.sizeOf(context);
    final bodyHeight = math.min(450.0, size.height * 0.65);

    final Widget body = briefing.when(
      data: (b) => PageView(
        controller: _controller,
        onPageChanged: (i) {
          HapticFeedback.selectionClick();
          setState(() => _page = i);
        },
        children: [
          for (final page in [_pageGreeting(b), _pageToday(b), _pageLaunch(b)])
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(28, 4, 28, 8),
              child: page,
            ),
        ],
      ),
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, _) => Center(
        child: Padding(
          padding: const EdgeInsets.all(28),
          child: Text(
            'Have a good day, ${_firstName.isEmpty ? 'friend' : _firstName}.',
            textAlign: TextAlign.center,
            style: _display(g.ink, 28),
          ),
        ),
      ),
    );

    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
          child: Material(
            color: Theme.of(context).colorScheme.surface,
            elevation: 12,
            shadowColor: Colors.black.withValues(alpha: 0.3),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(28),
              side: BorderSide(color: g.line.withValues(alpha: 0.7), width: 0.8),
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 6, right: 6),
                    child: AscentButton.icon(
                      icon: Icons.close_rounded,
                      tooltip: 'Dismiss daily briefing',
                      onPressed: _close,
                    ),
                  ),
                ),
                SizedBox(height: bodyHeight, child: body),
                Padding(
                  padding: const EdgeInsets.fromLTRB(28, 4, 28, 20),
                  child: Row(
                    children: [
                      for (var i = 0; i < _pages; i++)
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          margin: const EdgeInsets.only(right: 6),
                          width: i == _page ? 22 : 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: i == _page
                                ? g.primaryButtonBg
                                : g.ink.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(
                              AscentDimensions.radiusFull,
                            ),
                          ),
                        ),
                      const Spacer(),
                      if (_page < _pages - 1)
                        Text(
                          'Swipe',
                          style: GoogleFonts.dmSans(
                            color: g.inkMuted,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      if (_page < _pages - 1)
                        Icon(
                          Icons.chevron_right_rounded,
                          size: 18,
                          color: g.inkMuted,
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
