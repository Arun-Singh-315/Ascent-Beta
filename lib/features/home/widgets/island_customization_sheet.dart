import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/island_preferences_provider.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../../shared/widgets/ascent_switch_row.dart';
import 'island_surface.dart';

Future<void> showIslandCustomization(BuildContext context) =>
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.glass.bg,
      builder: (_) => const IslandCustomizationSheet(),
    );

class IslandCustomizationSheet extends ConsumerWidget {
  const IslandCustomizationSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final prefs = ref.watch(islandPreferencesProvider);
    final g = context.glass;
    final largeText = MediaQuery.textScalerOf(context).scale(1) >= 1.5;
    final palette = IslandPalette.resolve(
      prefs.finish,
      Theme.of(context).brightness == Brightness.dark,
    );
    Future<void> save(
      IslandPreferences Function(IslandPreferences) change,
    ) async {
      try {
        await ref.read(islandPreferencesProvider.notifier).update(change);
      } catch (_) {
        if (context.mounted) {
          AscentSnackBar.show(
            context,
            message: 'Could not save island style. Try again.',
            isError: true,
          );
        }
      }
    }

    return FractionallySizedBox(
      heightFactor: .9,
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          8,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Make it yours',
                    style: TextStyle(
                      color: g.ink,
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                IconButton(
                  tooltip: 'Close island customization',
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            Text('Dynamic Island', style: TextStyle(color: g.inkSecondary)),
            const SizedBox(height: 22),
            Text(
              'STYLE PREVIEW',
              style: TextStyle(
                color: g.inkMuted,
                fontSize: 10,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 10),
            // This preview is deliberately inert: opening settings never starts a session.
            IslandSurface(
              palette: palette,
              radius: 30,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Icon(Icons.timer_outlined, color: palette.accent),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            prefs.density == IslandDensity.minimal || largeText
                                ? 'Focus'
                                : 'A little deeper',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: palette.ink,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (prefs.density == IslandDensity.detailed &&
                              !largeText)
                            Text(
                              'Focus · live preview',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: palette.secondary,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '24:08',
                      style: TextStyle(
                        color: palette.accent,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Glass finish',
              style: TextStyle(color: g.ink, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final finish in IslandFinish.values)
                  ChoiceChip(
                    key: ValueKey('island_finish_${finish.name}'),
                    avatar: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [
                            IslandPalette.resolve(finish, false).top,
                            IslandPalette.resolve(finish, true).bottom,
                          ],
                        ),
                      ),
                    ),
                    label: Text(switch (finish) {
                      IslandFinish.sapphire => 'Sapphire',
                      IslandFinish.frost => 'Frost',
                      IslandFinish.midnight => 'Midnight',
                    }),
                    selected: prefs.finish == finish,
                    onSelected: (_) => save((p) => p.copyWith(finish: finish)),
                  ),
              ],
            ),
            const SizedBox(height: 22),
            Text(
              'Compact view',
              style: TextStyle(color: g.ink, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 10),
            AscentSegmentedControl<IslandDensity>(
              segments: const [
                AscentSegment(value: IslandDensity.detailed, label: 'Detailed'),
                AscentSegment(value: IslandDensity.minimal, label: 'Minimal'),
              ],
              selected: prefs.density,
              onChanged: (value) => save((p) => p.copyWith(density: value)),
            ),
            const SizedBox(height: 18),
            AscentSwitchRow(
              title: 'Upcoming reminders',
              helper: 'Show reminders due soon, including recently due alerts.',
              value: prefs.showUpcoming,
              onChanged: (value) => ref
                  .read(islandPreferencesProvider.notifier)
                  .update((p) => p.copyWith(showUpcoming: value)),
            ),
            AscentSwitchRow(
              title: 'Daily recap',
              helper: 'A brief text reflection shown once, then cleared automatically.',
              value: prefs.showRecap,
              onChanged: (value) => ref
                  .read(islandPreferencesProvider.notifier)
                  .update((p) => p.copyWith(showRecap: value)),
            ),
            AscentSwitchRow(
              title: 'Paused activities',
              helper: 'Keep paused sessions in view so you can resume them.',
              value: prefs.showPaused,
              onChanged: (value) => ref
                  .read(islandPreferencesProvider.notifier)
                  .update((p) => p.copyWith(showPaused: value)),
            ),
            AscentSwitchRow(
              title: 'Gentle transitions',
              helper: 'Always respects your device’s reduced motion setting.',
              value: prefs.animate,
              onChanged: (value) => ref
                  .read(islandPreferencesProvider.notifier)
                  .update((p) => p.copyWith(animate: value)),
            ),
            const SizedBox(height: 12),
            Text(
              'Live activities still appear when you hide reminders or the recap. These preferences change what you see, without stopping your sessions.',
              style: TextStyle(
                color: g.inkSecondary,
                fontSize: 12,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
