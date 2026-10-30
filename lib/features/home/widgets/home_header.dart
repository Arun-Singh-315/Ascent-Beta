import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/day_palette.dart';
import '../../../app/theme/frozen_palette.dart';
import '../../../app/theme/merlot_palette.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/settings_provider.dart';
import '../../ai_assistant/ai_assistant_screen.dart';
import '../home_customization_sheet.dart';
import '../../../core/services/cosmic_profile_service.dart';

/// A quiet greeting, with secondary controls kept out of the content hierarchy.
class HomeHeader extends ConsumerWidget {
  const HomeHeader({super.key, required this.profile});
  final UserProfile? profile;

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final name = profile?.name.isNotEmpty == true
        ? profile!.name
        : 'Your space';
    final role = profile?.targetRole ?? '';
    final assistantName = ref.watch(assistantNameProvider);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeHeaderRow(
            date: Text(
              DateFormat('EEE, d MMM').format(DateTime.now()),
              key: const ValueKey('home_date'),
              style: AscentTextStyles.homeCaption.copyWith(
                color: g.ink,
                fontWeight: FontWeight.w700,
                letterSpacing: .3,
              ),
            ),
            actions: [
              FilledButton.icon(
                key: const ValueKey('home_assistant_button'),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  AiAssistantScreen.showFromHome(context);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  backgroundColor: context.isDark
                      ? SharedControlColors.actionBlue.withValues(alpha: 0.14)
                      : Colors.white,
                  foregroundColor: context.isDark
                      ? SharedControlColors.actionBlueDark
                      : SharedControlColors.actionBlue,
                  side: BorderSide(
                    color: SharedControlColors.actionBlue.withValues(
                      alpha: context.isDark ? 0.6 : 0.45,
                    ),
                    width: 1.2,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  textStyle: AscentTextStyles.homeSecondary.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: Icon(
                  Icons.auto_awesome,
                  size: 16,
                  color: context.isDark
                      ? SharedControlColors.actionBlueDark
                      : SharedControlColors.actionBlue,
                ),
                label: Text(
                  'Ask $assistantName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isDark
                            ? g.fill
                            : (g.merlot
                                  ? MerlotPalette.surface
                                  : (g.frozen
                                        ? FrozenPalette.surface
                                        : DayPalette.surface)),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isDark
                              ? g.edge
                              : (g.merlot
                                    ? MerlotPalette.line
                                    : (g.frozen
                                          ? FrozenPalette.line
                                          : DayPalette.line)),
                          width: g.merlot ? 0.75 : AppBorderScale.w1point0,
                        ),
                        boxShadow: isDark
                            ? null
                            : [
                                BoxShadow(
                                  color:
                                      (g.merlot
                                              ? MerlotPalette.action
                                              : (g.frozen
                                                    ? FrozenPalette.action
                                                    : DayPalette.action))
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
                                  : DayPalette.sun)
                            : (g.merlot
                                  ? MerlotPalette.action
                                  : (g.frozen
                                        ? FrozenPalette.action
                                        : DayPalette.moon)),
                      ),
                    ),
                  ),
                ),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),

              // Avatar Circle (opens profile & quick settings sheet)
              Material(
                color: AppPalette.transparent,
                child: AppTapArea(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    context.push('/settings');
                  },
                  borderRadius: AppGeometry.roundedr99,
                  child: Container(
                    width: 48,
                    height: 48,
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
                                      DayPalette.gradientStart,
                                      DayPalette.gradientEnd,
                                    ],
                                  )
                                : null),
                      color: (g.frozen || g.merlot)
                          ? null
                          : (isDark ? g.claySoft : null),
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
                            : (isDark ? g.edge : DayPalette.line),
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
                                color:
                                    (isDark
                                            ? MerlotPalette.darkAction
                                            : MerlotPalette.action)
                                        .withValues(
                                          alpha: isDark ? 0.25 : 0.20,
                                        ),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : (!isDark
                                ? [
                                    BoxShadow(
                                      color: DayPalette.action.withValues(
                                        alpha: 0.15,
                                      ),
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
                          color: g.frozen || g.merlot
                              ? Theme.of(context).colorScheme.onPrimary
                              : (isDark ? g.ink : DayPalette.deepInk),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Text(
            _greeting(),
            style: AscentTextStyles.homeBody.copyWith(color: g.inkSecondary),
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: AscentTextStyles.homeDisplay.copyWith(
              color: g.ink,
              fontSize: 28,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          if (profile?.dateOfBirth != null) ...[
            Builder(
              builder: (context) {
                const service = CosmicProfileService();
                final sign = service.getZodiac(profile!.dateOfBirth!);
                final mood = service.getDayLivingMood();
                final isBday = service.isBirthdayToday(profile!.dateOfBirth!);
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 2,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${sign.symbol} ${sign.name} · ${sign.vedicRashi}',
                            style: AscentTextStyles.labelMedium.copyWith(
                              color: g.ink,
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: BoxDecoration(
                                  color: mood.livingTint,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                sign.element.label,
                                style: AscentTextStyles.labelSmall.copyWith(
                                  color: g.inkMuted,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          if (isBday)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: g.claySoft,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                '🎉 Birthday',
                                style: AscentTextStyles.labelSmall.copyWith(
                                  color: g.clay,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 10,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Customize Home',
                      onPressed: () {
                        HapticFeedback.lightImpact();
                        showHomeCustomization(context);
                      },
                      icon: Icon(
                        Icons.dashboard_customize_outlined,
                        size: 19,
                        color: g.inkMuted,
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 44,
                        minHeight: 44,
                      ),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                );
              },
            ),
          ] else ...[
            Row(
              children: [
                if (role.isNotEmpty && role.toLowerCase() != 'inner peace')
                  Expanded(
                    child: Text(
                      role,
                      style: AscentTextStyles.homeSecondary.copyWith(
                        color: g.inkMuted,
                      ),
                    ),
                  )
                else
                  const Spacer(),
                IconButton(
                  tooltip: 'Customize Home',
                  onPressed: () {
                    HapticFeedback.lightImpact();
                    showHomeCustomization(context);
                  },
                  icon: Icon(
                    Icons.dashboard_customize_outlined,
                    size: 19,
                    color: g.inkMuted,
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 48,
                    minHeight: 48,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 320 ||
            MediaQuery.textScalerOf(context).scale(13) > 17) {
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
                    if (i == 0) Flexible(child: actions[i]) else actions[i],
                  ],
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
