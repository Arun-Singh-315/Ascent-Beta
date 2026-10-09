import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/streak/study_streak_provider.dart';

/// Redesigned HomeHeader based on Ascent Home Redesign spec:
/// - Top row: uppercase date caption on left, Riya glass pill + avatar (+ streak) on right.
/// - Display name with Bricolage Grotesque (34/40).
/// - Secondary greeting "Good morning / afternoon / evening,".
/// - Role micro-badge.
/// - Centralized Riya AI gateway button linking to /ai-assistant.
class HomeHeader extends ConsumerWidget {
  final UserProfile? profile;

  const HomeHeader({super.key, required this.profile});

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final isDark = context.isDark;
    final name = profile?.name.isNotEmpty == true ? profile!.name : 'Learner';
    final role = profile?.targetRole.isNotEmpty == true ? profile!.targetRole : 'Software Engineer';
    final dateStr = DateFormat('EEE, d MMM').format(DateTime.now()).toUpperCase();
    final studyStreak = ref.watch(studyStreakProvider);
    final isStreakCardVisible = ref.watch(studyStreakCardVisibleProvider);
    final legacyStreak = ref.watch(currentStreakStreamProvider).value ?? 0;
    final streak = studyStreak.displayStreakDays > 0 ? studyStreak.displayStreakDays : legacyStreak;
    final assistantName = ref.watch(assistantNameProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── TOP ROW: DATE CAPTION & ACTION PILLS (RIYA + AVATAR) ───────
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Date Caption
              Text(
                dateStr,
                style: AscentTextStyles.homeCaption.copyWith(
                  color: g.inkMuted,
                  letterSpacing: 0.5,
                  fontWeight: FontWeight.w600,
                ),
              ),

              // Right cluster: Interactive Streak flame + Riya button + Avatar
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Streak Pill (Toggles Home Streak Card visibility)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        ref.read(studyStreakCardVisibleProvider.notifier).toggle();
                      },
                      onLongPress: () {
                        HapticFeedback.mediumImpact();
                        _showStreakDetailsSheet(context, streak, isDark);
                      },
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 10),
                        decoration: BoxDecoration(
                          color: isStreakCardVisible ? g.claySoft : g.fill,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(
                            color: isStreakCardVisible ? g.clay : g.edge,
                            width: 1.0,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.local_fire_department_rounded,
                              size: 15,
                              color: g.clay,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              '$streak',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w700,
                                color: g.clay,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Riya glass pill button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        context.push('/ai-assistant');
                      },
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: g.fill,
                          borderRadius: BorderRadius.circular(99),
                          border: Border.all(color: g.edge, width: 1.0),
                          boxShadow: [
                            BoxShadow(
                              color: g.shadow.withValues(alpha: isDark ? 0.3 : 0.05),
                              blurRadius: 10,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 14,
                              color: g.clay,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              assistantName,
                              style: AscentTextStyles.homeSecondary.copyWith(
                                color: g.ink,
                                fontWeight: FontWeight.w600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // Avatar Circle (opens profile & quick settings sheet)
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        _showProfileSheet(context, ref, name, role, isDark);
                      },
                      borderRadius: BorderRadius.circular(99),
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: g.claySoft,
                          shape: BoxShape.circle,
                          border: Border.all(color: g.edge, width: 1.0),
                        ),
                        child: Center(
                          child: Text(
                            name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A',
                            style: GoogleFonts.bricolageGrotesque(
                              color: g.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
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

          const SizedBox(height: 14),

          // ── GREETING & DISPLAY NAME ───────────────────────────────────
          Text(
            _greeting(),
            style: AscentTextStyles.homeBody.copyWith(
              color: g.inkSecondary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            name,
            style: AscentTextStyles.homeDisplay.copyWith(
              color: g.ink,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),

          const SizedBox(height: 6),

          // ── ROLE MICRO-BADGE & LABELED MIND SPACE SHORTCUT ────────────
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (role.isNotEmpty)
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/settings');
                  },
                  borderRadius: BorderRadius.circular(6),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                    decoration: BoxDecoration(
                      color: g.claySoft,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(
                        color: g.clay.withValues(alpha: 0.25),
                        width: 0.8,
                      ),
                    ),
                    child: Text(
                      role,
                      style: GoogleFonts.jetBrainsMono(
                        color: g.clay,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w700,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // Explicitly labeled Mind Space Shortcut
              InkWell(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/thought-wall');
                },
                borderRadius: BorderRadius.circular(6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2.5),
                  decoration: BoxDecoration(
                    color: g.fill,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: g.edge,
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.psychology_rounded,
                        size: 13,
                        color: g.inkSecondary,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Mind Space',
                        style: GoogleFonts.plusJakartaSans(
                          color: g.inkSecondary,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showProfileSheet(
    BuildContext context,
    WidgetRef ref,
    String name,
    String role,
    bool isDark,
  ) {
    final g = context.glass;
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: ctx.bgSurfaceElevated,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: ctx.divider, width: 1),
          ),
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: ctx.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: g.claySoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: g.edge),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty ? name.substring(0, 1).toUpperCase() : 'A',
                        style: GoogleFonts.bricolageGrotesque(
                          color: g.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 20,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.bricolageGrotesque(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: ctx.textPrimary,
                          ),
                        ),
                        Text(
                          role,
                          style: GoogleFonts.dmSans(
                            fontSize: 13,
                            color: ctx.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Divider(color: ctx.divider, height: 1),
              const SizedBox(height: 12),

              // Theme Mode switch
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  isDark ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
                  color: g.clay,
                ),
                title: Text(
                  'Dark Theme',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                ),
                trailing: Switch(
                  value: isDark,
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    ref.read(themeModeProvider.notifier).setThemeMode(
                          val ? ThemeMode.dark : ThemeMode.light,
                        );
                  },
                ),
              ),

              // Full Settings Link
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.settings_outlined, color: ctx.textMuted),
                title: Text(
                  'Settings & Profile',
                  style: GoogleFonts.dmSans(fontWeight: FontWeight.w600),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(ctx).pop();
                  context.push('/settings');
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showStreakDetailsSheet(BuildContext context, int streak, bool isDark) {
    final g = context.glass;
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
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 20),
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: g.claySoft,
                  border: Border.all(
                    color: g.clay.withValues(alpha: 0.5),
                    width: 1.5,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.local_fire_department_rounded,
                    size: 36,
                    color: g.clay,
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                '$streak Day${streak == 1 ? '' : 's'} Active',
                style: GoogleFonts.bricolageGrotesque(
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
                style: GoogleFonts.dmSans(
                  fontSize: 13,
                  color: ctx.textMuted,
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(ctx).pop();
                  },
                  style: FilledButton.styleFrom(
                    backgroundColor: g.clay,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                  ),
                  child: Text(
                    'Keep Going',
                    style: GoogleFonts.dmSans(
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
