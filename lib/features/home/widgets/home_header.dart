import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/settings_provider.dart';
import '../home_customization_sheet.dart';
import '../../../core/services/cosmic_profile_service.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';

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
              // Toggle — width set precisely at the row level in _HomeHeaderRow
              AscentSegmentedControl<ThemeMode>(
                key: const ValueKey('home_day_night_toggle'),
                accented: true,
                segments: const [
                  AscentSegment(
                    value: ThemeMode.light,
                    label: 'Day',
                    icon: Icons.wb_sunny_rounded,
                  ),
                  AscentSegment(
                    value: ThemeMode.dark,
                    label: 'Night',
                    icon: Icons.nights_stay_rounded,
                  ),
                ],
                selected: context.isDark ? ThemeMode.dark : ThemeMode.light,
                onChanged: (mode) =>
                    ref.read(themeModeProvider.notifier).setThemeMode(mode),
              ),
              // Profile avatar — compact 32dp tap target
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/settings');
                },
                child: Tooltip(
                  message: 'Profile and settings',
                  child: CircleAvatar(
                    key: const ValueKey('home_profile_button'),
                    radius: 16,
                    backgroundColor: g.claySoft,
                    foregroundColor: g.ink,
                    child: Text(
                      name.isNotEmpty
                          ? String.fromCharCode(name.runes.first).toUpperCase()
                          : 'A',
                      style: AscentTextStyles.labelMedium.copyWith(
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
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
                children: [
                  SizedBox(
                    width: 140,
                    child: actions[0],
                  ),
                  if (actions.length > 1) actions[1],
                ],
              ),
            ],
          );
        }
        return Row(
          key: const ValueKey('home_header_actions'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Date label gets remaining space after the actions
            Expanded(child: date),
            const SizedBox(width: 8),
            // Sized toggle — Day/Night toggle with fixed width
            SizedBox(
              width: 140,
              child: actions[0],
            ),
            const SizedBox(width: 8),
            // Avatar — compact fixed size tap target
            actions[1],
          ],
        );
      },
    );
  }
}
