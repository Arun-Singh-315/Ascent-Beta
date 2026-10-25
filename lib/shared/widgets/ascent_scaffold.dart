import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/glass_theme.dart';
import 'ascent_atmosphere.dart';
import 'feature_guide.dart';
import 'glass_surface.dart';

/// The unified Liquid Glass page scaffold for Ascent.
///
/// Wraps any screen in the signature Ascent atmospheric background
/// (deep obsidian base + dual ambient glows), with a translucent,
/// haptic-enabled glass header that seamlessly matches the Home screen.
class AscentScaffold extends StatelessWidget {
  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final VoidCallback? onBack;
  final Widget body;
  final Widget? floatingActionButton;
  final FloatingActionButtonLocation? floatingActionButtonLocation;
  final Widget? bottomNavigationBar;
  final Color? glow1;
  final Color? glow2;
  final PreferredSizeWidget? bottom;
  final bool showFeatureHelp;
  final bool safeAreaTop;
  final bool safeAreaBottom;

  const AscentScaffold({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.onBack,
    required this.body,
    this.floatingActionButton,
    this.floatingActionButtonLocation,
    this.bottomNavigationBar,
    this.glow1,
    this.glow2,
    this.bottom,
    this.showFeatureHelp = true,
    this.safeAreaTop = true,
    this.safeAreaBottom = true,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return Scaffold(
      backgroundColor: g.bg,
      extendBodyBehindAppBar: false,
      floatingActionButton: floatingActionButton,
      floatingActionButtonLocation: floatingActionButtonLocation,
      bottomNavigationBar: bottomNavigationBar,
      appBar:
          (title != null ||
              titleWidget != null ||
              leading != null ||
              (actions != null && actions!.isNotEmpty))
          ? AscentAppBar(
              title: title,
              titleWidget: titleWidget,
              subtitle: subtitle,
              leading: leading,
              actions: [
                ...?actions,
                if (title == 'Settings')
                  IconButton(
                    tooltip: 'Replay guided tour',
                    icon: const Icon(Icons.tour_outlined),
                    onPressed: () => showAscentTour(context),
                  ),
                if (showFeatureHelp && guideFor(title) != null)
                  IconButton(
                    tooltip: 'How this works',
                    icon: const Icon(Icons.help_outline_rounded),
                    onPressed: () => showFeatureGuide(context, title!),
                  ),
              ],
              showBackButton: showBackButton,
              onBack: onBack,
              bottom: bottom,
            )
          : null,
      body: SafeArea(
        top: safeAreaTop && (title == null && titleWidget == null),
        bottom: safeAreaBottom,
        child: AscentAtmosphereBackground(
          glow1: glow1,
          glow2: glow2,
          child: FeatureGuideHost(feature: title, child: body),
        ),
      ),
    );
  }
}

/// A liquid glass app bar that provides a frosted translucent look,
/// tactile back pill button, and unified typography.
class AscentAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final Widget? leading;
  final List<Widget>? actions;
  final bool showBackButton;
  final VoidCallback? onBack;
  final PreferredSizeWidget? bottom;

  const AscentAppBar({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    this.leading,
    this.actions,
    this.showBackButton = true,
    this.onBack,
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0.0));

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    Widget? leadingWidget = leading;
    if (leadingWidget == null && showBackButton) {
      leadingWidget = _LiquidBackButton(onPressed: onBack);
    }

    Widget? headerTitle = titleWidget;
    if (headerTitle == null && title != null) {
      headerTitle = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title!,
            style: AscentTextStyles.displaySmall
                .copyWith(color: g.ink, letterSpacing: -0.3)
                .merge(AppTypeRoles.typeRole69),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            const SizedBox(height: 1),
            Text(
              subtitle!,
              style: AppTypography.jetBrainsMono105W500120(color: g.inkMuted),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      );
    }

    return AppBar(
      backgroundColor: (Theme.of(context).brightness == Brightness.dark)
          ? g.bg.withValues(alpha: .85)
          : Colors.transparent,
      flexibleSpace: (Theme.of(context).brightness == Brightness.dark)
          ? null
          : const GlassSurface(
              radius: 0,
              padding: EdgeInsets.zero,
              child: SizedBox.expand(),
            ),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: leadingWidget,
      leadingWidth: 54,
      title: headerTitle,
      actions: [...?actions, const SizedBox(width: 8)],
      bottom: bottom,
      centerTitle: false,
    );
  }
}

class _LiquidBackButton extends StatelessWidget {
  final VoidCallback? onPressed;

  const _LiquidBackButton({this.onPressed});

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return Center(
      child: AppTag(
        width: 36,
        height: 36,
        nightDecoration: BoxDecoration(
          color: g.fill,
          shape: BoxShape.circle,
          border: Border.all(color: g.edge, width: AppBorderScale.w0point9),
        ),
        child: Material(
          color: AppPalette.transparent,
          child: AppTapArea(
            customBorder: const CircleBorder(),
            onTap: () {
              HapticFeedback.lightImpact();
              if (onPressed != null) {
                onPressed!();
              } else if (context.canPop()) {
                context.pop();
              } else {
                context.go('/home');
              }
            },
            child: Center(
              child: Icon(Icons.arrow_back_rounded, size: 18, color: g.ink),
            ),
          ),
        ),
      ),
    );
  }
}
