import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';

class WelcomeBackBanner extends ConsumerWidget {
  final int days;
  const WelcomeBackBanner({super.key, required this.days});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s14,
        vertical: AppSpace.s10,
      ),
      nightDecoration: BoxDecoration(
        color: context.accentSecondary.withValues(alpha: 0.08),
        borderRadius: AppGeometry.roundedr12,
        border: Border.all(
          color: context.accentSecondary.withValues(alpha: 0.25),
          width: AppBorderScale.w0point8,
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.wb_sunny_outlined,
            color: context.accentSecondary,
            size: 20,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back! You were away $days days.',
                  style: AscentTextStyles.labelSmall
                      .copyWith(color: context.textPrimary)
                      .merge(AppTypeRoles.typeRole2),
                ),
                const SizedBox(height: 1),
                Text(
                  'Consistency starts with one focused block. Let\'s build momentum today!',
                  style: AscentTextStyles.bodySmall
                      .copyWith(color: context.textMuted)
                      .merge(AppTypeRoles.typeRole4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
