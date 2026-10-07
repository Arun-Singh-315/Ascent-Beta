import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
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

  IconData _greetingIcon() {
    final hour = DateTime.now().hour;
    if (hour < 12) return Icons.wb_sunny_rounded;
    if (hour < 17) return Icons.wb_twilight_rounded;
    return Icons.nightlight_round;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final name = profile?.name.isNotEmpty == true ? profile!.name : 'Learner';
    final role = profile?.targetRole.isNotEmpty == true ? profile!.targetRole : 'Software Engineer';
    final dateStr = DateFormat('EEE, MMM d').format(DateTime.now());
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final streak = ref.watch(currentStreakStreamProvider).value ?? 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // ── LEFT: GREETING, HERO NAME & ROLE ─────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top time & context subline with subtle warm icon
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _greetingIcon(),
                      size: 13,
                      color: const Color(0xFFF59E0B),
                    ),
                    const SizedBox(width: 5),
                    Text(
                      '${_greeting()} · $dateStr',
                      style: GoogleFonts.plusJakartaSans(
                        color: context.textMuted,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.1,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 3),
                // Hero user name (never truncated by streak, full horizontal width)
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/settings');
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Text(
                    name,
                    style: GoogleFonts.plusJakartaSans(
                      color: context.textPrimary,
                      fontSize: 21,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.4,
                      height: 1.2,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(height: 4),
                // Target role tag
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/settings');
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                    decoration: BoxDecoration(
                      color: context.accentSecondary.withValues(alpha: isDark ? 0.12 : 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: context.accentSecondary.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      role,
                      style: GoogleFonts.jetBrainsMono(
                        color: context.accentSecondary,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(width: 12),

          // ── RIGHT: SLEEK ACTIONS CLUSTER (Streak + Theme + Avatar) ────
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Dedicated Interactive Streak Flame Pill
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showStreakDetailsSheet(context, streak, isDark);
                  },
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                    decoration: BoxDecoration(
                      color: const Color(0xFFE28B57).withValues(alpha: isDark ? 0.20 : 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFFE28B57).withValues(alpha: 0.45),
                        width: 0.9,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.local_fire_department_rounded,
                          size: 14,
                          color: Color(0xFFE28B57),
                        ),
                        const SizedBox(width: 3.5),
                        Text(
                          '$streak',
                          style: GoogleFonts.jetBrainsMono(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFE28B57),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),

              // Theme Mode Toggle button
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: context.bgSurfaceElevated,
                  shape: BoxShape.circle,
                  border: Border.all(color: context.divider, width: 0.8),
                ),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  iconSize: 18,
                  tooltip: isDark ? 'Switch to Light Mode' : 'Switch to Dark Mode',
                  icon: Icon(
                    isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                    color: isDark ? const Color(0xFFFBBF24) : context.textSecondary,
                  ),
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    ref.read(themeModeProvider.notifier).setThemeMode(
                      isDark ? ThemeMode.light : ThemeMode.dark,
                    );
                  },
                ),
              ),
              const SizedBox(width: 6),

              // Settings / Profile avatar
              Tooltip(
                message: 'Profile & Settings',
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/settings');
                  },
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.accentPrimary.withValues(alpha: 0.18),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: context.accentPrimary.withValues(alpha: 0.45),
                        width: 1.0,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A',
                        style: GoogleFonts.plusJakartaSans(
                          color: context.accentPrimary,
                          fontWeight: FontWeight.w800,
                          fontSize: 13.5,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),

              // Flame icon circle
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFE28B57).withValues(alpha: isDark ? 0.22 : 0.12),
                  border: Border.all(
                    color: const Color(0xFFE28B57).withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: const Center(
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    size: 36,
                    color: Color(0xFFE28B57),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // Streak number
              Text(
                '$streak Day${streak == 1 ? '' : 's'} Active',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: ctx.textPrimary,
                ),
              ),
              const SizedBox(height: 6),

              Text(
                streak > 0
                    ? 'Consistency is your edge. Complete any activity today to keep the flame alive.'
                    : 'Start your streak today. Check off an activity to ignite the flame.',
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13,
                  color: ctx.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),

              // Status card
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: ctx.bgBase,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: ctx.divider, width: 0.8),
                ),
                child: Row(
                  children: [
                    Icon(
                      streak > 0 ? Icons.check_circle_rounded : Icons.info_outline_rounded,
                      size: 18,
                      color: streak > 0 ? ctx.accentSecondary : ctx.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        streak > 0
                            ? 'Streak is active for today.'
                            : 'Log or complete a task today to start your streak.',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12.5,
                          color: ctx.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),

              // Dismiss button
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(ctx).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE28B57),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(
                    'Keep Going',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
