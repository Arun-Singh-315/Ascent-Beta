import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../app/theme/color_tokens.dart';

/// A shimmer loading placeholder that respects the Ascent light/dark palette.
///
/// Use the named constructors for common shapes:
/// ```dart
/// SkeletonShimmer.line(width: 120)       // text line
/// SkeletonShimmer.card(height: 160)      // card block
/// SkeletonShimmer.circle(size: 48)       // avatar
/// SkeletonShimmer.custom(child: myShape) // arbitrary shape
/// ```
class SkeletonShimmer extends StatelessWidget {
  const SkeletonShimmer._({
    super.key,
    required this.child,
  });

  /// Default skeleton box constructor.
  factory SkeletonShimmer({
    Key? key,
    double? width,
    double height = 120,
    double radius = 16,
  }) =>
      SkeletonShimmer.card(
        key: key,
        width: width,
        height: height,
        radius: radius,
      );

  /// Single text-line skeleton.

  factory SkeletonShimmer.line({
    Key? key,
    double? width,
    double height = 14,
    double radius = 6,
  }) =>
      SkeletonShimmer._(
        key: key,
        child: _ShimmerBox(
          width: width,
          height: height,
          radius: radius,
        ),
      );

  /// Card-shaped skeleton block.
  factory SkeletonShimmer.card({
    Key? key,
    double? width,
    double height = 120,
    double radius = 16,
  }) =>
      SkeletonShimmer._(
        key: key,
        child: _ShimmerBox(
          width: width,
          height: height,
          radius: radius,
        ),
      );

  /// Circular avatar / icon skeleton.
  factory SkeletonShimmer.circle({
    Key? key,
    double size = 48,
  }) =>
      SkeletonShimmer._(
        key: key,
        child: _ShimmerBox(
          width: size,
          height: size,
          radius: size / 2,
        ),
      );

  /// Wraps any arbitrary [child] widget with the shimmer effect.
  factory SkeletonShimmer.custom({
    Key? key,
    required Widget child,
  }) =>
      SkeletonShimmer._(key: key, child: child);

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;

    final baseColor = isDark
        ? const Color(0xFF252D37)
        : const Color(0xFFEFEDE9);
    final highlightColor = isDark
        ? const Color(0xFF2E3745)
        : const Color(0xFFFBF9F6);

    return Shimmer.fromColors(
      baseColor: baseColor,
      highlightColor: highlightColor,
      child: child,
    );
  }
}

// ── Internal helper ─────────────────────────────────────────────────────────

class _ShimmerBox extends StatelessWidget {
  const _ShimmerBox({
    this.width,
    required this.height,
    required this.radius,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── Composite skeletons ──────────────────────────────────────────────────────

/// Skeleton that mirrors the 6-block home card layout.
///
/// Used while the home screen's data is loading.
class HomeCardSkeleton extends StatelessWidget {
  const HomeCardSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Block row 1 — two half-width cards
        Row(
          children: [
            Expanded(child: SkeletonShimmer.card(height: 100)),
            const SizedBox(width: 12),
            Expanded(child: SkeletonShimmer.card(height: 100)),
          ],
        ),
        const SizedBox(height: 12),
        // Block row 2 — full-width card
        SkeletonShimmer.card(height: 120),
        const SizedBox(height: 12),
        // Block row 3 — two half-width cards
        Row(
          children: [
            Expanded(child: SkeletonShimmer.card(height: 100)),
            const SizedBox(width: 12),
            Expanded(child: SkeletonShimmer.card(height: 100)),
          ],
        ),
        const SizedBox(height: 12),
        // Block row 4 — full-width card
        SkeletonShimmer.card(height: 120),
        const SizedBox(height: 12),
        // Block row 5 — two half-width cards
        Row(
          children: [
            Expanded(child: SkeletonShimmer.card(height: 100)),
            const SizedBox(width: 12),
            Expanded(child: SkeletonShimmer.card(height: 100)),
          ],
        ),
      ],
    );
  }
}

/// Skeleton for the horizontal quick-stats strip below the greeting.
class StatsStripSkeleton extends StatelessWidget {
  const StatsStripSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (int i = 0; i < 4; i++) ...[
          Expanded(
            child: SkeletonShimmer.card(height: 72),
          ),
          if (i < 3) const SizedBox(width: 10),
        ],
      ],
    );
  }
}
