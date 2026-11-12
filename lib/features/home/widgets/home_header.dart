import 'dart:async';
import '../../../app/theme/home_design.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/home_layout_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/cosmic_profile_service.dart';
import '../../../core/services/festival_service.dart';
import '../../../core/streak/study_streak_provider.dart';
import 'home_day_design.dart';
import 'home_weather.dart';
import 'home_header_scene.dart';
import 'daily_welcome_dialog.dart';
import '../../../core/services/daily_welcome_service.dart';
import '../../../core/providers/daily_briefing_provider.dart';

class HomeHeader extends ConsumerStatefulWidget {
  const HomeHeader({super.key, required this.profile, this.now});
  final UserProfile? profile;
  final DateTime? now;
  @override
  ConsumerState<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends ConsumerState<HomeHeader> {
  Timer? _minuteTimer;
  @override
  void initState() {
    super.initState();
    if (widget.now == null) {
      _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = widget.now ?? DateTime.now();
    final day = HomeDayDesign.at(now, dark: dark);
    final design = HomeDesign.of(context);
    final ink = design.primaryText;
    final secondary = design.secondaryText;
    final name = widget.profile?.name.trim() ?? '';
    final dob = widget.profile?.dateOfBirth;
    final sign = dob == null
        ? null
        : const CosmicProfileService().getZodiac(dob);
    final streak = math.max(
      ref.watch(studyStreakProvider).displayStreakDays,
      ref.watch(currentStreakStreamProvider).value ?? 0,
    );
    final showStreak = streak > 0 && ref.watch(homeStreakVisibleProvider);
    final todayFestival = ref.watch(todayFestivalProvider);

    Widget circle({
      required Key key,
      required String tooltip,
      required Widget icon,
      required VoidCallback onTap,
    }) => IconButton(
      key: key,
      tooltip: tooltip,
      onPressed: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      style: IconButton.styleFrom(
        backgroundColor: design.surface.withValues(alpha: .55),
        foregroundColor: ink,
        shape: CircleBorder(
          side: BorderSide(color: design.separator, width: .8),
        ),
        minimumSize: const Size(44, 44),
      ),
      icon: icon,
    );

    final actions = Row(
      key: const ValueKey('home_header_actions'),
      mainAxisSize: MainAxisSize.min,
      children: [
        circle(
          key: const ValueKey('home_day_night_toggle'),
          tooltip: dark ? 'Switch to Day mode' : 'Switch to Night mode',
          icon: Icon(
            dark ? Icons.dark_mode_outlined : Icons.light_mode_outlined,
            size: 22,
          ),
          onTap: () => ref
              .read(themeModeProvider.notifier)
              .setThemeMode(dark ? ThemeMode.light : ThemeMode.dark),
        ),
        const SizedBox(width: 10),
        circle(
          key: const ValueKey('home_profile_button'),
          tooltip: 'Profile and settings',
          icon: Text(
            name.isEmpty
                ? 'A'
                : String.fromCharCode(name.runes.first).toUpperCase(),
            style: AscentTextStyles.cardTitle.copyWith(
              color: ink,
              fontSize: 17,
            ),
          ),
          onTap: () => context.push('/settings'),
        ),
      ],
    );
    final date = Align(
      alignment: Alignment.centerLeft,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: design.surface.withValues(alpha: .65),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: design.separator, width: .8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.calendar_today_rounded, size: 12, color: design.secondaryText),
            const SizedBox(width: 6),
            Text(
              DateFormat('EEE, d MMM').format(now),
              key: const ValueKey('home_date'),
              style: AscentTextStyles.body.copyWith(
                color: ink,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );

    return ClipRRect(
      key: const ValueKey('home_day_header'),
      borderRadius: BorderRadius.zero,
      child: HomeHeaderScene(
        flat: true,
        now: now,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  if (MediaQuery.textScalerOf(context).scale(14) > 21 &&
                      constraints.maxWidth < 350) {
                    return Wrap(
                      spacing: 16,
                      runSpacing: 8,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [date, actions],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: date),
                      const SizedBox(width: 12),
                      actions,
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: Duration(
                  milliseconds: MediaQuery.disableAnimationsOf(context)
                      ? 0
                      : 360,
                ),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(
                    offset: Offset(0, (1 - value) * 5),
                    child: child,
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final greeting = Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              day.greeting,
                              style: HomeType.greeting.copyWith(
                                color: secondary,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              name.isEmpty ? 'Your day, your pace.' : name,
                              key: const ValueKey('home_user_name'),
                              style: HomeType.title.copyWith(color: ink),
                            ),
                          ],
                        );
                        final mark = Material(
                          color: Colors.transparent,
                          child: InkWell(
                            key: const ValueKey('home_daily_briefing'),
                            borderRadius: BorderRadius.circular(34),
                            onTap: () => DailyWelcomeDialog.show(
                              context,
                              day: briefingDay(now),
                              name: widget.profile?.name ?? '',
                            ),
                            child: SizedBox(
                              width: 68,
                              height: 68,
                              child: FittedBox(child: HomeCelestialMark(now: now)),
                            ),
                          ),
                        );
                        if (MediaQuery.textScalerOf(context).scale(14) > 21 &&
                            constraints.maxWidth < 350) {
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              greeting,
                              const SizedBox(height: 8),
                              Align(
                                alignment: Alignment.centerRight,
                                child: mark,
                              ),
                            ],
                          );
                        }
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(child: greeting),
                            const SizedBox(width: 12),
                            mark,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                    if (todayFestival != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Container(
                          key: const ValueKey('home_festival_banner'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 7,
                          ),
                          decoration: BoxDecoration(
                            color: ink.withValues(alpha: .05),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: ink.withValues(alpha: .16),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                todayFestival.emoji,
                                style: const TextStyle(fontSize: 16),
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: Text(
                                  'Happy ${todayFestival.name}! ✨',
                                  style: AscentTextStyles.labelMedium.copyWith(
                                    color: ink,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    if (sign != null || showStreak)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Wrap(
                          spacing: 14,
                          runSpacing: 8,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            if (sign != null)
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 22,
                                    height: 22,
                                    alignment: Alignment.center,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: design.learningInk,
                                    ),
                                    child: Text(
                                      sign.symbol,
                                      textScaler: TextScaler.noScaling,
                                      style: TextStyle(
                                        fontFamily: 'AscentZodiacSymbols',
                                        fontSize: 15,
                                        color: design.canvas,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Flexible(
                                    child: Text(
                                      '${sign.name} · ${sign.vedicRashi} · ${sign.element.label}',
                                      key: const ValueKey('home_rashi'),
                                      style: AscentTextStyles.labelMedium
                                          .copyWith(
                                            color: ink,
                                            fontWeight: FontWeight.w500,
                                            fontSize: 12,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            if (showStreak)
                              Text(
                                '$streak day streak',
                                style: AscentTextStyles.labelSmall.copyWith(
                                  color: secondary,
                                ),
                              ),
                          ],
                        ),
                      ),
                    Text(
                      todayFestival != null ? todayFestival.thought : day.cue,
                      key: const ValueKey('home_day_cue'),
                      style: AscentTextStyles.bodySmall.copyWith(
                        color: secondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const HomeWeather(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
