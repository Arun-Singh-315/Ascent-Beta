import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

class AppChip extends StatelessWidget {
  const AppChip({
    super.key,
    required this.label,
    this.icon,
    this.emoji,
    this.isSelected = false,
    this.onTap,
    this.height = 36.0,
    this.fontSize = 13.0,
    this.iconColor,
    this.textColor,
  });

  final String label;
  final IconData? icon;
  final String? emoji;
  final bool isSelected;
  final VoidCallback? onTap;
  final double height;
  final double fontSize;
  final Color? iconColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bg = isSelected ? c.primaryContainer : c.surfaceAlt;
    final borderColor = isSelected ? c.primary : c.border;
    final fg = textColor ?? (isSelected ? c.onPrimaryContainer : c.textPrimary);
    final iColor =
        iconColor ?? (isSelected ? c.onPrimaryContainer : c.textSecondary);

    return Material(
      color: bg,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(Rd.chip),
        side: BorderSide(color: borderColor),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(Rd.chip),
        splashColor: c.accent.withValues(alpha: 0.1),
        highlightColor: c.accent.withValues(alpha: 0.05),
        onTap: onTap,
        child: Container(
          height: height,
          padding: const EdgeInsets.symmetric(horizontal: 14),
          alignment: Alignment.center,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (emoji != null) ...[
                Text(emoji!, style: TextStyle(fontSize: fontSize + 1)),
                const SizedBox(width: 8),
              ] else if (icon != null) ...[
                Icon(icon, size: 16, color: iColor),
                const SizedBox(width: 8),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: fontSize,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: fg,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
