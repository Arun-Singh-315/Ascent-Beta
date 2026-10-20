import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import '../home_customization_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/frozen_palette.dart';
import '../../../app/theme/merlot_palette.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/home_layout_provider.dart';
import '../../../core/streak/study_streak_provider.dart';
import 'daily_briefing_card.dart';

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
    final name = profile?.name.isNotEmpty == true
        ? profile!.name
        : 'Your space';
    final role = profile?.targetRole.isNotEmpty == true
        ? profile!.targetRole
        : 'Your daily companion';
    final dateStr = DateFormat(
      'EEE, d MMM',
    ).format(DateTime.now()).toUpperCase();
    final studyStreak = ref.watch(studyStreakProvider);
    final isStreakCardVisible = ref.watch(homeStreakVisibleProvider);
    final streak = studyStreak.displayStreakDays;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Date has its own line so action pills cannot crowd or cover it.
          _HomeHeaderRow(
            date: Text(
              dateStr,
              key: const ValueKey('home_date'),
              style: AscentTextStyles.homeCaption
                  .copyWith(color: g.inkMuted, letterSpacing: 0.5)
                  .merge(AppTypeRoles.typeRole8),
            ),
            actions: [
              // Streak Pill (Toggles Home Streak Card visibility)
              Material(
                color: AppPalette.transparent,
                child: AppTapArea(
                  onTap: () async {
                    HapticFeedback.lightImpact();
                    if (streak == 0) {
                      await DailyBriefingCard.show(context, DateTime.now());
                      return;
                    }
                    final layout = ref.read(homeLayoutProvider);
                    final visible = {...layout.visible};
                    isStreakCardVisible
                        ? visible.remove('streak')
                        : visible.add('streak');
                    try {
                      await ref
                          .read(homeLayoutProvider.notifier)
                          .save(layout.copyWith(visible: visible));
                    } catch (_) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Could not update Home. Try again.'),
                          ),
                        );
                      }
                    }
                  },
                  onLongPress: () {
                    HapticFeedback.mediumImpact();
                    _showStreakDetailsSheet(context, streak, isDark);
                  },
                  borderRadius: AppGeometry.roundedr99,
                  child: Container(
                    constraints: const BoxConstraints(minHeight: 44),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s12,
                      vertical: AppSpace.s8,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? (g.merlot
                              ? (isStreakCardVisible
                                  ? MerlotPalette.darkTint
                                  : Colors.transparent)
                              : (g.frozen
                                  ? (isStreakCardVisible
                                      ? FrozenPalette.darkTint
                                      : Colors.transparent)
                                  : (isStreakCardVisible
                                      ? g.clay.withValues(alpha: 0.22)
                                      : Colors.transparent)))
                          : (isStreakCardVisible
                              ? (g.merlot
                                  ? MerlotPalette.action
                                  : (g.frozen
                                      ? FrozenPalette.action
                                      : const Color(0xFFFEF3C7)))
                              : (g.merlot ? MerlotPalette.surface : Colors.white)),
                      borderRadius: AppGeometry.roundedr99,
                      border: Border.all(
                        color: isDark
                            ? (g.merlot
                                ? (isStreakCardVisible
                                    ? MerlotPalette.darkLine
                                    : MerlotPalette.darkLineSubtle)
                                : (g.frozen
                                    ? (isStreakCardVisible
                                        ? FrozenPalette.darkLine
                                        : FrozenPalette.darkLine)
                                    : (isStreakCardVisible ? g.clay : g.edge)))
                            : (g.merlot
                                ? (isStreakCardVisible
                                    ? MerlotPalette.actionDeep
                                    : MerlotPalette.line)
                                : (g.frozen
                                    ? FrozenPalette.line
                                    : (isStreakCardVisible
                                        ? const Color(0xFFF59E0B)
                                        : const Color(0xFFE2E8F0)))),
                        width: g.merlot ? 0.75 : AppBorderScale.w1point0,
                      ),
                      boxShadow: isDark
                          ? null
                          : [
                              BoxShadow(
                                color: (isStreakCardVisible
                                        ? (g.merlot
                                            ? MerlotPalette.action
                                            : (g.frozen
                                                ? FrozenPalette.action
                                                : const Color(0xFFF59E0B)))
                                        : (g.merlot
                                            ? MerlotPalette.action
                                            : const Color(0xFF0F172A)))
                                    .withValues(alpha: 0.08),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.local_fire_department_rounded,
                          size: 16,
                          color: isDark
                              ? (g.merlot
                                  ? MerlotPalette.darkSpark
                                  : (g.frozen
                                      ? FrozenPalette.darkSpark
                                      : g.clay))
                              : (isStreakCardVisible
                                  ? (g.merlot
                                      ? const Color(0xFFFBBF24)
                                      : (g.frozen
                                          ? Colors.white
                                          : const Color(0xFFEA580C)))
                                  : (g.merlot
                                      ? MerlotPalette.mutedInk
                                      : (g.frozen
                                          ? FrozenPalette.mutedInk
                                          : const Color(0xFF64748B)))),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            streak == 0 ? 'Start' : '$streak',
                            style: AppTypography.jetBrainsMono115W7009(
                              color: isDark
                                  ? (g.merlot
                                      ? (isStreakCardVisible
                                          ? MerlotPalette.darkInk
                                          : MerlotPalette.darkMutedInk)
                                      : (g.frozen
                                          ? (isStreakCardVisible
                                              ? FrozenPalette.darkInk
                                              : FrozenPalette.darkMutedInk)
                                          : (isStreakCardVisible
                                              ? Colors.white
                                              : g.inkMuted)))
                                  : (isStreakCardVisible
                                      ? (g.merlot
                                          ? Colors.white
                                          : (g.frozen
                                              ? Colors.white
                                              : const Color(0xFFB45309)))
                                      : (g.merlot
                                          ? MerlotPalette.ink
                                          : (g.frozen
                                              ? FrozenPalette.ink
                                              : const Color(0xFF0F172A)))),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Quick 1-Tap Theme Mode Switcher
              Material(
                color: AppPalette.transparent,
                child: AppTapArea(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    final next = isDark ? ThemeMode.light : ThemeMode.dark;
                    ref.read(themeModeProvider.notifier).setThemeMode(next);
                  },
                  borderRadius: AppGeometry.roundedr99,
                  child: Tooltip(
                    message: isDark
                        ? 'Switch to Luminous Day Theme'
                        : 'Switch to Night Glass Theme',
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: isDark
                            ? g.fill
                            : (g.merlot
                                ? MerlotPalette.surface
                                : (g.frozen
                                    ? FrozenPalette.surface
                                    : const Color(0xFFFFF7ED))),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? g.edge
                              : (g.merlot
                                  ? MerlotPalette.line
                                  : (g.frozen
                                      ? FrozenPalette.line
                                      : const Color(0xFFFDBA74))),
                          width: g.merlot ? 0.75 : AppBorderScale.w1point0,
                        ),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color: (g.merlot
                                          ? MerlotPalette.action
                                          : (g.frozen
                                              ? FrozenPalette.action
                                              : const Color(0xFFF97316)))
                                      .withValues(alpha: 0.10),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                      ),
                      child: Icon(
                        isDark
                            ? Icons.light_mode_rounded
                            : Icons.dark_mode_rounded,
                        size: 20,
                        color: isDark
                            ? (g.merlot
                                ? MerlotPalette.spark
                                : const Color(0xFFF59E0B))
                            : (g.merlot
                                ? MerlotPalette.action
                                : (g.frozen
                                    ? FrozenPalette.action
                                    : const Color(0xFF6366F1))),
                      ),
                    ),
                  ),
                ),
              ),

              // Avatar Circle (opens profile & quick settings sheet)
              Material(
                color: AppPalette.transparent,
                child: AppTapArea(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    _showProfileSheet(context, ref, name, role, isDark);
                  },
                  borderRadius: AppGeometry.roundedr99,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      gradient: g.frozen
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                isDark
                                    ? FrozenPalette.darkActionBright
                                    : FrozenPalette.actionBright,
                                isDark
                                    ? FrozenPalette.darkAction
                                    : FrozenPalette.action,
                              ],
                            )
                          : g.merlot
                          ? LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: isDark
                                  ? [
                                      MerlotPalette.darkAction,
                                      MerlotPalette.darkActionDeep,
                                    ]
                                  : [
                                      MerlotPalette.action,
                                      MerlotPalette.actionDeep,
                                    ],
                            )
                          : (!isDark
                              ? const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFFFEDD5),
                                    Color(0xFFFED7AA),
                                  ],
                                )
                              : null),
                      color: (g.frozen || g.merlot) ? null : (isDark ? g.claySoft : null),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: g.frozen
                            ? (isDark
                                  ? FrozenPalette.darkLine
                                  : FrozenPalette.line)
                            : g.merlot
                            ? (isDark
                                  ? MerlotPalette.darkLine
                                  : MerlotPalette.actionDeep)
                            : (isDark ? g.edge : const Color(0xFFFDBA74)),
                        width: g.merlot ? 1.0 : AppBorderScale.w1point0,
                      ),
                      boxShadow: g.frozen
                          ? [
                              BoxShadow(
                                color:
                                    (isDark
                                            ? FrozenPalette.darkAction
                                            : FrozenPalette.action)
                                        .withValues(alpha: 0.20),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ]
                          : g.merlot
                          ? [
                              BoxShadow(
                                color: (isDark
                                        ? MerlotPalette.darkAction
                                        : MerlotPalette.action)
                                    .withValues(alpha: isDark ? 0.25 : 0.20),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : (!isDark
                              ? [
                                  BoxShadow(
                                    color: const Color(0xFFF97316).withValues(alpha: 0.15),
                                    blurRadius: 8,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty
                            ? String.fromCharCode(
                                name.runes.first,
                              ).toUpperCase()
                            : 'A',
                        style: AppTypography.bricolageGrotesque15W70099(
                          color: g.frozen
                              ? Colors.white
                              : g.merlot
                              ? Colors.white
                              : (isDark ? g.ink : const Color(0xFF9A3412)),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 14),

          // ── GREETING & DISPLAY NAME ───────────────────────────────────
          Text(
            _greeting(),
            style: AscentTextStyles.homeHeadline.copyWith(
              color: g.inkSecondary,
              fontSize: 16,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: AscentTextStyles.homeTitle.copyWith(
              color: g.ink,
              fontSize: 26,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
              height: 1.15,
            ),
          ),

          const SizedBox(height: 6),

          // ── ROLE MICRO-BADGE & LABELED MIND SPACE SHORTCUT ────────────
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (role.isNotEmpty)
                AppTapArea(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/settings');
                  },
                  borderRadius: AppGeometry.roundedr6,
                  child: AppTag(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s7,
                      vertical: AppSpace.s2point5,
                    ),
                    nightDecoration: BoxDecoration(
                      color: g.claySoft,
                      borderRadius: AppGeometry.roundedr6,
                      border: Border.all(
                        color: g.clay.withValues(alpha: 0.25),
                        width: AppBorderScale.w0point8,
                      ),
                    ),
                    child: Text(
                      role,
                      style: AppTypography.jetBrainsMono105W70034(
                        color: g.clay,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

              // A quiet icon keeps personalization reachable without a second label.
              IconButton(
                tooltip: 'Customize Home',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  showHomeCustomization(context);
                },
                icon: Icon(Icons.tune_rounded, size: 19, color: g.inkSecondary),
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
      backgroundColor: AppPalette.transparent,
      builder: (ctx) {
        return AppCard(
          nightDecoration: BoxDecoration(
            color: ctx.bgSurfaceElevated,
            borderRadius: const BorderRadius.vertical(
              top: AppGeometry.radiusr24,
            ),
            border: Border.all(color: ctx.divider, width: AppBorderScale.w1),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s24,
            AppSpace.s16,
            AppSpace.s24,
            AppSpace.s32,
          ),
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
                    borderRadius: AppGeometry.roundedr2,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  AppTag(
                    width: 48,
                    height: 48,
                    nightDecoration: BoxDecoration(
                      color: g.claySoft,
                      shape: BoxShape.circle,
                      border: Border.all(color: g.edge),
                    ),
                    child: Center(
                      child: Text(
                        name.isNotEmpty
                            ? String.fromCharCode(
                                name.runes.first,
                              ).toUpperCase()
                            : 'A',
                        style: AppTypography.bricolageGrotesque20W700100(
                          color: g.ink,
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
                          style: AppTypography.bricolageGrotesque18W700101(
                            color: ctx.textPrimary,
                          ),
                        ),
                        Text(
                          role,
                          style: AppTypography.dmSans13Regular102(
                            color: ctx.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              AppDivider(color: ctx.divider, height: 1),
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
                  style: AppTypography.dmSansInheritedW600103(),
                ),
                trailing: Switch(
                  value: isDark,
                  onChanged: (val) {
                    HapticFeedback.lightImpact();
                    ref
                        .read(themeModeProvider.notifier)
                        .setThemeMode(val ? ThemeMode.dark : ThemeMode.light);
                  },
                ),
              ),

              // Full Settings Link
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.settings_outlined, color: ctx.textMuted),
                title: Text(
                  'Settings & Profile',
                  style: AppTypography.dmSansInheritedW600103(),
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
      backgroundColor: AppPalette.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return AppCard(
          nightDecoration: BoxDecoration(
            color: ctx.bgSurfaceElevated,
            borderRadius: const BorderRadius.vertical(
              top: AppGeometry.radiusr24,
            ),
            border: Border.all(color: ctx.divider, width: AppBorderScale.w1),
          ),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s20,
            AppSpace.s16,
            AppSpace.s20,
            AppSpace.s32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: ctx.divider,
                  borderRadius: AppGeometry.roundedr2,
                ),
              ),
              const SizedBox(height: 20),
              AppTag(
                width: 64,
                height: 64,
                nightDecoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: g.claySoft,
                  border: Border.all(
                    color: g.clay.withValues(alpha: 0.5),
                    width: AppBorderScale.w1point5,
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
                streak > 0
                    ? '$streak Day${streak == 1 ? '' : 's'} Active'
                    : 'Start your first study day',
                textAlign: TextAlign.center,
                style: AppStateTypography.stateType25(
                  state0: streak > 0,
                  color: ctx.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                streak > 0
                    ? 'Your study time builds this streak. Check Home for today’s progress.'
                    : 'Complete 120 minutes of study to begin. Quick Todos do not count as study time.',
                textAlign: TextAlign.center,
                style: AppTypography.dmSans13Regular105(color: ctx.textMuted),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    Navigator.of(ctx).pop();
                  },
                  style: context.surfaces.buttonStyle(
                    FilledButton.styleFrom(
                      backgroundColor: g.clay,
                      foregroundColor: AppPalette.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: AppGeometry.roundedr12,
                      ),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpace.s13,
                      ),
                    ),
                    filled: true,
                    icon: false,
                  ),
                  child: Text(
                    'Keep Going',
                    style: AppTypography.dmSans14W600106(),
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

class _HomeHeaderRow extends StatelessWidget {
  const _HomeHeaderRow({required this.date, required this.actions});
  final Widget date;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    if (context.isDark || MediaQuery.textScalerOf(context).scale(13) > 17) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          date,
          SizedBox(height: s.spacing),
          Wrap(
            key: const ValueKey('home_header_actions'),
            alignment: WrapAlignment.end,
            spacing: s.spacing,
            runSpacing: s.spacing,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 2, child: date),
        SizedBox(width: s.spacing),
        Expanded(
          flex: 5,
          child: Row(
            key: const ValueKey('home_header_actions'),
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) SizedBox(width: s.spacing),
                if (i == actions.length - 1)
                  actions[i]
                else
                  Flexible(child: actions[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
