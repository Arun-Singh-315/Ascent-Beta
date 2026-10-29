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
              DateFormat('EEE, d MMM').format(DateTime.now()).toUpperCase(),
              key: const ValueKey('home_date'),
              style: AscentTextStyles.homeCaption.copyWith(
                color: g.inkMuted,
                letterSpacing: 1,
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
                    horizontal: 12,
                    vertical: 10,
                  ),
                  backgroundColor: g.claySoft,
                  foregroundColor: g.ink,
                  textStyle: AscentTextStyles.homeSecondary.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                icon: Icon(
                  Icons.auto_awesome_outlined,
                  size: 17,
                  color: g.clay,
                ),
                label: Text(
                  'Ask $assistantName',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: context.isDark
                    ? 'Switch to Luminous Day Theme'
                    : 'Switch to Night Glass Theme',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  ref
                      .read(themeModeProvider.notifier)
                      .setThemeMode(
                        context.isDark ? ThemeMode.light : ThemeMode.dark,
                      );
                },
                icon: Icon(
                  context.isDark
                      ? Icons.light_mode_outlined
                      : Icons.dark_mode_outlined,
                  size: 20,
                  color: g.inkSecondary,
                ),
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              ),
              IconButton(
                tooltip: 'Profile and settings',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.push('/settings');
                },
                constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
                icon: CircleAvatar(
                  radius: 18,
                  backgroundColor: g.claySoft,
                  foregroundColor: g.ink,
                  child: Text(
                    name.isNotEmpty
                        ? String.fromCharCode(name.runes.first).toUpperCase()
                        : 'A',
                    style: AscentTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.w600,
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
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
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
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: 'Customize Home',
                          onPressed: () {
                            HapticFeedback.lightImpact();
                            showHomeCustomization(context);
                          },
                          icon: Icon(Icons.tune_rounded, size: 19, color: g.inkMuted),
                          constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isBday
                          ? '🎉 Happy Birthday! A radiant new solar cycle begins today.'
                          : '“${sign.definingEssence}”',
                      style: AscentTextStyles.bodySmall.copyWith(
                        color: g.inkSecondary,
                        fontSize: 12.5,
                        fontStyle: FontStyle.italic,
                        height: 1.35,
                        letterSpacing: 0.1,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
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
                  icon: Icon(Icons.tune_rounded, size: 19, color: g.inkMuted),
                  constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
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
