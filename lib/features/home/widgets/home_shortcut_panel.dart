import 'package:ascent/app/app_navigation.dart';
import '../../../shared/widgets/ascent_press_feedback.dart';
import 'home_section_heading.dart';
import '../../../app/theme/home_design.dart';
import 'home_capture_actions.dart';
import '../../../core/providers/local_day_provider.dart';
import 'home_shortcut_summary.dart';
import 'home_record_actions.dart';
import '../../reminders/widgets/ios_reminder_dialog.dart';
import '../../reminders/reminder_action_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
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
    final result = <HomeShortcutItem>[];
    for (final id
        in widget.shortcuts ??
            const ['focus', 'hydration', 'assistant', 'vault']) {
      final item = kRegisteredShortcuts[id];
      if (item != null && !result.any((other) => other.route == item.route)) {
        result.add(item);
      }
      if (result.length == 4) break;
    }
    return result;
  }

  String _compactBadgeValue(
    String summary,
    int? explicitCount, {
    String? id,
  }) {
    if (explicitCount != null) {
      if (id == 'hydration' || id == 'health') {
        return '$explicitCount ml';
      }
      return '$explicitCount';
    }
    final trimmed = summary.trim();
    if (trimmed.isEmpty || trimmed == '…') return '';
    if (id == 'hydration' || id == 'health') {
      final match = RegExp(
        r'^(\d+(?:\.\d+)?)\s*(?:ml|l)?',
        caseSensitive: false,
      ).firstMatch(trimmed);
      if (match != null) {
        final val = match.group(1)!;
        if (val == '0') return '';
        final intVal = int.tryParse(val) ?? 0;
        return intVal >= 1000
            ? '${(intVal / 1000).toStringAsFixed(1)}L'
            : '$val ml';
      }
    }
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
    final design = HomeDesign.of(context);
    final ink = design.primaryText;
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
    final seenDay = prefs?.getString('ascent_yesterday_report_seen_day');
    final isPinned = prefs?.getBool('ascent_yesterday_report_pinned') ?? false;
    final isUnread = seenDay != todayKey;
    final shouldShowButton =
        prefs != null && (isPinned || isUnread || _showYesterdayReport);

    return Container(
      key: const ValueKey('home_shortcut_panel'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionHeading(
            title: 'Your space',
            showIndicator: false,
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  key: const ValueKey('edit_home_shortcuts'),
                  tooltip: 'Edit shortcuts',
                  onPressed: () => showHomeShortcutEditor(context),
                  icon: Icon(
                    Icons.tune_rounded,
                    size: 20,
                    color: HomeDesign.of(context).secondaryText,
                  ),
                ),
                PopupMenuButton<String>(
                  key: const ValueKey('home_space_actions'),
                  tooltip: 'Your space actions',
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: HomeDesign.of(context).secondaryText,
                  ),
                  onSelected: (action) {
                    if (action == 'report') {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _showYesterdayReport = !_showYesterdayReport;
                      });
                      if (_showYesterdayReport) {
                        prefs?.setString(
                          'ascent_yesterday_report_seen_day',
                          todayKey,
                        );
                      }
                    }
                    if (action == 'add') showHomeCaptureActions(context);
                    if (action == 'edit') showHomeShortcutEditor(context);
                  },
                  itemBuilder: (_) => [
                    if (shouldShowButton)
                      PopupMenuItem(
                        value: 'report',
                        key: const ValueKey('yesterday_report_menu_item'),
                        child: Text(
                          _showYesterdayReport
                              ? 'Hide yesterday’s reflection'
                              : 'Yesterday’s reflection',
                        ),
                      ),
                    const PopupMenuItem(
                      value: 'add',
                      key: ValueKey('home_add'),
                      child: Text('Add something'),
                    ),
                    const PopupMenuItem(value: 'edit', child: Text('Edit shortcuts')),
                  ],
                ),
              ],
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
                                context.open(item.route);
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
                                  final isWater = item.id == 'hydration' || item.id == 'health';
                                  final waterMl = isWater
                                      ? (ref.watch(todayWaterMlStreamProvider).value ?? 0)
                                      : 0;
                                  final waterGoal = isWater
                                      ? (ref.watch(dailyWaterGoalStreamProvider).value ?? 2500)
                                      : 2500;
                                  final waterProgress = isWater && waterGoal > 0
                                      ? (waterMl / waterGoal).clamp(0.0, 1.0)
                                      : null;
                                  final badge = _compactBadgeValue(
                                    summary,
                                    widget.badgeCounts?[item.id],
                                    id: item.id,
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
                                            framed: false,
                                            selected:
                                                widget.activeShortcutId ==
                                                item.id,
                                            size: 54,
                                            progress: waterProgress,
                                          ),
                                          if (badge.isNotEmpty)
                                            Positioned(
                                              top: -5,
                                              right: isWater ? -8 : -4,
                                              child: Container(
                                                padding: EdgeInsets.symmetric(
                                                  horizontal: isWater ? 6.5 : 5,
                                                  vertical: isWater ? 2.0 : 1.5,
                                                ),
                                                constraints:
                                                    const BoxConstraints(
                                                      minWidth: 18,
                                                      minHeight: 18,
                                                    ),
                                                alignment: Alignment.center,
                                                decoration: BoxDecoration(
                                                  color: dark
                                                      ? const Color(0xFF2E3442)
                                                      : const Color(0xFF0F172A),
                                                  borderRadius:
                                                      BorderRadius.circular(10),
                                                  border: Border.all(
                                                    color: dark
                                                        ? const Color(0xFF475569)
                                                        : Colors.white,
                                                    width: 1.0,
                                                  ),
                                                  boxShadow: [
                                                    BoxShadow(
                                                      color: Colors.black
                                                          .withValues(alpha: 0.18),
                                                      blurRadius: 4,
                                                      offset: const Offset(0, 1),
                                                    ),
                                                  ],
                                                ),
                                                child: Text(
                                                  badge,
                                                  key: ValueKey(
                                                    'shortcut_badge_${item.id}',
                                                  ),
                                                  style: TextStyle(
                                                    color: Colors.white,
                                                    fontSize: isWater ? 10 : 11,
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
                                              color: ink,
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
                                            isWater
                                                ? (waterMl > 0
                                                    ? '$waterMl ml logged'
                                                    : 'Goal ${(waterGoal / 1000).toStringAsFixed(1)}L')
                                                : (badge.isNotEmpty &&
                                                        summary.startsWith(badge)
                                                    ? summary
                                                          .substring(badge.length)
                                                          .trim()
                                                    : summary),
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
            const SizedBox(height: 14),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Reminders',
                      style: AscentTextStyles.homeTitle.copyWith(
                        color: design.primaryText,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    key: const ValueKey('home_reminder_add'),
                    tooltip: 'New reminder',
                    icon: Icon(
                      Icons.add_rounded,
                      size: 20,
                      color: design.primaryText,
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      showIOSReminderDialog(context);
                    },
                  ),
                  IconButton(
                    tooltip: 'Open reminders',
                    icon: Icon(
                      Icons.arrow_forward_rounded,
                      size: 18,
                      color: design.secondaryText,
                    ),
                    onPressed: () => context.push('/reminders'),
                  ),
                ],
              ),
            ),
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
        : design.secondaryText;

    final cardBg = dark
        ? const Color(0xFF15181C)
        : const Color(0xFF1E2126);
    final cardBorder = overdue
        ? accentColor.withValues(alpha: 0.5)
        : (dark
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.12));

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          key: ValueKey('hub_reminder_${reminder.id}'),
          borderRadius: BorderRadius.circular(16),
          onLongPress: () => showHomeReminderActions(context, ref, reminder),
          onTap: () => context.push('/reminders?reminder=${reminder.id}'),
          child: Container(
            decoration: BoxDecoration(
              color: cardBg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: cardBorder,
                width: 1,
              ),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Circular 1-tap complete toggle (zero blue sidebar)
                Semantics(
                  button: true,
                  label: 'Mark reminder complete',
                  child: InkResponse(
                    onTap: () async {
                      HapticFeedback.mediumImpact();
                      await runReminderAction(
                        context,
                        ref,
                        reminder,
                        ReminderRowAction.done,
                      );
                    },
                    radius: 20,
                    child: Container(
                      width: 22,
                      height: 22,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.transparent,
                        border: Border.all(
                          color: overdue
                              ? accentColor
                              : (dark ? Colors.white38 : Colors.white54),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        reminder.title,
                        style: AscentTextStyles.listRowTitle.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 14,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: 12,
                            color: overdue ? accentColor : Colors.white60,
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              '${overdue ? 'Overdue · ' : ''}$day · ${DateFormat('h:mm a').format(time)}',
                              style: AscentTextStyles.interfaceLabel.copyWith(
                                color: overdue ? accentColor : Colors.white60,
                                fontSize: 12,
                                height: 1.2,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Snooze 10 min',
                  icon: const Icon(
                    Icons.snooze_rounded,
                    size: 18,
                    color: Colors.white60,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => runReminderAction(
                    context,
                    ref,
                    reminder,
                    ReminderRowAction.snooze,
                  ),
                ),
                IconButton(
                  tooltip: 'Reminder actions',
                  icon: const Icon(
                    Icons.more_vert_rounded,
                    size: 18,
                    color: Colors.white60,
                  ),
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                  onPressed: () => showHomeReminderActions(context, ref, reminder),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
