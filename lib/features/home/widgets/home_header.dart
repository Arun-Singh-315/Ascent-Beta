import 'dart:async';
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
import '../../../core/streak/study_streak_provider.dart';
import 'home_day_design.dart';

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
    final ink = HomeDayDesign.ink(dark);
    final secondary = HomeDayDesign.secondary(dark);
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
        backgroundColor: Colors.transparent,
        foregroundColor: ink,
        shape: CircleBorder(
          side: BorderSide(color: ink.withValues(alpha: .38), width: .8),
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
              fontSize: 20,
            ),
          ),
          onTap: () => context.push('/settings'),
        ),
      ],
    );
    final date = Text(
      DateFormat('EEE, d MMM').format(now),
      key: const ValueKey('home_date'),
      style: AscentTextStyles.body.copyWith(color: ink, fontSize: 14),
    );

    return ClipPath(
      key: const ValueKey('home_day_header'),
      clipper: const _HeaderCurve(),
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [day.sky, HomeDayDesign.canvas(dark), day.light],
            stops: const [0, .54, 1],
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
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
              const SizedBox(height: 20),
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
                        final showMotif =
                            constraints.maxWidth >= 300 &&
                            MediaQuery.textScalerOf(context).scale(14) < 21;
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    day.greeting,
                                    style: AscentTextStyles.body.copyWith(
                                      color: ink,
                                      fontSize: 18,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    name.isEmpty
                                        ? 'Your day, your pace.'
                                        : name,
                                    key: const ValueKey('home_user_name'),
                                    style: AscentTextStyles.homeTitle.copyWith(
                                      color: ink,
                                      fontSize: 32,
                                      height: 1.15,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: -.9,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (showMotif) ...[
                              const SizedBox(width: 12),
                              ExcludeSemantics(
                                child: CustomPaint(
                                  size: const Size(88, 58),
                                  painter: _DayHorizon(
                                    day.sunHeight,
                                    dark
                                        ? const Color(0xFFD8B78F)
                                        : const Color(0xFFB48451),
                                  ),
                                ),
                              ),
                            ],
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 14),
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
                                    width: 27,
                                    height: 27,
                                    alignment: Alignment.center,
                                    decoration: const BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: Color(0xFFAA805A),
                                    ),
                                    child: Text(
                                      sign.symbol,
                                      textScaler: TextScaler.noScaling,
                                      style: const TextStyle(
                                        fontFamily: 'AscentZodiacSymbols',
                                        fontSize: 18,
                                        color: Colors.white,
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
                                            fontWeight: FontWeight.w700,
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
                      day.cue,
                      key: const ValueKey('home_day_cue'),
                      style: AscentTextStyles.bodySmall.copyWith(
                        color: secondary,
                        height: 1.4,
                      ),
                    ),
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

class _HeaderCurve extends CustomClipper<Path> {
  const _HeaderCurve();
  @override
  Path getClip(Size size) => Path()
    ..lineTo(0, size.height - 15)
    ..cubicTo(
      size.width * .32,
      size.height + 15,
      size.width * .68,
      size.height - 26,
      size.width,
      size.height - 20,
    )
    ..lineTo(size.width, 0)
    ..close();
  @override
  bool shouldReclip(_HeaderCurve oldClipper) => false;
}

class _DayHorizon extends CustomPainter {
  const _DayHorizon(this.height, this.color);
  final double height;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = .9
      ..style = PaintingStyle.stroke;
    final horizon = size.height * .79;
    final center = Offset(size.width * .52, horizon);
    final radius = 12 + height * 6;
    canvas.save();
    canvas.clipRect(Rect.fromLTRB(0, 0, size.width, horizon));
    final sun = Offset(center.dx, horizon + radius * (1 - height) * .75);
    canvas.drawCircle(
      sun,
      radius,
      Paint()..color = color.withValues(alpha: .12),
    );
    canvas.drawCircle(sun, radius, paint);
    if (height > .3) {
      for (var i = 0; i < 5; i++) {
        final angle = math.pi + (i + 1) * math.pi / 6;
        canvas.drawLine(
          sun + Offset(math.cos(angle), math.sin(angle)) * (radius + 6),
          sun + Offset(math.cos(angle), math.sin(angle)) * (radius + 12),
          paint,
        );
      }
    }
    canvas.restore();
    canvas.drawPath(
      Path()
        ..moveTo(0, horizon + 5)
        ..quadraticBezierTo(center.dx, horizon - 6, size.width, horizon + 5),
      paint,
    );
  }

  @override
  bool shouldRepaint(_DayHorizon oldDelegate) =>
      oldDelegate.height != height || oldDelegate.color != color;
}
