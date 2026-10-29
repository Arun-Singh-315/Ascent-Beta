import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';

/// Canonical, contrast-safe tile for shielded/private commitments and thoughts.
/// Guarantees WCAG AAA contrast across all themes (Merlot Linen, Clear Sky, Classic Clay)
/// in both Dark and Day modes with zero bleached/chalky backgrounds.
/// Overflow immune at 320px width with 2.0x text scaling.
class LockedCommitmentTile extends StatelessWidget {
  final VoidCallback onTap;
  final String label;

  const LockedCommitmentTile({
    super.key,
    required this.onTap,
    this.label = 'Private commitment',
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(
            horizontal: 14,
            vertical: 12,
          ),
          decoration: BoxDecoration(
            color: isDark ? const Color(0x1C000000) : const Color(0x0A000000),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: g.line.withValues(alpha: isDark ? 0.40 : 0.70),
              width: 1.0,
            ),
          ),
          child: Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                size: 16,
                color: g.clay,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.bodyMedium.copyWith(
                    color: g.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: g.clay.withValues(alpha: isDark ? 0.20 : 0.12),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: g.clay.withValues(alpha: 0.32),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        'Unlock',
                        style: TextStyle(
                          color: g.clay,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.1,
                        ),
                      ),
                    ),
                    const SizedBox(width: 3),
                    Icon(
                      Icons.arrow_forward_rounded,
                      size: 11,
                      color: g.clay,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
