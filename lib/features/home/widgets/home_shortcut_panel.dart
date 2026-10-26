import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/dimension_tokens.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../promises/providers/promise_providers.dart';
import '../../../shared/widgets/glass_surface.dart';

class HomeShortcutItem {
  final String id;
  final String label;
  final IconData icon;
  final String route;

  const HomeShortcutItem({
    required this.id,
    required this.label,
    required this.icon,
    required this.route,
  });
}

const Map<String, HomeShortcutItem> kRegisteredShortcuts = {
  'promises': HomeShortcutItem(
    id: 'promises',
    label: 'Promises',
    icon: Icons.bookmark_added_outlined,
    route: '/promises',
  ),
  'today': HomeShortcutItem(
    id: 'today',
    label: 'Today',
    icon: Icons.calendar_today_rounded,
    route: '/today',
  ),
  'thought-wall': HomeShortcutItem(
    id: 'thought-wall',
    label: 'Mind Space',
    icon: Icons.lightbulb_outline_rounded,
    route: '/thought-wall',
  ),
  'mind': HomeShortcutItem(
    id: 'thought-wall',
    label: 'Mind Space',
    icon: Icons.lightbulb_outline_rounded,
    route: '/thought-wall',
  ),
  'learning': HomeShortcutItem(
    id: 'learning',
    label: 'Learning',
    icon: Icons.school_outlined,
    route: '/learning',
  ),
  'reminders': HomeShortcutItem(
    id: 'reminders',
    label: 'Reminders',
    icon: Icons.notifications_none_rounded,
    route: '/reminders',
  ),
  'money': HomeShortcutItem(
    id: 'money',
    label: 'Money',
    icon: Icons.account_balance_wallet_outlined,
    route: '/money',
  ),
  'focus': HomeShortcutItem(
    id: 'focus',
    label: 'Focus',
    icon: Icons.timer_outlined,
    route: '/focus',
  ),
  'medicine': HomeShortcutItem(
    id: 'medicine',
    label: 'Medicine',
    icon: Icons.medication_outlined,
    route: '/medicine',
  ),
  'hydration': HomeShortcutItem(
    id: 'hydration',
    label: 'Water',
    icon: Icons.water_drop_outlined,
    route: '/hydration',
  ),
  'health': HomeShortcutItem(
    id: 'hydration',
    label: 'Water',
    icon: Icons.water_drop_outlined,
    route: '/hydration',
  ),
  'walk': HomeShortcutItem(
    id: 'walk',
    label: 'Walk',
    icon: Icons.directions_walk_rounded,
    route: '/walk',
  ),
  'chai-break': HomeShortcutItem(
    id: 'chai-break',
    label: 'Breaks',
    icon: Icons.coffee_outlined,
    route: '/chai-break',
  ),
  'momentum': HomeShortcutItem(
    id: 'momentum',
    label: 'Challenges',
    icon: Icons.flag_outlined,
    route: '/momentum',
  ),
  'challenge': HomeShortcutItem(
    id: 'momentum',
    label: 'Challenges',
    icon: Icons.flag_outlined,
    route: '/momentum',
  ),
  'vault': HomeShortcutItem(
    id: 'vault',
    label: 'Vault',
    icon: Icons.shield_outlined,
    route: '/vault',
  ),
};

/// Dynamic top shortcut bar on Home (up to four user-customized shortcuts)
/// featuring live glanceable count badges for tasks, thoughts, and reminders.
class HomeShortcutPanel extends ConsumerWidget {
  const HomeShortcutPanel({
    super.key,
    this.shortcuts,
    this.shortcutItems,
    this.badgeCounts,
    this.activeShortcutId,
    this.onSelectShortcut,
  });

  /// The list of shortcut IDs configured by user (e.g. from HomeLayout.shortcuts).
  final List<String>? shortcuts;

  /// Optional direct items override (e.g. for testing).
  final List<HomeShortcutItem>? shortcutItems;

  /// Optional manual badge count override map for testing or explicit mocking.
  final Map<String, int>? badgeCounts;

  /// Currently selected shortcut ID (if any) filtering the Home feed below.
  final String? activeShortcutId;

  /// Callback when a shortcut is tapped to filter Home or toggle back to home.
  final ValueChanged<String?>? onSelectShortcut;

  List<HomeShortcutItem> _resolveItems() {
    if (shortcutItems != null) {
      return shortcutItems!.take(4).toList();
    }
    final raw = shortcuts ?? const ['thought-wall', 'hydration', 'momentum', 'vault'];
    final items = <HomeShortcutItem>[];
    for (final id in raw) {
      final item = kRegisteredShortcuts[id];
      if (item != null && !items.any((e) => e.route == item.route)) {
        items.add(item);
      }
      if (items.length >= 4) break;
    }
    return items;
  }

  int _resolveBadgeCount(WidgetRef ref, String id) {
    if (badgeCounts != null && badgeCounts!.containsKey(id)) {
      return badgeCounts![id] ?? 0;
    }
    switch (id) {
      case 'today':
        return ref
                .watch(todayActivitiesProvider)
                .value
                ?.where((a) => a.status != TodayActivityStatus.done && a.completedAt == null)
                .length ??
            0;
      case 'thought-wall':
      case 'mind':
        return ref.watch(todayThoughtsCountStreamProvider).value ?? 0;
      case 'reminders':
        return ref.watch(allRemindersProvider).value?.where((r) => r.isActive).length ?? 0;
      case 'promises':
        return ref.watch(activePromisesStreamProvider).value?.length ?? 0;
      case 'hydration':
      case 'health':
        final ml = ref.watch(todayWaterMlStreamProvider).value ?? 0;
        return ml > 0 ? (ml ~/ 250) : 0;
      case 'medicine':
        return ref.watch(todayMedicineLogsStreamProvider).value?.length ?? 0;
      default:
        return 0;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final items = _resolveItems();

    if (items.isEmpty) {
      return const SizedBox.shrink();
    }

    return GlassSurface(
      key: const ValueKey('home_shortcut_panel'),
      radius: 24,
      enableBlur: false,
      padding: const EdgeInsets.symmetric(
        horizontal: AscentDimensions.spaceSm,
        vertical: AscentDimensions.spaceMd,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: items.map((item) {
          final count = _resolveBadgeCount(ref, item.id);
          final isSelected = activeShortcutId == item.id;
          return Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: ValueKey('shortcut_${item.id}'),
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  HapticFeedback.lightImpact();
                  if (onSelectShortcut != null) {
                    onSelectShortcut!(isSelected ? null : item.id);
                  } else {
                    context.push(item.route);
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: isSelected
                      ? BoxDecoration(
                          color: g.clay.withValues(alpha: isDark ? 0.22 : 0.12),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: g.clay.withValues(alpha: 0.5),
                            width: 1.0,
                          ),
                        )
                      : null,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Stack(
                        clipBehavior: Clip.none,
                        alignment: Alignment.center,
                        children: [
                          Icon(
                            item.icon,
                            size: 22,
                            color: isSelected ? g.clay : g.ink,
                          ),
                          if (count > 0)
                            Positioned(
                              top: -7,
                              right: -12,
                              child: Container(
                                key: ValueKey('shortcut_badge_${item.id}'),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 5,
                                  vertical: 1.5,
                                ),
                                constraints: const BoxConstraints(minWidth: 16),
                                decoration: BoxDecoration(
                                  color: g.clay.withValues(
                                    alpha: isDark ? 0.35 : 0.22,
                                  ),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: g.line,
                                    width: 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      count > 99 ? '99+' : '$count',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w700,
                                        color: g.ink,
                                        height: 1.1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        item.label,
                        style: TextStyle(
                          color: g.inkSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
