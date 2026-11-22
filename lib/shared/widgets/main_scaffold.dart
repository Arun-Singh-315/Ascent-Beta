import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/home_design.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/providers/settings_provider.dart';
import 'ascent_snack_bar.dart';
import 'glass_chrome.dart';
import 'live_session_bar.dart';

/// The persistent shell around the five main tabs (CLAUDE.md §4):
/// Home · Things · Assistant (centre) · Mind · You.
///
/// Each tab keeps its own navigation stack via
/// [StatefulShellRoute.indexedStack]. Back from any non-Home tab returns to
/// Home; on Home a second back within two seconds exits the app.
class MainScaffold extends ConsumerStatefulWidget {
  final StatefulNavigationShell shell;

  const MainScaffold({super.key, required this.shell});

  /// Index of the centre Assistant tab.
  static const assistantIndex = 2;

  @override
  ConsumerState<MainScaffold> createState() => _MainScaffoldState();
}

class _MainScaffoldState extends ConsumerState<MainScaffold> {
  DateTime? _lastBackPressTime;

  void _handleBack() {
    if (widget.shell.currentIndex != 0) {
      HapticFeedback.selectionClick();
      widget.shell.goBranch(0);
      return;
    }
    final now = DateTime.now();
    if (_lastBackPressTime == null ||
        now.difference(_lastBackPressTime!) > const Duration(seconds: 2)) {
      _lastBackPressTime = now;
      ScaffoldMessenger.of(context).removeCurrentSnackBar();
      AscentSnackBar.show(
        context,
        message: 'Press back again to exit',
        duration: const Duration(seconds: 2),
      );
      return;
    }
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final assistantName = ref.watch(assistantNameProvider);
    final tabs = [
      const _TabItem(
        id: 'home',
        icon: Icons.home_outlined,
        activeIcon: Icons.home_rounded,
        label: 'Home',
      ),
      const _TabItem(
        id: 'things',
        icon: Icons.check_circle_outline_rounded,
        activeIcon: Icons.check_circle_rounded,
        label: 'Things',
      ),
      _TabItem(
        id: 'assistant',
        icon: Icons.auto_awesome_outlined,
        activeIcon: Icons.auto_awesome_rounded,
        label: assistantName,
      ),
      const _TabItem(
        id: 'mind',
        icon: Icons.lightbulb_outline_rounded,
        activeIcon: Icons.lightbulb_rounded,
        label: 'Mind',
      ),
      const _TabItem(
        id: 'you',
        icon: Icons.person_outline_rounded,
        activeIcon: Icons.person_rounded,
        label: 'You',
      ),
    ];
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _handleBack();
      },
      child: Scaffold(
        backgroundColor: HomeDesign.of(context).canvas,
        extendBody: true,
        body: widget.shell,
        // A running timer sits right above the tab bar on every tab, so it
        // never runs out of sight (CLAUDE.md §5.2).
        bottomNavigationBar: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LiveSessionBar(),
            _AscentTabBar(
              currentIndex: widget.shell.currentIndex,
              tabs: tabs,
              onTap: (index) {
                HapticFeedback.selectionClick();
                widget.shell.goBranch(
                  index,
                  initialLocation: index == widget.shell.currentIndex,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

/// The glass tab bar. Labels stay whole at large text sizes: icons and
/// labels shrink to fit rather than wrapping or overflowing.
class _AscentTabBar extends StatelessWidget {
  const _AscentTabBar({
    required this.currentIndex,
    required this.onTap,
    required this.tabs,
  });

  final int currentIndex;
  final ValueChanged<int> onTap;
  final List<_TabItem> tabs;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    return GlassChrome(
      key: const ValueKey('ascent_tab_bar'),
      rimTopOnly: true,
      padding: EdgeInsets.fromLTRB(
        AppSpace.s4,
        AppSpace.s4,
        AppSpace.s4,
        AppSpace.s4 + bottomInset,
      ),
      child: Row(
        children: [
          for (var i = 0; i < tabs.length; i++)
            Expanded(
              child: _TabButton(
                key: ValueKey('tab_${tabs[i].id}'),
                item: tabs[i],
                active: i == currentIndex,
                centre: i == MainScaffold.assistantIndex,
                onTap: () => onTap(i),
              ),
            ),
        ],
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    super.key,
    required this.item,
    required this.active,
    required this.centre,
    required this.onTap,
  });

  final _TabItem item;
  final bool active;
  final bool centre;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final fg = active ? g.actionInk : g.inkMuted;
    final icon = Icon(active ? item.activeIcon : item.icon, size: 24, color: fg);
    return Semantics(
      button: true,
      selected: active,
      label: item.label,
      excludeSemantics: true,
      child: InkResponse(
        onTap: onTap,
        containedInkWell: true,
        highlightShape: BoxShape.rectangle,
        borderRadius: AppGeometry.roundedr12,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s2,
                vertical: AppSpace.s4,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (centre)
                    // The assistant sits in the centre on a tinted tile.
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: g.actionInk.withValues(alpha: active ? .16 : .08),
                        borderRadius: AppGeometry.roundedr12,
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpace.s12,
                          vertical: AppSpace.s2,
                        ),
                        child: icon,
                      ),
                    )
                  else
                    icon,
                  const SizedBox(height: AppSpace.s2),
                  Text(
                    item.label,
                    maxLines: 1,
                    softWrap: false,
                    style: AscentTextStyles.tabLabel.copyWith(
                      color: fg,
                      fontWeight: active ? FontWeight.w600 : FontWeight.w500,
                    ),
                  ),
                ],
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
  final String id;

  const _TabItem({
    required this.id,
    required this.icon,
    required this.activeIcon,
    required this.label,
  });
}
