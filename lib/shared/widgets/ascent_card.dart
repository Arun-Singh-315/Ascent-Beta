import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/color_tokens.dart';

/// A surface card that follows the Ascent design system.
///
/// Features a calm translucent glassy background, subtle 0.9px border, gentle diffuse shadow,
/// and smooth ink ripple with tactile haptics when [onTap] is provided.
class AscentCard extends StatelessWidget {
  const AscentCard({
    super.key,
    required this.child,
    this.padding,
    this.margin,
    this.onTap,
    this.color,
    this.radius = 16,
    this.hasShadow = true,
    this.hasBorder = true,
  });

  /// The content displayed inside the card.
  final Widget child;

  /// Inner padding. Defaults to [EdgeInsets.all(16)] when null.
  final EdgeInsetsGeometry? padding;

  /// Outer margin. Defaults to null.
  final EdgeInsetsGeometry? margin;

  /// When non-null the card becomes tappable with an ink ripple.
  final VoidCallback? onTap;

  /// Override the default [AscentColors.bgSurface] background.
  final Color? color;

  /// Corner radius. Defaults to 16.
  final double radius;

  /// When true (default) adds a delicate diffuse shadow.
  final bool hasShadow;

  /// When true (default) adds a refined hairline border.
  final bool hasBorder;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = color ??
        (context.isDark
            ? context.bgSurface.withValues(alpha: 0.6)
            : context.bgSurface.withValues(alpha: 0.88));
    final shadowColor = context.isDark ? AscentColors.shadowDark : AscentColors.shadow;
    final borderColor = context.divider.withValues(alpha: context.isDark ? 0.7 : 0.55);
    final borderRadius = BorderRadius.circular(radius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: borderRadius,
        border: hasBorder ? Border.all(color: borderColor, width: 0.9) : null,
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: shadowColor.withValues(alpha: context.isDark ? 0.25 : 0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap!();
                },
          borderRadius: borderRadius,
          child: Padding(
            padding: padding ?? const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    );
  }
}
