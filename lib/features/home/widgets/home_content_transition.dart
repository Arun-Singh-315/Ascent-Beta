import 'package:flutter/material.dart';

/// Lets content settle when saved data adds/removes a row or changes its state.
class HomeContentTransition extends StatelessWidget {
  const HomeContentTransition({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => AnimatedSize(
    duration: Duration(
      milliseconds: MediaQuery.disableAnimationsOf(context) ? 0 : 240,
    ),
    curve: Curves.easeInOutCubic,
    alignment: Alignment.topCenter,
    child: child,
  );
}
