import 'package:flutter/material.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';

/// One card for a whole list, instead of one card per item.
///
/// Rows are built lazily, so 1,000 items cost only the rows on screen.
/// Short lists size to their content; long ones get a fixed height and
/// scroll inside the card (thin rounded scrollbar, a soft fade at the edge
/// that hints there is more), so the page itself does not have to scroll
/// past hundreds of rows to reach what is below.
class ScrollCard extends StatefulWidget {
  const ScrollCard({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.title,
    this.icon,
    this.count,
    this.trailing,
    this.maxHeight,
    this.scrollAfter = 7,
    this.divider = true,
    this.dividerIndent = AppSpace.s16,
    this.empty,
    this.fill = false,
  });

  /// Fill the height the parent gives (inside an `Expanded`) and always
  /// scroll inside, so the screen around the card stays still.
  final bool fill;

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;

  /// Optional header row (icon, title, count, trailing action).
  final String? title;
  final IconData? icon;
  final int? count;
  final Widget? trailing;

  /// Height of the scrolling body; defaults to about 60% of the screen.
  final double? maxHeight;

  /// Up to this many items the card just grows; beyond it, it scrolls.
  final int scrollAfter;
  final bool divider;
  final double dividerIndent;

  /// Shown inside the card when there are no items.
  final Widget? empty;

  @override
  State<ScrollCard> createState() => _ScrollCardState();
}

class _ScrollCardState extends State<ScrollCard> {
  final _controller = ScrollController();
  bool _atEnd = false;

  @override
  void initState() {
    super.initState();
    _controller.addListener(_onScroll);
  }

  @override
  void dispose() {
    _controller.removeListener(_onScroll);
    _controller.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (!_controller.hasClients) return;
    final end =
        _controller.position.pixels >=
        _controller.position.maxScrollExtent - 4;
    if (end != _atEnd) setState(() => _atEnd = end);
  }

  Widget _separator(BuildContext context) => Divider(
    height: 1,
    thickness: 1,
    indent: widget.dividerIndent,
    color: context.glass.line,
  );

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final n = widget.itemCount;
    Widget body;
    if (n == 0) {
      body = widget.empty ?? const SizedBox.shrink();
    } else if (n <= widget.scrollAfter && !widget.fill) {
      body = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < n; i++) ...[
            if (i > 0 && widget.divider) _separator(context),
            widget.itemBuilder(context, i),
          ],
        ],
      );
    } else {
      final height =
          widget.maxHeight ??
          (MediaQuery.sizeOf(context).height * .6).clamp(280.0, 620.0);
      final list = Scrollbar(
        controller: _controller,
        thickness: 3,
        radius: const Radius.circular(999),
        thumbVisibility: true,
        child: ListView.separated(
          controller: _controller,
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.only(right: AppSpace.s4),
          itemCount: n,
          separatorBuilder: (c, _) =>
              widget.divider ? _separator(c) : const SizedBox.shrink(),
          itemBuilder: widget.itemBuilder,
        ),
      );
      body = SizedBox(
        height: widget.fill ? null : height,
        child: Stack(
          children: [
            Positioned.fill(child: list),
            // A soft fade at the bottom says "there is more" without a label.
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: 28,
              child: IgnorePointer(
                child: AnimatedOpacity(
                  opacity: _atEnd ? 0 : 1,
                  duration: const Duration(milliseconds: 200),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [g.surface.withValues(alpha: 0), g.surface],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }
    final header = widget.title == null
        ? null
        : Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpace.s16,
              AppSpace.s12,
              AppSpace.s8,
              AppSpace.s8,
            ),
            child: Row(
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 18, color: g.inkSecondary),
                  const SizedBox(width: AppSpace.s8),
                ],
                Flexible(
                  child: Text(
                    widget.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AscentTextStyles.listRowTitle.copyWith(
                      color: g.ink,
                    ),
                  ),
                ),
                if (widget.count != null) ...[
                  const SizedBox(width: AppSpace.s8),
                  Text(
                    '${widget.count}',
                    style: AscentTextStyles.tabular(
                      AscentTextStyles.caption,
                    ).copyWith(color: g.inkMuted),
                  ),
                ],
                const Spacer(),
                ?widget.trailing,
              ],
            ),
          );
    return DecoratedBox(
      decoration: BoxDecoration(
        color: g.surface,
        borderRadius: AppGeometry.roundedr20,
        border: Border.all(color: g.line),
      ),
      child: ClipRRect(
        borderRadius: AppGeometry.roundedr20,
        child: Column(
          mainAxisSize: widget.fill ? MainAxisSize.max : MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            ?header,
            if (header != null && n > 0) Divider(height: 1, color: g.line),
            if (widget.fill && n > 0) Expanded(child: body) else body,
          ],
        ),
      ),
    );
  }
}

/// A small section label inside a [ScrollCard] list ("Overdue 20").
class ScrollCardSection extends StatelessWidget {
  const ScrollCardSection({
    super.key,
    required this.title,
    this.count,
    this.icon,
    this.color,
    this.onTap,
    this.collapsed,
  });
  final String title;
  final int? count;
  final IconData? icon;
  final Color? color;
  final VoidCallback? onTap;

  /// When set, shows a chevron (collapsed or open).
  final bool? collapsed;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final c = color ?? g.inkSecondary;
    return Semantics(
      header: true,
      button: onTap != null,
      child: InkWell(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 40),
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s16,
            AppSpace.s10,
            AppSpace.s12,
            AppSpace.s6,
          ),
          child: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 15, color: c),
                const SizedBox(width: AppSpace.s6),
              ],
              Flexible(
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.caption.copyWith(color: c),
                ),
              ),
              if (count != null) ...[
                const SizedBox(width: AppSpace.s6),
                Text(
                  '$count',
                  style: AscentTextStyles.tabular(
                    AscentTextStyles.caption,
                  ).copyWith(color: g.inkMuted),
                ),
              ],
              const Spacer(),
              if (collapsed != null)
                Icon(
                  collapsed!
                      ? Icons.keyboard_arrow_down_rounded
                      : Icons.keyboard_arrow_up_rounded,
                  size: 18,
                  color: g.inkMuted,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
