import 'package:flutter/material.dart';

import '../../../app/theme/brand_palette.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../core/promises/promise_service.dart';

/// The gold tint for promises in the current theme.
Color promiseTint(BuildContext context) =>
    BrandPalette.pillarTint('promises', dark: context.glass.isDark);

/// One dot per day: filled gold = kept, gold ring = forgiven by grace,
/// soft grey = missed, blue ring = waiting for an answer, faint = ahead.
///
/// Long or ongoing promises show a window of [window] days around today so
/// the row never overflows; [wrap] lays every day out in rows instead
/// (detail screen).
class PromiseDots extends StatelessWidget {
  const PromiseDots({
    super.key,
    required this.progress,
    this.size = 12,
    this.window = 21,
    this.wrap = false,
  });
  final PromiseProgress progress;
  final double size;
  final int window;
  final bool wrap;

  @override
  Widget build(BuildContext context) {
    final days = progress.days;
    final todayIndex = progress.dayNumber - 1;
    var start = 0;
    var end = days.length;
    if (!wrap && days.length > window) {
      start = (todayIndex - window + 4).clamp(0, days.length - window);
      end = start + window;
    }
    final label =
        '${progress.kept} kept, ${progress.missed} missed'
        '${progress.length == null ? '' : ' of ${progress.length} days'}';
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: wrap
            ? Wrap(
                spacing: size * .5,
                runSpacing: size * .5,
                children: [
                  for (var i = start; i < end; i++)
                    _Dot(
                      key: ValueKey('promise_dot_$i'),
                      mark: days[i],
                      size: size,
                      isToday: i == todayIndex,
                    ),
                ],
              )
            : LayoutBuilder(
                builder: (context, c) {
                  // Shrink the dots rather than overflow on narrow screens.
                  final count = end - start;
                  final fit = c.maxWidth / (count * 1.5);
                  final s = fit < size ? fit : size;
                  return Row(
                    children: [
                      for (var i = start; i < end; i++) ...[
                        _Dot(
                          key: ValueKey('promise_dot_$i'),
                          mark: days[i],
                          size: s,
                          isToday: i == todayIndex,
                        ),
                        if (i < end - 1) SizedBox(width: s * .5),
                      ],
                    ],
                  );
                },
              ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({
    super.key,
    required this.mark,
    required this.size,
    required this.isToday,
  });
  final DayMark mark;
  final double size;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final gold = promiseTint(context);
    final (Color fill, Color? ring) = switch (mark) {
      DayMark.kept => (gold, null),
      DayMark.grace => (gold.withValues(alpha: .12), gold),
      DayMark.missed => (g.inkMuted.withValues(alpha: .35), null),
      DayMark.open => (Colors.transparent, g.actionInk),
      DayMark.future => (g.inkMuted.withValues(alpha: .14), null),
    };
    final reduce = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      // Re-keyed by mark, so a newly kept day springs in once.
      key: ValueKey(mark),
      tween: Tween(begin: mark == DayMark.kept && !reduce ? .4 : 1, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (context, scale, child) =>
          Transform.scale(scale: scale, child: child),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: fill,
          border: ring == null
              ? null
              : Border.all(color: ring, width: isToday ? 1.6 : 1.2),
        ),
      ),
    );
  }
}
