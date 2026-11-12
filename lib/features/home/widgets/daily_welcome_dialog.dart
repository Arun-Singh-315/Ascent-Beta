import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' hide TextDirection;
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/daily_briefing_provider.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_dialog.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../capture/quick_capture_sheet.dart';
import '../../today/add_activity_sheet.dart';
import 'home_day_design.dart';
import 'home_theme.dart';
import '../../../app/theme/monochrome_surfaces.dart';
import 'home_header_landscape.dart';
import 'home_rhythm_artwork.dart';

/// A once-daily, read-only brief: schedule, a next step, and a manageable reset.
class DailyWelcomeDialog extends ConsumerStatefulWidget {
  const DailyWelcomeDialog({
    super.key,
    required this.day,
    required this.name,
    required this.host,
    this.now,
  });
  final DateTime day;
  final String name;
  final BuildContext host;
  final DateTime? now;

  static Future<void> show(
    BuildContext context, {
    required DateTime day,
    required String name,
  }) => showAscentFrostedDialog<void>(
    context: context,
    useRootNavigator: true,
    barrierLabel: 'Dismiss daily briefing',
    transitionDuration: const Duration(milliseconds: 320),
    builder: (dialogContext) => Theme(
      data: HomeTheme.from(Theme.of(dialogContext)),
      child: DailyWelcomeDialog(day: day, name: name, host: context),
    ),
  );

  @override
  ConsumerState<DailyWelcomeDialog> createState() => _DailyWelcomeDialogState();
}

class _DailyWelcomeDialogState extends ConsumerState<DailyWelcomeDialog> {
  final _controller = PageController();
  final _pageStorage = PageStorageBucket();
  int _page = 0;
  AscentGlass get _glass => context.glass.monochrome != null
      ? context.glass
      : HomeTheme.from(Theme.of(context)).extension<AscentGlass>()!;
  bool get _dark => Theme.of(context).brightness == Brightness.dark;
  Color get _blue => _dark
      ? SharedControlColors.actionBlueDark
      : SharedControlColors.actionBlue;
  Color get _red =>
      _dark ? SharedControlColors.dueRedDark : SharedControlColors.dueRed;
  DateTime get _now => widget.now ?? DateTime.now();
  String get _name => widget.name.trim().split(RegExp(r'\s+')).first;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _close() => Navigator.of(context).pop();
  void _then(VoidCallback action) {
    final host = widget.host;
    _close();
    if (host.mounted) action();
  }

  void _open(String route) => _then(() => widget.host.push(route));
  void _task(int? id) => _open(id == null ? '/today' : '/today?task=$id');
  void _go(int page) {
    if (!_controller.hasClients) return;
    HapticFeedback.selectionClick();
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.jumpToPage(page);
    } else {
      _controller.animateToPage(
        page,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
      );
    }
  }

  TextStyle _title([double size = 28]) =>
      AscentTextStyles.interfaceTitle.copyWith(
        color: _glass.ink,
        fontSize: size,
        height: 1.12,
        fontWeight: FontWeight.w600,
        letterSpacing: -.4,
      );
  Widget _body(String text, {Color? color}) => Text(
    text,
    style: AscentTextStyles.interfaceBody.copyWith(
      color: color ?? _glass.inkSecondary,
      height: 1.45,
    ),
  );
  Widget _label(String text, {Color? color}) => Text(
    text,
    style: AscentTextStyles.interfaceLabel.copyWith(
      color: color ?? _glass.inkSecondary,
    ),
  );

  Widget _heading(String label, String title, String art) => LayoutBuilder(
    builder: (context, constraints) => Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label(label),
              const SizedBox(height: 10),
              Text(title, style: _title()),
            ],
          ),
        ),
        if (MediaQuery.textScalerOf(context).scale(14) < 21 &&
            constraints.maxWidth > 260) ...[
          const SizedBox(width: 8),
          ExcludeSemantics(
            child: CustomPaint(
              size: const Size(82, 98),
              painter: HomeRhythmArtwork(
                id: art,
                dark: _dark,
                tint: _glass.inkSecondary,
              ),
            ),
          ),
        ],
      ],
    ),
  );

  Widget _metric(String value, String label, VoidCallback onTap, {Color? accentColor}) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: (accentColor ?? _blue).withValues(alpha: _dark ? 0.12 : 0.06),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: (accentColor ?? _blue).withValues(alpha: _dark ? 0.28 : 0.16),
            width: 1.0,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: _title(23).copyWith(
                color: accentColor ?? _glass.ink,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AscentTextStyles.interfaceLabel.copyWith(
                color: _glass.inkSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _overview(DailyBriefing b) {
    final g = _glass;
    final large = MediaQuery.textScalerOf(context).scale(14) >= 21;
    final greeting = HomeDayDesign.at(_now).greeting.replaceAll(',', '');
    final next = b.nextReminder;
    final calendar =
        '/reminders?view=calendar&date=${DateFormat('yyyy-MM-dd').format(widget.day)}';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: CustomPaint(
            painter: large
                ? null
                : HomeHeaderLandscape(
                    now: _now,
                    dark: _dark,
                    opacity: _dark ? .22 : .30,
                  ),
            child: Padding(
              padding: EdgeInsets.fromLTRB(18, 18, large ? 18 : 52, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _label(DateFormat('EEEE, d MMMM').format(widget.day)),
                  const SizedBox(height: 14),
                  Text(
                    _name.isEmpty
                        ? '$greeting.'
                        : large
                        ? '$greeting\n$_name.'
                        : '$greeting,\n$_name.',
                    style: _title(large ? 24 : 28),
                  ),
                  const SizedBox(height: 12),
                  _body('Here’s what needs your time today.'),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        if (large)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _metric(
                b.dueToday == 0 ? 'Clear' : '${b.dueToday}',
                'Tasks due today',
                () => _task(null),
                accentColor: _blue,
              ),
              const SizedBox(height: 10),
              _metric(
                b.remindersToday == 0 ? 'None' : '${b.remindersToday}',
                'Reminders today',
                () => _open(calendar),
                accentColor: _dark ? const Color(0xFFFCD34D) : const Color(0xFFD97706),
              ),
            ],
          )
        else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: _metric(
                  b.dueToday == 0 ? 'Clear' : '${b.dueToday}',
                  'Tasks due today',
                  () => _task(null),
                  accentColor: _blue,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _metric(
                  b.remindersToday == 0 ? 'None' : '${b.remindersToday}',
                  'Reminders today',
                  () => _open(calendar),
                  accentColor: _dark ? const Color(0xFFFCD34D) : const Color(0xFFD97706),
                ),
              ),
            ],
          ),
        const SizedBox(height: 22),
        if (next != null) ...[
          _label('Next reminder · ${DateFormat.jm().format(next.scheduledAt)}'),
          const SizedBox(height: 8),
          Text(next.title, style: _title(23)),
          const SizedBox(height: 14),
          AscentButton.primary(
            label: 'View reminder',
            icon: Icons.north_east_rounded,
            expanded: true,
            onPressed: () => _open('/reminders?reminder=${next.id}'),
          ),
        ] else ...[
          _label(
            b.remindersToday == 0
                ? 'No fixed reminders'
                : 'No more reminders today',
          ),
          const SizedBox(height: 8),
          _body(
            b.overdue > 0
                ? '${b.overdue} carried-over ${b.overdue == 1 ? 'task also needs' : 'tasks also need'} a decision. You can review them in Reset.'
                : b.dueToday > 0
                ? 'Your saved tasks are ready in Focus. Choose one clear starting point.'
                : 'Open your week to plan a task or leave some breathing room.',
          ),
          const SizedBox(height: 14),
          AscentButton.primary(
            label: 'Open calendar',
            icon: Icons.calendar_month_outlined,
            expanded: true,
            onPressed: () => _open(calendar),
          ),
        ],
        const SizedBox(height: 8),
        Text(
          'Your saved schedule, refreshed when you open this brief.',
          style: AscentTextStyles.interfaceSupporting.copyWith(
            color: g.inkMuted,
            height: 1.4,
          ),
        ),
      ],
    );
  }

  String _reason(Task task) {
    if (task.isDailyStanding) return 'Daily task';
    if (task.plannedDate == null) return 'No date set';
    if (briefingDay(task.plannedDate!) == briefingDay(widget.day)) {
      return 'Due today';
    }
    return 'Carried over · ${DateFormat.MMMd().format(task.plannedDate!)}';
  }

  Widget _focus(DailyBriefing b) {
    final g = _glass;
    final first = b.focusTasks.isEmpty ? null : b.focusTasks.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Your next step', 'One thing first.', 'walk'),
        const SizedBox(height: 18),
        _body(
          b.nextTask == null
              ? 'Start with something small enough to finish.'
              : 'Chosen from tasks due today, then carryover and undated tasks.',
        ),
        const SizedBox(height: 20),
        if (b.nextTask != null) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MonochromeSurfaces.of(context).groupedFill,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 6,
                  children: [
                    _label(first == null ? 'Suggested start' : _reason(first)),
                    if (first?.estimatedMinutes != null &&
                        first!.estimatedMinutes! > 0)
                      _label(
                        '${first.estimatedMinutes} min estimate',
                        color: g.inkSecondary,
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  b.nextTask!,
                  key: const ValueKey('briefing_next_task'),
                  style: _title(25),
                ),
                const SizedBox(height: 20),
                AscentButton.primary(
                  label: b.nextTaskId == null
                      ? 'Open Dayboard'
                      : 'Open this task',
                  icon: Icons.arrow_forward_rounded,
                  expanded: true,
                  onPressed: () => _task(b.nextTaskId),
                ),
              ],
            ),
          ),
          if (b.focusTasks.length > 1) ...[
            const SizedBox(height: 22),
            _label('Also on your list'),
            const SizedBox(height: 8),
            for (final task in b.focusTasks.skip(1))
              _action(
                icon: Icons.radio_button_unchecked_rounded,
                title: task.title,
                detail: _reason(task),
                onTap: () => _task(task.id),
              ),
          ],
        ] else ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: MonochromeSurfaces.of(context).groupedFill,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Icon(Icons.edit_calendar_outlined, size: 34, color: _blue),
                const SizedBox(height: 14),
                Text('Choose your first step', style: _title(25)),
                const SizedBox(height: 10),
                _body(
                  'Add a task with a date or a time estimate. It will appear here when it needs your attention.',
                ),
                const SizedBox(height: 18),
                AscentButton.primary(
                  label: 'Add a task',
                  icon: Icons.add_rounded,
                  expanded: true,
                  onPressed: () =>
                      _then(() => AddActivitySheet.show(widget.host)),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _action({
    required IconData icon,
    required String title,
    required String detail,
    required VoidCallback onTap,
    bool overdue = false,
  }) {
    final g = _glass;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 2),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(icon, color: overdue ? _red : _blue, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AscentTextStyles.cardTitle.copyWith(
                        color: g.ink,
                        fontSize: 17,
                      ),
                    ),
                    const SizedBox(height: 4),
                    _body(detail),
                  ],
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: g.inkSecondary,
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _reset(DailyBriefing b) {
    final g = _glass;
    final recorded = b.completedYesterday > 0 || b.trackedMinutesYesterday > 0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _heading('Make room', 'A lighter plan.', 'chai-break'),
        const SizedBox(height: 18),
        _body(
          b.overdue > 0 || b.unscheduled > 0
              ? 'A quick review can make today easier to follow.'
              : 'Your task list has no carryover or undated items to review.',
        ),
        const SizedBox(height: 12),
        if (b.overdue > 0)
          _action(
            icon: Icons.event_repeat_rounded,
            title:
                '${b.overdue} carried-over ${b.overdue == 1 ? 'task' : 'tasks'}',
            detail: 'Open one and decide: do it, move its date, or let it go.',
            overdue: true,
            onTap: () => _task(b.firstOverdueTaskId),
          ),
        if (b.unscheduled > 0)
          _action(
            icon: Icons.edit_calendar_outlined,
            title:
                '${b.unscheduled} ${b.unscheduled == 1 ? 'task has' : 'tasks have'} no date',
            detail: 'Give one task a place in your week.',
            onTap: () => _task(b.firstUnscheduledTaskId),
          ),
        if (b.overdue == 0 && b.unscheduled == 0)
          _action(
            icon: Icons.spa_outlined,
            title: 'Leave space for a pause',
            detail: 'A short breathing break is ready whenever you need it.',
            onTap: () => _open('/chai-break'),
          ),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: g.ink.withValues(alpha: .04),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _label('RECORDED Yesterday', color: g.inkSecondary),
              const SizedBox(height: 10),
              _body(
                recorded
                    ? b.yesterdayStory
                    : 'No completed tasks or focus time recorded. You can start from what matters today.',
              ),
            ],
          ),
        ),
        const SizedBox(height: 20),
        AscentButton.primary(
          label: 'Capture something',
          icon: Icons.edit_note_rounded,
          expanded: true,
          onPressed: () => _then(() => showQuickCapture(widget.host)),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = _glass;
    final briefing = ref.watch(dailyBriefingProvider(widget.day));
    final ready = briefing.hasValue && !briefing.hasError;
    final motion = MediaQuery.disableAnimationsOf(context);
    return Theme(
      data: HomeTheme.from(Theme.of(context)),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final rtl = Directionality.of(context) == TextDirection.rtl;
                return SizedBox(
                width: math.min(395, constraints.maxWidth),
                height: math.min(530, constraints.maxHeight * 0.82),
                child: Material(
                  color: MonochromeSurfaces.of(context).elevated,
                  elevation: 16,
                  shadowColor: Colors.black.withValues(alpha: .25),
                  borderRadius: BorderRadius.circular(28),
                  clipBehavior: Clip.antiAlias,
                  child: AnimatedContainer(
                    duration: Duration(milliseconds: motion ? 0 : 280),
                    decoration: BoxDecoration(
                      color: MonochromeSurfaces.of(context).elevated,
                    ),
                    child: Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(6),
                                decoration: BoxDecoration(
                                  color: g.clay.withValues(alpha: 0.12),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.wb_twilight_rounded,
                                  color: g.clay,
                                  size: 18,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  'Daily brief',
                                  style: AscentTextStyles.cardTitle.copyWith(
                                    color: g.ink,
                                    fontSize: 17,
                                  ),
                                ),
                              ),
                              IconButton(
                                tooltip: 'Dismiss daily briefing',
                                onPressed: _close,
                                icon: const Icon(Icons.close_rounded),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: AscentSegmentedControl<int>(
                            key: const ValueKey('briefing_sections'),
                            restrained: true,
                            segments: const [
                              AscentSegment(
                                value: 0,
                                label: 'Overview',
                                key: ValueKey('brief_tab_overview'),
                              ),
                              AscentSegment(
                                value: 1,
                                label: 'Focus',
                                key: ValueKey('brief_tab_focus'),
                              ),
                              AscentSegment(
                                value: 2,
                                label: 'Reset',
                                key: ValueKey('brief_tab_reset'),
                              ),
                            ],
                            selected: _page,
                            enabled: ready,
                            onChanged: _go,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Expanded(
                          child: briefing.when(
                            skipLoadingOnReload: true,
                            data: (b) => PageStorage(
                              bucket: _pageStorage,
                              child: PageView(
                                key: const PageStorageKey('daily_brief_pages'),
                                controller: _controller,
                                onPageChanged: (page) {
                                  HapticFeedback.selectionClick();
                                  setState(() => _page = page);
                                },
                                children: [
                                  for (final (index, content) in [
                                    _overview(b),
                                    _focus(b),
                                    _reset(b),
                                  ].indexed)
                                    SingleChildScrollView(
                                      key: PageStorageKey(
                                        'daily_brief_card_$index',
                                      ),
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        12,
                                        20,
                                        24,
                                      ),
                                      child: content,
                                    ),
                                ],
                              ),
                            ),
                            loading: () => const Center(
                              child: CircularProgressIndicator(
                                semanticsLabel: 'Loading daily brief',
                              ),
                            ),
                            error: (_, _) => SingleChildScrollView(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                children: [
                                  const SizedBox(height: 24),
                                  Icon(
                                    Icons.cloud_off_rounded,
                                    color: g.inkSecondary,
                                    size: 40,
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Couldn’t load your daily brief.',
                                    style: _title(25),
                                  ),
                                  const SizedBox(height: 12),
                                  _body(
                                    'Try again when you’re ready, or continue to Home.',
                                  ),
                                  const SizedBox(height: 20),
                                  AscentButton.primary(
                                    label: 'Retry',
                                    expanded: true,
                                    onPressed: () => ref.invalidate(
                                      dailyBriefingProvider(widget.day),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.center,
                            child: Row(
                              children: [
                                AscentButton.navigation(
                                  label: 'Back',
                                  semanticLabel: 'Previous briefing card',
                                  tooltip: 'Previous briefing card',
                                  icon: rtl
                                      ? Icons.chevron_right_rounded
                                      : Icons.chevron_left_rounded,
                                  onPressed: _page == 0 || !ready
                                      ? null
                                      : () => _go(_page - 1),
                                ),
                                const SizedBox(width: 12),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: g.ink.withValues(alpha: 0.06),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: g.line.withValues(alpha: 0.4),
                                      width: 0.8,
                                    ),
                                  ),
                                  child: Text(
                                    '${_page + 1} of 3',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w600,
                                      color: g.inkSecondary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                AscentButton.navigation(
                                  label: _page == 2 || !ready ? 'Done' : 'Next',
                                  icon: _page == 2 || !ready
                                      ? null
                                      : (rtl
                                            ? Icons.chevron_left_rounded
                                            : Icons.chevron_right_rounded),
                                  iconAtEnd: true,
                                  onPressed: !ready || _page == 2
                                      ? _close
                                      : () => _go(_page + 1),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          ),
        ),
      ),
    );
  }
}
