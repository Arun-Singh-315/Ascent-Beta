import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/color_tokens.dart';

import 'ascent_drawer.dart';
import 'live_session_bar.dart';

/// The persistent shell wrapping the bottom navigation bar.
/// Each tab maintains its own independent navigation stack via
/// [StatefulShellRoute.indexedStack].
class MainScaffold extends StatelessWidget {
  final StatefulNavigationShell shell;

  const MainScaffold({super.key, required this.shell});

  static const _tabs = [
    _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    _TabItem(icon: Icons.today_outlined, activeIcon: Icons.today_rounded, label: 'Today'),
    _TabItem(icon: Icons.view_kanban_outlined, activeIcon: Icons.view_kanban_rounded, label: 'Pipeline'),
    _TabItem(icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart_rounded, label: 'Analytics'),
    _TabItem(icon: Icons.more_horiz_outlined, activeIcon: Icons.more_horiz_rounded, label: 'More'),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AscentDrawer(),
      body: shell,
      bottomNavigationBar: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const LiveSessionBar(),
          _AscentBottomNav(
            currentIndex: shell.currentIndex,
            onTap: (index) => shell.goBranch(
              index,
              // Allow double-tapping a tab to return to its initial route
              initialLocation: index == shell.currentIndex,
            ),
            tabs: _tabs,
          ),
        ],
      ),
    );
  }
}

class _AscentBottomNav extends StatelessWidget {
  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_TabItem> tabs;

  const _AscentBottomNav({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(

        color: context.bgBase,
        border: Border(
          top: BorderSide(
            color: context.divider,
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            children: List.generate(tabs.length, (index) {
              final tab = tabs[index];
              final isActive = index == currentIndex;
              return Expanded(
                child: InkWell(
                  onTap: () => onTap(index),
                  splashColor: context.accentPrimary.withValues(alpha: 0.1),
                  highlightColor: Colors.transparent,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 200),
                        child: Icon(
                          isActive ? tab.activeIcon : tab.icon,
                          key: ValueKey(isActive),
                          color: isActive ? context.accentPrimary : context.textMuted,
                          size: 24,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        tab.label,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: isActive ? FontWeight.w600 : FontWeight.w400,
                          color: isActive ? context.accentPrimary : context.textMuted,
                          height: 1.2,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _TabItem {
  final IconData icon;
  final IconData activeIcon;
  final String label;

  const _TabItem({
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
