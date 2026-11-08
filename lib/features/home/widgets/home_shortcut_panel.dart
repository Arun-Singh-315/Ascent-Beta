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
import 'home_day_design.dart';
import 'home_shortcut_editor.dart';
import 'home_shortcut_icon.dart';
import 'home_shortcuts.dart';
import '../../../app/theme/glass_theme.dart';
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
    if (widget.shortcutItems != null) return widget.shortcutItems!.take(4).toList();
    final result = <HomeShortcutItem>[];
    for (final id
        in widget.shortcuts ?? const ['focus', 'hydration', 'assistant', 'vault']) {
      final item = kRegisteredShortcuts[id];
      if (item != null && !result.any((other) => other.route == item.route)) {
        result.add(item);
      }
      if (result.length == 4) break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = HomeDayDesign.ink(dark);
    final accentColor = dark
        ? SharedControlColors.actionBlueDark
        : SharedControlColors.actionBlue;
    final items = _resolveItems();
    final List<Reminder> upcoming = widget.showReminders
        ? (widget.reminders ?? ref.watch<List<Reminder>>(homeVisibleRemindersProvider))
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
    final shouldShowButton = prefs != null && (isPinned || isUnread || _showYesterdayReport);

    return Container(
      key: const ValueKey('home_shortcut_panel'),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: HomeDayDesign.line(dark), width: .8),
      ),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Your space',
                  style: AscentTextStyles.homeTitle.copyWith(
                    color: ink,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    letterSpacing: -.5,
                  ),
                ),
              ),
              if (shouldShowButton)
                Stack(
                  alignment: Alignment.topRight,
                  children: [
                    IconButton(
                      key: const ValueKey('yesterday_report_button'),
                      tooltip: 'Yesterday’s summary reflection',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _showYesterdayReport = !_showYesterdayReport;
                        });
                        if (_showYesterdayReport) {
                          prefs?.setString('ascent_yesterday_report_seen_day', todayKey);
                        }
                      },
                      icon: Icon(
                        _showYesterdayReport
                            ? Icons.auto_stories_rounded
                            : Icons.auto_stories_outlined,
                        size: 20,
                        color: _showYesterdayReport ? accentColor : ink,
                      ),
                    ),
                    if (isUnread && !_showYesterdayReport)
                      Positioned(
                        top: 8,
                        right: 8,
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: accentColor,
                          ),
                        ),
                      ),
                  ],
                ),
              IconButton(
                key: const ValueKey('home_add'),
                tooltip: 'Add activity, thought or commitment',
                onPressed: () => showHomeCaptureActions(context),
                icon: Icon(Icons.add_rounded, color: ink),
              ),
              IconButton(
                key: const ValueKey('edit_home_shortcuts'),
                tooltip: 'Edit shortcuts',
                onPressed: () => showHomeShortcutEditor(context),
                icon: Icon(Icons.edit_outlined, size: 20, color: ink),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 320),
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
                        color: HomeDayDesign.line(dark),
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
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: -0.3,
                                    ),
                                  ),
                                  Text(
                                    'A thoughtful recap of your day',
                                    style: TextStyle(
                                      color: HomeDayDesign.secondary(dark),
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.close_rounded, size: 18, color: ink),
                              tooltip: 'Close reflection',
                              visualDensity: VisualDensity.compact,
                              onPressed: () => setState(() => _showYesterdayReport = false),
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
                            color: HomeDayDesign.secondary(dark),
                            fontSize: 12.5,
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
                            color: HomeDayDesign.secondary(dark),
                            fontSize: 12.5,
                            height: 1.45,
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Divider(
                            height: 1,
                            thickness: 0.6,
                            color: HomeDayDesign.line(dark),
                          ),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                'Keep report in Your Space',
                                style: TextStyle(
                                  color: ink,
                                  fontSize: 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            AscentSwitch(
                              key: const ValueKey('keep_yesterday_report_toggle'),
                              value: isPinned,
                              onChanged: (val) {
                                prefs?.setBool('ascent_yesterday_report_pinned', val);
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
            TextButton.icon(
              onPressed: () => showHomeShortcutEditor(context),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Choose shortcuts'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final large =
                    MediaQuery.textScalerOf(context).scale(14) > 21 ||
                    constraints.maxWidth < 250;
                final columns = large ? 2 : items.length;
                final width =
                    (constraints.maxWidth - (columns - 1) * 8) / columns;
                return Wrap(
                  spacing: 8,
                  runSpacing: 12,
                  children: [
                    for (final item in items)
                      SizedBox(
                        width: width,
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: ValueKey('shortcut_${item.id}'),
                            overlayColor: WidgetStatePropertyAll(
                              ink.withValues(alpha: .06),
                            ),
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              HapticFeedback.selectionClick();
                              if (widget.onSelectShortcut != null) {
                                widget.onSelectShortcut!(
                                  widget.activeShortcutId == item.id ? null : item.id,
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
                              padding: const EdgeInsets.symmetric(vertical: 7),
                              child: Column(
                                children: [
                                  HomeShortcutIcon(
                                    key: ValueKey('shortcut_icon_${item.id}'),
                                    icon: item.icon,
                                    selected: widget.activeShortcutId == item.id,
                                    size: 44,
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    item.id == 'assistant'
                                        ? assistant
                                        : item.label,
                                    textAlign: TextAlign.center,
                                    style: AscentTextStyles.labelMedium
                                        .copyWith(
                                          color: ink,
                                          fontSize: 12.5,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    widget.badgeCounts?.containsKey(item.id) == true
                                        ? '${widget.badgeCounts![item.id]} today'
                                        : ref.watch(
                                            homeShortcutSummaryProvider(
                                              item.id,
                                            ),
                                          ),
                                    key: ValueKey(
                                      'shortcut_summary_${item.id}',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: AscentTextStyles.labelSmall.copyWith(
                                      color: HomeDayDesign.secondary(dark),
                                      fontSize: 10.5,
                                      height: 1.35,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                );
              },
            ),
          if (upcoming.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Divider(
                height: 1,
                thickness: .7,
                color: HomeDayDesign.line(dark),
              ),
            ),
            if (older.isNotEmpty)
              TextButton.icon(
                onPressed: () => context.push('/reminders'),
                icon: const Icon(Icons.history_rounded, size: 18),
                label: Text('${older.length} earlier overdue'),
              ),
            for (final reminder in today.take(2))
              _ReminderPreview(reminder: reminder),
            if (upcoming.length > 2)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context.push('/reminders'),
                  child: Text('All ${upcoming.length} reminders'),
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
    return Material(
      color: Colors.transparent,
      child: InkWell(
        key: ValueKey('hub_reminder_${reminder.id}'),
        borderRadius: BorderRadius.circular(14),
        onLongPress: () => showHomeReminderActions(context, ref, reminder),
        onTap: () => context.push('/reminders?reminder=${reminder.id}'),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
          child: Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: 22,
                color: overdue
                    ? (dark
                          ? SharedControlColors.dueRedDark
                          : SharedControlColors.dueRed)
                    : (dark
                          ? SharedControlColors.actionBlueDark
                          : SharedControlColors.actionBlue),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: AscentTextStyles.listRowTitle.copyWith(
                        color: HomeDayDesign.ink(dark),
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${overdue ? 'Overdue · ' : ''}$day · ${DateFormat('h:mm a').format(time)}',
                      style: AscentTextStyles.labelSmall.copyWith(
                        color: overdue
                            ? (dark
                                  ? SharedControlColors.dueRedDark
                                  : SharedControlColors.dueRed)
                            : HomeDayDesign.secondary(dark),
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
                color: HomeDayDesign.secondary(dark),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
