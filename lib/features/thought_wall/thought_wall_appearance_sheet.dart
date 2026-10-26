import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

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
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Wall appearance',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Close appearance',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'CARD BACKGROUND',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Coloured Fill')),
                    selected: appearance.bubbleFilled,
                    onSelected: _saving
                        ? null
                        : (_) => _save(appearance.copyWith(bubbleFilled: true)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Border Only')),
                    selected: !appearance.bubbleFilled,
                    onSelected: _saving
                        ? null
                        : (_) => _save(appearance.copyWith(bubbleFilled: false)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'BORDER THICKNESS',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.0,
                  ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                for (final (label, width) in [
                  ('Thin (1px)', 1.0),
                  ('Standard', 1.8),
                  ('Bold (2.6px)', 2.6),
                ]) ...[
                  Expanded(
                    child: ChoiceChip(
                      label: Center(child: Text(label)),
                      selected: (appearance.bubbleBorderWidth - width).abs() < 0.1,
                      onSelected: _saving
                          ? null
                          : (_) => _save(
                                appearance.copyWith(bubbleBorderWidth: width),
                              ),
                    ),
                  ),
                  if (width != 2.6) const SizedBox(width: 8),
                ],
              ],
            ),
            const SizedBox(height: 16),
            const Text('Card style'),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final style in ThoughtCardStyle.values)
                  ChoiceChip(
                    label: Text(switch (style) {
                      ThoughtCardStyle.soft => 'Soft',
                      ThoughtCardStyle.bubble => 'Bubble',
                      ThoughtCardStyle.minimal => 'Minimal',
                    }),
                    selected: appearance.style == style,
                    onSelected: _saving
                        ? null
                        : (_) => _save(appearance.copyWith(style: style)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Spacing'),
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
                    ),
                    selected: appearance.density == density,
                    onSelected: _saving
                        ? null
                        : (_) => _save(appearance.copyWith(density: density)),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            const Text('Applies to every card in Thought Wall and Home.'),
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
    );
  }
}
