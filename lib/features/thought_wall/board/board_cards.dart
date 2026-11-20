import '../../../shared/widgets/selection_tick.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/shared_control_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../thought_wall_preferences.dart';
import '../utils/thought_checklist_helper.dart';
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

BorderRadius _boardRadius(ThoughtCardStyle style, int index) => switch (style) {
  ThoughtCardStyle.soft || ThoughtCardStyle.bubble => BorderRadius.only(
    topLeft: index.isEven ? const Radius.circular(6) : const Radius.circular(18),
    topRight: index.isOdd ? const Radius.circular(6) : const Radius.circular(18),
    bottomLeft: const Radius.circular(18),
    bottomRight: const Radius.circular(18),
  ),
  ThoughtCardStyle.minimal => AppGeometry.roundedr8,
};

/// One thought on the board. It shows the thought and nothing else: no
/// buttons, no menus. Tap opens it, long-press selects, double-tap completes.
/// Long thoughts expand and collapse inline with smooth liquid animation.
class BoardCard extends StatefulWidget {
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
  State<BoardCard> createState() => _BoardCardState();
}

class _BoardCardState extends State<BoardCard>
    with SingleTickerProviderStateMixin {
  bool _expanded = false;
  late final AnimationController _cardAnimController;
  late final Animation<double> _cardFade;
  late final Animation<Offset> _cardSlide;

  @override
  void initState() {
    super.initState();
    _cardAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _cardFade = CurvedAnimation(
      parent: _cardAnimController,
      curve: Curves.easeOut,
    );
    _cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.07),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _cardAnimController,
      curve: Curves.easeOutCubic,
    ));
    _cardAnimController.forward();
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    super.dispose();
  }

  Thought get thought => widget.thought;
  int get index => widget.index;
  DateTime get now => widget.now;
  ThoughtWallAppearance get appearance => widget.appearance;
  String? get spaceName => widget.spaceName;
  bool get isSelected => widget.isSelected;
  bool get isSelectionMode => widget.isSelectionMode;
  bool get isLocked => widget.isLocked;
  VoidCallback? get onTap => widget.onTap;
  VoidCallback? get onLongPress => widget.onLongPress;
  VoidCallback? get onDoubleTap => widget.onDoubleTap;

  @override
  void didUpdateWidget(covariant BoardCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.thought.id != widget.thought.id) {
      _expanded = false;
    }
  }

  /// Width that fits the text instead of always spanning the screen. Anything
  /// that needs the full card (long text, checklists, prompts, promises,
  /// selection mode) keeps the full width.
  double _hugWidth(BuildContext context, double maxWidth) {
    if (!maxWidth.isFinite ||
        isSelectionMode ||
        appearance.style == ThoughtCardStyle.minimal ||
        thought.mood == 'promise') {
      return maxWidth;
    }
    final content = isHighPriorityContent(thought.content)
        ? thought.content.replaceFirst(RegExp(r'^\[HIGH\]\s*'), '')
        : thought.content;
    if (ThoughtChecklistHelper.hasChecklistItems(content)) return maxWidth;
    final kind = isLocked ? BoardCardKind.note : boardCardKind(thought.content);
    if (kind == BoardCardKind.list || kind == BoardCardKind.long || isLocked) {
      return maxWidth;
    }
    final text = displayContent(thought.content).trim();
    if (text.length > 220 || text.contains('\n\n')) {
      return maxWidth;
    }

    final comfortable = appearance.density == ThoughtCardDensity.comfortable;
    final padding = comfortable ? AppSpace.s16 : AppSpace.s12;
    final chrome = padding * 2 + 4; // padding, 1px borders and a small safety gap

    final textStyle = kind == BoardCardKind.spark
        ? AscentTextStyles.cardTitle.copyWith(
            color: context.glass.ink,
            fontSize: 15.5,
            fontWeight: FontWeight.w500,
            height: 1.4,
          )
        : AppTypography.thoughtContent(color: context.glass.ink);

    final painter = TextPainter(
      text: TextSpan(
        text: text,
        style: textStyle,
      ),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 6,
      textWidthBasis: TextWidthBasis.longestLine,
    )..layout(maxWidth: (maxWidth - chrome).clamp(0.0, maxWidth));

    final overflowed = painter.didExceedMaxLines;
    final textWidth = painter.width + chrome;
    painter.dispose();
    if (overflowed) return maxWidth;

    // Minimum floor so date & action indicators fit comfortably without wrapping.
    final floor = maxWidth < 200.0 ? maxWidth : 200.0;
    return textWidth.clamp(floor, maxWidth);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = context.isDark;
    final accent = boardAccentFor(g, thought);
    final kind = isLocked ? BoardCardKind.note : boardCardKind(thought.content);
    final minimal = appearance.style == ThoughtCardStyle.minimal;
    final comfortable = appearance.density == ThoughtCardDensity.comfortable;
    final padding = comfortable ? AppSpace.s16 : AppSpace.s12;
    // Night bubbles are always transparent with a hairline, so no shade can
    // appear behind the text even if the filled-bubble option is on.
    final filled = appearance.bubbleFilled && !dark;
    final fill = (!filled || minimal)
        ? (dark
            ? Colors.transparent
            : const Color(0xFFF7F5F0).withValues(alpha: .75))
        : (dark ? const Color(0xFF16181F) : const Color(0xFFF7F5F0));
    final borderColor = isSelected
        ? (dark ? SharedControlColors.actionBlueDark : SharedControlColors.actionBlue)
        : thought.isCompleted
        ? context.doneInk.withValues(alpha: dark ? .35 : .25)
        : (dark
            // A visible hairline on the night canvas, softly tinted by mood.
            ? Color.alphaBlend(
                accent.withValues(alpha: 0.40),
                g.ink.withValues(alpha: 0.26),
              )
            : Color.lerp(
                g.edge,
                accent.withValues(alpha: 0.20),
                0.40,
              )!);
    final borderWidth = isSelected ? 1.8 : 1.0;
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
        boxShadow: (minimal || !filled)
            ? const []
            : [
                BoxShadow(
                  color: (dark ? accent : Colors.black).withValues(
                    alpha: dark ? 0.20 : 0.04,
                  ),
                  blurRadius: dark ? 12 : 8,
                  offset: dark ? Offset.zero : const Offset(0, 2),
                ),
              ],
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
                if (high)
                  Icon(
                    Icons.star_rounded,
                    size: 15,
                    color: dark
                        ? SharedControlColors.actionBlueDark
                        : SharedControlColors.actionBlue,
                  ),
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
            child: SelectionTick(selected: isSelected),
          ),
        ],
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final hugWidth = constraints.constrainWidth(
          _hugWidth(context, constraints.maxWidth),
        );
        return SizedBox(
          width: hugWidth,
          child: FadeTransition(
            opacity: _cardFade,
            child: SlideTransition(
              position: _cardSlide,
              child: Semantics(
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
              ),
            ),
          ),
        );
      },
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
          style: AscentTextStyles.cardTitle.copyWith(
            color: g.ink,
            fontSize: 15.5,
            fontWeight: FontWeight.w500,
            height: 1.4,
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
        final isVeryLong =
            kind == BoardCardKind.long ||
            text.length > 220 ||
            text.contains('\n\n');
        if (isVeryLong) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeInOutCubic,
                alignment: Alignment.topLeft,
                child: _expanded
                    ? Text(
                        text,
                        style: AppTypography.thoughtContent(color: g.ink),
                      )
                    : ShaderMask(
                        shaderCallback: (rect) => const LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            Colors.black,
                            Colors.black,
                            Colors.transparent,
                          ],
                          stops: [0.0, 0.72, 1.0],
                        ).createShader(rect),
                        blendMode: BlendMode.dstIn,
                        child: Text(
                          text,
                          maxLines: kind == BoardCardKind.long ? 6 : 5,
                          overflow: TextOverflow.clip,
                          style: AppTypography.thoughtContent(color: g.ink),
                        ),
                      ),
              ),
              const SizedBox(height: AppSpace.s6),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  HapticFeedback.lightImpact();
                  setState(() => _expanded = !_expanded);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: g.clay.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(
                      color: g.clay.withValues(alpha: 0.22),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _expanded ? 'Show less' : 'Show more',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: g.clay,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        _expanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 13,
                        color: g.clay,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        }
        return Text(
          text,
          maxLines: 6,
          overflow: TextOverflow.ellipsis,
          style: AppTypography.thoughtContent(color: g.ink),
        );
    }
  }
}
