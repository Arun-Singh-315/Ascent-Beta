import 'package:flutter/material.dart';

/// The official Ascent logo widget.
/// Renders the signature geometric concentric radar/focus logo
/// on a deep dark squircle container with subtle border and lighting.
class AscentLogo extends StatelessWidget {
  final double size;
  final double? borderRadius;
  final bool showBorder;
  final bool showShadow;

  const AscentLogo({
    super.key,
    this.size = 72,
    this.borderRadius,
    this.showBorder = true,
    this.showShadow = true,
  });

  @override
  Widget build(BuildContext context) {
    final radius = borderRadius ?? (size * 0.26);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: showBorder
            ? Border.all(
                color: Colors.white.withValues(alpha: 0.12),
                width: 1.0,
              )
            : null,
        boxShadow: showShadow
            ? [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: size * 0.25,
                  offset: Offset(0, size * 0.08),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Image.asset(
          'assets/images/logo.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
