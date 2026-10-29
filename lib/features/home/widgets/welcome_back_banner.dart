import 'dart:async';

import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
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
    this.visibleFor = const Duration(seconds: 3),
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
    try {
      await _controller.reverse().orCancel;
    } catch (_) {}
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
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor = isDark
        ? Color.alphaBlend(
            context.accentSecondary.withValues(alpha: 0.16),
            context.bgSurfaceElevated,
          )
        : context.bgSurfaceElevated;
    final borderColor = isDark
        ? context.accentSecondary.withValues(alpha: 0.35)
        : context.accentSecondary.withValues(alpha: 0.25);

    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, -0.6),
          end: Offset.zero,
        ).animate(curved),
        child: Material(
          color: Colors.transparent,
          child: Container(
            decoration: BoxDecoration(
              color: surfaceColor,
              borderRadius: AppGeometry.roundedr16,
              border: Border.all(
                color: borderColor,
                width: AppBorderScale.w1point0,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.4)
                      : Colors.black.withValues(alpha: 0.1),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: InkWell(
              onTap: _dismiss,
              borderRadius: AppGeometry.roundedr16,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s14,
                  vertical: AppSpace.s10,
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(AppSpace.s6),
                      decoration: BoxDecoration(
                        color: context.accentSecondary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.wb_sunny_rounded,
                        color: context.accentSecondary,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: AppSpace.s10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.days == 1
                                ? 'Welcome back! You were away 1 day.'
                                : 'Welcome back! You were away ${widget.days} days.',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AscentTextStyles.labelSmall
                                .copyWith(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w600,
                                )
                                .merge(AppTypeRoles.typeRole2),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Consistency starts with one focused block. Let\'s build momentum today!',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: AscentTextStyles.bodySmall
                                .copyWith(
                                  color: context.textMuted,
                                  fontSize: 11,
                                )
                                .merge(AppTypeRoles.typeRole4),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    IconButton(
                      icon: Icon(
                        Icons.close_rounded,
                        size: 16,
                        color: context.textMuted,
                      ),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(
                        minWidth: 28,
                        minHeight: 28,
                      ),
                      tooltip: 'Dismiss',
                      onPressed: _dismiss,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
