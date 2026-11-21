import 'package:flutter/material.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';

/// A preview card at the bottom of Home showcasing upcoming features.
/// Styled with a transparent backdrop and sleek dark/crisp border.
class HomeComingSoonCard extends StatelessWidget {
  const HomeComingSoonCard({super.key});

  static const _features = [
    _ComingSoonFeature(
      icon: Icons.verified_outlined,
      title: 'Promises',
      subtitle: 'Daily vows & accountability',
    ),
    _ComingSoonFeature(
      icon: Icons.coffee_outlined,
      title: 'Chai Break',
      subtitle: 'Mindful breathing & soundscapes',
    ),
    _ComingSoonFeature(
      icon: Icons.directions_walk_rounded,
      title: 'Outdoor Walk',
      subtitle: 'Route tracking & pace analysis',
    ),
    _ComingSoonFeature(
      icon: Icons.menu_book_rounded,
      title: 'Book Reader',
      subtitle: 'Distraction-free reading hub',
    ),
    _ComingSoonFeature(
      icon: Icons.local_fire_department_rounded,
      title: 'Momentum',
      subtitle: 'Streak goals & pace challenges',
    ),
    _ComingSoonFeature(
      icon: Icons.grid_on_rounded,
      title: 'Consistency',
      subtitle: 'Interactive activity heatmaps',
    ),
    _ComingSoonFeature(
      icon: Icons.insights_rounded,
      title: 'Deep Analytics',
      subtitle: 'Long-term habit trends & charts',
    ),
    _ComingSoonFeature(
      icon: Icons.cloud_sync_outlined,
      title: 'Cloud Backup',
      subtitle: 'Encrypted multi-device sync',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final borderColor = isDark
        ? const Color(0xFF3A3A3C)
        : const Color(0xFF1C1C1E);

    return Container(
      key: const ValueKey('home_coming_soon_card'),
      margin: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: AppSpace.s12,
      ),
      padding: const EdgeInsets.all(AppSpace.s20),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.black.withValues(alpha: 0.25)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: borderColor,
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s10,
                  vertical: AppSpace.s4,
                ),
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF2C2C2E)
                      : const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      size: 13,
                      color: Colors.white,
                    ),
                    const SizedBox(width: 5),
                    Text(
                      'COMING SOON',
                      style: AscentTextStyles.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Icon(
                Icons.hourglass_top_rounded,
                size: 16,
                color: g.inkMuted,
              ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Text(
            'What\'s Next in Ascent',
            style: AscentTextStyles.homeTitle.copyWith(
              color: g.ink,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: AppSpace.s4),
          Text(
            'Features being actively polished for upcoming updates.',
            style: AscentTextStyles.caption.copyWith(
              color: g.inkMuted,
            ),
          ),
          const SizedBox(height: AppSpace.s16),
          LayoutBuilder(
            builder: (context, constraints) {
              final isVeryLarge =
                  MediaQuery.textScalerOf(context).scale(14) > 22;
              final cols = (constraints.maxWidth > 500 && !isVeryLarge)
                  ? 2
                  : 1;
              const gap = AppSpace.s8;
              final itemWidth = cols == 2
                  ? (constraints.maxWidth - gap) / 2
                  : constraints.maxWidth;

              return Wrap(
                spacing: gap,
                runSpacing: gap,
                children: [
                  for (final item in _features)
                    SizedBox(
                      width: itemWidth,
                      child: _FeatureTile(feature: item, isDark: isDark),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ComingSoonFeature {
  const _ComingSoonFeature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;
}

class _FeatureTile extends StatelessWidget {
  const _FeatureTile({
    required this.feature,
    required this.isDark,
  });

  final _ComingSoonFeature feature;
  final bool isDark;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s12,
        vertical: AppSpace.s10,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.08)
              : Colors.black.withValues(alpha: 0.12),
          width: 0.8,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              feature.icon,
              size: 16,
              color: g.ink,
            ),
          ),
          const SizedBox(width: AppSpace.s10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  feature.title,
                  style: AscentTextStyles.bodyMedium.copyWith(
                    color: g.ink,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  feature.subtitle,
                  style: AscentTextStyles.caption.copyWith(
                    color: g.inkMuted,
                    fontSize: 11,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
