import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/providers/database_provider.dart';

/// Intent-grouped Navigation Drawer matching Spec §7:
/// Profile (top) -> Prepare -> Track -> Documents -> Insights -> App
class AscentDrawer extends ConsumerWidget {
  const AscentDrawer({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(userProfileStreamProvider);

    return Drawer(
      backgroundColor: context.bgBase,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          children: [
            // ── Profile Header ──────────────────────────────────────────
            profileAsync.when(
              loading: () => const SizedBox(height: 60),
              error: (_, _) => const SizedBox(),
              data: (profile) {

                final name = profile?.name.isNotEmpty == true ? profile!.name : 'Learner';
                final role = profile?.targetRole.isNotEmpty == true ? profile!.targetRole : 'Job Seeker';
                return Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: context.bgSurface,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: context.divider),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: context.accentPrimary.withValues(alpha: 0.15),
                        child: Text(
                          name.substring(0, 1).toUpperCase(),
                          style: AscentTextStyles.displaySmall.copyWith(
                            color: context.accentPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
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
                            Text(
                              role,
                              style: AscentTextStyles.bodySmall.copyWith(
                                color: context.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.settings_outlined, size: 20, color: context.textMuted),
                        onPressed: () {
                          Navigator.pop(context);
                          context.push('/settings');
                        },
                      ),
                    ],
                  ),
                );
              },
            ),
            const SizedBox(height: 20),

            // ── Prepare ─────────────────────────────────────────────────
            _DrawerSectionLabel(title: 'PREPARE', color: context.accentPrimary),
            _DrawerTile(
              icon: Icons.alt_route_rounded,
              label: 'Study Plan',
              route: '/study-plan',
              color: context.accentPrimary,
            ),
            _DrawerTile(
              icon: Icons.code_rounded,
              label: 'DSA Tracker',
              route: '/dsa',
              color: context.accentPrimary,
            ),
            _DrawerTile(
              icon: Icons.psychology_alt_rounded,
              label: 'Interview Prep Bank',
              route: '/interview-prep',
              color: context.accentPrimary,
            ),
            const SizedBox(height: 16),

            // ── Track ───────────────────────────────────────────────────
            _DrawerSectionLabel(title: 'TRACK', color: context.accentSecondary),
            _DrawerTile(
              icon: Icons.calendar_month_rounded,
              label: 'Consistency Heatmap',
              route: '/consistency',
              color: context.accentSecondary,
            ),
            _DrawerTile(
              icon: Icons.edit_note_rounded,
              label: 'Notes & Journal',
              route: '/notes',
              color: context.accentSecondary,
            ),
            const SizedBox(height: 16),

            // ── Documents ───────────────────────────────────────────────
            _DrawerSectionLabel(title: 'DOCUMENTS', color: context.accentInfo),
            _DrawerTile(
              icon: Icons.description_rounded,
              label: 'Resume Vault',
              route: '/resume-vault',
              color: context.accentInfo,
            ),
            const SizedBox(height: 16),

            // ── Insights ────────────────────────────────────────────────
            _DrawerSectionLabel(title: 'INSIGHTS', color: context.accentPrimary),
            _DrawerTile(
              icon: Icons.insights_rounded,
              label: 'Analytics & Insights',
              route: '/analytics',
              color: context.accentPrimary,
            ),
            const SizedBox(height: 16),

            // ── App ─────────────────────────────────────────────────────
            _DrawerSectionLabel(title: 'APP', color: context.textMuted),
            _DrawerTile(
              icon: Icons.settings_rounded,
              label: 'Settings',
              route: '/settings',
              color: context.textMuted,
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _DrawerSectionLabel extends StatelessWidget {
  final String title;
  final Color color;

  const _DrawerSectionLabel({required this.title, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 12, bottom: 6, top: 4),
      child: Text(
        title,
        style: AscentTextStyles.labelSmall.copyWith(
          color: color,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _DrawerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String route;
  final Color color;

  const _DrawerTile({
    required this.icon,
    required this.label,
    required this.route,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      dense: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      leading: Icon(icon, color: color, size: 22),
      title: Text(
        label,
        style: AscentTextStyles.labelLarge.copyWith(
          color: context.textPrimary,
          fontSize: 14,
        ),
      ),
      trailing: Icon(Icons.chevron_right_rounded, size: 18, color: context.textMuted),
      onTap: () {
        Navigator.pop(context);
        context.push(route);
      },
    );
  }
}
