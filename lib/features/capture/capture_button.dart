import 'package:flutter/material.dart';

import '../../shared/widgets/ascent_button.dart';
import 'capture_sheet.dart';

/// The global capture entry (CLAUDE.md §1.5, §4).
///
/// A nav-bar button on Things and Mind, and in Home's compact header once
/// the Home capture card has scrolled away. Nothing floats over content.
class CaptureButton extends StatelessWidget {
  const CaptureButton.nav({super.key});

  static const label = 'Capture anything';

  @override
  Widget build(BuildContext context) => AscentButton.icon(
    key: const ValueKey('capture_nav'),
    icon: Icons.bolt_rounded,
    tooltip: label,
    semanticLabel: label,
    onPressed: () => showCaptureSheet(context),
  );
}
