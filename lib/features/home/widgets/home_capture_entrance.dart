import 'package:flutter/material.dart';

class HomeCaptureEntrance extends StatefulWidget {
  const HomeCaptureEntrance({
    super.key,
    required this.animate,
    required this.child,
  });

  final bool animate;
  final Widget child;

  @override
  State<HomeCaptureEntrance> createState() => HomeCaptureEntranceState();
}

class HomeCaptureEntranceState extends State<HomeCaptureEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: widget.animate ? 0 : 1,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final fade = Curves.easeOutCubic.transform(_controller.value);
      final settle = Curves.easeOutBack.transform(_controller.value);
      return Opacity(
        opacity: fade.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -28 * (1 - settle)),
          child: Transform.scale(
            scale: 0.94 + 0.06 * settle,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      );
    },
  );
}
