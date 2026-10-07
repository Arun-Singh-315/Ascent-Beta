import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/color_tokens.dart';

import 'package:flutter/services.dart';

import 'ascent_drawer.dart';
import 'live_session_bar.dart';

/// The persistent shell wrapping the bottom navigation bar.
/// Each tab maintains its own independent navigation stack via
/// [StatefulShellRoute.indexedStack].
class MainScaffold extends StatefulWidget {
  final StatefulNavigationShell shell;

  const MainScaffold({super.key, required this.shell});

  static const _tabs = [
    _TabItem(icon: Icons.home_outlined, activeIcon: Icons.home_rounded, label: 'Home'),
    _TabItem(icon: Icons.checklist_outlined, activeIcon: Icons.checklist_rounded, label: 'Study'),
    _TabItem(icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet_rounded, label: 'Money'),
    _TabItem(icon: Icons.directions_walk_outlined, activeIcon: Icons.directions_walk_rounded, label: 'Walk'),
    _TabItem(icon: Icons.grid_view_outlined, activeIcon: Icons.grid_view_rounded, label: 'More'),
  ];

  @override
  State<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends State<MainScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;

        // 1. If drawer is open, close it cleanly first
        if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
          _scaffoldKey.currentState?.closeDrawer();
          return;
        }

        // 2. If user is on a secondary tab, navigate back to Home (Tab 0)
        if (widget.shell.currentIndex != 0) {
          HapticFeedback.selectionClick();
          widget.shell.goBranch(0);
          return;
        }

        // 3. User is on Home tab: double back within 2 seconds to exit app
        final now = DateTime.now();
        if (_lastBackPressTime == null ||
            now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
          _lastBackPressTime = now;
          HapticFeedback.lightImpact();

          final messenger = ScaffoldMessenger.of(context);
          messenger.removeCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              content: const Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.touch_app_rounded, size: 16, color: Colors.white70),
                  SizedBox(width: 8),
                  Text(
                    'Press back again to exit',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF1E222D).withValues(alpha: 0.95),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(
                  color: Colors.white.withValues(alpha: 0.12),
                  width: 0.8,
                ),
              ),
              margin: const EdgeInsets.only(bottom: 74, left: 60, right: 60),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
          );
          return;
        }

        // Second press confirmed within 2 seconds -> exit app
        SystemNavigator.pop();
      },
      child: Scaffold(
        key: _scaffoldKey,
        drawer: const AscentDrawer(),
        body: widget.shell,
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LiveSessionBar(),
            _AscentBottomNav(
              currentIndex: widget.shell.currentIndex,
              onTap: (index) {
                HapticFeedback.selectionClick();
                widget.shell.goBranch(
                  index,
                  initialLocation: index == widget.shell.currentIndex,
                );
              },
              tabs: MainScaffold._tabs,
            ),
          ],
        ),
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
    final bg = context.bgSurface;
    final divider = context.divider;
    final activeColor = context.accentPrimary;
    final inactiveColor = context.textMuted;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(
            color: divider,
            width: 0.8,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 56,
          child: Row(
            children: List.generate(tabs.length, (index) {
              final tab = tabs[index];
              final isActive = index == currentIndex;
              return Expanded(
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: () => onTap(index),
                    splashColor: activeColor.withValues(alpha: 0.08),
                    highlightColor: Colors.transparent,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 180),
                            curve: Curves.easeOutCubic,
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? activeColor.withValues(alpha: 0.12)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              isActive ? tab.activeIcon : tab.icon,
                              color: isActive ? activeColor : inactiveColor,
                              size: 20,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tab.label,
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                              color: isActive ? activeColor : inactiveColor,
                              height: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),
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
