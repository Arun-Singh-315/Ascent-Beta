import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/app_navigation.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/shared_control_tokens.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_scaffold.dart';

/// One row in the You list.
class YouEntry {
  const YouEntry({
    required this.icon,
    required this.tint,
    required this.title,
    required this.route,
    this.subtitle,
  });

  final IconData icon;
  final Color tint;
  final String title;
  final String? subtitle;
  final String route;
}

/// A titled group of [YouEntry] rows.
class YouGroup {
  const YouGroup(this.title, this.entries);

  final String title;
  final List<YouEntry> entries;
}

/// Every destination the You tab offers. It keeps every entry point the old
/// More tab and side drawer had (CLAUDE.md §9).
const youGroups = [
  YouGroup('Daily Rhythm', [
    YouEntry(
      icon: Icons.water_drop_outlined,
      tint: PillarTints.water,
      title: 'Water',
      subtitle: 'Daily goal and quick logs',
      route: '/hydration',
    ),
    YouEntry(
      icon: Icons.medication_outlined,
      tint: PillarTints.live,
      title: 'Medicines',
      subtitle: 'Doses, care plans and reports',
      route: '/medicine',
    ),
    YouEntry(
      icon: Icons.account_balance_wallet_outlined,
      tint: PillarTints.money,
      title: 'Money',
      subtitle: 'Spending, bills and budgets',
      route: '/money',
    ),
    YouEntry(
      icon: Icons.timer_outlined,
      tint: PillarTints.plan,
      title: 'Focus',
      subtitle: 'Focus sessions',
      route: '/focus',
    ),
  ]),
  YouGroup('Plan', [
    YouEntry(
      icon: Icons.handshake_outlined,
      tint: PillarTints.promise,
      title: 'Promises',
      subtitle: 'Daily promises to yourself',
      route: '/promises',
    ),
    YouEntry(
      icon: Icons.notifications_none_rounded,
      tint: PillarTints.plan,
      title: 'Reminders',
      subtitle: 'Alerts and recurring prompts',
      route: '/reminders',
    ),
    YouEntry(
      icon: Icons.calendar_month_outlined,
      tint: PillarTints.plan,
      title: 'Calendar',
      route: '/calendar',
    ),
    YouEntry(
      icon: Icons.event_note_outlined,
      tint: PillarTints.plan,
      title: 'Plans',
      subtitle: 'Study and meal plans',
      route: '/plans',
    ),
  ]),
  YouGroup('Private', [
    YouEntry(
      icon: Icons.shield_outlined,
      tint: PillarTints.money,
      title: 'Vault',
      subtitle: 'Cards, IDs and secure notes',
      route: '/vault',
    ),
    YouEntry(
      icon: Icons.history_rounded,
      tint: PillarTints.neutral,
      title: 'History',
      subtitle: 'Search everything you did',
      route: '/history',
    ),
    YouEntry(
      icon: Icons.backup_outlined,
      tint: PillarTints.plan,
      title: 'Backup & restore',
      subtitle: 'Keep a copy of everything safe',
      route: '/backup',
    ),
    YouEntry(
      icon: Icons.settings_outlined,
      tint: PillarTints.neutral,
      title: 'Settings',
      subtitle: 'Theme, notifications and preferences',
      route: '/settings',
    ),
  ]),
];

/// The You tab: profile, Life and Grow modules, Vault, Analytics, History and
/// Settings as an inset grouped list (CLAUDE.md §4).
class YouScreen extends ConsumerWidget {
  const YouScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = ref.watch(userProfileStreamProvider).value?.name.trim() ?? '';
    final bottom = MediaQuery.paddingOf(context).bottom;
    return AscentScaffold(
      title: 'You',
      largeTitle: true,
      showBackButton: false,
      showFeatureHelp: false,
      backgroundColor: context.glass.bg,
      body: ListView(
        key: const ValueKey('you_list'),
        physics: const BouncingScrollPhysics(
          parent: AlwaysScrollableScrollPhysics(),
        ),
        padding: EdgeInsets.fromLTRB(
          AppSpace.s16,
          AppSpace.s8,
          AppSpace.s16,
          AppSpace.s24 + bottom,
        ),
        children: [
          _Group(
            children: [
              _Row(
                entry: YouEntry(
                  icon: Icons.person_outline_rounded,
                  tint: PillarTints.plan,
                  title: name.isEmpty ? 'Your profile' : _titleCase(name),
                  subtitle: 'Name, theme and preferences',
                  route: '/settings',
                ),
                leading: _Initial(name: name),
              ),
            ],
          ),
          for (final group in youGroups) ...[
            const SizedBox(height: AppSpace.s28),
            _GroupHeader(group.title),
            _Group(
              children: [for (final entry in group.entries) _Row(entry: entry)],
            ),
          ],
        ],
      ),
    );
  }
}

/// Icon tile edge (CLAUDE.md §3.3: 30 px tiles in grouped lists).
const _tileSize = 30.0;

String _titleCase(String value) => value
    .split(RegExp(r'\s+'))
    .where((w) => w.isNotEmpty)
    .map((w) => w[0].toUpperCase() + w.substring(1))
    .join(' ');

class _GroupHeader extends StatelessWidget {
  const _GroupHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.s16,
      AppSpace.s0,
      AppSpace.s16,
      AppSpace.s8,
    ),
    child: Semantics(
      header: true,
      child: Text(
        title,
        style: AscentTextStyles.caption.copyWith(color: context.glass.inkMuted),
      ),
    ),
  );
}

/// A rounded inset group with hairlines inset past the icon tile.
class _Group extends StatelessWidget {
  const _Group({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return ClipRRect(
      borderRadius: AppGeometry.roundedr12,
      child: ColoredBox(
        color: Theme.of(context).colorScheme.surface,
        child: Column(
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0)
                Padding(
                  padding: const EdgeInsets.only(
                    left: AppSpace.s16 + _tileSize + AppSpace.s12,
                  ),
                  child: Divider(height: 1, thickness: 1, color: g.line),
                ),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry, this.leading});

  final YouEntry entry;
  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final subtitle = entry.subtitle;
    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        key: ValueKey('you_row_${entry.route}'),
        onTap: () {
          HapticFeedback.selectionClick();
          context.open(entry.route);
        },
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpace.s16,
              vertical: AppSpace.s10,
            ),
            child: Row(
              children: [
                leading ?? _IconTile(icon: entry.icon, tint: entry.tint),
                const SizedBox(width: AppSpace.s12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        entry.title,
                        style: AscentTextStyles.listRowTitle.copyWith(
                          color: g.ink,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle,
                          style: AscentTextStyles.supportingText.copyWith(
                            color: g.inkMuted,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: AppSpace.s8),
                Icon(Icons.chevron_right_rounded, size: 20, color: g.inkMuted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IconTile extends StatelessWidget {
  const _IconTile({required this.icon, required this.tint});

  final IconData icon;
  final Color tint;

  @override
  Widget build(BuildContext context) => Container(
    width: _tileSize,
    height: _tileSize,
    decoration: BoxDecoration(
      color: tint.withValues(alpha: .14),
      borderRadius: AppGeometry.roundedr8,
    ),
    child: Icon(icon, size: 18, color: tint),
  );
}

class _Initial extends StatelessWidget {
  const _Initial({required this.name});

  final String name;

  @override
  Widget build(BuildContext context) => Container(
    width: _tileSize,
    height: _tileSize,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: PillarTints.plan.withValues(alpha: .14),
      shape: BoxShape.circle,
    ),
    child: name.isEmpty
        ? const Icon(
            Icons.person_outline_rounded,
            size: 18,
            color: PillarTints.plan,
          )
        : Text(
            name[0].toUpperCase(),
            style: AscentTextStyles.listRowTitle.copyWith(
              color: PillarTints.plan,
            ),
          ),
  );
}
