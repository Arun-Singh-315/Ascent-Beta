import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';
import '../../app/theme/shared_control_tokens.dart';
import 'ascent_button.dart';
import '../../app/theme/home_design.dart';

import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/monochrome_surfaces.dart';
import '../../features/home/widgets/home_theme.dart';
import '../../core/providers/calendar_view_mode_provider.dart';

import 'package:flutter/services.dart';

import '../../features/ai_assistant/ai_assistant_screen.dart';
import '../../core/providers/settings_provider.dart';
import 'ascent_drawer.dart';

/// The persistent shell wrapping the bottom navigation bar.
/// Each tab maintains its own independent navigation stack via
/// [StatefulShellRoute.indexedStack].
class MainScaffold extends ConsumerStatefulWidget {
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
      icon: Icons.lock_outline_rounded,
      activeIcon: Icons.lock_rounded,
      label: 'Vault',
    ),
    _TabItem(
      icon: Icons.grid_view_outlined,
      activeIcon: Icons.widgets_rounded,
      label: 'More',
    ),
  ];

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime? _lastBackPressTime;

  @override
  Widget build(BuildContext context) {
    final assistantName = ref.watch(assistantNameProvider);
    final assistantLabel = 'Ask $assistantName';
    final neutralShell =
        widget.shell.currentIndex == 0 ||
        (widget.shell.currentIndex == 1 && ref.watch(calendarViewModeProvider));
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
        backgroundColor: neutralShell ? HomeDesign.of(context).canvas : null,
        extendBody: true,
        // Scaffold's extended-body MediaQuery and each screen's SafeArea
        // already reserve the full navigation height, including the large-text grid.
        body: widget.shell,
        floatingActionButton:
            MediaQuery.viewInsetsOf(context).bottom > 0 ||
                widget.shell.currentIndex == 0
            ? null
            : AscentButton.primary(
                key: const ValueKey('global_ask_assistant'),
                label: assistantLabel,
                icon: Icons.auto_awesome_rounded,
                compact: true,
                expanded: false,
                onPressed: () => AiAssistantScreen.showFromHome(context),
              ),
        floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
        bottomNavigationBar: AnimatedTheme(
          duration: Duration(
            milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 320,
          ),
          curve: Curves.easeInOutCubic,
          data: HomeTheme.from(Theme.of(context)),
          child: _AscentBottomNav(
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
    final neutral = Theme.of(context).extension<MonochromeSurfaces>();
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final bottomInset = MediaQuery.paddingOf(context).bottom;

    final dark = Theme.of(context).brightness == Brightness.dark;
    final blue = dark
        ? SharedControlColors.actionBlueDark
        : SharedControlColors.actionBlue;
    final activeTileColor = blue.withValues(alpha: dark ? .18 : .09);

    final c = context.c;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 0, 16, 12 + bottomInset),
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: c.surface,
          borderRadius: BorderRadius.circular(Rd.nav),
          border: Border.all(color: c.border),
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            Widget tabAt(int index) {
              final tab = tabs[index];
              final active = index == currentIndex;
              final fg = active ? blue : c.textSecondary;
              return Semantics(
                button: true,
                selected: active,
                label: tab.label,
                child: InkWell(
                  onTap: () => onTap(index),
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: Duration(
                      milliseconds: disableAnimations ? 0 : 200,
                    ),
                    curve: Curves.easeOutCubic,
                    constraints: const BoxConstraints(minHeight: 56),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: active ? activeTileColor : Colors.transparent,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(tab.activeIcon, size: 22, color: fg),
                        const SizedBox(height: 3),
                        Text(
                          tab.label,
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            color: fg,
                            fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }

            final scale = MediaQuery.textScalerOf(context).scale(1);
            final columns = neutral != null && scale >= 1.45
                ? (scale > 2.2 ? 1 : 2)
                : tabs.length;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var start = 0; start < tabs.length; start += columns)
                  Row(
                    children: [
                      for (
                        var index = start;
                        index < start + columns && index < tabs.length;
                        index++
                      )
                        Expanded(child: tabAt(index)),
                    ],
                  ),
              ],
            );
          },
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
