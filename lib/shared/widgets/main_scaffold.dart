import 'dart:ui';

import 'package:ascent/app/theme/dimension_tokens.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/glass_theme.dart';

import 'package:flutter/services.dart';

import 'ascent_drawer.dart';

/// The persistent shell wrapping the bottom navigation bar.
/// Each tab maintains its own independent navigation stack via
/// [StatefulShellRoute.indexedStack].
class MainScaffold extends StatefulWidget {
  final StatefulNavigationShell shell;

  const MainScaffold({super.key, required this.shell});

  static const _tabs = [
    _TabItem(
      icon: Icons.home_outlined,
      activeIcon: Icons.home_rounded,
      label: 'Home',
    ),
    _TabItem(
      icon: Icons.notifications_none_rounded,
      activeIcon: Icons.notifications_rounded,
      label: 'Reminders',
    ),
    _TabItem(
      icon: Icons.account_balance_wallet_outlined,
      activeIcon: Icons.account_balance_wallet_rounded,
      label: 'Money',
    ),
    _TabItem(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.grid_view_rounded,
      label: 'More',
    ),
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
              content: Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    size: 16,
                    color: AppPalette.white70,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Press back again to exit',
                    style: AppTypeRoles.typeRole76.copyWith(
                      color: AppPalette.white,
                    ),
                  ),
                ],
              ),
              duration: const Duration(seconds: 2),
              behavior: SnackBarBehavior.floating,
              backgroundColor:
                  (context.glass.frozen
                          ? context.glass.ink
                          : AppPalette.colorFF2D251E)
                      .withValues(alpha: 0.95),
              elevation: 4,
              shape: RoundedRectangleBorder(
                borderRadius: AppGeometry.roundedr20,
                side: BorderSide(
                  color: AppPalette.white.withValues(alpha: 0.12),
                  width: AppBorderScale.w0point8,
                ),
              ),
              margin: const EdgeInsets.only(
                bottom: AppSpace.s74,
                left: AppSpace.s60,
                right: AppSpace.s60,
              ),
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s16,
                vertical: AppSpace.s8,
              ),
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
        extendBody: true,
        body: widget.shell,
        bottomNavigationBar: _AscentBottomNav(
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
    final g = context.glass;
    final isDark = g.isDark;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final highContrast = MediaQuery.of(context).highContrast;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    // Glass fill & blur settings from C06 & C07
    final enableBlur = !highContrast && !disableAnimations;
    final navBg = enableBlur
        ? g.elevated.withValues(alpha: isDark ? 0.94 : 0.92)
        : g.elevated;

    final navShadow = BoxShadow(
      color: Color.fromRGBO(0, 0, 0, isDark ? 0.20 : 0.10),
      blurRadius: 16,
      offset: const Offset(0, 4),
      spreadRadius: 0,
    );

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 8 + bottomInset),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AscentDimensions.radiusXxl),
          boxShadow: [navShadow],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AscentDimensions.radiusXxl),
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: enableBlur ? 12 : 0,
              sigmaY: enableBlur ? 12 : 0,
            ),
            child: Container(
              constraints: const BoxConstraints(minHeight: 64),
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: navBg,
                borderRadius: BorderRadius.circular(AscentDimensions.radiusXxl),
                border: Border.all(
                  color: g.line,
                  width: AscentDimensions.contentOutlineWidth,
                ),
              ),
              child: Row(
                children: List.generate(tabs.length, (index) {
                  final tab = tabs[index];
                  final isActive = index == currentIndex;

                  final fg = isActive ? g.tonalFg : g.inkSecondary;
                  final capsuleBg = isActive ? g.tonalBg : Colors.transparent;

                  return Expanded(
                    child: InkWell(
                      onTap: () => onTap(index),
                      borderRadius: BorderRadius.circular(AscentDimensions.radiusXxl),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: capsuleBg,
                          borderRadius: BorderRadius.circular(
                            AscentDimensions.radiusXxl,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              isActive ? tab.activeIcon : tab.icon,
                              size: 22,
                              color: fg,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              tab.label,
                              style: AscentTextStyles.caption.copyWith(
                                color: fg,
                                fontWeight: isActive
                                    ? FontWeight.w600
                                    : FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),
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
