import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

/// Observes contact without competing with taps, long presses, or swipes.
class AscentPressFeedback extends StatefulWidget {
  const AscentPressFeedback({
    super.key,
    required this.child,
    this.enabled = true,
  });
  final Widget child;
  final bool enabled;
  @override
  State<AscentPressFeedback> createState() => _AscentPressFeedbackState();
}

class _AscentPressFeedbackState extends State<AscentPressFeedback> {
  int? _pointer;
  Offset? _origin;
  bool _pressed = false;
  void _release() {
    _pointer = null;
    _origin = null;
    if (_pressed) setState(() => _pressed = false);
  }

  @override
  void didUpdateWidget(AscentPressFeedback oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled) _release();
  }

  @override
  Widget build(BuildContext context) => Listener(
    behavior: HitTestBehavior.deferToChild,
    onPointerDown: (event) {
      if (!widget.enabled ||
          _pointer != null ||
          event.buttons != kPrimaryButton) {
        return;
      }
      _pointer = event.pointer;
      _origin = event.position;
      setState(() => _pressed = true);
    },
    onPointerMove: (event) {
      if (event.pointer == _pointer &&
          _origin != null &&
          (event.position - _origin!).distance > kTouchSlop) {
        _release();
      }
    },
    onPointerUp: (event) {
      if (event.pointer == _pointer) _release();
    },
    onPointerCancel: (event) {
      if (event.pointer == _pointer) _release();
    },
    child: AnimatedScale(
      scale: _pressed && !MediaQuery.disableAnimationsOf(context) ? .985 : 1,
      duration: Duration(
        milliseconds: MediaQuery.disableAnimationsOf(context)
            ? 0
            : (_pressed ? 100 : 160),
      ),
      curve: Curves.easeOutCubic,
      child: widget.child,
    ),
  );
}
