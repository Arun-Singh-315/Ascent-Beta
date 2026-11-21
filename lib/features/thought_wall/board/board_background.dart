import 'package:flutter/material.dart';

import '../../../shared/widgets/ascent_backdrop.dart';

/// Mindspace sits on its own lilac backdrop with a faint doodle pattern,
/// like a chat wallpaper: calm, a little playful, never behind the text.
class BoardBackground extends StatelessWidget {
  const BoardBackground({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      AscentBackdrop(tone: BackdropTone.mind, child: child);
}
