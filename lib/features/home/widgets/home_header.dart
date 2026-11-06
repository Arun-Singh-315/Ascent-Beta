import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/home_layout_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/streak/study_streak_provider.dart';
import '../home_customization_sheet.dart';
import '../../../core/services/cosmic_profile_service.dart';

/// A quiet greeting, with dynamic live day-cycle indicator and fluid typography.
class HomeHeader extends ConsumerStatefulWidget {
  const HomeHeader({super.key, required this.profile});
  final UserProfile? profile;

  @override
  ConsumerState<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends ConsumerState<HomeHeader>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    final inTest = WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!inTest) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  (String, IconData, Color, String) _getDayPeriodInfo(int hour) {
    if (hour >= 5 && hour < 12) {
      return (
        'Good morning,',
        Icons.wb_twilight_rounded,
        const Color(0xFFE59834),
        'Morning focus',
      );
    } else if (hour >= 12 && hour < 17) {
      return (
        'Good afternoon,',
        Icons.wb_sunny_rounded,
        const Color(0xFFD97706),
        'Peak hours',
      );
    } else if (hour >= 17 && hour < 21) {
      return (
        'Good evening,',
        Icons.wb_twilight_rounded,
        const Color(0xFFC05621),
        'Golden hour',
      );
    } else {
      return (
        'Good night,',
        Icons.nights_stay_rounded,
        const Color(0xFF6366F1),
        'Quiet hours',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final profile = widget.profile;
    final name = profile?.name.isNotEmpty == true
        ? profile!.name
        : 'Your space';
    final role = profile?.targetRole ?? '';
    final now = DateTime.now();
    final (greeting, periodIcon, periodColor, periodSubtitle) =
        _getDayPeriodInfo(now.hour);
    final assistantName = ref.watch(assistantNameProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _HomeHeaderRow(
            date: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Live breathing day-cycle indicator dot
                AnimatedBuilder(
                  animation: _pulseController,
                  builder: (context, _) {
                    final scale = 0.85 + (_pulseController.value * 0.3);
                    return Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: periodColor,
                        boxShadow: [
                          BoxShadow(
                            color: periodColor.withValues(
                              alpha: 0.35 + (_pulseController.value * 0.35),
                            ),
                            blurRadius: 4 * scale,
                            spreadRadius: 1 * scale,
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(width: 7),
                Text(
                  DateFormat('EEE, d MMM').format(now),
                  key: const ValueKey('home_date'),
                  style: AscentTextStyles.homeCaption.copyWith(
                    color: g.inkMuted,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .3,
                  ),
                ),
                Builder(
                  builder: (context) {
                    final studyStreak = ref.watch(studyStreakProvider);
                    final currentStreak =
                        ref.watch(currentStreakStreamProvider).value ?? 0;
                    final streak =
                        math.max(studyStreak.displayStreakDays, currentStreak);
                    final isStreakCardVisible =
                        ref.watch(homeStreakVisibleProvider);
                    if (streak <= 0) return const SizedBox.shrink();
                    return GestureDetector(
                      onTap: () async {
                        HapticFeedback.lightImpact();
                        final layout = ref.read(homeLayoutProvider);
                        final visible = {...layout.visible};
                        isStreakCardVisible
                            ? visible.remove('streak')
                            : visible.add('streak');
                        try {
                          await ref
                              .read(homeLayoutProvider.notifier)
                              .save(layout.copyWith(visible: visible));
                        } catch (_) {}
                        ref.read(studyStreakCardVisibleProvider.notifier).toggle();
                      },
                      child: Container(
                        margin: const EdgeInsets.only(left: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE28B57).withValues(
                            alpha: context.isDark ? 0.22 : 0.14,
                          ),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0xFFE28B57).withValues(alpha: 0.5),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.local_fire_department_rounded,
                              size: 12,
                              color: Color(0xFFE28B57),
                            ),
                            const SizedBox(width: 3),
                            Text(
                              '$streak',
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFE28B57),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            actions: [
              // Apple-Style Quick Theme Morph Button
              Material(
                color: Colors.transparent,
                child: Tooltip(
                  message: context.isDark ? 'Switch to Day mode' : 'Switch to Night mode',
                  child: InkWell(
                    key: const ValueKey('home_day_night_toggle'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      final nextMode = context.isDark ? ThemeMode.light : ThemeMode.dark;
                      ref.read(themeModeProvider.notifier).setThemeMode(nextMode);
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: g.fill.withValues(alpha: context.isDark ? 0.35 : 0.65),
                        border: Border.all(
                          color: g.line.withValues(alpha: context.isDark ? 0.5 : 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          transitionBuilder: (child, anim) => RotationTransition(
                            turns: child.key == const ValueKey('sun_icon')
                                ? Tween<double>(begin: 0.75, end: 1.0).animate(anim)
                                : Tween<double>(begin: 0.85, end: 1.0).animate(anim),
                            child: FadeTransition(opacity: anim, child: child),
                          ),
                          child: context.isDark
                              ? Icon(
                                  Icons.nights_stay_rounded,
                                  key: const ValueKey('moon_icon'),
                                  size: 18,
                                  color: g.clay,
                                )
                              : Icon(
                                  Icons.wb_sunny_rounded,
                                  key: const ValueKey('sun_icon'),
                                  size: 18,
                                  color: g.amber,
                                ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // AI Assistant Gateway Button
              Material(
                color: Colors.transparent,
                child: Tooltip(
                  message: 'Ask $assistantName',
                  child: InkWell(
                    key: const ValueKey('home_assistant_button'),
                    borderRadius: BorderRadius.circular(20),
                    onTap: () {
                      HapticFeedback.lightImpact();
                      context.push('/ai-assistant');
                    },
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: g.fill.withValues(alpha: context.isDark ? 0.35 : 0.65),
                        border: Border.all(
                          color: g.line.withValues(alpha: context.isDark ? 0.5 : 0.3),
                          width: 0.8,
                        ),
                      ),
                      child: Center(
                        child: Icon(
                          Icons.auto_awesome,
                          size: 17,
                          color: g.clay,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              // Profile avatar & settings signature
              GestureDetector(
                onTap: () {
                  HapticFeedback.lightImpact();
                  context.push('/settings');
                },
                child: Tooltip(
                  message: 'Profile and settings',
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: g.line.withValues(alpha: context.isDark ? 0.4 : 0.25),
                        width: 1.0,
                      ),
                    ),
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
              ),
            ],
          ),
          const SizedBox(height: 18),
          // Dynamic greeting with ambient time-of-day badge
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                greeting,
                style: AscentTextStyles.homeBody.copyWith(
                  color: g.inkSecondary,
                  fontSize: 14.0,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                decoration: BoxDecoration(
                  color: periodColor.withValues(alpha: context.isDark ? 0.2 : 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: periodColor.withValues(alpha: context.isDark ? 0.35 : 0.25),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(periodIcon, size: 11, color: periodColor),
                    const SizedBox(width: 4),
                    Text(
                      periodSubtitle,
                      style: GoogleFonts.inter(
                        color: periodColor,
                        fontSize: 10.5,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            name,
            style: AscentTextStyles.homeDisplay.copyWith(
              color: g.ink,
              fontSize: 32,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.8,
              height: 1.15,
            ),
          ),
          const SizedBox(height: 6),
          if (profile?.dateOfBirth != null) ...[
            Builder(
              builder: (context) {
                const service = CosmicProfileService();
                final sign = service.getZodiac(profile!.dateOfBirth!);
                final mood = service.getDayLivingMood();
                final isBday = service.isBirthdayToday(profile.dateOfBirth!);
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
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 280) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              date,
              const SizedBox(height: 8),
              Row(
                key: const ValueKey('home_header_actions'),
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  for (var i = 0; i < actions.length; i++) ...[
                    if (i > 0) const SizedBox(width: 10),
                    actions[i],
                  ],
                ],
              ),
            ],
          );
        }
        return Row(
          key: const ValueKey('home_header_actions'),
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Date label expands freely
            Expanded(child: date),
            const SizedBox(width: 12),
            // Minimal action dock: Sun/Moon button + Profile Avatar
            for (var i = 0; i < actions.length; i++) ...[
              if (i > 0) const SizedBox(width: 8),
              actions[i],
            ],
          ],
        );
      },
    );
  }
}
