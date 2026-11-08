import 'package:flutter/material.dart';

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
  'assistant': HomeShortcutItem(
    id: 'assistant',
    label: 'Riya',
    icon: Icons.auto_awesome_rounded,
    route: '/ai-assistant',
  ),
  'promises': HomeShortcutItem(
    id: 'promises',
    label: 'Commitments',
    icon: Icons.bookmark_added_rounded,
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
    label: 'Mindspace',
    icon: Icons.lightbulb_rounded,
    route: '/thought-wall',
  ),
  'mind': HomeShortcutItem(
    id: 'thought-wall',
    label: 'Mindspace',
    icon: Icons.lightbulb_rounded,
    route: '/thought-wall',
  ),
  'learning': HomeShortcutItem(
    id: 'learning',
    label: 'Growth',
    icon: Icons.school_rounded,
    route: '/learning',
  ),
  'reminders': HomeShortcutItem(
    id: 'reminders',
    label: 'Reminders',
    icon: Icons.notifications_rounded,
    route: '/reminders',
  ),
  'money': HomeShortcutItem(
    id: 'money',
    label: 'Money',
    icon: Icons.account_balance_wallet_rounded,
    route: '/money',
  ),
  'focus': HomeShortcutItem(
    id: 'focus',
    label: 'Focus',
    icon: Icons.timer_rounded,
    route: '/focus',
  ),
  'medicine': HomeShortcutItem(
    id: 'medicine',
    label: 'Medicine',
    icon: Icons.medication_rounded,
    route: '/medicine',
  ),
  'hydration': HomeShortcutItem(
    id: 'hydration',
    label: 'Water',
    icon: Icons.water_drop_rounded,
    route: '/hydration',
  ),
  'health': HomeShortcutItem(
    id: 'hydration',
    label: 'Water',
    icon: Icons.water_drop_rounded,
    route: '/hydration',
  ),
  'walk': HomeShortcutItem(
    id: 'walk',
    label: 'Move',
    icon: Icons.directions_walk_rounded,
    route: '/walk',
  ),
  'chai-break': HomeShortcutItem(
    id: 'chai-break',
    label: 'Pause',
    icon: Icons.coffee_rounded,
    route: '/chai-break',
  ),
  'momentum': HomeShortcutItem(
    id: 'momentum',
    label: 'Momentum',
    icon: Icons.flag_rounded,
    route: '/momentum',
  ),
  'challenge': HomeShortcutItem(
    id: 'momentum',
    label: 'Momentum',
    icon: Icons.flag_rounded,
    route: '/momentum',
  ),
  'vault': HomeShortcutItem(
    id: 'vault',
    label: 'Vault',
    icon: Icons.shield_rounded,
    route: '/vault',
  ),
};
