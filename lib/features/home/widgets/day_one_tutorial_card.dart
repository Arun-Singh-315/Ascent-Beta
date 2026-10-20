import 'dart:ui';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/frozen_palette.dart';
import '../../../app/theme/merlot_palette.dart';
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

/// Modal Pop-up Quick Start Guide.
/// Replaces the cramped inline tutorial card with an elegant, focused modal popup dialog.
class DayOneTutorialDialog extends ConsumerWidget {
  final String userName;

  const DayOneTutorialDialog({super.key, required this.userName});

  static const String prefKey = 'ascent_day_one_tutorial_v2_dismissed';

  static Future<void> show(
    BuildContext context, {
    required String userName,
  }) {
    HapticFeedback.mediumImpact();
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierColor: AppPalette.black.withValues(alpha: 0.65),
      builder: (ctx) => DayOneTutorialDialog(userName: userName),
    );
  }

  void _dismissTutorial(BuildContext context, WidgetRef ref) {
    HapticFeedback.lightImpact();
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool(prefKey, true);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryButtonFg = isDark
        ? (g.merlot ? Colors.white : context.textOnPrimary)
        : AppPalette.white;
    final firstName = userName.trim().split(' ').first;

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
      child: Dialog(
        backgroundColor: Colors.transparent,
        elevation: 0,
        insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: GlassSurface(
            radius: 24,
            fillColor: isDark
                ? (g.merlot
                    ? MerlotPalette.darkSurface
                    : (g.frozen ? FrozenPalette.darkSurface : null))
                : (g.merlot
                    ? MerlotPalette.surface
                    : (g.frozen ? FrozenPalette.surface : Colors.white)),
            padding: const EdgeInsets.all(AppSpace.s22),
            customBorder: Border.all(
              color: isDark
                  ? (g.merlot
                      ? MerlotPalette.darkLine
                      : (g.frozen ? FrozenPalette.darkLineSubtle : g.edge))
                  : (g.merlot
                      ? MerlotPalette.line
                      : (g.frozen
                          ? FrozenPalette.lineSubtle
                          : g.clay.withValues(alpha: 0.35))),
              width: (g.merlot || g.frozen) ? 0.75 : AppBorderScale.w1point1,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
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
                            Icon(
                              Icons.auto_awesome_rounded,
                              size: 13,
                              color: g.clay,
                            ),
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
                        icon: Icon(
                          Icons.close_rounded,
                          size: 20,
                          color: g.inkMuted,
                        ),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                        tooltip: 'Dismiss guide',
                        onPressed: () => _dismissTutorial(context, ref),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),

                  // Greeting
                  Text(
                    firstName.isEmpty
                        ? 'Welcome to your space! Here\'s how Ascent works:'
                        : 'Welcome, $firstName! Here\'s how Ascent works:',
                    style: AppTypography.plusJakartaSans155W700118(color: g.ink)
                        .copyWith(fontSize: 18),
                  ),
                  const SizedBox(height: 14),

                  // 3 Quick Points
                  _dialogTutorialRow(
                    icon: Icons.check_circle_outline_rounded,
                    iconColor: g.sage,
                    title: 'To-Dos vs. Timed Focus',
                    description:
                        'Quick tasks have checkboxes. Long study sessions have dedicated focus clocks.',
                    g: g,
                  ),
                  const SizedBox(height: 12),

                  _dialogTutorialRow(
                    icon: Icons.chat_bubble_outline_rounded,
                    iconColor: g.clay,
                    title: 'Riya AI Gateway',
                    description:
                        'Tap the glowing Riya button above to plan your day or ask anything naturally.',
                    g: g,
                  ),
                  const SizedBox(height: 12),

                  _dialogTutorialRow(
                    icon: Icons.school_outlined,
                    iconColor: g.slate,
                    title: 'Learning Hub & Consistency',
                    description:
                        'Track your structured course syllabus and build an uninterrupted daily streak.',
                    g: g,
                  ),
                  const SizedBox(height: 12),

                  TextButton.icon(
                    onPressed: () {
                      _dismissTutorial(context, ref);
                      showAscentTour(context);
                    },
                    icon: const Icon(Icons.touch_app_outlined, size: 18),
                    label: const Text(
                      'Start guided tour · try features step by step',
                    ),
                    style: TextButton.styleFrom(
                      foregroundColor: g.clay,
                      padding: EdgeInsets.zero,
                    ),
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
                              disabledBackgroundColor:
                                  g.clay.withValues(alpha: 0.38),
                              disabledForegroundColor:
                                  primaryButtonFg.withValues(alpha: 0.4),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: AppGeometry.roundedr12,
                              ),
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpace.s12,
                              ),
                              minimumSize: const Size(64, 44),
                            ),
                            filled: true,
                            icon: false,
                          ),
                          onPressed: () {
                            _dismissTutorial(context, ref);
                            AddActivitySheet.show(context);
                          },
                          child: const Text(
                            'Add First Activity 🚀',
                            style: TextStyle(fontWeight: FontWeight.w700),
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
                              vertical: AppSpace.s12,
                            ),
                            foregroundColor: g.ink,
                            minimumSize: const Size(64, 44),
                          ),
                          filled: false,
                          icon: false,
                        ),
                        onPressed: () => _dismissTutorial(context, ref),
                        child: const Text(
                          'Got it! 👍',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static Widget _dialogTutorialRow({
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
          padding: const EdgeInsets.all(AppSpace.s7),
          nightDecoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 16, color: iconColor),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: AppTypography.plusJakartaSans125W600119(color: g.ink)
                    .copyWith(fontSize: 14),
              ),
              const SizedBox(height: 2),
              Text(
                description,
                style: AppTypeRoles.typeRole23.copyWith(
                  color: g.inkMuted,
                  height: 1.35,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

