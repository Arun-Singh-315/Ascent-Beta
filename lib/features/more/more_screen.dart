import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/providers/database_provider.dart';

class MoreScreen extends ConsumerWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileStreamProvider);

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        title: Text(
          'Explore Ascent',
          style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary),
        ),
        backgroundColor: context.bgBase,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        children: [
          // ── 1. Profile Card (Top, not buried - Spec §7) ──────────────────
          profileAsync.when(
            loading: () => const SizedBox(height: 72),
            error: (_, _) => const SizedBox(),
            data: (profile) {
              final name = profile?.name.isNotEmpty == true ? profile!.name : 'Learner';
              final role = profile?.targetRole.isNotEmpty == true ? profile!.targetRole : 'Job Seeker';
              return Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.bgSurface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.divider),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: context.accentPrimary.withValues(alpha: 0.15),
                      child: Text(
                        name.substring(0, 1).toUpperCase(),
                        style: AscentTextStyles.displaySmall.copyWith(
                          color: context.accentPrimary,
                          fontWeight: FontWeight.w700,
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
                            style: AscentTextStyles.labelLarge.copyWith(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            role,
                            style: AscentTextStyles.bodySmall.copyWith(
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () => context.push('/settings'),
                      child: Text(
                        'Edit',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: context.accentPrimary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 24),

          // ── 2. Prepare Group ─────────────────────────────────────────────
          _GroupHeader(title: 'PREPARE', color: context.accentPrimary),
          _NavItemTile(
            icon: Icons.alt_route_rounded,
            title: 'Study Plan & Roadmap',
            subtitle: 'Phase progress, weekly targets & curriculum',
            route: '/study-plan',
            color: context.accentPrimary,
          ),
          _NavItemTile(
            icon: Icons.code_rounded,
            title: 'DSA Tracker',
            subtitle: 'Logged algorithms, topic mastery & revisits',
            route: '/dsa',
            color: context.accentPrimary,
          ),
          _NavItemTile(
            icon: Icons.psychology_alt_rounded,
            title: 'Interview Prep Bank',
            subtitle: 'Question logs, company notes & outcomes',
            route: '/interview-prep',
            color: context.accentPrimary,
          ),
          const SizedBox(height: 20),

          // ── 3. Track Group ───────────────────────────────────────────────
          _GroupHeader(title: 'TRACK', color: context.accentSecondary),
          _NavItemTile(
            icon: Icons.calendar_month_rounded,
            title: 'Consistency Heatmap',
            subtitle: 'Daily study presence, streak records & logs',
            route: '/consistency',
            color: context.accentSecondary,
          ),
          _NavItemTile(
            icon: Icons.edit_note_rounded,
            title: 'Notes & Journal',
            subtitle: 'Topic recaps, quick thoughts & company insights',
            route: '/notes',
            color: context.accentSecondary,
          ),
          _NavItemTile(
            icon: Icons.notifications_active_rounded,
            title: 'Reminders & Alerts',
            subtitle: 'Upcoming rounds, tasks & study alarms',
            route: '/reminders',
            color: context.accentSecondary,
          ),
          const SizedBox(height: 20),

          // ── 4. Documents Group ───────────────────────────────────────────
          _GroupHeader(title: 'DOCUMENTS', color: context.accentInfo),
          _NavItemTile(
            icon: Icons.description_rounded,
            title: 'Resume Vault',
            subtitle: 'Tailored versions, role mappings & files',
            route: '/resume-vault',
            color: context.accentInfo,
          ),
          const SizedBox(height: 20),

          // ── 5. Insights Group ────────────────────────────────────────────
          _GroupHeader(title: 'INSIGHTS', color: context.accentPrimary),
          _NavItemTile(
            icon: Icons.insights_rounded,
            title: 'Analytics & Trends',
            subtitle: 'Skill radar, study hours & conversion funnel',
            route: '/analytics',
            color: context.accentPrimary,
          ),
          const SizedBox(height: 20),

          // ── 6. App Group ─────────────────────────────────────────────────
          _GroupHeader(title: 'PREFERENCES', color: context.textMuted),
          _NavItemTile(
            icon: Icons.settings_rounded,
            title: 'Settings',
            subtitle: 'Theme, study goals, notifications & data backup',
            route: '/settings',
            color: context.textMuted,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  final Color color;

  const _GroupHeader({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        title,
        style: AscentTextStyles.labelSmall.copyWith(
          color: color,
          letterSpacing: 1.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _NavItemTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String route;
  final Color color;

  const _NavItemTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        title: Text(
          title,
          style: AscentTextStyles.labelLarge.copyWith(
            color: context.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
        ),
        trailing: Icon(
          Icons.chevron_right_rounded,
          color: context.textMuted,
          size: 20,
        ),
        onTap: () => context.push(route),
      ),
    );
  }
}
