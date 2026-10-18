import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/frozen_palette.dart';

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
    final isFrozen = context.isFrozen;
    final isDark = context.isDark;
    final bg = isFrozen
        ? (isDark
            ? FrozenPalette.darkSurface.withValues(alpha: 0.96)
            : FrozenPalette.surface.withValues(alpha: 0.96))
        : context.bgSurface;
    final divider = isFrozen
        ? (isDark ? FrozenPalette.darkLine : FrozenPalette.line)
        : context.divider;
    final inactiveColor = isFrozen
        ? (isDark ? FrozenPalette.darkMutedInk : FrozenPalette.mutedInk)
        : context.textMuted;
    final activeColor = isFrozen
        ? (isDark ? FrozenPalette.darkAction : FrozenPalette.action)
        : context.glass.clay;
    final activeCapsuleBg = isFrozen
        ? (isDark ? FrozenPalette.darkTint : FrozenPalette.tint)
        : context.glass.claySoft;

    return Container(
      decoration: BoxDecoration(
        color: bg,
        border: Border(
          top: BorderSide(
            color: divider,
            width: isFrozen ? 1.0 : AppBorderScale.w0point8,
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
                  color: AppPalette.transparent,
                  child: AppTapArea(
                    onTap: () => onTap(index),
                    splashColor: context.divider.withValues(alpha: 0.2),
                    highlightColor: AppPalette.transparent,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOut,
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.s14,
                              vertical: AppSpace.s3,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? activeCapsuleBg
                                  : AppPalette.transparent,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Icon(
                              isActive ? tab.activeIcon : tab.icon,
                              color: isActive ? activeColor : inactiveColor,
                              size: 19,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            tab.label,
                            style:
                                AppStateTypography.stateType26(
                                  state0: isActive,
                                ).copyWith(
                                  color: isActive
                                      ? (isFrozen
                                            ? activeColor
                                            : context.glass.ink)
                                      : inactiveColor,
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
