import 'dart:async';

import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';

import '../../../app/theme/color_tokens.dart';

/// A short-lived greeting for returning users.
///
/// It is meant to be placed in a [Stack] above the scrolling home content so it
/// never pushes the Things hub down. It slides in, stays for [visibleFor], then
/// slides out and calls [onDismissed]. Tapping it dismisses it early.
class WelcomeBackBanner extends StatefulWidget {
  const WelcomeBackBanner({
    super.key,
    required this.days,
    required this.onDismissed,
    this.visibleFor = const Duration(seconds: 4),
  });

  final int days;
  final VoidCallback onDismissed;
  final Duration visibleFor;

  @override
  State<WelcomeBackBanner> createState() => _WelcomeBackBannerState();
}

class _WelcomeBackBannerState extends State<WelcomeBackBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  Timer? _timer;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 260),
    )..forward();
    _timer = Timer(widget.visibleFor, _dismiss);
  }

  Future<void> _dismiss() async {
    if (_closing || !mounted) return;
    _closing = true;
    _timer?.cancel();
    await _controller.reverse();
    if (mounted) widget.onDismissed();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
      reverseCurve: Curves.easeInCubic,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.6),
          end: Offset.zero,
        ).animate(curved),
        child: AppCard(
          onTap: _dismiss,
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s14,
            vertical: AppSpace.s10,
          ),
          // Opaque on purpose: this floats over the header for a few seconds.
          nightDecoration: BoxDecoration(
            color: Color.alphaBlend(
              context.accentSecondary.withValues(alpha: 0.12),
              Theme.of(context).colorScheme.surface,
            ),
            borderRadius: AppGeometry.roundedr12,
            border: Border.all(
              color: context.accentSecondary.withValues(alpha: 0.25),
              width: AppBorderScale.w0point8,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.wb_sunny_outlined,
                color: context.accentSecondary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  widget.days == 1
                      ? 'Welcome back! You were away 1 day.'
                      : 'Welcome back! You were away ${widget.days} days.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.labelSmall
                      .copyWith(color: context.textPrimary)
                      .merge(AppTypeRoles.typeRole2),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
