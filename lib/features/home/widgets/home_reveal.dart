import 'package:flutter/material.dart';

/// Soft first-appearance for Home modules: a short fade with a small lift.
/// Plays once when the module is first built and is skipped entirely when the
/// system asks for reduced motion.
class HomeReveal extends StatelessWidget {
  const HomeReveal({super.key, required this.child, this.delay = Duration.zero});
  final Widget child;
  final Duration delay;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320) + delay,
      curve: Interval(
        delay.inMilliseconds / (320 + delay.inMilliseconds),
        1,
        curve: Curves.easeOutCubic,
      ),
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 8 * (1 - t)), child: child),
      ),
      child: child,
    );
  }
}
