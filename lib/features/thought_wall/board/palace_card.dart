import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../shared/widgets/selection_tick.dart';
import '../thought_wall_preferences.dart';
import 'board_cards.dart' show boardAccentFor, boardMoodIcon;
import 'board_logic.dart';
import 'thought_lifecycle.dart';
import 'thought_lines.dart';

/// One thought in the Mindspace.
///
/// Reading never opens a popup: tapping the card grows it to its full text and
/// shows one action strip; tapping again folds it. The only extra control is a
/// small chevron on the footer row, drawn only when the text really overflows.
class PalaceCard extends StatefulWidget {
  const PalaceCard({
    super.key,
    required this.thought,
    required this.now,
    required this.appearance,
    this.place = ThoughtPlace.today,
    this.spaceName,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.isLocked = false,
    this.highlight = false,
    this.onSelectToggle,
    this.onLongPress,
    this.onDoubleTap,
    this.onUnlock,
    this.onToggleItem,
    this.onDone,
    this.onEdit,
    this.onArchive,
    this.onMore,
    this.onBring,
    this.note,
  });

  final Thought thought;
  final DateTime now;
  final ThoughtWallAppearance appearance;
  final ThoughtPlace place;
  final String? spaceName;
  final bool isSelected;
  final bool isSelectionMode;

  /// A private commitment that is still locked.
  final bool isLocked;

  /// Opened from Home: starts expanded and gets an accent border.
  final bool highlight;
  final VoidCallback? onSelectToggle;
  final VoidCallback? onLongPress;
  final VoidCallback? onDoubleTap;
  final VoidCallback? onUnlock;

  /// Ticks or unticks the bullet with this checklist index.
  final void Function(int itemIndex)? onToggleItem;
  final VoidCallback? onDone;
  final VoidCallback? onEdit;
  final VoidCallback? onArchive;
  final VoidCallback? onMore;

  /// Present only in the Earlier row: brings this thought to Today.
  final VoidCallback? onBring;

  /// Pointer shown in History, e.g. "finished 20 Nov".
  final String? note;

  @override
  State<PalaceCard> createState() => _PalaceCardState();
}

class _PalaceCardState extends State<PalaceCard> {
  late bool _expanded = widget.highlight;

  static const _collapsedTextLines = 4;
  static const _collapsedItems = 5;

  Thought get thought => widget.thought;

  @override
  void didUpdateWidget(covariant PalaceCard old) {
    super.didUpdateWidget(old);
    if (old.thought.id != thought.id) _expanded = widget.highlight;
    if (widget.isSelectionMode && _expanded) _expanded = false;
  }

  void _toggleExpanded() {
    HapticFeedback.lightImpact();
    setState(() => _expanded = !_expanded);
  }

  void _onTap() {
    if (widget.isSelectionMode) return widget.onSelectToggle?.call();
    if (widget.isLocked) return widget.onUnlock?.call();
    _toggleExpanded();
  }

  TextStyle _bodyStyle(AscentGlass g) =>
      AppTypography.thoughtContent(color: g.ink);

  /// True when the collapsed card would hide part of the text.
  bool _overflows(BuildContext context, double width, List<ThoughtLine> lines) {
    if (widget.isLocked) return false;
    final g = context.glass;
    final isList = listItems(displayContent(thought.content)).isNotEmpty;
    if (isList) {
      if (lines.length > _collapsedItems) return true;
      // Bullet text is clamped to two lines; measure each against the width
      // left after the 44dp leading box.
      for (final line in lines) {
        if (_exceeds(context, line.text, width - 44, 2, _bodyStyle(g))) {
          return true;
        }
      }
      return false;
    }
    final text = lines.map((l) => l.text).join('\n');
    return _exceeds(context, text, width, _collapsedTextLines, _bodyStyle(g));
  }

  bool _exceeds(
    BuildContext context,
    String text,
    double width,
    int maxLines,
    TextStyle style,
  ) {
    if (width <= 0) return false;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: maxLines,
    )..layout(maxWidth: width);
    final over = painter.didExceedMaxLines;
    painter.dispose();
    return over;
  }

  Widget _leading(
    AscentGlass g,
    ThoughtLine line,
    BulletStyle style,
    bool enabled,
  ) {
    if (style.showsCircle(line)) {
      final done = line.isDone;
      return GestureDetector(
        key: ValueKey('bullet_toggle_${thought.id}_${line.itemIndex}'),
        behavior: HitTestBehavior.opaque,
        onTap: enabled && !widget.isSelectionMode
            ? () {
                HapticFeedback.selectionClick();
                widget.onToggleItem?.call(line.itemIndex!);
              }
            : null,
        child: SizedBox(
          width: 44,
          height: 36,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 160),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: done ? context.doneInk : Colors.transparent,
                border: Border.all(
                  color: done ? context.doneInk : g.inkMuted,
                  width: 1.4,
                ),
              ),
              child: done
                  ? Icon(Icons.check_rounded, size: 14, color: g.bg)
                  : null,
            ),
          ),
        ),
      );
    }
    final glyph = line.glyph ?? '•';
    return SizedBox(
      width: 44,
      height: 28,
      child: Center(
        child: Text(
          glyph,
          key: ValueKey('bullet_glyph_${thought.id}_${line.itemIndex}'),
          style: AscentTextStyles.bodyMedium.copyWith(color: g.inkMuted),
        ),
      ),
    );
  }

  Widget _body(
    BuildContext context,
    AscentGlass g,
    List<ThoughtLine> lines,
    bool overflow,
  ) {
    if (widget.isLocked) {
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
    final style = resolveBulletStyle(
      thought.bulletStyle,
      widget.appearance.defaultBullets,
    );
    final isList = listItems(displayContent(thought.content)).isNotEmpty;
    final body = _bodyStyle(g);
    final canTick = !thought.isArchived;

    if (!isList) {
      final text = lines.map((l) => l.text).join('\n');
      final textWidget = _expanded || !overflow
          ? Text(text, style: body)
          : ShaderMask(
              shaderCallback: (rect) => const LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.black, Colors.black, Colors.transparent],
                stops: [0.0, 0.72, 1.0],
              ).createShader(rect),
              blendMode: BlendMode.dstIn,
              child: Text(
                text,
                maxLines: _collapsedTextLines,
                overflow: TextOverflow.clip,
                style: body,
              ),
            );
      return textWidget;
    }

    final shown = _expanded || !overflow
        ? lines
        : lines.take(_collapsedItems).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (final line in shown)
          if (line.isItem)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _leading(g, line, style, canTick),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Text(
                      line.text,
                      maxLines: _expanded ? null : 2,
                      overflow: _expanded ? null : TextOverflow.ellipsis,
                      style: body.copyWith(
                        fontWeight: line.isHighlighted
                            ? FontWeight.w700
                            : null,
                        color: style.showsCircle(line) && line.isDone
                            ? g.inkMuted
                            : g.ink,
                        decoration:
                            style.showsCircle(line) && line.isDone
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                line.text,
                maxLines: _expanded ? null : 2,
                overflow: _expanded ? null : TextOverflow.ellipsis,
                style: body,
              ),
            ),
        if (!_expanded && overflow && lines.length > _collapsedItems)
          Padding(
            padding: const EdgeInsets.only(left: 44, top: 2),
            child: Text(
              '+${lines.length - _collapsedItems} more',
              style: AscentTextStyles.labelSmall.copyWith(
                color: g.inkSecondary,
              ),
            ),
          ),
      ],
    );
  }

  Widget _footer(
    BuildContext context,
    AscentGlass g,
    bool canFold,
    Color accent,
  ) {
    final tagStyle = AscentTextStyles.labelSmall.copyWith(color: g.inkMuted);
    final progress = widget.isLocked ? null : progressLabel(thought.content);
    final origin = originTag(thought, widget.now);
    final tags = <Widget>[
      Text(boardTimeLabel(thought.createdAt, widget.now), style: tagStyle),
      if (origin != null)
        Text(origin, key: ValueKey('tag_origin_${thought.id}'), style: tagStyle),
      if (widget.place == ThoughtPlace.archivedToday)
        Text(
          'Archived',
          key: ValueKey('tag_archived_${thought.id}'),
          style: tagStyle.copyWith(color: g.clay, fontWeight: FontWeight.w700),
        ),
      if (progress != null)
        Text(progress, key: ValueKey('tag_progress_${thought.id}'), style: tagStyle),
      if (widget.note != null)
        Text(widget.note!, key: ValueKey('tag_note_${thought.id}'), style: tagStyle),
      if (widget.spaceName != null)
        Text('#${widget.spaceName}', style: tagStyle),
    ];
    return Row(
      children: [
        Expanded(
          child: Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              ...tags,
              if (thought.isPinned)
                Icon(Icons.push_pin_rounded, size: 13, color: accent),
              if (thought.isCompleted)
                Icon(
                  Icons.check_circle_rounded,
                  size: 15,
                  color: context.doneInk,
                ),
            ],
          ),
        ),
        if (canFold)
          GestureDetector(
            key: ValueKey('card_chevron_${thought.id}'),
            behavior: HitTestBehavior.opaque,
            onTap: _toggleExpanded,
            child: SizedBox(
              width: 44,
              height: 32,
              child: Align(
                alignment: Alignment.centerRight,
                child: Icon(
                  _expanded
                      ? Icons.keyboard_arrow_up_rounded
                      : Icons.keyboard_arrow_down_rounded,
                  size: 20,
                  color: g.inkSecondary,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _action(
    AscentGlass g, {
    required Key key,
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    Color? color,
  }) {
    final ink = color ?? g.ink;
    return Semantics(
      button: true,
      label: label,
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        onTap: onTap == null
            ? null
            : () {
                HapticFeedback.selectionClick();
                onTap();
              },
        child: Container(
          constraints: const BoxConstraints(minHeight: 44, minWidth: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s12,
            vertical: AppSpace.s8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: ink.withValues(alpha: .28)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 17, color: ink),
              const SizedBox(width: 6),
              Text(
                label,
                style: AscentTextStyles.interfaceLabel.copyWith(color: ink),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actionStrip(AscentGlass g) {
    final archived = thought.isArchived;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s8),
      child: Wrap(
        key: ValueKey('card_actions_${thought.id}'),
        spacing: AppSpace.s8,
        runSpacing: AppSpace.s8,
        children: [
          if (widget.onBring != null)
            _action(
              g,
              key: ValueKey('card_bring_${thought.id}'),
              icon: Icons.today_rounded,
              label: 'Bring to Today',
              onTap: widget.onBring,
            ),
          _action(
            g,
            key: ValueKey('card_done_${thought.id}'),
            icon: thought.isCompleted
                ? Icons.replay_rounded
                : Icons.check_rounded,
            label: thought.isCompleted ? 'Reopen' : 'Done',
            onTap: widget.onDone,
          ),
          _action(
            g,
            key: ValueKey('card_edit_${thought.id}'),
            icon: Icons.edit_outlined,
            label: 'Edit',
            onTap: widget.onEdit,
          ),
          _action(
            g,
            key: ValueKey('card_archive_${thought.id}'),
            icon: archived ? Icons.unarchive_outlined : Icons.archive_outlined,
            label: archived ? 'Restore' : 'Archive',
            onTap: widget.onArchive,
          ),
          _action(
            g,
            key: ValueKey('card_more_${thought.id}'),
            icon: Icons.more_horiz_rounded,
            label: 'More',
            onTap: widget.onMore,
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final dark = context.isDark;
    final appearance = widget.appearance;
    final minimal = appearance.style == ThoughtCardStyle.minimal;
    final padding = appearance.density == ThoughtCardDensity.comfortable
        ? AppSpace.s16
        : AppSpace.s12;
    final accentColor = boardAccentFor(g, thought);
    final filled = appearance.bubbleFilled && !dark && !minimal;
    final fill = filled
        ? g.elevated
        : (dark ? Colors.transparent : g.elevated.withValues(alpha: .55));
    final dimmed =
        thought.isCompleted || widget.place == ThoughtPlace.archivedToday;
    final borderColor = widget.isSelected || widget.highlight
        ? g.clay
        : thought.isCompleted
        ? context.doneInk.withValues(alpha: dark ? .35 : .25)
        : Color.lerp(g.edge, accentColor.withValues(alpha: .20), .4)!;
    final moodIcon = boardMoodIcon(thought.mood);
    final high = isHighPriorityContent(thought.content);

    final lines = widget.isLocked
        ? const <ThoughtLine>[]
        : parseThoughtLines(displayContent(thought.content).trim());

    final card = LayoutBuilder(
      builder: (context, constraints) {
        final textWidth = constraints.maxWidth - padding * 2 - 2;
        final overflow = _overflows(context, textWidth, lines);
        final listLike = listItems(displayContent(thought.content)).isNotEmpty;
        final showStrip =
            _expanded && !widget.isSelectionMode && !widget.isLocked;
        final style = resolveBulletStyle(
          thought.bulletStyle,
          appearance.defaultBullets,
        );
        final offerDone =
            showStrip &&
            listLike &&
            style != BulletStyle.bullet &&
            !thought.isCompleted &&
            !thought.isArchived &&
            allItemsDone(displayContent(thought.content));
        return Container(
          decoration: BoxDecoration(
            color: fill,
            borderRadius: minimal
                ? AppGeometry.roundedr8
                : BorderRadius.circular(18),
            border: Border.all(
              color: borderColor,
              width: widget.isSelected ? 1.8 : 1.0,
            ),
          ),
          padding: EdgeInsets.all(padding),
          child: AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            alignment: Alignment.topLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (moodIcon != null || high) ...[
                  Row(
                    children: [
                      if (moodIcon != null)
                        Icon(moodIcon, size: 15, color: accentColor),
                      if (high) ...[
                        const SizedBox(width: AppSpace.s6),
                        Icon(Icons.star_rounded, size: 15, color: g.clay),
                      ],
                    ],
                  ),
                  const SizedBox(height: AppSpace.s6),
                ],
                _body(context, g, lines, overflow),
                const SizedBox(height: AppSpace.s4),
                _footer(context, g, overflow, accentColor),
                if (offerDone)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      key: ValueKey('card_all_done_${thought.id}'),
                      behavior: HitTestBehavior.opaque,
                      onTap: widget.onDone,
                      child: Container(
                        constraints: const BoxConstraints(minHeight: 44),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'All done. Mark thought done?',
                          style: AscentTextStyles.labelLarge.copyWith(
                            color: g.clay,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                if (showStrip) _actionStrip(g),
              ],
            ),
          ),
        );
      },
    );

    Widget out = card;
    if (widget.isSelectionMode) {
      out = Stack(
        children: [
          card,
          PositionedDirectional(
            top: AppSpace.s8,
            end: AppSpace.s8,
            child: SelectionTick(selected: widget.isSelected),
          ),
        ],
      );
    }

    return Semantics(
      button: true,
      selected: widget.isSelected,
      expanded: _expanded,
      label: widget.isLocked
          ? 'Private commitment'
          : displayContent(thought.content),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _onTap,
        onLongPress: widget.onLongPress,
        onDoubleTap: widget.isSelectionMode ? null : widget.onDoubleTap,
        child: Opacity(opacity: dimmed ? .66 : 1, child: out),
      ),
    );
  }
}
