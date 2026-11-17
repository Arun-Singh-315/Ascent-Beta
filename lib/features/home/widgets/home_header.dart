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
import 'home_assistant_hero_card.dart';
import 'home_day_design.dart';
import 'home_weather.dart';

class HomeHeader extends ConsumerStatefulWidget {
  const HomeHeader({
    super.key,
    required this.profile,
    this.now,
    this.includeAssistant = true,
  });
  final UserProfile? profile;
  final DateTime? now;
  final bool includeAssistant;

  @override
  ConsumerState<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends ConsumerState<HomeHeader>
    with SingleTickerProviderStateMixin {
  Timer? _minuteTimer;
  late final AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    );
    final inTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!inTest) {
      _animController.repeat();
    }
    if (widget.now == null) {
      _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  @override
  void dispose() {
    _minuteTimer?.cancel();
    _animController.dispose();
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

  Widget _buildFloatingPillsRow(
    BuildContext context,
    dynamic c,
    bool dark,
    ZodiacSignInfo? sign,
    int streak,
    bool showStreak,
    String streakLabel,
    IconData streakIcon,
  ) {
    final weatherState = ref.watch(homeWeatherProvider);
    final current = weatherState.value?['current'] as Map<String, dynamic>?;
    String city = 'Local';
    try {
      final configured =
          ref.watch(sharedPreferencesProvider).getString('weather_city');
      if (configured != null && configured.trim().isNotEmpty) {
        city = configured.split(',').first.trim();
      }
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
      descStr = 'Offline';
      weatherIcon = Icons.cloud_off_rounded;
    } else if (weatherState.isLoading) {
      tempStr = '…';
      descStr = 'Syncing';
      weatherIcon = Icons.wb_sunny_outlined;
    } else {
      tempStr = '--°';
      descStr = 'Weather';
      weatherIcon = Icons.wb_sunny_outlined;
    }

    final pillBg = c.surfaceAlt.withValues(alpha: dark ? 0.45 : 0.65);
    final pillBorder = Border.all(
      color: c.border.withValues(alpha: dark ? 0.75 : 0.85),
      width: 1,
    );

    return Container(
      key: const ValueKey('home_atmospheric_card'),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 1. Floating Weather & Temperature Pill
          Material(
            color: Colors.transparent,
            child: InkWell(
              key: const ValueKey('home_weather'),
              borderRadius: BorderRadius.circular(20),
              onTap: () {
                HapticFeedback.selectionClick();
                showWeatherForecastSheet(context);
              },
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: math.max(
                    0.0,
                    MediaQuery.sizeOf(context).width - 32,
                  ),
                ),
                padding:
                    const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: pillBg,
                  borderRadius: BorderRadius.circular(20),
                  border: pillBorder,
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(weatherIcon, size: 14, color: c.accent),
                      const SizedBox(width: 6),
                      Text(
                        '$tempStr · $descStr',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: c.textPrimary,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '· $city',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w500,
                          color: c.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          if (sign != null)
            // 2. Floating Vedic Rashi & Cosmic Sign Pill
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('home_rashi'),
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.selectionClick();
                  _showCosmicInsightDialog(context, sign);
                },
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: math.max(
                      0.0,
                      MediaQuery.sizeOf(context).width - 32,
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(20),
                    border: pillBorder,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          sign.symbol,
                          style: const TextStyle(fontSize: 13),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${sign.vedicRashi} · ${sign.name}',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                            letterSpacing: -0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (showStreak)
            // 3. Floating Streak Pill
            Material(
              color: Colors.transparent,
              child: InkWell(
                key: const ValueKey('home_streak_chip'),
                borderRadius: BorderRadius.circular(20),
                onTap: () {
                  HapticFeedback.selectionClick();
                  ref
                      .read(studyStreakCardVisibleProvider.notifier)
                      .toggle();
                },
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: math.max(
                      0.0,
                      MediaQuery.sizeOf(context).width - 32,
                    ),
                  ),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: pillBg,
                    borderRadius: BorderRadius.circular(20),
                    border: pillBorder,
                  ),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(streakIcon, size: 14, color: c.warn),
                        const SizedBox(width: 4),
                        Text(
                          streakLabel,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
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
    final cleaned = rawName.replaceAll(';)', '').trim();
    final name = cleaned.isEmpty
        ? ''
        : cleaned.split(RegExp(r'\s+')).map((w) {
            if (w.isEmpty) return '';
            return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
          }).join(' ');
    final initial = name.isEmpty ? 'A' : name[0].toUpperCase();
    final dob = widget.profile?.dateOfBirth;
    final sign =
        dob == null ? null : const CosmicProfileService().getZodiac(dob);
    final todayFestival = ref.watch(todayFestivalProvider);
    final assistantName = ref.watch(assistantNameProvider);

    final weatherState = ref.watch(homeWeatherProvider);
    final current = weatherState.value?['current'] as Map<String, dynamic>?;
    final weatherCode = (current?['weather_code'] as num?)?.toInt();

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
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.header),
        ),
        border: AppBorder.bottom(c.border),
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.header),
        ),
        child: Stack(
          children: [
            // Dynamic Living Atmospheric Canvas (Rain, stars, weather dynamics)
            Positioned.fill(
              child: AnimatedBuilder(
                animation: _animController,
                builder: (context, _) => RepaintBoundary(
                  child: CustomPaint(
                    key: const ValueKey('home_atmospheric_canvas'),
                    painter: _AtmosphereCanvasPainter(
                      progress: _animController.value,
                      hour: now.hour,
                      weatherCode: weatherCode,
                      dark: dark,
                      accentColor: c.accent,
                    ),
                  ),
                ),
              ),
            ),

            // Header Content
            Padding(
              padding: EdgeInsets.fromLTRB(
                16,
                MediaQuery.paddingOf(context).top + 10,
                16,
                18,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Row 1: Date (Left) | Day/Night Toggle + Profile Avatar (Right)
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Left: Date
                      Expanded(
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

                      // Right Actions: Day/Night Theme Toggle + Profile Avatar "A"
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // 1. Day / Night theme toggle button
                          Tooltip(
                            message: dark
                                ? 'Switch to light theme'
                                : 'Switch to dark theme',
                            child: Material(
                              color: Colors.transparent,
                              shape: const CircleBorder(),
                              child: InkWell(
                                key: const ValueKey('home_theme_toggle_btn'),
                                borderRadius: BorderRadius.circular(20),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  final newMode =
                                      dark ? ThemeMode.light : ThemeMode.dark;
                                  ref
                                      .read(themeModeProvider.notifier)
                                      .setThemeMode(newMode);
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
                                    transitionBuilder: (child, anim) =>
                                        RotationTransition(
                                      turns: anim,
                                      child: FadeTransition(
                                          opacity: anim, child: child),
                                    ),
                                    child: Icon(
                                      dark
                                          ? Icons.light_mode_rounded
                                          : Icons.dark_mode_rounded,
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

                  // Row 2: Greeting & Name (Clean, minimal, personal profile feel)
                  const SizedBox(height: 16),
                  Text(
                    greeting,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w500,
                      color: c.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
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

                  // Row 3: Floating Transparent Pills with Border (Weather & Temp, Vedic Rashi, Streak)
                  const SizedBox(height: 12),
                  _buildFloatingPillsRow(
                    context,
                    c,
                    dark,
                    sign,
                    streak,
                    showStreak,
                    streakLabel,
                    streakIcon,
                  ),

                  // Row 4: Festival Celebration Banner (if festival today)
                  if (todayFestival != null) ...[
                    const SizedBox(height: 10),
                    Container(
                      key: const ValueKey('home_festival_banner'),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
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
                          Icon(Icons.celebration_rounded,
                              size: 16, color: c.warn),
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

                  // Optional embedded AI Gateway (spacious header keeps it outside by default)
                  if (widget.includeAssistant) ...[
                    const SizedBox(height: 12),
                    HomeAssistantHeroCard(
                      assistantName: assistantName,
                    ),
                  ],

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
            ),
          ],
        ),
      ),
    );
  }
}

class _AtmosphereCanvasPainter extends CustomPainter {
  _AtmosphereCanvasPainter({
    required this.progress,
    required this.hour,
    required this.weatherCode,
    required this.dark,
    required this.accentColor,
  });

  final double progress;
  final int hour;
  final int? weatherCode;
  final bool dark;
  final Color accentColor;

  bool get isRain {
    if (weatherCode == null) return false;
    final code = weatherCode!;
    return (code >= 51 && code <= 67) ||
        (code >= 80 && code <= 82) ||
        code >= 95;
  }

  bool get isSnow {
    if (weatherCode == null) return false;
    final code = weatherCode!;
    return (code >= 71 && code <= 77) || code == 85 || code == 86;
  }

  bool get isNight => hour < 5 || hour >= 21;
  bool get isEvening => hour >= 17 && hour < 21;
  bool get isMorning => hour >= 5 && hour < 12;

  @override
  void paint(Canvas canvas, Size size) {
    if (isRain) {
      _paintRain(canvas, size);
    } else if (isSnow) {
      _paintSnow(canvas, size);
    } else if (isNight) {
      _paintNightStars(canvas, size);
    } else if (isMorning) {
      _paintMorningGlow(canvas, size);
    } else if (isEvening) {
      _paintEveningWarmth(canvas, size);
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (dark ? const Color(0xFF5B8AC4) : const Color(0xFF285A94))
          .withValues(alpha: dark ? 0.22 : 0.16)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    const streakCount = 28;
    for (var i = 0; i < streakCount; i++) {
      final seedX = ((i * 37) % 100) / 100.0;
      final seedY = ((i * 73) % 100) / 100.0;
      final speed = 0.8 + ((i % 5) * 0.15);

      final x = seedX * size.width - 20;
      final y =
          ((seedY + progress * speed) % 1.0) * (size.height + 40) - 20;
      const length = 16.0;
      const dx = 4.0; // slight wind angle

      canvas.drawLine(
        Offset(x, y),
        Offset(x + dx, y + length),
        paint,
      );
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: dark ? 0.55 : 0.40)
      ..style = PaintingStyle.fill;

    const flakeCount = 20;
    for (var i = 0; i < flakeCount; i++) {
      final seedX = ((i * 43) % 100) / 100.0;
      final seedY = ((i * 67) % 100) / 100.0;
      final speed = 0.4 + ((i % 4) * 0.1);
      final radius = 1.5 + (i % 3) * 0.8;

      final sway = math.sin((progress * 2 * math.pi) + i) * 6.0;
      final x = seedX * size.width + sway;
      final y = ((seedY + progress * speed) % 1.0) * size.height;

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _paintNightStars(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const starCount = 18;

    for (var i = 0; i < starCount; i++) {
      final x = (((i * 59) % 100) / 100.0) * size.width;
      final y = (((i * 83) % 65) / 100.0) * size.height;
      final pulse =
          (math.sin((progress * 2 * math.pi) + (i * 1.5)) + 1.0) / 2.0;
      final alpha = (0.2 + 0.5 * pulse).clamp(0.0, 1.0);

      paint.color =
          Colors.white.withValues(alpha: dark ? alpha : alpha * 0.5);
      final radius = 0.9 + (i % 3) * 0.6;
      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  void _paintMorningGlow(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (dark ? const Color(0xFFFBBF24) : const Color(0xFFF59E0B))
              .withValues(alpha: dark ? 0.12 : 0.10),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.85, 20),
        radius: 120,
      ));

    canvas.drawCircle(Offset(size.width * 0.85, 20), 120, glowPaint);
  }

  void _paintEveningWarmth(Canvas canvas, Size size) {
    final warmthPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (dark ? const Color(0xFFEA580C) : const Color(0xFFF97316))
              .withValues(alpha: dark ? 0.15 : 0.08),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(
        center: Offset(size.width * 0.2, size.height * 0.8),
        radius: 140,
      ));

    canvas.drawCircle(
        Offset(size.width * 0.2, size.height * 0.8), 140, warmthPaint);
  }

  @override
  bool shouldRepaint(_AtmosphereCanvasPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.hour != hour ||
      oldDelegate.weatherCode != weatherCode ||
      oldDelegate.dark != dark;
}
