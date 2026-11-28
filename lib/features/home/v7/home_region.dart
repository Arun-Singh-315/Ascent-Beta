import 'package:flutter/material.dart';

import '../../../app/theme/ascent_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/ascent_icon.dart';

/// A Home v7 section: a soft surface (barely-there fill, 1 pt edge, 24 pt
/// corners, no shadow) so the page reads as one calm sheet with clear
/// parts, never floating content and never heavy cards.
class HomeRegion extends StatelessWidget {
  const HomeRegion({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = const EdgeInsets.fromLTRB(16, 0, 16, 16),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: t.region,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: t.separator),
        ),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// A section's header row: tinted glyph tile, title, quiet count and an
/// optional small action.
class HomeRegionHeader extends StatelessWidget {
  const HomeRegionHeader({
    super.key,
    required this.glyph,
    required this.title,
    this.tint,
    this.count,
    this.trailing,
  });

  final AscentGlyph glyph;
  final String title;

  /// The feature colour; navy (action) when null.
  final Color? tint;
  final String? count;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final c = tint ?? t.action;
    return Semantics(
      header: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 28),
        child: Row(
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: c.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: AscentIcon(glyph, size: 16, color: c),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AscentTextStyles.section.copyWith(color: t.action),
              ),
            ),
            if (count != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  count!,
                  style: AscentTextStyles.meta.copyWith(color: t.labelTertiary),
                ),
              ),
            ?trailing,
          ],
        ),
      ),
    );
  }
}
