import 'package:flutter/material.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../thought_wall_preferences.dart';
import 'board_logic.dart';

/// Accent colour for a thought, taken from the active theme so every theme
/// (Frost, Merlot, Evergreen, Dusk) keeps its own palette.
///
/// Special moods keep a stable colour. Plain thoughts rotate gently through
/// the theme accents so the wall has variety without any setup.
Color boardAccentFor(AscentGlass g, Thought thought) {
  if (g.frozen) {
    return thought.mood == 'win' ? g.sage : g.slate;
  }
  switch (thought.mood) {
    case 'idea':
      return g.amber;
    case 'win':
      return g.sage;
    case 'future':
      return g.merlot ? g.clay : g.coral;
    case 'me_to_me':
    case 'promise':
      return g.clay;
  }
  final rotation = [g.slate, g.clay, g.sage, g.amber];
  return rotation[thought.id.abs() % rotation.length];
}

/// Accent colour for a space, stable for the same space key.
Color spaceAccentFor(AscentGlass g, String key) {
  final palette = g.frozen
      ? [g.slate, g.sage]
      : [g.slate, g.clay, g.sage, g.amber];
  return palette[stableHash(key) % palette.length];
}

/// Small glyph for non-plain moods, so colour is never the only signal.
IconData? boardMoodIcon(String mood) => switch (mood) {
  'idea' => Icons.lightbulb_outline_rounded,
  'win' => Icons.emoji_events_outlined,
  'future' => Icons.schedule_rounded,
  'me_to_me' => Icons.person_outline_rounded,
  'promise' => Icons.handshake_rounded,
  _ => null,
};

BorderRadius _boardRadius(ThoughtCardStyle style, int index) =>
    switch (style) {
      ThoughtCardStyle.soft => AppGeometry.roundedr18,
      ThoughtCardStyle.bubble => BorderRadius.only(
        topLeft: AppGeometry.radiusr18,
        topRight: AppGeometry.radiusr18,
        bottomLeft: index.isEven ? AppGeometry.radiusr4 : AppGeometry.radiusr18,
        bottomRight: index.isOdd ? AppGeometry.radiusr4 : AppGeometry.radiusr18,
      ),
      ThoughtCardStyle.minimal => AppGeometry.roundedr8,
    };

/// One thought on the board. It shows the thought and nothing else: no
/// buttons, no menus. Tap opens it, long-press selects, double-tap completes.
class BoardCard extends StatelessWidget {
  const BoardCard({
    super.key,
    required this.thought,
    required this.index,
    required this.now,
    this.appearance = const ThoughtWallAppearance(),
    this.spaceName,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.isLocked = false,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
  });

  final Thought thought;
  final int index;
  final DateTime now;
  final ThoughtWallAppearance appearance;

  /// Name of the space the thought lives in, shown as a small tag.
  final String? spaceName;
  final bool isSelected;
  final bool isSelectionMode;

  /// A private promise that has not been unlocked yet.
  final bool isLocked;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = context.isDark;
    final accent = boardAccentFor(g, thought);
    final kind = isLocked ? BoardCardKind.note : boardCardKind(thought.content);
    final minimal = appearance.style == ThoughtCardStyle.minimal;
    final comfortable = appearance.density == ThoughtCardDensity.comfortable;
    final padding = comfortable ? AppSpace.s16 : AppSpace.s12;
    final tint = thought.mood == 'thought' ? .09 : .16;

    final fill = (!appearance.bubbleFilled || minimal)
        ? Colors.transparent
        : Color.alphaBlend(
            accent.withValues(alpha: dark ? tint + .04 : tint),
            g.fill,
          );
    final borderColor = isSelected
        ? g.clay
        : thought.isCompleted
        ? context.doneInk.withValues(alpha: .5)
        : accent.withValues(alpha: dark ? .55 : .45);
    final borderWidth = isSelected
        ? 2.0
        : appearance.bubbleBorderWidth.clamp(1.0, 2.5).toDouble();
    final radius = _boardRadius(appearance.style, index);

    final moodIcon = boardMoodIcon(thought.mood);
    final high = isHighPriorityContent(thought.content);
    final tagStyle = AscentTextStyles.labelSmall.copyWith(
      color: g.inkSecondary,
    );

    Widget card = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: radius,
        border: Border.all(color: borderColor, width: borderWidth),
      ),
      padding: EdgeInsets.all(padding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (moodIcon != null || high || spaceName != null) ...[
            Wrap(
              spacing: AppSpace.s6,
              runSpacing: AppSpace.s4,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (moodIcon != null) Icon(moodIcon, size: 15, color: accent),
                if (high) Icon(Icons.flag_rounded, size: 15, color: g.coral),
                if (spaceName != null)
                  Text('#$spaceName', style: tagStyle, maxLines: 1),
              ],
            ),
            const SizedBox(height: AppSpace.s6),
          ],
          _content(context, g, kind),
          const SizedBox(height: AppSpace.s8),
          Row(
            children: [
              Expanded(
                child: Text(
                  boardTimeLabel(thought.createdAt, now),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: tagStyle.copyWith(color: g.inkMuted),
                ),
              ),
              if (thought.isPinned)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpace.s4),
                  child: Icon(Icons.push_pin_rounded, size: 14, color: accent),
                ),
              if (thought.isCompleted)
                Padding(
                  padding: const EdgeInsets.only(left: AppSpace.s4),
                  child: Icon(
                    Icons.check_circle_rounded,
                    size: 16,
                    color: context.doneInk,
                  ),
                ),
            ],
          ),
        ],
      ),
    );

    if (isSelectionMode) {
      card = Stack(
        children: [
          card,
          PositionedDirectional(
            top: AppSpace.s8,
            end: AppSpace.s8,
            child: Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 22,
              color: isSelected ? g.clay : g.inkMuted,
            ),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: isLocked ? 'Private commitment' : displayContent(thought.content),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        onDoubleTap: isSelectionMode ? null : onDoubleTap,
        child: Opacity(opacity: thought.isCompleted ? .66 : 1, child: card),
      ),
    );
  }

  Widget _content(BuildContext context, AscentGlass g, BoardCardKind kind) {
    if (isLocked) {
      return Row(
        children: [
          Icon(Icons.lock_rounded, size: 16, color: g.clay),
          const SizedBox(width: AppSpace.s8),
          Expanded(
            child: Text(
              'Private commitment',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AscentTextStyles.bodyMedium.copyWith(color: g.ink),
            ),
          ),
        ],
      );
    }
    final text = displayContent(thought.content).trim();
    switch (kind) {
      case BoardCardKind.spark:
        return Text(
          text,
          maxLines: 4,
          overflow: TextOverflow.ellipsis,
          style: AscentTextStyles.sectionHeading.copyWith(
            color: g.ink,
            height: 1.3,
          ),
        );
      case BoardCardKind.list:
        final items = bulletItems(thought.content);
        final shown = items.take(5).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final item in shown)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpace.s4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: AppSpace.s6),
                      child: Icon(Icons.circle, size: 5, color: g.inkMuted),
                    ),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text(
                        item,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.thoughtContent(color: g.ink),
                      ),
                    ),
                  ],
                ),
              ),
            if (items.length > shown.length)
              Text(
                '+${items.length - shown.length} more',
                style: AscentTextStyles.labelSmall.copyWith(
                  color: g.inkSecondary,
                ),
              ),
          ],
        );
      case BoardCardKind.note:
      case BoardCardKind.long:
        return Text(
          text,
          maxLines: kind == BoardCardKind.long ? 10 : 7,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.thoughtContent(color: g.ink),
        );
    }
  }
}

/// The newest (or opened) thought, drawn large and high-contrast at the top.
class BoardHeroCard extends StatelessWidget {
  const BoardHeroCard({
    super.key,
    required this.thought,
    required this.now,
    this.label = 'Latest',
    this.spaceName,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onTap,
    this.onLongPress,
    this.onDoubleTap,
  });

  final Thought thought;
  final DateTime now;
  final String label;
  final String? spaceName;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = context.isDark;
    final fill = dark ? Color.alphaBlend(g.clay.withValues(alpha: .22), g.fill) : g.ink;
    final onFill = dark ? g.ink : g.bg;
    final text = displayContent(thought.content).trim();
    final short = text.length <= 90 && !text.contains('\n');

    return Semantics(
      button: true,
      selected: isSelected,
      label: text,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        onDoubleTap: isSelectionMode ? null : onDoubleTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppSpace.s20),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: AppGeometry.roundedr24,
            border: Border.all(
              color: isSelected ? g.clay : Colors.transparent,
              width: 2,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label.toUpperCase(),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AscentTextStyles.labelSmall.copyWith(
                        color: onFill.withValues(alpha: .72),
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                  if (thought.isPinned)
                    Icon(Icons.push_pin_rounded, size: 15, color: onFill),
                  if (isSelectionMode)
                    Padding(
                      padding: const EdgeInsets.only(left: AppSpace.s8),
                      child: Icon(
                        isSelected
                            ? Icons.check_circle_rounded
                            : Icons.radio_button_unchecked_rounded,
                        size: 22,
                        color: onFill,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: AppSpace.s10),
              Text(
                text,
                maxLines: short ? 4 : 8,
                overflow: TextOverflow.ellipsis,
                style: short
                    ? AscentTextStyles.pageTitle.copyWith(
                        color: onFill,
                        height: 1.25,
                      )
                    : AppTypography.thoughtContent(color: onFill).copyWith(
                        fontSize: 17,
                      ),
              ),
              const SizedBox(height: AppSpace.s12),
              Text(
                [
                  boardTimeLabel(thought.createdAt, now),
                  if (spaceName != null) '#$spaceName',
                ].join('  ·  '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AscentTextStyles.labelSmall.copyWith(
                  color: onFill.withValues(alpha: .72),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
