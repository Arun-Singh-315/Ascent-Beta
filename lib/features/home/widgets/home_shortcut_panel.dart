import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/database/app_database.dart';
import '../../../core/learning_hub/learning_hub_provider.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/streak/study_streak_provider.dart';
import '../../../core/theme/app_colors.dart';
import 'home_capture_actions.dart';
import 'home_shortcuts.dart';
import 'home_shortcut_summary.dart';

export 'home_shortcuts.dart';

/// Four personal doorways (Focus, Water, Riya, Vault) with calm, clean presentation.
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

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final items = _resolveItems();
    final assistantName = ref.watch(assistantNameProvider);
    final waterMl = ref.watch(todayWaterMlStreamProvider).value ?? 500;
    final focusMins = ref.watch(studyStreakProvider).todaySeconds ~/ 60;
    final msgCount = ref.watch(todayShortcutMessageCountProvider).value ?? 0;

    final dark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Container(
        key: const ValueKey('home_shortcut_panel'),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
        decoration: BoxDecoration(
          color: c.surfaceAlt.withValues(alpha: dark ? 0.35 : 0.45),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: c.border.withValues(alpha: 0.8),
            width: 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top action bar inside single border: quick capture '+' on right
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Tooltip(
                  message: 'Your space actions',
                  child: Material(
                    color: c.surfaceAlt.withValues(alpha: 0.6),
                    shape: CircleBorder(
                      side: BorderSide(color: c.border.withValues(alpha: 0.7)),
                    ),
                    child: InkWell(
                      key: const ValueKey('home_add'),
                      customBorder: const CircleBorder(),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        showHomeCaptureActions(context);
                      },
                      child: SizedBox(
                        width: 32,
                        height: 32,
                        child: Icon(Icons.add, size: 18, color: c.textPrimary),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // 4 equal shortcut tiles
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final item in items)
                  Expanded(
                    child: _ShortcutTile(
                      item: item,
                      assistantName: assistantName,
                      waterMl: waterMl,
                      focusMins: focusMins,
                      msgCount: msgCount,
                      onTap: () {
                        HapticFeedback.selectionClick();
                        if (widget.onSelectShortcut != null) {
                          widget.onSelectShortcut!(
                            widget.activeShortcutId == item.id
                                ? null
                                : item.id,
                          );
                        } else {
                          final route = item.id == 'learning' &&
                                  !ref
                                      .read(learningHubProvider)
                                      .hasStartedLearning
                              ? '/study-plan'
                              : item.route;
                          context.push(route);
                        }
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ShortcutTile extends StatelessWidget {
  const _ShortcutTile({
    required this.item,
    required this.assistantName,
    required this.waterMl,
    required this.focusMins,
    required this.msgCount,
    required this.onTap,
  });

  final HomeShortcutItem item;
  final String assistantName;
  final int waterMl;
  final int focusMins;
  final int msgCount;
  final VoidCallback onTap;

  IconData _iconFor(String id) {
    switch (id) {
      case 'focus':
        return Icons.timer_outlined;
      case 'hydration':
      case 'health':
        return Icons.water_drop_outlined;
      case 'assistant':
        return Icons.auto_awesome_rounded;
      case 'vault':
        return Icons.shield_outlined;
      default:
        return item.icon;
    }
  }

  String _labelFor(String id) {
    if (id == 'assistant') return assistantName;
    if (id == 'hydration') return 'Water';
    return item.label;
  }

  Widget _valueWidget(BuildContext context, String id) {
    final c = context.c;
    switch (id) {
      case 'focus':
        return Text(
          '$focusMins min',
          style: TextStyle(fontSize: 12, color: c.textSecondary),
        );
      case 'hydration':
      case 'health':
        return Text(
          '$waterMl ml',
          style: TextStyle(fontSize: 12, color: c.textSecondary),
        );
      case 'assistant':
        return Text(
          '$msgCount messages',
          style: TextStyle(fontSize: 12, color: c.textSecondary),
        );
      case 'vault':
        return Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 12, color: c.textSecondary),
            const SizedBox(width: 3),
            Text(
              'Locked',
              style: TextStyle(fontSize: 12, color: c.textSecondary),
            ),
          ],
        );
      default:
        return Text(
          'Active',
          style: TextStyle(fontSize: 12, color: c.textSecondary),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final iconData = _iconFor(item.id);
    final label = _labelFor(item.id);

    return InkWell(
      key: ValueKey('shortcut_${item.id}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 56px circle, surfaceAlt fill, 1px border, icon 22px in accent
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: c.surfaceAlt,
                border: Border.all(color: c.border),
              ),
              child: Icon(iconData, size: 22, color: c.accent),
            ),
            const SizedBox(height: 8),

            // Label below (13px textPrimary)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                label,
                textAlign: TextAlign.center,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: c.textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 2),

            // Value line (12px textSecondary)
            FittedBox(
              fit: BoxFit.scaleDown,
              child: _valueWidget(context, item.id),
            ),
          ],
        ),
      ),
    );
  }
}
