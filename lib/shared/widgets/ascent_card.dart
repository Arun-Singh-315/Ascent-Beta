import 'package:flutter/material.dart';

import '../../app/theme/color_tokens.dart';

/// A surface card that follows the Ascent design system.
///
/// Wraps [child] in a rounded, optionally-tappable container with a
/// consistent shadow and background colour derived from [AscentColors].
///
/// ```dart
/// AscentCard(
///   onTap: () => _open(item),
///   child: ListTile(title: Text(item.title)),
/// )
/// ```
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

  /// When true (default) adds a subtle 12 px blur shadow.
  final bool hasShadow;

  @override
  Widget build(BuildContext context) {
    final surfaceColor = color ??
        (context.isDark ? AscentColors.bgSurfaceDark : AscentColors.bgSurface);
    final shadowColor =
        context.isDark ? AscentColors.shadowDark : AscentColors.shadow;

    final borderRadius = BorderRadius.circular(radius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(

        color: surfaceColor,
        borderRadius: borderRadius,
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: shadowColor.withValues(alpha: 0.06),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
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
