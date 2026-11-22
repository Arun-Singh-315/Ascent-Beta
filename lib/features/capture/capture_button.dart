import 'package:flutter/material.dart';

import '../../shared/widgets/ascent_button.dart';
import 'capture_sheet.dart';

/// The global capture entry (CLAUDE.md §1.5, §4).
///
/// Home shows it as the floating + ([CaptureButton.fab]). Things and Mind,
/// which already have their own composers at the bottom and top, show it in
/// the nav bar ([CaptureButton.nav]) so nothing overlaps.
class CaptureButton extends StatelessWidget {
  const CaptureButton.fab({super.key}) : _fab = true;
  const CaptureButton.nav({super.key}) : _fab = false;
  final bool _fab;

  static const label = 'Capture anything';

  @override
  Widget build(BuildContext context) => _fab
      ? AscentButton.fab(
          key: const ValueKey('capture_fab'),
          icon: Icons.add_rounded,
          tooltip: label,
          semanticLabel: label,
          onPressed: () => showCaptureSheet(context),
        )
      : AscentButton.icon(
          key: const ValueKey('capture_nav'),
          icon: Icons.bolt_rounded,
          tooltip: label,
          semanticLabel: label,
          onPressed: () => showCaptureSheet(context),
        );
}
