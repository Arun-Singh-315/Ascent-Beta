import 'dart:math' as math;
import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/theme/ascent_tokens.dart';
import '../../../app/theme/calm_blue_palette.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/providers/time_tracking_provider.dart';
import '../../../shared/widgets/ascent_icon.dart';
import '../model/home_day_provider.dart';
import '../widgets/home_weather.dart';

/// Home v7 masthead: date and weather, theme toggle, avatar, then the
/// headline ("Good morning, Arun." / "62% of today is done.").
class HomeMasthead extends ConsumerWidget {
  const HomeMasthead({super.key, required this.name});
  final String name;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final period = ref.watch(homePeriodProvider);
    final mood = ref.watch(homeMoodProvider);
    final percent = ref.watch(homeSummaryProvider.select((s) => s.percent));
    final total = ref.watch(homeTodayListProvider.select((l) => l.total));
    final first = name.trim().split(RegExp(r'\s+')).first;
    final hello = first.isEmpty
        ? '${greetingFor(period)}.'
        : '${greetingFor(period)}, ${first[0].toUpperCase()}${first.substring(1)}.';
    final head = AscentTextStyles.greeting.copyWith(color: t.action);
    final accent = head.copyWith(color: t.water, fontWeight: FontWeight.w700);
    final InlineSpan second = switch (mood) {
      DayMood.open ||
      DayMood.quiet => TextSpan(text: 'Your day is open.', style: head),
      DayMood.allDone => TextSpan(
        children: [
          TextSpan(text: 'All $total', style: accent),
          TextSpan(text: ' done.', style: head),
        ],
      ),
      _ => TextSpan(
        children: [
          TextSpan(text: '${percent ?? 0}%', style: accent),
          TextSpan(text: ' of today is done.', style: head),
        ],
      ),
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(
        4,
        MediaQuery.paddingOf(context).top + 44,
        4,
        0,
      ),
      child: Column(
        key: const ValueKey('home_masthead'),
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  DateFormat('EEEE, d MMMM').format(DateTime.now()),
                  key: const ValueKey('home_date'),
                  style: AscentTextStyles.meta.copyWith(
                    color: t.labelSecondary,
                    fontWeight: FontWeight.w500,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const _WeatherWord(),
              const _ThemeToggle(),
              const SizedBox(width: 6),
              _Avatar(initial: first.isEmpty ? null : first[0].toUpperCase()),
            ],
          ),
          const SizedBox(height: 12),
          Semantics(
            header: true,
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: '$hello\n', style: head),
                  second,
                ],
              ),
              key: const ValueKey('home_headline'),
            ),
          ),
        ],
      ),
    );
  }
}

class _WeatherWord extends ConsumerWidget {
  const _WeatherWord();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final configured = weatherConfigured(ref.watch(sharedPreferencesProvider));
    final current =
        ref.watch(homeWeatherProvider).value?['current']
            as Map<String, dynamic>?;
    if (configured && current == null) return const SizedBox.shrink();
    final label = current == null
        ? 'Add weather'
        : '${(current['temperature_2m'] as num).round()}°';
    return TextButton(
      key: const ValueKey('home_weather'),
      onPressed: () => showWeatherForecastSheet(context),
      style: TextButton.styleFrom(
        foregroundColor: current == null ? t.action : t.labelSecondary,
        minimumSize: const Size(44, 44),
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
      child: Text(label, style: AscentTextStyles.meta),
    );
  }
}

class _ThemeToggle extends ConsumerWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Semantics(
      button: true,
      label: dark ? 'Switch to light' : 'Switch to dark',
      excludeSemantics: true,
      child: InkResponse(
        key: const ValueKey('home_theme_toggle'),
        radius: 22,
        onTap: () {
          HapticFeedback.selectionClick();
          ref
              .read(themeModeProvider.notifier)
              .setThemeMode(dark ? ThemeMode.light : ThemeMode.dark);
        },
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: t.separator),
                color: t.surface.withValues(alpha: .45),
              ),
              alignment: Alignment.center,
              child: AscentIcon(
                dark ? AscentGlyph.sun : AscentGlyph.moon,
                size: 16,
                color: t.labelSecondary,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.initial});
  final String? initial;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      label: 'Profile and settings',
      excludeSemantics: true,
      child: InkResponse(
        key: const ValueKey('home_profile_button'),
        radius: 22,
        onTap: () => context.push('/settings'),
        child: SizedBox(
          width: 44,
          height: 44,
          child: Center(
            child: Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: t.actionTint,
              ),
              child: initial == null
                  ? AscentIcon(AscentGlyph.you, size: 18, color: t.action)
                  : Text(
                      initial!,
                      style: AscentTextStyles.button.copyWith(
                        color: t.action,
                        fontSize: 13,
                      ),
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The navy summary panel: three rings (things, water, focus), the three
/// values with their change against yesterday, and one insight underneath.
class HomeSummaryPanel extends ConsumerWidget {
  const HomeSummaryPanel({super.key});

  static const _ringColors = [
    CalmBluePalette.ringThings,
    CalmBluePalette.ringWater,
    CalmBluePalette.ringFocus,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(homeSummaryProvider);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final narrow = MediaQuery.textScalerOf(context).scale(1) > 1.5;
    final rings = _SummaryRings(
      values: [for (final l in s.lines) l.progress],
      colors: _ringColors,
    );
    final lines = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (i, l) in s.lines.indexed)
          Padding(
            padding: EdgeInsets.only(top: i == 0 ? 0 : 8),
            child: _SummaryLineRow(line: l, color: _ringColors[i]),
          ),
      ],
    );
    return Container(
      key: const ValueKey('home_summary'),
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: dark
              ? const [
                  CalmBluePalette.darkSummaryTop,
                  CalmBluePalette.darkSummaryBottom,
                ]
              : const [
                  CalmBluePalette.summaryTop,
                  CalmBluePalette.summaryBottom,
                ],
        ),
        border: dark ? Border.all(color: CalmBluePalette.summaryEdge) : null,
        boxShadow: dark
            ? null
            : const [
                BoxShadow(
                  color: CalmBluePalette.summaryShadow,
                  blurRadius: 26,
                  spreadRadius: -14,
                  offset: Offset(0, 10),
                ),
              ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (narrow)
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [rings, const SizedBox(height: 12), lines],
            )
          else
            Row(
              children: [
                rings,
                const SizedBox(width: 16),
                Expanded(child: lines),
              ],
            ),
          const SizedBox(height: 12),
          const Divider(
            height: 1,
            thickness: 1,
            color: CalmBluePalette.summaryDivider,
          ),
          const SizedBox(height: 11),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Padding(
                padding: EdgeInsets.only(top: 2),
                child: AscentIcon(
                  AscentGlyph.riya,
                  size: 14,
                  color: CalmBluePalette.ringFocus,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    children: [
                      for (final p in s.insight)
                        TextSpan(
                          text: p.text,
                          style: p.bold
                              ? const TextStyle(
                                  color: CalmBluePalette.summaryInk,
                                  fontWeight: FontWeight.w600,
                                )
                              : null,
                        ),
                    ],
                  ),
                  key: const ValueKey('home_insight'),
                  style: AscentTextStyles.meta.copyWith(
                    fontSize: 12.5,
                    height: 1.45,
                    color: CalmBluePalette.summarySoft,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryLineRow extends StatelessWidget {
  const _SummaryLineRow({required this.line, required this.color});
  final SummaryLine line;
  final Color color;

  @override
  Widget build(BuildContext context) => Semantics(
    label:
        '${line.label}: ${line.value}${line.unit}'
        '${line.delta == null ? '' : ', ${line.delta} versus yesterday'}',
    excludeSemantics: true,
    child: Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            line.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AscentTextStyles.meta.copyWith(
              fontSize: 12.5,
              color: CalmBluePalette.summaryMuted,
            ),
          ),
        ),
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: line.value,
                style: AscentTextStyles.value.copyWith(
                  fontSize: 15,
                  color: CalmBluePalette.summaryInk,
                ),
              ),
              TextSpan(
                text: line.unit,
                style: AscentTextStyles.meta.copyWith(
                  fontSize: 11,
                  color: CalmBluePalette.summaryMuted,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          width: 38,
          child: Text(
            line.delta ?? '',
            textAlign: TextAlign.end,
            style: AscentTextStyles.meta.copyWith(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: line.deltaUp
                  ? CalmBluePalette.summaryUp
                  : CalmBluePalette.summaryDown,
            ),
          ),
        ),
      ],
    ),
  );
}

/// Three nested rings; they grow to new values in 600 ms (instant under
/// reduce motion).
class _SummaryRings extends StatelessWidget {
  const _SummaryRings({required this.values, required this.colors});
  final List<double> values;
  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    final still = MediaQuery.disableAnimationsOf(context);
    return SizedBox(
      width: 84,
      height: 84,
      child: TweenAnimationBuilder<List<double>>(
        tween: _ListTween(end: values),
        duration: Duration(milliseconds: still ? 0 : 600),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) =>
            CustomPaint(painter: _RingsPainter(v, colors)),
      ),
    );
  }
}

class _ListTween extends Tween<List<double>> {
  _ListTween({required super.end}) : super(begin: [0, 0, 0]);
  @override
  List<double> lerp(double t) => [
    for (var i = 0; i < end!.length; i++)
      (begin!.length > i ? begin![i] : 0) +
          (end![i] - (begin!.length > i ? begin![i] : 0)) * t,
  ];
}

class _RingsPainter extends CustomPainter {
  _RingsPainter(this.values, this.colors);
  final List<double> values;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0, gap = 3.0;
    final center = size.center(Offset.zero);
    for (var i = 0; i < values.length; i++) {
      final r = size.width / 2 - stroke / 2 - i * (stroke + gap);
      final rect = Rect.fromCircle(center: center, radius: r);
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round;
      canvas.drawCircle(center, r, paint..color = CalmBluePalette.summaryTrack);
      final v = values[i].clamp(0.0, 1.0);
      if (v > 0) {
        canvas.drawArc(
          rect,
          -math.pi / 2,
          2 * math.pi * v,
          false,
          paint..color = colors[i],
        );
      }
    }
  }

  @override
  bool shouldRepaint(_RingsPainter old) =>
      old.values.toString() != values.toString();
}

/// The slim glass bar that replaces the masthead once you scroll past it:
/// "Today", progress, and tabs that follow the section you're in.
class HomeCompactBar extends ConsumerWidget {
  const HomeCompactBar({
    super.key,
    required this.tabs,
    required this.current,
    required this.onTab,
  });

  final List<String> tabs;
  final int current;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = context.tokens;
    final list = ref.watch(homeTodayListProvider);
    final percent = ref.watch(homeSummaryProvider.select((s) => s.percent));
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          key: const ValueKey('home_compact_bar'),
          padding: EdgeInsets.fromLTRB(
            18,
            MediaQuery.paddingOf(context).top + 40,
            18,
            8,
          ),
          decoration: BoxDecoration(
            color: t.canvas.withValues(alpha: .84),
            border: Border(bottom: BorderSide(color: t.separator)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      'Today',
                      style: AscentTextStyles.section.copyWith(color: t.action),
                    ),
                  ),
                  if (list.total > 0)
                    Text(
                      '${list.done} of ${list.total} · ${percent ?? 0}%',
                      style: AscentTextStyles.meta.copyWith(
                        color: t.labelSecondary,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              ClipRRect(
                borderRadius: BorderRadius.circular(3),
                child: LinearProgressIndicator(
                  value: list.total == 0 ? 0 : list.done / list.total,
                  minHeight: 3,
                  backgroundColor: t.separator,
                  color: t.water,
                ),
              ),
              const SizedBox(height: 9),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final (i, name) in tabs.indexed) ...[
                      if (i > 0) const SizedBox(width: 6),
                      _Tab(
                        label: name,
                        selected: i == current,
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onTab(i);
                        },
                      ),
                    ],
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

class _Tab extends StatelessWidget {
  const _Tab({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 44),
          child: Center(
            widthFactor: 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              height: 28,
              padding: const EdgeInsets.symmetric(horizontal: 11),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? t.actionTint : null,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: selected ? t.actionTint : t.separator,
                ),
              ),
              child: Text(
                label,
                style: AscentTextStyles.button.copyWith(
                  color: selected ? t.action : t.labelSecondary,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The frosted pill at the very top: a running session's timer, or a
/// countdown to the next thing within three hours. Hidden otherwise.
class HomeLivePill extends ConsumerWidget {
  const HomeLivePill({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final running = ref.watch(
      timeTrackingProvider.select(
        (s) => s.activeSession != null && (s.isRunning || s.isPaused),
      ),
    );
    if (running) return const _SessionPill();
    final focus = ref.watch(homeDayProvider.select((d) => d.focus));
    final now = ref.watch(homeMinuteProvider).value ?? DateTime.now();
    final at = focus.activity?.scheduledTime;
    if (at == null || !at.isAfter(now)) return const SizedBox.shrink();
    final mins = at.difference(now).inMinutes;
    if (mins > 180) return const SizedBox.shrink();
    final when = mins < 60
        ? '$mins min'
        : '${mins ~/ 60} h ${mins % 60 == 0 ? '' : '${mins % 60} min'}'.trim();
    return _Pill(
      key: const ValueKey('home_live_pill'),
      label: focus.activity!.title,
      value: 'in $when',
      dot: context.tokens.warning,
    );
  }
}

class _SessionPill extends ConsumerWidget {
  const _SessionPill();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(
      timeTrackingProvider.select(
        (s) => (
          secs: s.elapsedSeconds,
          label: s.activeSession?.label ?? 'Focus',
          paused: s.isPaused,
        ),
      ),
    );
    final m = s.secs ~/ 60, sec = s.secs % 60;
    return _Pill(
      key: const ValueKey('home_live_pill'),
      label: s.paused ? 'Paused · ${s.label}' : s.label,
      value: '$m:${sec.toString().padLeft(2, '0')}',
      dot: s.paused ? context.tokens.labelTertiary : context.tokens.success,
      onTap: () => context.push('/focus'),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({
    super.key,
    required this.label,
    required this.value,
    required this.dot,
    this.onTap,
  });
  final String label, value;
  final Color dot;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    return Semantics(
      liveRegion: true,
      label: '$label $value',
      excludeSemantics: true,
      child: GestureDetector(
        onTap: onTap,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(99),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
            child: Container(
              height: 30,
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width - 120,
              ),
              padding: const EdgeInsets.fromLTRB(9, 0, 12, 0),
              decoration: BoxDecoration(
                color: t.canvas.withValues(alpha: .82),
                borderRadius: BorderRadius.circular(99),
                border: Border.all(color: t.separator),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 7,
                    height: 7,
                    decoration: BoxDecoration(
                      color: dot,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 7),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AscentTextStyles.button.copyWith(color: t.label),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    value,
                    style: AscentTextStyles.button.copyWith(
                      color: dot,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
