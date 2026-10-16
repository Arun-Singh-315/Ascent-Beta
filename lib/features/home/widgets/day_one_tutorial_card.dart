import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/feature_guide.dart';
import '../../today/add_activity_sheet.dart';

/// Lightweight, dismissible Day-1 Quick Start Guide.
/// Replaces the old blocking modal dialog with a zero-freeze, ambient glass card
/// that introduces the core mental model of Ascent on first launch.
class DayOneTutorialCard extends ConsumerStatefulWidget {
  final String userName;

  const DayOneTutorialCard({super.key, required this.userName});

  @override
  ConsumerState<DayOneTutorialCard> createState() => _DayOneTutorialCardState();
}

class _DayOneTutorialCardState extends ConsumerState<DayOneTutorialCard> {
  bool _dismissed = false;

  static const String _prefKey = 'ascent_day_one_tutorial_v2_dismissed';

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _dismissed = prefs.getBool(_prefKey) ?? false;
  }

  void _dismissTutorial() {
    HapticFeedback.lightImpact();
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool(_prefKey, true);
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryButtonFg = isDark ? context.textOnPrimary : AppPalette.white;
    final firstName = widget.userName.trim().split(' ').first;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s14),
      child: GlassSurface(
        radius: 20,
        padding: const EdgeInsets.all(AppSpace.s18),
        customBorder: Border.all(
          color: g.clay.withValues(alpha: 0.35),
          width: AppBorderScale.w1point1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Tag badge + close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                AppTag(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s9,
                    vertical: AppSpace.s3point5,
                  ),
                  nightDecoration: BoxDecoration(
                    color: g.claySoft,
                    borderRadius: AppGeometry.roundedr8,
                    border: Border.all(
                      color: g.clay.withValues(alpha: 0.3),
                      width: AppBorderScale.w0point8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 12, color: g.clay),
                      const SizedBox(width: 5),
                      Text(
                        'QUICK START GUIDE',
                        style: AppTypography.jetBrainsMono10W700117(
                          color: g.clay,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: g.inkMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Dismiss guide',
                  onPressed: _dismissTutorial,
                ),
              ],
            ),
            const SizedBox(height: 12),

            TextButton.icon(
              onPressed: () => showAscentTour(context),
              icon: const Icon(Icons.touch_app_outlined),
              label: const Text(
                'Start guided tour · try features step by step',
              ),
            ),

            // Greeting
            Text(
              firstName.isEmpty
                  ? 'Welcome to your space! Here\'s how Ascent works:'
                  : 'Welcome, $firstName! Here\'s how Ascent works:',
              style: AppTypography.plusJakartaSans155W700118(color: g.ink),
            ),
            const SizedBox(height: 12),

            // 3 Quick Points
            _tutorialRow(
              icon: Icons.check_circle_outline_rounded,
              iconColor: g.sage,
              title: 'To-Dos vs. Timed Focus',
              description:
                  'Quick tasks have checkboxes. Long study sessions have dedicated focus clocks.',
              g: g,
            ),
            const SizedBox(height: 10),

            _tutorialRow(
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: g.clay,
              title: 'Riya AI Gateway',
              description:
                  'Tap the glowing Riya button above to plan your day or ask anything naturally.',
              g: g,
            ),
            const SizedBox(height: 10),

            _tutorialRow(
              icon: Icons.school_outlined,
              iconColor: g.slate,
              title: 'Learning Hub & Consistency',
              description:
                  'Track your structured course syllabus and build an uninterrupted daily streak.',
              g: g,
            ),
            const SizedBox(height: 16),

            // Actions row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: context.surfaces.buttonStyle(
                      ElevatedButton.styleFrom(
                        backgroundColor: g.clay,
                        foregroundColor: primaryButtonFg,
                        disabledBackgroundColor: g.clay.withValues(alpha: 0.38),
                        disabledForegroundColor:
                            primaryButtonFg.withValues(alpha: 0.4),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: AppGeometry.roundedr12,
                        ),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.s10,
                        ),
                        minimumSize: const Size(64, 40),
                      ),
                      filled: true,
                      icon: false,
                    ),
                    onPressed: () {
                      _dismissTutorial();
                      AddActivitySheet.show(context);
                    },
                    child: const Text(
                      'Add First Activity 🚀',
                      style: AppTypeRoles.typeRole38,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: context.surfaces.buttonStyle(
                    OutlinedButton.styleFrom(
                      side: BorderSide(color: g.edge),
                      shape: RoundedRectangleBorder(
                        borderRadius: AppGeometry.roundedr12,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s16,
                        vertical: AppSpace.s10,
                      ),
                      foregroundColor: g.ink,
                      minimumSize: const Size(64, 40),
                    ),
                    filled: false,
                    icon: false,
                  ),
                  onPressed: _dismissTutorial,
                  child: const Text(
                    'Got it! 👍',
                    style: AppTypeRoles.typeRole42,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tutorialRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required AscentGlass g,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppTag(
          padding: const EdgeInsets.all(AppSpace.s6),
          nightDecoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.plusJakartaSans125W600119(color: g.ink),
              ),
              const SizedBox(height: 1),
              Text(
                description,
                style: AppTypeRoles.typeRole23.copyWith(
                  color: g.inkMuted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
