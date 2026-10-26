import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import 'thought_wall_preferences.dart';

class ThoughtWallAppearanceSheet extends ConsumerStatefulWidget {
  const ThoughtWallAppearanceSheet({super.key});

  @override
  ConsumerState<ThoughtWallAppearanceSheet> createState() =>
      _ThoughtWallAppearanceSheetState();
}

class _ThoughtWallAppearanceSheetState
    extends ConsumerState<ThoughtWallAppearanceSheet> {
  bool _saving = false;
  String? _error;

  Future<void> _save(ThoughtWallAppearance appearance) async {
    HapticFeedback.selectionClick();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(thoughtWallAppearanceProvider.notifier).save(appearance);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not save. Please try again.');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final appearance = ref.watch(thoughtWallAppearanceProvider);
    final g = context.glass;

    return Theme(
      data: Theme.of(context).copyWith(
        chipTheme: ChipThemeData(
          backgroundColor: Colors.transparent,
          selectedColor: g.clay.withValues(alpha: 0.14),
          showCheckmark: false,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          side: WidgetStateBorderSide.resolveWith((states) {
            final isSelected = states.contains(WidgetState.selected);
            return BorderSide(
              color: isSelected ? g.clay : g.line.withValues(alpha: 0.5),
              width: isSelected ? 1.8 : 1.0,
            );
          }),
          labelStyle: TextStyle(
            color: g.ink,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: context.isDark ? context.bgSurface : g.fill,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(top: BorderSide(color: g.line)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 36,
                    height: 4,
                    decoration: BoxDecoration(
                      color: g.inkMuted.withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Icon(Icons.tune_rounded, size: 20, color: g.clay),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Wall appearance',
                            style: AscentTextStyles.homeTitle.copyWith(
                              color: g.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Mind Palace Card Style',
                            style: AscentTextStyles.homeCaption.copyWith(
                              color: g.inkMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close appearance',
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close_rounded, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'CARD BACKGROUND',
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: g.inkMuted,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ChoiceChip(
                      avatar: Icon(
                        appearance.bubbleFilled
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 16,
                        color: appearance.bubbleFilled
                            ? g.clay
                            : g.inkSecondary,
                      ),
                      label: Text(
                        'Coloured Fill',
                        style: TextStyle(
                          color: appearance.bubbleFilled ? g.clay : g.ink,
                          fontWeight: appearance.bubbleFilled
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      selected: appearance.bubbleFilled,
                      onSelected: _saving
                          ? null
                          : (_) => _save(appearance.copyWith(bubbleFilled: true)),
                    ),
                    ChoiceChip(
                      avatar: Icon(
                        !appearance.bubbleFilled
                            ? Icons.check_circle_rounded
                            : Icons.circle_outlined,
                        size: 16,
                        color: !appearance.bubbleFilled
                            ? g.clay
                            : g.inkSecondary,
                      ),
                      label: Text(
                        'Border Only',
                        style: TextStyle(
                          color: !appearance.bubbleFilled ? g.clay : g.ink,
                          fontWeight: !appearance.bubbleFilled
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                      selected: !appearance.bubbleFilled,
                      onSelected: _saving
                          ? null
                          : (_) => _save(appearance.copyWith(bubbleFilled: false)),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'BORDER THICKNESS',
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: g.inkMuted,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (label, width) in [
                      ('Thin (1px)', 1.0),
                      ('Standard', 1.8),
                      ('Bold (2.6px)', 2.6),
                    ])
                      ChoiceChip(
                        label: Text(
                          label,
                          style: TextStyle(
                            color:
                                (appearance.bubbleBorderWidth - width).abs() <
                                        0.1
                                    ? g.clay
                                    : g.ink,
                            fontWeight:
                                (appearance.bubbleBorderWidth - width).abs() <
                                        0.1
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                          ),
                        ),
                        selected:
                            (appearance.bubbleBorderWidth - width).abs() < 0.1,
                        onSelected: _saving
                            ? null
                            : (_) => _save(
                                  appearance.copyWith(bubbleBorderWidth: width),
                                ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Card style',
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: g.inkMuted,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final style in ThoughtCardStyle.values)
                      ChoiceChip(
                        label: Text(
                          switch (style) {
                            ThoughtCardStyle.soft => 'Soft',
                            ThoughtCardStyle.bubble => 'Bubble',
                            ThoughtCardStyle.minimal => 'Minimal',
                          },
                          style: TextStyle(
                            color: appearance.style == style ? g.clay : g.ink,
                            fontWeight: appearance.style == style
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        selected: appearance.style == style,
                        onSelected: _saving
                            ? null
                            : (_) => _save(appearance.copyWith(style: style)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Spacing',
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: g.inkMuted,
                    letterSpacing: 1.0,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final density in ThoughtCardDensity.values)
                      ChoiceChip(
                        label: Text(
                          density == ThoughtCardDensity.compact
                              ? 'Compact'
                              : 'Comfortable',
                          style: TextStyle(
                            color: appearance.density == density ? g.clay : g.ink,
                            fontWeight: appearance.density == density
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                        selected: appearance.density == density,
                        onSelected: _saving
                            ? null
                            : (_) => _save(appearance.copyWith(density: density)),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                Text(
                  'Applies to every card in Thought Wall and Home.',
                  style: AscentTextStyles.bodySmall.copyWith(color: g.inkMuted),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Text(
                      _error!,
                      style: TextStyle(color: Theme.of(context).colorScheme.error),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
