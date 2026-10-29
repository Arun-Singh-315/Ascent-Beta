import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/glass_theme.dart';

/// Compact, bordered actions and status labels with the same glass treatment.
class GlassChip extends StatelessWidget {
  const GlassChip({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.selected = false,
    this.success = false,
    this.tooltip,
  });
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool selected, success;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = success ? context.doneInk : context.glass.ink;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
      side: BorderSide(
        color: ink.withValues(
          alpha: selected || success
              ? .5
              : dark
              ? .28
              : .22,
        ),
      ),
    );
    Widget child = Material(
      color: success
          ? ink.withValues(alpha: dark ? .10 : .07)
          : selected
          ? ink.withValues(alpha: .12)
          : context.glass.fill.withValues(alpha: dark ? .22 : .5),
      shape: shape,
      child: InkWell(
        customBorder: shape,
        onTap: onTap != null
            ? () {
                HapticFeedback.selectionClick();
                onTap!();
              }
            : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: ink),
                const SizedBox(width: 5),
              ],
              Flexible(
                child: Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (tooltip != null) child = Tooltip(message: tooltip!, child: child);
    return Semantics(button: onTap != null, selected: selected, child: child);
  }
}
