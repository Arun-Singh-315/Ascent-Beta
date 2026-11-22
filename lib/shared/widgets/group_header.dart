import 'package:flutter/material.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';

/// The one header for a group inside a card ("Morning 4", "Medicine 3").
///
/// The colour lives in a small tinted icon tile, never in a stripe down the
/// side of the group: groups are separated by hairlines and whitespace.
class GroupHeader extends StatelessWidget {
  const GroupHeader({
    super.key,
    required this.icon,
    required this.tint,
    required this.title,
    this.count,
    this.trailing,
  });
  final IconData icon;
  final Color tint;
  final String title;
  final int? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      header: true,
      label: count == null ? title : '$title, $count',
      child: ExcludeSemantics(
        child: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: tint.withValues(alpha: g.isDark ? .18 : .12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 17, color: tint),
            ),
            const SizedBox(width: AppSpace.s12),
            Flexible(
              child: Text(
                title,
                style: AscentTextStyles.listRowTitle.copyWith(
                  color: g.ink,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (count != null) ...[
              const SizedBox(width: AppSpace.s8),
              Text(
                '$count',
                style: AscentTextStyles.tabular(
                  AscentTextStyles.caption,
                ).copyWith(color: g.inkMuted),
              ),
            ],
            if (trailing != null) ...[const Spacer(), trailing!],
          ],
        ),
      ),
    );
  }
}
