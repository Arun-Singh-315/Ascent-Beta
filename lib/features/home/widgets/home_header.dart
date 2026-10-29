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
import '../../ai_assistant/ai_assistant_screen.dart';

/// Home greeting and responsive date, assistant, theme, and profile controls.
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
    final assistantName = ref.watch(assistantNameProvider);

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
              FilledButton.icon(
                key: const ValueKey('home_assistant_button'),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  AiAssistantScreen.showFromHome(context);
                },
                style: FilledButton.styleFrom(
                  minimumSize: const Size(48, 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                ),
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
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
                                  color:
                                      (g.merlot
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
                                      Color(0xFFFFEDD5),
                                      Color(0xFFFED7AA),
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
                                      color: const Color(
                                        0xFFF97316,
                                      ).withValues(alpha: 0.15),
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
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
            ],
          ),
          const SizedBox(height: 24),
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
        if (constraints.maxWidth < 360 ||
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
      },
    );
  }
}
