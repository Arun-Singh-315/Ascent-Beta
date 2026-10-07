import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../shared/widgets/new_day_dialog.dart';

class HomeHeader extends ConsumerWidget {
  final UserProfile? profile;

  const HomeHeader({super.key, required this.profile});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = profile?.name.isNotEmpty == true ? profile!.name : 'Learner';
    final role = profile?.targetRole.isNotEmpty == true ? profile!.targetRole : 'Software Engineer';
    final dateStr = DateFormat('EEEE, MMM d').format(DateTime.now());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final streak = ref.watch(currentStreakStreamProvider).value ?? 0;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              showNewDayDialog(context, ref);
            },
            borderRadius: BorderRadius.circular(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        '${_greeting()}, $name',
                        style: GoogleFonts.plusJakartaSans(
                          color: context.textPrimary,
                          fontSize: 19,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 6),
                    // Streak Flame Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE28B57).withValues(alpha: isDark ? 0.22 : 0.14),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFE28B57).withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.local_fire_department_rounded, size: 12, color: Color(0xFFE28B57)),
                          const SizedBox(width: 3),
                          Text(
                            '$streak',
                            style: GoogleFonts.jetBrainsMono(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: const Color(0xFFE28B57),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(
                  '$dateStr · $role',
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: context.textMuted,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Quick Day / Night Toggle button
            IconButton(
              tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
              icon: Icon(
                isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                size: 21,
                color: isDark ? const Color(0xFFFBBF24) : context.textSecondary,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                ref.read(themeModeProvider.notifier).setThemeMode(
                  isDark ? ThemeMode.light : ThemeMode.dark,
                );
              },
            ),
            const SizedBox(width: 4),
            // Settings / Profile avatar
            Tooltip(
              message: 'Settings & Profile',
              child: InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/settings');
                },
                borderRadius: BorderRadius.circular(20),
                child: Padding(
                  padding: const EdgeInsets.all(4),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: context.bgSurfaceElevated,
                      shape: BoxShape.circle,
                      border: Border.all(color: context.divider, width: 1.0),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A',
                        style: GoogleFonts.plusJakartaSans(
                          color: context.textPrimary,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
