import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

enum StatusType { ok, warn, alert, neutral }

class StatusPill extends StatelessWidget {
  const StatusPill({
    super.key,
    required this.label,
    this.icon,
    this.type = StatusType.ok,
  });

  final String label;
  final IconData? icon;
  final StatusType type;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final Color bg;
    final Color fg;

    switch (type) {
      case StatusType.ok:
        bg = c.okTint;
        fg = c.ok;
        break;
      case StatusType.warn:
        bg = c.warnTint;
        fg = c.warn;
        break;
      case StatusType.alert:
        bg = c.alertTint;
        fg = c.alert;
        break;
      case StatusType.neutral:
        bg = c.surfaceAlt;
        fg = c.textSecondary;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(Rd.chip),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
