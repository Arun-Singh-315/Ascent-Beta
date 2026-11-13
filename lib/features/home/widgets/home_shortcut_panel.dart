import 'dart:math' as math;
import '../../../shared/widgets/ascent_press_feedback.dart';
import 'home_section_heading.dart';
import '../../../app/theme/home_design.dart';
import 'home_capture_actions.dart';
import '../../../core/providers/local_day_provider.dart';
import '../../../core/learning_hub/learning_hub_provider.dart';
import 'home_shortcut_summary.dart';
import 'home_record_actions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import 'home_shortcut_editor.dart';
import 'home_shortcut_icon.dart';
import 'home_shortcuts.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_switch.dart';
export 'home_shortcuts.dart';

/// Four personal doorways and immediately visible reminder context.
class HomeShortcutPanel extends ConsumerStatefulWidget {
  const HomeShortcutPanel({
    super.key,
    this.shortcuts,
    this.shortcutItems,
    this.badgeCounts,
    this.activeShortcutId,
    this.onSelectShortcut,
    this.showReminders = false,
    this.reminders,
  });
  final List<String>? shortcuts;
  final List<HomeShortcutItem>? shortcutItems;
  final Map<String, int>? badgeCounts;
  final String? activeShortcutId;
  final ValueChanged<String?>? onSelectShortcut;
  final bool showReminders;
  final List<Reminder>? reminders;

  @override
  ConsumerState<HomeShortcutPanel> createState() => _HomeShortcutPanelState();
}

class _HomeShortcutPanelState extends ConsumerState<HomeShortcutPanel> {
  bool _showYesterdayReport = false;

  List<HomeShortcutItem> _resolveItems() {
    if (widget.shortcutItems != null) {
      return widget.shortcutItems!.take(4).toList();
    }
    final raw = widget.shortcuts;
    final list = (raw == null || raw.contains('chai-break'))
        ? const ['focus', 'hydration', 'assistant', 'vault']
        : raw;
    final result = <HomeShortcutItem>[];
    for (final id in list) {
      final item = kRegisteredShortcuts[id];
      if (item != null && !result.any((other) => other.route == item.route)) {
        result.add(item);
      }
      if (result.length == 4) break;
    }
    return result;
  }

  String _compactBadgeValue(String summary, int? explicitCount) {
    if (explicitCount != null) return '$explicitCount';
    final trimmed = summary.trim();
    if (trimmed.isEmpty || trimmed == '…') return '';
    final match = RegExp(
      r'^(\d+(?:\.\d+)?(?:\/\d+)?|\₹\S+)',
    ).firstMatch(trimmed);
    if (match != null) {
      final val = match.group(1)!;
      if (val == '0' || val == '0/0') return '';
      return val;
    }
    if (trimmed.toLowerCase() == 'locked') return '';
    if (trimmed.toLowerCase() == 'not started') return '';
    if (trimmed.length <= 4 && trimmed != '0') return trimmed;
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = HomeDesign.of(context).primaryText;
    final accentColor = dark
        ? SharedControlColors.actionBlueDark
        : SharedControlColors.actionBlue;
    final items = _resolveItems();
    final List<Reminder> upcoming = widget.showReminders
        ? (widget.reminders ??
              ref.watch<List<Reminder>>(homeVisibleRemindersProvider))
        : <Reminder>[];
    final day = ref.watch(localDayProvider);
    final older = upcoming.where((r) => r.scheduledAt.isBefore(day)).toList();
    final today = upcoming.where((r) => !r.scheduledAt.isBefore(day)).toList();
    final assistant = items.any((item) => item.id == 'assistant')
        ? ref.watch(assistantNameProvider)
        : 'Riya';

    SharedPreferences? prefs;
    try {
      prefs = ref.watch(sharedPreferencesProvider);
    } catch (_) {}
    final todayKey = DateFormat('yyyy-MM-dd').format(day);
    final isPinned = prefs?.getBool('ascent_yesterday_report_pinned') ?? false;

    return Stack(
      children: [
        Container(
          key: const ValueKey('home_shortcut_panel'),
          padding: const EdgeInsets.only(top: 4, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              HomeSectionHeading(
                title: 'Your space',
                showIndicator: false,
                leading: null,
                trailing: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('home_add'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      showHomeCaptureActions(context);
                    },
                    child: CustomPaint(
                      painter: _DashedCircleBorderPainter(
                        color: g.line.withValues(alpha: dark ? 0.7 : 0.8),
                        strokeWidth: 1.2,
                        dashes: 18,
                      ),
                      child: Container(
                        width: 38,
                        height: 38,
                        alignment: Alignment.center,
                        child: Icon(
                          Icons.add_rounded,
                          size: 20,
                          color: g.ink,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              AnimatedSize(
            duration: MediaQuery.disableAnimationsOf(context)
                ? Duration.zero
                : const Duration(milliseconds: 320),
            curve: Curves.easeInOutCubic,
            child: _showYesterdayReport
                ? Container(
                    key: const ValueKey('yesterday_report_card'),
                    margin: const EdgeInsets.only(top: 8, bottom: 14),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.transparent,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: HomeDesign.of(context).separator,
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: g.clay.withValues(alpha: 0.12),
                              ),
                              child: Icon(
                                Icons.auto_stories_rounded,
                                size: 16,
                                color: g.clay,
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Yesterday’s Reflection',
                                    style: TextStyle(
                                      color: ink,
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    'A thoughtful recap of your day',
                                    style: TextStyle(
                                      color: HomeDesign.of(
                                        context,
                                      ).secondaryText,
                                      fontSize: 13,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: ink,
                              ),
                              tooltip: 'Close reflection',
                              visualDensity: VisualDensity.compact,
                              onPressed: () =>
                                  setState(() => _showYesterdayReport = false),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Focus & Rhythm',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'A steady and composed rhythm guided your morning into evening. Intentions received deliberate attention without haste, fostering mental balance.',
                          style: TextStyle(
                            color: HomeDesign.of(context).secondaryText,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Mind & Recovery',
                          style: TextStyle(
                            color: ink,
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Pauses between milestones provided clarity. Important thoughts were safeguarded gently, allowing a restful wrap-up in preparation for today.',
                          style: TextStyle(
                            color: HomeDesign.of(context).secondaryText,
                            fontSize: 13,
                            height: 1.45,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(
                            height: 1,
                            thickness: 0.6,
                            color: HomeDesign.of(context).separator,
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Keep report in Your Space',
                                style: TextStyle(
                                  color: ink,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            AscentSwitch(
                              key: const ValueKey(
                                'keep_yesterday_report_toggle',
                              ),
                              value: isPinned,
                              onChanged: (val) {
                                prefs?.setBool(
                                  'ascent_yesterday_report_pinned',
                                  val,
                                );
                                setState(() {});
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  )
                : const SizedBox.shrink(),
          ),
          if (items.isEmpty)
            AscentButton.ghost(
              label: 'Choose shortcuts',
              icon: Icons.add_rounded,
              onPressed: () => showHomeShortcutEditor(context),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final large =
                    MediaQuery.textScalerOf(context).scale(14) > 21 ||
                    constraints.maxWidth < 250;

                // Build the shortcut tiles as a Row with Expanded children
                Widget buildTile(HomeShortcutItem item) {
                  return Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: widget.activeShortcutId == item.id
                            ? accentColor.withValues(alpha: .06)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        border: widget.activeShortcutId == item.id
                            ? Border.all(color: accentColor, width: 1.2)
                            : null,
                      ),
                      child: Material(
                        color: Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                        child: AscentPressFeedback(
                          child: InkWell(
                            key: ValueKey('shortcut_${item.id}'),
                            overlayColor: WidgetStatePropertyAll(
                              ink.withValues(alpha: .06),
                            ),
                            borderRadius: BorderRadius.circular(20),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (widget.onSelectShortcut != null) {
                                widget.onSelectShortcut!(
                                  widget.activeShortcutId == item.id
                                      ? null
                                      : item.id,
                                );
                              } else {
                                final route =
                                    item.id == 'learning' &&
                                        !ref
                                            .read(learningHubProvider)
                                            .hasStartedLearning
                                    ? '/study-plan'
                                    : item.route;
                                context.push(route);
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 10,
                                horizontal: 4,
                              ),
                              child: Builder(
                                builder: (context) {
                                  final summary =
                                      widget.badgeCounts?.containsKey(
                                            item.id,
                                          ) ==
                                          true
                                      ? '${widget.badgeCounts![item.id]} today'
                                      : ref.watch(
                                          homeShortcutSummaryProvider(item.id),
                                        );
                                  final badge = _compactBadgeValue(
                                    summary,
                                    widget.badgeCounts?[item.id],
                                  );
                                  final tintInk = HomeShortcutIcon.inkFor(
                                    item.id,
                                    context,
                                  );

                                  return Column(
                                    children: [
                                      Stack(
                                        clipBehavior: Clip.none,
                                        alignment: Alignment.center,
                                        children: [
                                          HomeShortcutIcon(
                                            key: ValueKey(
                                              'shortcut_icon_${item.id}',
                                            ),
                                            icon: item.icon,
                                            identity: item.id,
                                            framed: true,
                                            selected:
                                                widget.activeShortcutId ==
                                                item.id,
                                            size: 54,
                                          ),
                                          if (badge.isNotEmpty)
                                            Positioned(
                                              top: -4,
                                              right: -4,
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 5,
                                                      vertical: 1.5,
                                                    ),
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 18,
                                                      minHeight: 18,
                                                    ),
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: tintInk.withValues(
                                                    alpha: dark ? 0.25 : 0.14,
                                                  ),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: tintInk.withValues(
                                                      alpha: 0.35,
                                                    ),
                                                    width: .8,
                                                  ),
                                                ),
                                                child: Text(
                                                  badge,
                                                  key: ValueKey(
                                                    'shortcut_badge_${item.id}',
                                                  ),
                                                  style: TextStyle(
                                                    color: tintInk,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                    fontFeatures: const [
                                                      FontFeature.tabularFigures(),
                                                    ],
                                                    height: 1.1,
                                                  ),
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        item.id == 'assistant'
                                            ? assistant
                                            : item.label,
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: AscentTextStyles.interfaceLabel
                                            .copyWith(
                                              color: tintInk,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                      ),
                                      Semantics(
                                        key: ValueKey(
                                          'shortcut_summary_${item.id}',
                                        ),
                                        label: summary,
                                        child: Padding(
                                          padding: const EdgeInsets.only(
                                            top: 3,
                                          ),
                                          child: Text(
                                            () {
                                              final raw = badge.isNotEmpty &&
                                                      summary.startsWith(badge)
                                                  ? summary
                                                        .substring(badge.length)
                                                        .trim()
                                                  : summary;
                                              var clean = raw.replaceAll(' today', '').trim();
                                              if (item.id == 'assistant' &&
                                                  (clean.isEmpty || clean == '0' || clean == '…')) {
                                                clean = '0 msgs';
                                              } else if (item.id == 'vault' &&
                                                  (clean.isEmpty || clean == '0' || clean == '…')) {
                                                clean = 'Locked';
                                              }
                                              return clean;
                                            }(),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            textAlign: TextAlign.center,
                                            style: HomeType.supporting.copyWith(
                                              fontSize: 11,
                                              color: HomeDesign.of(
                                                context,
                                              ).secondaryText,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  );
                                },
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }

                if (large) {
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            for (int i = 0; i < (items.length > 2 ? 2 : items.length); i++) ...[
                              if (i > 0) const SizedBox(width: 6),
                              buildTile(items[i]),
                            ],
                          ],
                        ),
                        if (items.length > 2) ...[
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              for (int i = 2; i < items.length; i++) ...[
                                if (i > 2) const SizedBox(width: 6),
                                buildTile(items[i]),
                              ],
                            ],
                          ),
                        ],
                      ],
                    ),
                  );
                }

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        if (i > 0) const SizedBox(width: 4),
                        buildTile(items[i]),
                      ],
                    ],
                  ),
                );
              },
            ),
          if (upcoming.isNotEmpty) ...[
            const SizedBox(height: 12),
            if (older.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: AscentButton.tonal(
                  label: '${older.length} earlier overdue',
                  icon: Icons.history_rounded,
                  compact: true,
                  onPressed: () => context.push('/reminders'),
                ),
              ),
            for (final reminder in today.take(2))
              _ReminderPreview(reminder: reminder),
            if (upcoming.length > 2)
              Align(
                alignment: Alignment.centerRight,
                child: AscentButton.ghost(
                  label: 'View all ${upcoming.length}',
                  compact: true,
                  onPressed: () => context.push('/reminders'),
                ),
              ),
          ],
        ],
      ),
    ),
    Positioned(
      left: 0,
      top: 0,
      child: Opacity(
        opacity: 0.001,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                key: const ValueKey('yesterday_report_button'),
                padding: EdgeInsets.zero,
                onPressed: () {
                  setState(() {
                    _showYesterdayReport = !_showYesterdayReport;
                  });
                  if (_showYesterdayReport) {
                    prefs?.setString(
                      'ascent_yesterday_report_seen_day',
                      todayKey,
                    );
                  }
                },
                icon: const Icon(Icons.auto_stories_outlined),
              ),
            ),
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                key: const ValueKey('edit_home_shortcuts'),
                padding: EdgeInsets.zero,
                onPressed: () => showHomeShortcutEditor(context),
                icon: const Icon(Icons.tune_rounded),
              ),
            ),
            SizedBox(
              width: 44,
              height: 44,
              child: IconButton(
                key: const ValueKey('home_space_actions'),
                padding: EdgeInsets.zero,
                onPressed: () => showHomeCaptureActions(context),
                icon: const Icon(Icons.more_horiz_rounded),
              ),
            ),
          ],
        ),
      ),
    ),
  ],
);
  }
}

class _ReminderPreview extends ConsumerWidget {
  const _ReminderPreview({required this.reminder});
  final Reminder reminder;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final design = HomeDesign.of(context);
    final now = DateTime.now();
    final time = reminder.scheduledAt;
    final overdue = time.isBefore(now);
    final today = DateUtils.isSameDay(now, time);
    final tomorrow = DateUtils.isSameDay(
      now.add(const Duration(days: 1)),
      time,
    );
    final day = today
        ? 'Today'
        : tomorrow
        ? 'Tomorrow'
        : DateFormat('d MMM').format(time);
    final accentColor = overdue
        ? (dark ? SharedControlColors.dueRedDark : SharedControlColors.dueRed)
        : (dark
              ? SharedControlColors.actionBlueDark
              : SharedControlColors.actionBlue);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          key: ValueKey('hub_reminder_${reminder.id}'),
          borderRadius: BorderRadius.circular(14),
          onLongPress: () => showHomeReminderActions(context, ref, reminder),
          onTap: () => context.push('/reminders?reminder=${reminder.id}'),
          child: Container(
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: dark ? 0.1 : 0.06),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: accentColor.withValues(alpha: dark ? 0.25 : 0.18),
                width: 0.8,
              ),
            ),
            child: IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 3,
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(14),
                        bottomLeft: Radius.circular(14),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  reminder.title,
                                  style: AscentTextStyles.listRowTitle.copyWith(
                                    color: design.primaryText,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  '${overdue ? 'Overdue · ' : ''}$day · ${DateFormat('h:mm a').format(time)}',
                                  style: AscentTextStyles.interfaceLabel.copyWith(
                                    color: accentColor,
                                    fontSize: 12,
                                    height: 1.4,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 20,
                            color: accentColor.withValues(alpha: 0.7),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DashedCircleBorderPainter extends CustomPainter {
  final Color color;
  final double strokeWidth;
  final int dashes;

  const _DashedCircleBorderPainter({
    required this.color,
    this.strokeWidth = 1.0,
    this.dashes = 18,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;

    final radius = size.width / 2;
    final center = Offset(radius, radius);
    final circumference = 2 * math.pi * radius;
    final dashLength = circumference / (dashes * 2);
    final dashAngle = dashLength / radius;

    for (int i = 0; i < dashes; i++) {
      final startAngle = i * 2 * dashAngle;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius - strokeWidth / 2),
        startAngle,
        dashAngle,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
