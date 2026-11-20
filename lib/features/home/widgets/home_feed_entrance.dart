import 'dart:async';

import 'package:flutter/material.dart';

/// Home sections fade and rise 8 px into place, 30 ms apart, first six only
/// (CLAUDE.md §3.5). It plays once per app session, so returning to the Home
/// tab never replays it; reduce-motion shows everything at once.
class HomeFeedEntrance extends StatefulWidget {
  const HomeFeedEntrance({super.key, required this.index, required this.child});

  /// Position in the feed; 6 and later appear without animation.
  final int index;
  final Widget child;

  static bool _played = false;

  /// For tests: let the next Home build play the entrance again.
  @visibleForTesting
  static void reset() => _played = false;

  @override
  State<HomeFeedEntrance> createState() => _HomeFeedEntranceState();
}

class _HomeFeedEntranceState extends State<HomeFeedEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 320),
  );
  Timer? _delay;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    final reduce = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (HomeFeedEntrance._played || widget.index >= 6 || reduce) {
      _c.value = 1;
      return;
    }
    _delay = Timer(Duration(milliseconds: 30 * widget.index), () {
      if (mounted) _c.forward();
    });
    // Mark as played once the first frame of the feed is scheduled.
    WidgetsBinding.instance.addPostFrameCallback(
      (_) => HomeFeedEntrance._played = true,
    );
  }

  @override
  void dispose() {
    _delay?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _c,
    child: widget.child,
    builder: (context, child) {
      final t = Curves.easeOutCubic.transform(_c.value);
      return Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      );
    },
  );
}
