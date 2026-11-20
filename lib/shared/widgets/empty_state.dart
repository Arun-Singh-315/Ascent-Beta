import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/color_tokens.dart';
import 'ascent_button.dart';

/// A tappable example shown under an [EmptyState] (CLAUDE.md §6.1).
///
/// Tapping a starter should create a real, editable item straight away
/// (with Undo), so the user sees value without typing.
@immutable
class EmptyStarter {
  const EmptyStarter({required this.label, required this.onTap, this.icon});

  final String label;
  final IconData? icon;
  final VoidCallback onTap;
}

/// The single empty-state component for every empty list, section or screen.
///
/// Anatomy (CLAUDE.md §6.1): tinted icon tile → inviting title → value
/// message → one filled primary action → up to three starter chips.
/// Use [EmptyState.inline] inside Home cards and other compact sections.
class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onAction,
    this.tint,
    this.starters = const [],
  }) : inline = false;

  /// Compact one-row variant for sections inside cards.
  const EmptyState.inline({
    super.key,
    required this.icon,
    required this.title,
    this.actionLabel,
    this.onAction,
    this.tint,
  }) : subtitle = '',
       starters = const [],
       inline = true;

  /// The outlined pillar icon shown in the tile.
  final IconData icon;

  /// What will live here, phrased invitingly.
  final String title;

  /// Why it's worth starting (max two lines). Unused by [EmptyState.inline].
  final String subtitle;

  /// Label for the single primary action, e.g. "Add your first thing".
  final String? actionLabel;

  /// Opens the fastest create flow.
  final VoidCallback? onAction;

  /// Pillar tint for the icon tile. Defaults to the theme action color.
  final Color? tint;

  /// Up to three tappable examples; extra items are ignored.
  final List<EmptyStarter> starters;

  final bool inline;

  @override
  Widget build(BuildContext context) =>
      inline ? _buildInline(context) : _buildFull(context);

  Widget _iconTile(BuildContext context, {required double size}) {
    final color = tint ?? context.actionInk;
    return Container(
      width: size,
      height: size,
      decoration: ShapeDecoration(
        color: color.withValues(alpha: 0.12),
        shape: ContinuousRectangleBorder(
          borderRadius: BorderRadius.circular(size * 0.45),
        ),
      ),
      alignment: Alignment.center,
      child: Icon(icon, size: size * 0.44, color: color),
    );
  }

  Widget _buildFull(BuildContext context) {
    final shown = starters.take(3).toList(growable: false);
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s24,
          vertical: AppSpace.s24,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 320),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                excludeSemantics: true,
                child: _iconTile(context, size: 64),
              ),
              const SizedBox(height: AppSpace.s20),
              Semantics(
                header: true,
                child: Text(
                  title,
                  style: AscentTextStyles.cardTitle.copyWith(
                    color: context.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              if (subtitle.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s6),
                Text(
                  subtitle,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.supportingText.copyWith(
                    color: context.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
              if (actionLabel != null) ...[
                const SizedBox(height: AppSpace.s20),
                AscentButton.primary(
                  label: actionLabel!,
                  icon: Icons.add_rounded,
                  onPressed: onAction,
                ),
              ],
              if (shown.isNotEmpty) ...[
                const SizedBox(height: AppSpace.s16),
                Text(
                  'Or try one',
                  style: AscentTextStyles.caption.copyWith(
                    color: context.textMuted,
                  ),
                ),
                const SizedBox(height: AppSpace.s8),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: AppSpace.s8,
                  runSpacing: AppSpace.s8,
                  children: [
                    for (final s in shown) _StarterChip(starter: s, tint: tint),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInline(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
      child: Row(
        children: [
          Semantics(
            excludeSemantics: true,
            child: _iconTile(context, size: 36),
          ),
          const SizedBox(width: AppSpace.s12),
          Expanded(
            child: Text(
              title,
              style: AscentTextStyles.supportingText.copyWith(
                color: context.textSecondary,
              ),
            ),
          ),
          if (actionLabel != null)
            AscentButton.ghost(
              label: actionLabel!,
              onPressed: onAction,
              compact: true,
            ),
        ],
      ),
    );
  }
}

class _StarterChip extends StatelessWidget {
  const _StarterChip({required this.starter, this.tint});

  final EmptyStarter starter;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final accent = tint ?? context.actionInk;
    return Semantics(
      button: true,
      label: starter.label,
      excludeSemantics: true,
      child: Material(
        color: context.recessedSurface,
        shape: const StadiumBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            starter.onTap();
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    starter.icon ?? Icons.add_rounded,
                    size: 16,
                    color: accent,
                  ),
                  const SizedBox(width: AppSpace.s6),
                  Flexible(
                    child: Text(
                      starter.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AscentTextStyles.labelMedium.copyWith(
                        color: context.textPrimary,
                      ),
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
