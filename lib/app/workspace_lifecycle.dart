import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../core/providers/local_day_provider.dart';
import '../features/promises/providers/promise_providers.dart';

/// One app-wide clock and privacy boundary, independent of the current tab.
class WorkspaceLifecycle extends ConsumerStatefulWidget {
  const WorkspaceLifecycle({super.key, required this.child});
  final Widget child;
  @override
  ConsumerState<WorkspaceLifecycle> createState() => _WorkspaceLifecycleState();
}

class _WorkspaceLifecycleState extends ConsumerState<WorkspaceLifecycle>
    with WidgetsBindingObserver {
  Timer? _timer;
  bool _obscured = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _schedule();
  }

  void _schedule() {
    _timer?.cancel();
    final now = DateTime.now();
    final next = DateTime(
      now.year,
      now.month,
      now.day,
      now.hour,
      now.minute + 1,
    );
    _timer = Timer(next.difference(now), () {
      if (!mounted) return;
      ref.read(localClockProvider.notifier).refresh();
      _schedule();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      ref.read(localClockProvider.notifier).refresh();
      _schedule();
    } else {
      ref.read(unlockedPromiseIdsProvider.notifier).lockAll();
    }
    setState(() => _obscured = state != AppLifecycleState.resumed);
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Offstage(offstage: _obscured, child: widget.child),
      if (_obscured)
        ColoredBox(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: const Center(child: Icon(Icons.lock_outline_rounded)),
        ),
    ],
  );
}
