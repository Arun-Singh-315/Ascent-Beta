import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/glass_theme.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/ascent_scaffold.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final profileAsync = ref.watch(userProfileStreamProvider);

    return AscentScaffold(
      title: 'More',
      subtitle: 'Ascent modules & hubs',
      showBackButton: false,
      glow2: g.claySoft,
      body: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s16,
          vertical: AppSpace.s8,
        ),
        children: [
          // ── 1. Profile & Account Card ─────────────────────────────────────
          profileAsync.when(
            loading: () => const SizedBox(height: 76),
            error: (_, _) => const SizedBox(),
            data: (profile) {
              final name = profile?.name.isNotEmpty == true
                  ? profile!.name
                  : 'Learner';
              final role = profile?.targetRole.isNotEmpty == true
                  ? profile!.targetRole
                  : 'Job Seeker';
              final initial = name.isNotEmpty
                  ? name.substring(0, 1).toUpperCase()
                  : 'A';

              return AscentCard(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/settings');
                },
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s16,
                  vertical: AppSpace.s14,
                ),
                child: Row(
                  children: [
                    AppTag(
                      width: 50,
                      height: 50,
                      nightDecoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: g.claySoft,
                        border: Border.all(
                          color: g.clay.withValues(alpha: 0.3),
                          width: AppBorderScale.w1point2,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        initial,
                        style: AscentTextStyles.displaySmall
                            .copyWith(color: g.clay)
                            .merge(AppTypeRoles.typeRole11),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: AscentTextStyles.labelLarge
                                .copyWith(color: g.ink)
                                .merge(AppTypeRoles.typeRole57),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            role,
                            style: AscentTextStyles.bodySmall
                                .copyWith(color: g.inkMuted)
                                .merge(AppTypeRoles.typeRole58),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s12,
                        vertical: AppSpace.s6,
                      ),
                      nightDecoration: BoxDecoration(
                        color: g.fill,
                        borderRadius: AppGeometry.roundedr20,
                        border: Border.all(
                          color: g.edge,
                          width: AppBorderScale.w0point8,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.tune_rounded, size: 14, color: g.clay),
                          const SizedBox(width: 6),
                          Text(
                            'Edit',
                            style: AscentTextStyles.labelSmall
                                .copyWith(color: g.ink)
                                .merge(AppTypeRoles.typeRole8),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 22),

          // ── 2. Intelligence & Mind ────────────────────────────────────────
          _GroupHeader(title: 'INTELLIGENCE & ASSISTANT', dotColor: g.clay),
          AscentCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MoreListTile(
                  icon: Icons.auto_awesome_rounded,
                  iconTint: g.clay,
                  title: 'AI Life Assistant & Planner',
                  subtitle:
                      'On-device planner, natural-language logger & insights',
                  route: '/ai-assistant',
                ),
                _TileDivider(),
                _MoreListTile(
                  icon: Icons.bubble_chart_rounded,
                  iconTint: g.frozen ? g.slate : AppPalette.colorFFEC8C38,
                  title: 'Thought Wall • Mind Space',
                  subtitle:
                      'Unfiltered self-talk, sparks, daily wins & reflections',
                  route: '/thought-wall',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── 3. Life & Activity ───────────────────────────────────────────
          _GroupHeader(title: 'LIFE & ACTIVITY', dotColor: g.coral),
          AscentCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MoreListTile(
                  icon: Icons.directions_walk_rounded,
                  iconTint: g.sage,
                  title: 'Walk & Run Outdoor Tracker',
                  subtitle:
                      'Live GPS route telemetry, cadence, steps & endurance',
                  route: '/walk',
                ),
                _TileDivider(),
                _MoreListTile(
                  icon: Icons.medication_rounded,
                  iconTint: g.clay,
                  title: 'Medicine & Prescriptions',
                  subtitle: 'Daily dose schedules, timing reminders & tracking',
                  route: '/medicine',
                ),
                _TileDivider(),
                _MoreListTile(
                  icon: Icons.view_kanban_outlined,
                  iconTint: g.amber,
                  title: 'Job Pipeline Kanban',
                  subtitle:
                      'Applications, interview stages, offers & compensation',
                  route: '/pipeline',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── 4. Study & Career Hub ─────────────────────────────────────────
          _GroupHeader(title: 'STUDY & CAREER', dotColor: g.slate),
          AscentCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MoreListTile(
                  icon: Icons.alt_route_rounded,
                  iconTint: g.slate,
                  title: 'Study Plan & Roadmap',
                  subtitle:
                      'Phase progress, weekly targets & curriculum pacing',
                  route: '/study-plan',
                ),
                _TileDivider(),
                _MoreListTile(
                  icon: Icons.code_rounded,
                  iconTint: g.clay,
                  title: 'DSA Tracker',
                  subtitle:
                      'Logged algorithms, topic mastery & spaced revisits',
                  route: '/dsa',
                ),
                _TileDivider(),
                _MoreListTile(
                  icon: Icons.psychology_outlined,
                  iconTint: g.frozen ? g.slate : AppPalette.colorFFE79D5C,
                  title: 'Interview Prep Bank',
                  subtitle: 'Question logs, company notes & behavioral rounds',
                  route: '/interview-prep',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── 5. Tracking & Productivity ────────────────────────────────────
          _GroupHeader(title: 'TRACKING & PRODUCTIVITY', dotColor: g.sage),
          AscentCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MoreListTile(
                  icon: Icons.calendar_month_outlined,
                  iconTint: g.sage,
                  title: 'Consistency Heatmap',
                  subtitle:
                      'Daily study presence, streak records & activity logs',
                  route: '/consistency',
                ),
                _TileDivider(),
                _MoreListTile(
                  icon: Icons.notifications_none_rounded,
                  iconTint: g.amber,
                  title: 'Reminders & Alerts',
                  subtitle: 'Upcoming rounds, scheduled tasks & study alarms',
                  route: '/reminders',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── 6. Documents & Insights ───────────────────────────────────────
          _GroupHeader(title: 'DOCUMENTS & INSIGHTS', dotColor: g.amber),
          AscentCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _MoreListTile(
                  icon: Icons.description_outlined,
                  iconTint: g.clay,
                  title: 'Resume Vault',
                  subtitle: 'Tailored versions, role mappings & targeted PDFs',
                  route: '/resume-vault',
                ),
                _TileDivider(),
                _MoreListTile(
                  icon: Icons.insights_rounded,
                  iconTint: g.slate,
                  title: 'Analytics & Trends',
                  subtitle: 'Skill radar, study hours & conversion funnel',
                  route: '/analytics',
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),

          // ── 7. Preferences ───────────────────────────────────────────────
          _GroupHeader(title: 'SYSTEM & PREFERENCES', dotColor: g.inkMuted),
          AscentCard(
            padding: EdgeInsets.zero,
            child: _MoreListTile(
              icon: Icons.tune_rounded,
              iconTint: g.inkMuted,
              title: 'Settings',
              subtitle: 'Theme, study goals, notifications & data backup',
              route: '/settings',
            ),
          ),
          const SizedBox(height: 36),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  final Color dotColor;

  const _GroupHeader({required this.title, required this.dotColor});

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(left: AppSpace.s4, bottom: AppSpace.s8),
      child: Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(shape: BoxShape.circle, color: dotColor),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: AscentTextStyles.labelSmall
                .copyWith(color: g.inkMuted, letterSpacing: 0.9)
                .merge(AppTypeRoles.typeRole31),
          ),
        ],
      ),
    );
  }
}

class _MoreListTile extends StatelessWidget {
  final IconData icon;
  final Color iconTint;
  final String title;
  final String subtitle;
  final String route;

  const _MoreListTile({
    required this.icon,
    required this.iconTint,
    required this.title,
    required this.subtitle,
    required this.route,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return Material(
      color: AppPalette.transparent,
      child: AppTapArea(
        onTap: () {
          HapticFeedback.lightImpact();
          context.push(route);
        },
        borderRadius: AppGeometry.roundedr16,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s16,
            vertical: AppSpace.s13,
          ),
          child: Row(
            children: [
              AppCard(
                width: 40,
                height: 40,
                nightDecoration: BoxDecoration(
                  color: iconTint.withValues(alpha: 0.12),
                  borderRadius: AppGeometry.roundedr12,
                  border: Border.all(
                    color: iconTint.withValues(alpha: 0.18),
                    width: AppBorderScale.w0point8,
                  ),
                ),
                child: Icon(icon, color: iconTint, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AscentTextStyles.labelMedium
                          .copyWith(color: g.ink)
                          .merge(AppTypeRoles.typeRole32),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: AscentTextStyles.bodySmall
                          .copyWith(color: g.inkMuted)
                          .merge(AppTypeRoles.typeRole27),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: g.inkMuted.withValues(alpha: 0.5),
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TileDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return AppDivider(
      height: 1,
      thickness: 0.8,
      color: g.line,
      indent: 56,
      endIndent: 12,
    );
  }
}
