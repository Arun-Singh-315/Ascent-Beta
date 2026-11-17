import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/cosmic_profile_service.dart';
import '../../../core/services/festival_service.dart';
import '../../../core/streak/study_streak_provider.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'home_day_design.dart';
import 'home_weather.dart';

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

  (String, IconData, String) _getDayPeriodInfo(int hour) {
    if (hour >= 5 && hour < 12) {
      return ('Good morning,', Icons.wb_twilight_rounded, 'Morning focus');
    } else if (hour >= 12 && hour < 17) {
      return ('Good afternoon,', Icons.wb_sunny_rounded, 'Peak hours');
    } else if (hour >= 17 && hour < 21) {
      return ('Good evening,', Icons.wb_twilight_rounded, 'Golden hour');
    } else {
      return ('Good night,', Icons.nights_stay_rounded, 'Quiet hours');
    }
  }

  void _showCosmicInsightDialog(BuildContext context, ZodiacSignInfo sign) {
    final c = context.c;
    final dob = widget.profile?.dateOfBirth;
    final now = widget.now ?? DateTime.now();
    final insight = dob != null
        ? const CosmicProfileService().getDailyInsight(dob: dob, today: now)
        : null;

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: c.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Text(sign.symbol, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${sign.vedicRashi} (${sign.vedicHindi}) · ${sign.name}',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: c.textPrimary,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: c.accentTint,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${sign.element.icon} ${sign.element.label} Element · ${sign.archetype}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: c.accent,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              sign.definingEssence,
              style: TextStyle(
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: c.textPrimary,
                height: 1.4,
              ),
            ),
            if (insight != null) ...[
              const SizedBox(height: 12),
              Text(
                'Today’s Spark',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.5,
                  color: c.textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                insight.quote,
                style: TextStyle(
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                  color: c.textSecondary,
                  height: 1.35,
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildAtmosphericCard(
    BuildContext context,
    dynamic c,
    bool dark,
    ZodiacSignInfo? sign,
  ) {
    final weatherState = ref.watch(homeWeatherProvider);
    final current = weatherState.value?['current'] as Map<String, dynamic>?;
    String city = 'Bhopal';
    try {
      city = ref.watch(sharedPreferencesProvider).getString('weather_city')?.split(',').first ?? 'Bhopal';
    } catch (_) {}

    final String tempStr;
    final String descStr;
    final IconData weatherIcon;

    if (current != null) {
      final temp = (current['temperature_2m'] as num).round();
      tempStr = '$temp°';
      final code = (current['weather_code'] as num).toInt();
      descStr = weatherDescription(code);
      weatherIcon = weatherIconForCode(code);
    } else if (weatherState.hasError) {
      tempStr = '--°';
      descStr = 'Weather offline';
      weatherIcon = Icons.cloud_off_rounded;
    } else if (weatherState.isLoading) {
      tempStr = '…';
      descStr = 'Loading weather…';
      weatherIcon = Icons.wb_sunny_outlined;
    } else {
      tempStr = '28°';
      descStr = 'Clear sky';
      weatherIcon = Icons.wb_sunny_outlined;
    }

    return Container(
      key: const ValueKey('home_atmospheric_card'),
      decoration: BoxDecoration(
        color: c.surfaceAlt.withValues(alpha: dark ? 0.75 : 0.85),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: c.border.withValues(alpha: 0.8),
          width: 1,
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Left Side: Weather & Atmosphere (key: home_weather)
          Expanded(
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('home_weather'),
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  HapticFeedback.selectionClick();
                  showWeatherForecastSheet(context);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                  child: Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: c.accentTint,
                        ),
                        child: Icon(
                          weatherIcon,
                          size: 18,
                          color: c.accent,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              '$tempStr · $descStr',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                color: c.textPrimary,
                                letterSpacing: -0.1,
                              ),
                            ),
                            const SizedBox(height: 1),
                            Text(
                              '📍 $city',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: c.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (sign != null) ...[
            Container(
              width: 1,
              height: 32,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: c.border.withValues(alpha: 0.6),
            ),

            // Right Side: Celestial & Vedic Rashi (key: home_rashi)
            Expanded(
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('home_rashi'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    _showCosmicInsightDialog(context, sign);
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                    child: Row(
                      children: [
                        Container(
                          width: 34,
                          height: 34,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.warnTint,
                          ),
                          child: Text(
                            sign.symbol,
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '${sign.symbol} ${sign.vedicRashi} · ${sign.name}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: c.textPrimary,
                                  letterSpacing: -0.1,
                                ),
                              ),
                              const SizedBox(height: 1),
                              Text(
                                '${sign.element.icon} ${sign.element.label} · ${sign.archetype}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final now = widget.now ?? DateTime.now();
    final day = HomeDayDesign.at(now, dark: dark);
    final (greeting, periodIcon, periodSubtitle) = _getDayPeriodInfo(now.hour);

    final rawName = widget.profile?.name.trim() ?? '';
    final name = rawName.replaceAll(';)', '').trim();
    final initial = name.isEmpty ? 'A' : name[0].toUpperCase();
    final role = widget.profile?.targetRole.trim() ?? '';
    final dob = widget.profile?.dateOfBirth;
    final sign = dob == null ? null : const CosmicProfileService().getZodiac(dob);
    final todayFestival = ref.watch(todayFestivalProvider);
    final assistantName = ref.watch(assistantNameProvider);

    final streak = math.max(
      ref.watch(studyStreakProvider).displayStreakDays,
      ref.watch(currentStreakStreamProvider).value ?? 0,
    );
    final showStreak = streak > 0;

    final quote = todayFestival?.thought ??
        (day.cue.isNotEmpty
            ? day.cue
            : 'Rising with unwavering discipline and offering gratitude to the source of life.');

    final streakLabel = streak >= 30
        ? '$streak · Fire'
        : (streak >= 7 ? '$streak · Blaze' : '$streak');
    final streakIcon = streak >= 30
        ? Icons.whatshot_rounded
        : Icons.local_fire_department_rounded;

    return Container(
      key: const ValueKey('home_day_header'),
      padding: EdgeInsets.fromLTRB(
        16,
        MediaQuery.paddingOf(context).top + 10,
        16,
        18,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            c.headerTop,
            dark ? c.surfaceAlt : c.surface,
          ],
        ),
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.header),
        ),
        border: AppBorder.bottom(c.border.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          // Row 1: Date & Period badge (Left) | Day/Night Toggle + Profile Avatar (Right)
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Left: Date & Diurnal Period
              Expanded(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        DateFormat('EEE, d MMM').format(now),
                        key: const ValueKey('home_date'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w700,
                          color: c.textPrimary,
                          letterSpacing: -0.2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: c.accentTint,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: c.accent.withValues(alpha: 0.25),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(periodIcon, size: 11, color: c.accent),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                periodSubtitle,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                  color: c.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Right Actions: Day/Night Theme Toggle + Profile Avatar "A"
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1. Day / Night theme toggle button
                  Tooltip(
                    message: dark ? 'Switch to light theme' : 'Switch to dark theme',
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: const ValueKey('home_theme_toggle_btn'),
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          final newMode = dark ? ThemeMode.light : ThemeMode.dark;
                          ref.read(themeModeProvider.notifier).setThemeMode(newMode);
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.surfaceAlt,
                            border: Border.all(color: c.border),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 300),
                            transitionBuilder: (child, anim) => RotationTransition(
                              turns: anim,
                              child: FadeTransition(opacity: anim, child: child),
                            ),
                            child: Icon(
                              dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                              key: ValueKey(dark),
                              size: 18,
                              color: dark ? c.warn : c.textSecondary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(width: 8),

                  // 2. Profile Avatar "A" (Moved to right as requested)
                  Tooltip(
                    message: 'Profile and settings',
                    child: Material(
                      color: Colors.transparent,
                      shape: const CircleBorder(),
                      child: InkWell(
                        key: const ValueKey('home_profile_button'),
                        borderRadius: BorderRadius.circular(20),
                        onTap: () {
                          HapticFeedback.selectionClick();
                          context.push('/settings');
                        },
                        child: Container(
                          width: 38,
                          height: 38,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: c.accentTint,
                            border: Border.all(
                              color: c.accent.withValues(alpha: 0.4),
                              width: 1.5,
                            ),
                          ),
                          child: Text(
                            initial,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: c.accent,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Row 2: Greeting & Name (Oh it's your profile feel)
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                greeting,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: c.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 2),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(
                child: Text(
                  name.isEmpty ? 'Your space' : name,
                  key: const ValueKey('home_user_name'),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 27,
                    fontWeight: FontWeight.w700,
                    color: c.textPrimary,
                    height: 1.2,
                    letterSpacing: -0.5,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: c.accentTint,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: c.accent.withValues(alpha: 0.3),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.verified_rounded, size: 12, color: c.accent),
                    const SizedBox(width: 3),
                    Text(
                      'Profile',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.2,
                        color: c.accent,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (role.isNotEmpty && role.toLowerCase() != 'inner peace') ...[
            const SizedBox(height: 3),
            Text(
              role,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: c.textSecondary,
              ),
            ),
          ],

          // Row 3: Action Buttons (Ask Riya + Streak)
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              // Centralized AI Assistant Gateway button (Rule 4)
              Material(
                color: Colors.transparent,
                child: InkWell(
                  key: const ValueKey('home_assistant_button'),
                  borderRadius: BorderRadius.circular(24),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    context.push('/ai-assistant');
                  },
                  child: Container(
                    constraints: const BoxConstraints(
                      minHeight: 46,
                      minWidth: 120,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: c.accentTint,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: c.accent.withValues(alpha: 0.35),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          size: 16,
                          color: c.accent,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Ask $assistantName',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: c.accent,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // Streak Chip
              if (showStreak)
                Material(
                  color: Colors.transparent,
                  child: InkWell(
                    key: const ValueKey('home_streak_chip'),
                    borderRadius: BorderRadius.circular(24),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      ref.read(studyStreakCardVisibleProvider.notifier).toggle();
                    },
                    child: Container(
                      constraints: const BoxConstraints(minHeight: 46),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: c.surfaceAlt,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: c.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            streakIcon,
                            size: 16,
                            color: c.warn,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            streakLabel,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: c.textPrimary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),

          // Row 4: Festival Celebration Banner (if festival today)
          if (todayFestival != null) ...[
            const SizedBox(height: 10),
            Container(
              key: const ValueKey('home_festival_banner'),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: c.warnTint,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: c.warn.withValues(alpha: 0.35),
                  width: 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.celebration_rounded, size: 16, color: c.warn),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Happy ${todayFestival.name}! ✨ ${todayFestival.thought}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: c.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Row 5: Atmospheric & Celestial Showcase (Weather & Rashi synchronized)
          const SizedBox(height: 12),
          _buildAtmosphericCard(context, c, dark, sign),

          // Row 6: Quote / Day Cue
          const SizedBox(height: 12),
          Text(
            quote,
            key: const ValueKey('home_day_cue'),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 12,
              fontStyle: FontStyle.italic,
              color: c.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
