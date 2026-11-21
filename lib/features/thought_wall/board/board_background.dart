import 'package:flutter/material.dart';

import '../../../app/theme/glass_theme.dart';

/// Mindspace sits on the same plain app canvas as every other screen
/// (CLAUDE.md §3.1): no decorative gradients, textures or tinted backdrops.
class BoardBackground extends StatelessWidget {
  const BoardBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      ColoredBox(color: context.glass.bg, child: child);
}
