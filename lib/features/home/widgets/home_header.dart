import 'dart:async';
import '../../../app/theme/calm_blue_palette.dart';
import '../../../app/theme/ascent_tokens.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'home_header_scene.dart';
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
import '../../../app/app_navigation.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import 'home_day_design.dart';
import 'home_weather.dart';
import 'package:ascent/shared/widgets/ascent_dialog.dart';
import 'package:ascent/shared/widgets/ascent_button.dart';

class HomeHeader extends ConsumerStatefulWidget {
  const HomeHeader({
    super.key,
    required this.profile,
    this.now,
  });
  final UserProfile? profile;
  final DateTime? now;

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
    // The rain/snow canvas only moves while it is actually raining or
    // snowing; see [_syncAtmosphere]. Nothing loops on a clear day.
    if (widget.now == null) {
      _minuteTimer = Timer.periodic(const Duration(minutes: 1), (_) {
        if (mounted) setState(() {});
      });
    }
  }

  /// Starts the precipitation loop only when there is something to animate,
  /// and stops it otherwise (CLAUDE.md §2.8: no idle animation loops).
  void _syncAtmosphere(bool animate) {
    if (animate == _animController.isAnimating) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (animate && !_animController.isAnimating) {
        _animController.repeat();
      } else if (!animate && _animController.isAnimating) {
        _animController.stop();
      }
    });
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

    showAscentFrostedDialog<void>(
      context: context,
      builder: (ctx) => AscentDialog(
        title:
            '${sign.symbol}  ${sign.vedicRashi} (${sign.vedicHindi}) · ${sign.name}',
        contentWidget: Column(
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
                  fontWeight: FontWeight.w600,
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
          Align(
            alignment: Alignment.centerRight,
            child: AscentButton.tonal(
              label: 'Close',
              compact: true,
              onPressed: () => Navigator.of(ctx).pop(),
            ),
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
      final configured = ref
          .watch(sharedPreferencesProvider)
          .getString('weather_city');
      if (configured != null && configured.trim().isNotEmpty) {
        city = configured.split(',').first.trim();
      }
    } catch (_) {}

    // Not set up: a quiet "Add weather" chip (weather is opt-in).
    // Set up but offline: show nothing rather than an error (§7).
    final configured = weatherConfigured(ref.watch(sharedPreferencesProvider));
    final showWeather =
        !configured ||
        current != null ||
        (weatherState.isLoading && !weatherState.hasError);
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

    final pillBg = dark
        ? context.tokens.surface.withValues(alpha: 0.75)
        : c.surfaceAlt.withValues(alpha: 0.65);
    final pillBorder = Border.all(
      color: dark ? context.tokens.separator : c.border.withValues(alpha: 0.85),
      width: 1,
    );

    return Container(
      key: const ValueKey('home_atmospheric_card'),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // 1. Floating Weather & Temperature Pill (hidden when offline)
          if (showWeather)
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
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
                          configured ? '$tempStr · $descStr' : 'Add weather',
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            color: c.textPrimary,
                            letterSpacing: -0.1,
                          ),
                        ),
                        if (configured) const SizedBox(width: 4),
                        if (configured)
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
                  padding: const EdgeInsets.symmetric(
                    horizontal: 11,
                    vertical: 6,
                  ),
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
                        Text(sign.symbol, style: const TextStyle(fontSize: 13)),
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
                  context.open('/focus');
                },
                child: Container(
                  constraints: BoxConstraints(
                    maxWidth: math.max(
                      0.0,
                      MediaQuery.sizeOf(context).width - 32,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
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
        : cleaned
              .split(RegExp(r'\s+'))
              .map((w) {
                if (w.isEmpty) return '';
                return '${w[0].toUpperCase()}${w.substring(1).toLowerCase()}';
              })
              .join(' ');
    final initial = name.isEmpty ? 'A' : name[0].toUpperCase();
    final dob = widget.profile?.dateOfBirth;
    final sign = dob == null
        ? null
        : const CosmicProfileService().getZodiac(dob);
    final todayFestival = ref.watch(todayFestivalProvider);

    final weatherState = ref.watch(homeWeatherProvider);
    final current = weatherState.value?['current'] as Map<String, dynamic>?;
    final weatherCode = (current?['weather_code'] as num?)?.toInt();
    _syncAtmosphere(
      hasPrecipitation(weatherCode) && !MediaQuery.disableAnimationsOf(context),
    );

    final streak = math.max(
      ref.watch(studyStreakProvider).displayStreakDays,
      ref.watch(currentStreakStreamProvider).value ?? 0,
    );
    final showStreak = streak > 0;

    final quote =
        todayFestival?.thought ??
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
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.header),
        ),
        border: AppBorder.bottom(dark ? context.tokens.separator : c.border),
        boxShadow: dark
            ? [
                BoxShadow(
                  color: CalmBluePalette.darkShadow,
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(AppRadius.header),
        ),
        child: Stack(
          children: [
            // Time-of-day sky: dawn, clear day, golden hour, night
            // (CLAUDE.md §5.1). Cross-fades over 2 s when the period changes.
            Positioned.fill(
              child: HomeHeaderScene(now: now, child: const SizedBox.expand()),
            ),
            Positioned(
              right: 4,
              top: MediaQuery.paddingOf(context).top + 30,
              child: HomeCelestialMark(now: now),
            ),
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
                            fontWeight: FontWeight.w600,
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
                                  final newMode = dark
                                      ? ThemeMode.light
                                      : ThemeMode.dark;
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
                                            opacity: anim,
                                            child: child,
                                          ),
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
                                      fontWeight: FontWeight.w600,
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
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        greeting,
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: c.textSecondary,
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2.5,
                        ),
                        decoration: BoxDecoration(
                          color: dark
                              ? context.tokens.surface.withValues(alpha: 0.75)
                              : c.surfaceAlt,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: dark ? context.tokens.separator : c.border,
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              periodIcon,
                              size: 12,
                              color: dark ? context.tokens.action : c.accent,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              periodSubtitle,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: dark
                                    ? context.tokens.labelSecondary
                                    : c.textSecondary,
                                letterSpacing: -0.1,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    name.isEmpty ? 'Your space' : name,
                    key: const ValueKey('home_user_name'),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 27,
                      fontWeight: FontWeight.w600,
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
                        horizontal: 12,
                        vertical: 8,
                      ),
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
                          Icon(
                            Icons.celebration_rounded,
                            size: 16,
                            color: c.warn,
                          ),
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

/// Whether an Open-Meteo weather code is rain, drizzle, showers, snow or a
/// thunderstorm: the only weather the header canvas animates.
bool hasPrecipitation(int? code) =>
    code != null &&
    ((code >= 51 && code <= 67) ||
        (code >= 71 && code <= 77) ||
        (code >= 80 && code <= 86) ||
        code >= 95);

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
      _paintNightAura(canvas, size);
    } else if (isMorning) {
      _paintMorningGlow(canvas, size);
    } else if (isEvening) {
      _paintEveningWarmth(canvas, size);
    }
  }

  void _paintRain(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = (dark ? CalmBluePalette.darkAction : CalmBluePalette.action)
          .withValues(alpha: dark ? 0.22 : 0.16)
      ..strokeWidth = 1.0
      ..strokeCap = StrokeCap.round;

    const streakCount = 28;
    for (var i = 0; i < streakCount; i++) {
      final seedX = ((i * 37) % 100) / 100.0;
      final seedY = ((i * 73) % 100) / 100.0;
      final speed = 0.8 + ((i % 5) * 0.15);

      final x = seedX * size.width - 20;
      final y = ((seedY + progress * speed) % 1.0) * (size.height + 40) - 20;
      const length = 16.0;
      const dx = 4.0; // slight wind angle

      canvas.drawLine(Offset(x, y), Offset(x + dx, y + length), paint);
    }
  }

  void _paintSnow(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = CalmBluePalette.surface.withValues(alpha: dark ? 0.55 : 0.40)
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

  void _paintNightAura(Canvas canvas, Size size) {
    // 1. Celestial Deep Lunar Aura (Rich midnight-indigo glow from top right)
    final breath = (math.sin(progress * 2 * math.pi) + 1.0) / 2.0;
    final auraCenter = Offset(size.width * 0.82, 35);
    final auraRadius = math.max(160.0, size.width * 0.45);

    final celestialPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (dark ? CalmBluePalette.darkActionFill : CalmBluePalette.action).withValues(
            alpha: dark ? (0.24 + 0.06 * breath) : 0.12,
          ),
          (dark ? CalmBluePalette.darkSkyNight : CalmBluePalette.skyNight).withValues(
            alpha: dark ? 0.12 : 0.06,
          ),
          Colors.transparent,
        ],
        stops: const [0.0, 0.55, 1.0],
      ).createShader(Rect.fromCircle(center: auraCenter, radius: auraRadius));

    canvas.drawCircle(auraCenter, auraRadius, celestialPaint);

    // 2. Secondary soft twilight depth on lower left
    final twilightCenter = Offset(size.width * 0.15, size.height * 0.75);
    final twilightPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          (dark ? CalmBluePalette.darkCanvas : CalmBluePalette.recessed).withValues(
            alpha: dark ? 0.30 : 0.12,
          ),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: twilightCenter, radius: 140));
    canvas.drawCircle(twilightCenter, 140, twilightPaint);

    // 3. Ethereal Silky Horizon Ribbon (Living Midnight Aurora)
    final waveY1 =
        size.height * (0.42 + 0.04 * math.sin(progress * 2 * math.pi));
    final waveY2 =
        size.height * (0.58 - 0.04 * math.cos(progress * 2 * math.pi));

    final wavePath = Path()
      ..moveTo(0, size.height * 0.48)
      ..cubicTo(
        size.width * 0.35,
        waveY1,
        size.width * 0.68,
        waveY2,
        size.width,
        size.height * 0.42,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final ribbonPaint = Paint()
      ..shader =
          LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              (dark ? CalmBluePalette.darkWater : CalmBluePalette.water)
                  .withValues(alpha: dark ? 0.08 : 0.04),
              (dark ? CalmBluePalette.darkAction : CalmBluePalette.actionTint)
                  .withValues(alpha: dark ? 0.04 : 0.02),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromLTWH(
              0,
              size.height * 0.35,
              size.width,
              size.height * 0.65,
            ),
          );

    canvas.drawPath(wavePath, ribbonPaint);
  }

  void _paintMorningGlow(Canvas canvas, Size size) {
    final glowPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              (dark ? CalmBluePalette.darkWarning : CalmBluePalette.warning)
                  .withValues(alpha: dark ? 0.12 : 0.10),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(center: Offset(size.width * 0.85, 20), radius: 120),
          );

    canvas.drawCircle(Offset(size.width * 0.85, 20), 120, glowPaint);
  }

  void _paintEveningWarmth(Canvas canvas, Size size) {
    final warmthPaint = Paint()
      ..shader =
          RadialGradient(
            colors: [
              (dark ? CalmBluePalette.darkCommit : CalmBluePalette.commit)
                  .withValues(alpha: dark ? 0.15 : 0.08),
              Colors.transparent,
            ],
          ).createShader(
            Rect.fromCircle(
              center: Offset(size.width * 0.2, size.height * 0.8),
              radius: 140,
            ),
          );

    canvas.drawCircle(
      Offset(size.width * 0.2, size.height * 0.8),
      140,
      warmthPaint,
    );
  }

  @override
  bool shouldRepaint(_AtmosphereCanvasPainter oldDelegate) =>
      oldDelegate.progress != progress ||
      oldDelegate.hour != hour ||
      oldDelegate.weatherCode != weatherCode ||
      oldDelegate.dark != dark;
}
