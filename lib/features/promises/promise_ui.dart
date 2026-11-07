import 'package:flutter/material.dart';
import '../../shared/widgets/ascent_button.dart';

/// Explicit active/disabled contrast, independent of decorative theme buttons.
class PromiseActionButton extends StatelessWidget {
  const PromiseActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.icon,
  });
  final String label;
  final VoidCallback? onPressed;
  final IconData? icon;
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: AscentButton.tonal(
        label: label,
        icon: icon,
        compact: true,
        onPressed: onPressed,
      ),
    );
  }
}
