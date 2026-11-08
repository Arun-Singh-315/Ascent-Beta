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
import '../../../app/theme/shared_control_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import 'home_day_design.dart';
import 'home_shortcut_editor.dart';
import 'home_shortcut_icon.dart';
import 'home_shortcuts.dart';
export 'home_shortcuts.dart';

/// Four personal doorways and immediately visible reminder context.
class HomeShortcutPanel extends ConsumerWidget {
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

  List<HomeShortcutItem> _resolveItems() {
    if (shortcutItems != null) return shortcutItems!.take(4).toList();
    final result = <HomeShortcutItem>[];
    for (final id
        in shortcuts ?? const ['focus', 'hydration', 'assistant', 'vault']) {
      final item = kRegisteredShortcuts[id];
      if (item != null && !result.any((other) => other.route == item.route)) {
        result.add(item);
      }
      if (result.length == 4) break;
    }
    return result;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = HomeDayDesign.ink(dark);
    final items = _resolveItems();
    final List<Reminder> upcoming = showReminders
        ? (reminders ?? ref.watch<List<Reminder>>(homeVisibleRemindersProvider))
        : <Reminder>[];
    final day = ref.watch(localDayProvider);
    final older = upcoming.where((r) => r.scheduledAt.isBefore(day)).toList();
    final today = upcoming.where((r) => !r.scheduledAt.isBefore(day)).toList();
    final assistant = items.any((item) => item.id == 'assistant')
        ? ref.watch(assistantNameProvider)
        : 'Riya';
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
                              if (onSelectShortcut != null) {
                                onSelectShortcut!(
                                  activeShortcutId == item.id ? null : item.id,
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
                                    selected: activeShortcutId == item.id,
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
                                    badgeCounts?.containsKey(item.id) == true
                                        ? '${badgeCounts![item.id]} today'
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
