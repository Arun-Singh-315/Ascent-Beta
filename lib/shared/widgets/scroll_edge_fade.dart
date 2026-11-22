import 'package:flutter/material.dart';

/// Softens where a scrolling list meets a bar below it (an input, a dock):
/// the last [extent] pixels fade out, so a card passing under the edge
/// dissolves instead of looking sliced off with a hard, square cut.
class ScrollEdgeFade extends StatelessWidget {
  const ScrollEdgeFade({super.key, required this.child, this.extent = 28});
  final Widget child;
  final double extent;

  @override
  Widget build(BuildContext context) => ShaderMask(
    blendMode: BlendMode.dstIn,
    shaderCallback: (rect) {
      final stop = rect.height <= 0
          ? 1.0
          : (1 - extent / rect.height).clamp(0.0, 1.0);
      return LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: const [
          Color(0xFF000000),
          Color(0xFF000000),
          Color(0x00000000),
        ],
        stops: [0, stop, 1],
      ).createShader(rect);
    },
    child: child,
  );
}
