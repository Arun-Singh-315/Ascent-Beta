import 'package:flutter/material.dart';
import '../../../app/theme/home_design.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../app/theme/text_styles.dart';
import 'home_outline_surface.dart';

/// A compact entry for a module with no active content yet.
class HomeModuleRow extends StatelessWidget {
  const HomeModuleRow({
    super.key,
    required this.title,
    required this.icon,
    required this.onTap,
    this.subtitle,
    this.actionIcon = Icons.arrow_forward_rounded,
  });
  final String title;
  final String? subtitle;
  final IconData icon, actionIcon;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final colors = HomeDesign.of(context);
    final blue = Theme.of(context).brightness == Brightness.dark
        ? SharedControlColors.actionBlueDark
        : SharedControlColors.actionBlue;
    return Semantics(
      button: true,
      child: Container(
        decoration: HomeModuleGroupScope.maybeOf(context)
            ? null
            : HomeSurfaceStyle.decoration(context),
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: HomeDesign.of(context).learningTint,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      icon,
                      color: HomeDesign.of(context).learningInk,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: AscentTextStyles.interfaceTitle.copyWith(
                            color: colors.primaryText,
                            fontWeight: FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        if (subtitle != null) ...[
                          const SizedBox(height: 5),
                          Text(
                            subtitle!,
                            style: HomeType.supporting.copyWith(
                              color: colors.secondaryText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(actionIcon, size: 22, color: blue),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class HomeModuleGroupScope extends InheritedWidget {
  const HomeModuleGroupScope({super.key, required super.child});
  static bool maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<HomeModuleGroupScope>() !=
      null;
  @override
  bool updateShouldNotify(HomeModuleGroupScope oldWidget) => false;
}

class HomeModuleGroup extends StatelessWidget {
  const HomeModuleGroup({super.key, required this.children});
  final List<Widget> children;
  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('home_growth_commitments_group'),
    decoration: BoxDecoration(
      color: HomeDesign.of(context).surface.withValues(alpha: .65),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(
        color: HomeDesign.of(context).separator.withValues(alpha: .6),
      ),
    ),
    padding: const EdgeInsets.symmetric(horizontal: 16),
    clipBehavior: Clip.antiAlias,
    child: HomeModuleGroupScope(
      child: Column(
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Divider(
                  height: 1,
                  color: HomeDesign.of(context).separator,
                ),
              ),
            children[i],
          ],
        ],
      ),
    ),
  );
}
