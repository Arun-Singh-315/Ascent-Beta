import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/monochrome_surfaces.dart';
import '../../app/theme/shared_control_tokens.dart';
import '../../app/theme/text_styles.dart';

/// Shared date presentation only: callers own date selection, data and routing.
/// Today and scheduled content have separate markers and semantic meanings.
class AscentCalendarDay extends StatelessWidget {
  const AscentCalendarDay({
    super.key,
    required this.date,
    required this.onTap,
    this.today = false,
    this.selected = false,
    this.outsideMonth = false,
    this.hasScheduledItems = false,
    this.weekdayLabel,
    this.semanticLabel,
    this.agendaRow = false,
    this.compact = false,
  });

  final DateTime date;
  final VoidCallback onTap;
  final bool today, selected, outsideMonth, hasScheduledItems;
  final String? weekdayLabel, semanticLabel;
  final bool agendaRow;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final colors = MonochromeSurfaces.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final blue = dark
        ? SharedControlColors.actionBlueDark
        : SharedControlColors.actionBlue;
    final scale = MediaQuery.textScalerOf(context);
    // The disc grows with the actual scaled numeral, rather than shrinking text.
    final diameter = (scale.scale(17) * 1.2 + 12).clamp(32.0, double.infinity);
    final label = [
      semanticLabel ?? DateFormat.yMMMMEEEEd().format(date),
      if (today) 'Today',
      if (hasScheduledItems) 'Has scheduled items',
    ].join(', ');
    final dateVisual = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (weekdayLabel != null) ...[
          Text(
            weekdayLabel!,
            style: AscentTextStyles.interfaceLabel.copyWith(
              color: today ? colors.primaryText : colors.secondaryText,
              fontWeight: today ? FontWeight.w700 : FontWeight.w500,
            ),
          ),
          const SizedBox(height: 6),
        ],
        Container(
          key: ValueKey('calendar_disc_${date.year}_${date.month}_${date.day}'),
          width: diameter,
          height: diameter,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected && !today ? blue : Colors.transparent,
            shape: BoxShape.circle,
            border: today
                ? Border.all(
                    color: dark ? Colors.white : const Color(0xFF0F172A),
                    width: 1.5,
                  )
                : (selected
                    ? Border.all(color: colors.controlOutline, width: 1.5)
                    : null),
          ),
          child: Text(
            '${date.day}',
            style: AscentTextStyles.interfaceNavigation.copyWith(
              color: today
                  ? (dark ? Colors.white : const Color(0xFF0F172A))
                  : (selected
                      ? (dark ? const Color(0xFF0F172A) : Colors.white)
                      : (outsideMonth ? colors.secondaryText : colors.primaryText)),
              fontWeight: today ? FontWeight.w700 : FontWeight.w500,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
        const SizedBox(height: 3),
        _dot(
          key: ValueKey(
            'calendar_today_${date.year}_${date.month}_${date.day}',
          ),
          size: 4,
          color: today
              ? const Color(0xFFF59E0B)
              : Colors.transparent,
        ),
        const SizedBox(height: 3),
        _dot(
          key: ValueKey(
            'calendar_events_${date.year}_${date.month}_${date.day}',
          ),
          size: 4,
          color: hasScheduledItems ? colors.secondaryText : Colors.transparent,
        ),
      ],
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          splashColor: colors.pressedFill,
          highlightColor: colors.pressedFill,
          focusColor: colors.pressedFill,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: compact ? 2 : 8),
              child: agendaRow
                  ? Row(
                      children: [
                        dateVisual,
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                DateFormat('EEEE, MMM d').format(date),
                                style: AscentTextStyles.interfaceBody.copyWith(
                                  color: colors.primaryText,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                hasScheduledItems ? 'Scheduled' : 'No items',
                                style: AscentTextStyles.interfaceSupporting
                                    .copyWith(color: colors.secondaryText),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : dateVisual,
            ),
          ),
        ),
      ),
    );
  }

  Widget _dot({required Key key, required double size, required Color color}) =>
      Container(
        key: key,
        width: size,
        height: size,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle),
      );
}
