import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/glass_theme.dart';

/// One equal-size choice box. Use inside [AscentOptionRow] so every box in a
/// row has the same width and height, whatever its label or value.
class AscentOptionTile extends StatelessWidget {
  const AscentOptionTile({
    super.key,
    required this.icon,
    required this.label,
    this.value,
    this.selected = false,
    this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String label;

  /// Optional second line, such as "30 min" or "6:30 PM".
  final String? value;
  final bool selected;
  final VoidCallback? onTap;
  final bool enabled;

  static const double height = 68;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final fg = selected ? Colors.white : g.ink;
    final sub = selected ? Colors.white.withValues(alpha: 0.85) : g.inkMuted;
    return Semantics(
      button: true,
      selected: selected,
      enabled: enabled,
      label: value == null ? label : '$label, $value',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled && onTap != null
              ? () {
                  HapticFeedback.selectionClick();
                  onTap!();
                }
              : null,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            height: height,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: BoxDecoration(
              color: selected ? g.clay : g.fill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected ? g.clay : g.edge,
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, size: 20, color: selected ? Colors.white : g.clay),
                const SizedBox(height: 4),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: fg,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (value != null)
                  Text(
                    value!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: sub, fontSize: 11),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Lays tiles out in equal-width columns with even gaps.
class AscentOptionRow extends StatelessWidget {
  const AscentOptionRow({super.key, required this.children, this.gap = 8});

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      for (var i = 0; i < children.length; i++) ...[
        if (i > 0) SizedBox(width: gap),
        Expanded(child: children[i]),
      ],
    ],
  );
}
