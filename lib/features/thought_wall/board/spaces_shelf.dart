import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import 'board_cards.dart';
import 'board_logic.dart';
import 'space_style.dart';

/// One row of spaces above the wall: tap a space to step into it. This is the
/// only navigation on the wall; thoughts themselves carry no buttons.
class SpacesShelf extends StatelessWidget {
  const SpacesShelf({
    super.key,
    required this.spaces,
    required this.archivedCount,
    required this.onOpen,
    required this.onNew,
    required this.onOpenArchive,
  });

  final List<SpaceSummary> spaces;
  final int archivedCount;
  final ValueChanged<SpaceSummary> onOpen;
  final VoidCallback onNew;
  final VoidCallback onOpenArchive;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return SingleChildScrollView(
      key: const ValueKey('spaces_shelf'),
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpace.s16,
        vertical: AppSpace.s8,
      ),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _SpaceTile(
              key: const ValueKey('space_tile_new'),
              icon: Icons.add_rounded,
              label: 'New space',
              accent: g.clay,
              dashed: true,
              semanticsLabel: 'Create a new space',
              onTap: onNew,
            ),
            for (final space in spaces) ...[
              const SizedBox(width: AppSpace.s10),
              _SpaceTile(
                key: ValueKey('space_tile_${space.key}'),
                icon: spaceStyleFor(space.name).icon,
                label: space.name,
                accent: spaceAccentFor(g, space.key),
                count: space.total,
                progress: space.total == 0 ? null : space.done / space.total,
                semanticsLabel: space.total == 0
                    ? '${space.name}, empty'
                    : '${space.name}, ${space.total} '
                          '${space.total == 1 ? 'entry' : 'entries'}',
                onTap: () => onOpen(space),
              ),
            ],
            if (archivedCount > 0) ...[
              const SizedBox(width: AppSpace.s10),
              _SpaceTile(
                key: const ValueKey('space_tile_archive'),
                icon: Icons.archive_outlined,
                label: 'Archive',
                accent: g.inkMuted,
                count: archivedCount,
                semanticsLabel: 'Archive, $archivedCount',
                onTap: onOpenArchive,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SpaceTile extends StatelessWidget {
  const _SpaceTile({
    super.key,
    required this.icon,
    required this.label,
    required this.accent,
    required this.semanticsLabel,
    required this.onTap,
    this.count,
    this.progress,
    this.dashed = false,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final String semanticsLabel;
  final VoidCallback onTap;

  /// Entries in the space. Shown only when at least one.
  final int? count;
  final double? progress;
  final bool dashed;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Semantics(
      button: true,
      label: semanticsLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          width: 128,
          padding: const EdgeInsets.all(AppSpace.s12),
          decoration: BoxDecoration(
            color: dashed
                ? Colors.transparent
                : Color.alphaBlend(accent.withValues(alpha: .08), g.fill),
            borderRadius: AppGeometry.roundedr18,
            border: Border.all(
              color: accent.withValues(alpha: dashed ? .6 : .4),
              width: 1.4,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(icon, size: 22, color: accent),
                  const Spacer(),
                  if (count != null && count! > 0)
                    Text(
                      '$count',
                      style: AscentTextStyles.labelLarge.copyWith(
                        color: g.ink,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.s8),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AscentTextStyles.labelLarge.copyWith(color: g.ink),
              ),
              if (progress != null) ...[
                const SizedBox(height: AppSpace.s8),
                ProgressBar(value: progress!, color: accent),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A thin progress bar built from plain boxes. It reports no intrinsic width,
/// so it is safe inside `IntrinsicHeight` rows.
class ProgressBar extends StatelessWidget {
  const ProgressBar({super.key, required this.value, required this.color});

  /// 0 to 1.
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: AppGeometry.roundedr99,
      child: SizedBox(
        height: 4,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ColoredBox(color: color.withValues(alpha: .18)),
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: value.clamp(0.0, 1.0).toDouble(),
              child: ColoredBox(color: color),
            ),
          ],
        ),
      ),
    );
  }
}
