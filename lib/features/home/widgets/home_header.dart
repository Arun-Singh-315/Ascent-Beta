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
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/settings');
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
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
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Dedicated Interactive Streak Flame Pill (Non-blocking Sanctuary Sheet)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showStreakDetailsSheet(context, streak, isDark);
                      },
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3.5),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE28B57).withValues(alpha: isDark ? 0.22 : 0.14),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE28B57).withValues(alpha: 0.5),
                            width: 0.9,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.local_fire_department_rounded, size: 13, color: Color(0xFFE28B57)),
                            const SizedBox(width: 3.5),
                            Text(
                              '$streak',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFE28B57),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/settings');
                },
                borderRadius: BorderRadius.circular(4),
                child: Text(
                  '$dateStr · $role',
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: context.textMuted,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
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

  void _showStreakDetailsSheet(BuildContext context, int streak, bool isDark) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: ctx.bgSurfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: ctx.divider, width: 1),
          ),
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Grab handle
              Container(
                width: 38,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.textMuted.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),
              // Big Flame Icon
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: const Color(0xFFE28B57).withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                  border: Border.all(color: const Color(0xFFE28B57).withValues(alpha: 0.5)),
                ),
                child: const Center(
                  child: Icon(Icons.local_fire_department_rounded, size: 36, color: Color(0xFFE28B57)),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '$streak Day Streak 🔥',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 20,
                  fontWeight: FontWeight.w800,
                  color: ctx.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Consistency beats intensity every single time.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: ctx.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              // Metrics Glass Container
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: ctx.bgBase,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: ctx.divider.withValues(alpha: 0.8)),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Column(
                      children: [
                        Text('CURRENT', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: ctx.textMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('$streak Days', style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: const Color(0xFFE28B57))),
                      ],
                    ),
                    Container(height: 24, width: 1, color: ctx.divider),
                    Column(
                      children: [
                        Text('STATUS', style: GoogleFonts.jetBrainsMono(fontSize: 10, color: ctx.textMuted, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text(streak > 0 ? 'Active 🔥' : 'Start Today', style: GoogleFonts.jetBrainsMono(fontSize: 15, fontWeight: FontWeight.w700, color: ctx.accentPrimary)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Dismiss button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE28B57),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(ctx).pop();
                  },
                  child: Text('Keep It Up', style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w700)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
