import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/shared_control_tokens.dart';
import '../../app/theme/text_styles.dart';

/// The core button variants in the Ascent design system.
enum AscentButtonType {
  primary,
  secondary,
  tonal,
  outlined,
  ghost,
  icon,
  fab,
  destructive,
  navigation,
}

/// Unified, Apple-inspired button system as specified in Section 5 (C01).
class AscentButton extends StatelessWidget {
  const AscentButton({
    super.key,
    required this.type,
    this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = false,
    this.compact = false,
    this.tooltip,
    this.semanticLabel,
    this.iconAtEnd = false,
    this.strongOutline = false,
  });

  // ── Named constructors ────────────────────────────────────────────────────

  const AscentButton.primary({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = false,
    this.compact = false,
    this.tooltip,
    this.semanticLabel,
    this.iconAtEnd = false,
    this.strongOutline = false,
  }) : type = AscentButtonType.primary;

  const AscentButton.secondary({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = false,
    this.compact = false,
    this.tooltip,
    this.semanticLabel,
    this.iconAtEnd = false,
    this.strongOutline = false,
  }) : type = AscentButtonType.secondary;

  const AscentButton.tonal({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = false,
    this.compact = false,
    this.tooltip,
    this.semanticLabel,
    this.iconAtEnd = false,
    this.strongOutline = false,
  }) : type = AscentButtonType.tonal;

  const AscentButton.outlined({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = false,
    this.compact = false,
    this.tooltip,
    this.semanticLabel,
    this.iconAtEnd = false,
    this.strongOutline = false,
  }) : type = AscentButtonType.outlined;

  const AscentButton.ghost({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = false,
    this.compact = false,
    this.tooltip,
    this.semanticLabel,
    this.iconAtEnd = false,
    this.strongOutline = false,
  }) : type = AscentButtonType.ghost;

  const AscentButton.icon({
    super.key,
    required IconData this.icon,
    this.onPressed,
    this.compact = false,
    this.tooltip,
    this.semanticLabel,
    this.iconAtEnd = false,
    this.strongOutline = false,
  }) : type = AscentButtonType.icon,
       label = null,
       loading = false,
       expanded = false;

  const AscentButton.fab({
    super.key,
    required IconData this.icon,
    this.onPressed,
    this.tooltip,
    this.semanticLabel,
    this.iconAtEnd = false,
    this.strongOutline = false,
  }) : type = AscentButtonType.fab,
       label = null,
       loading = false,
       expanded = false,
       compact = false;

  const AscentButton.destructive({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = false,
    this.compact = false,
    this.tooltip,
    this.semanticLabel,
    this.iconAtEnd = false,
    this.strongOutline = false,
  }) : type = AscentButtonType.destructive;

  // ── Fields ────────────────────────────────────────────────────────────────

  const AscentButton.navigation({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.iconAtEnd = false,
    this.strongOutline = false,
    this.tooltip,
    this.semanticLabel,
  }) : type = AscentButtonType.navigation,
       loading = false,
       expanded = false,
       compact = false;

  final AscentButtonType type;
  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final bool compact;
  final String? tooltip;
  final String? semanticLabel;
  final bool iconAtEnd;
  final bool strongOutline;

  @override
  Widget build(BuildContext context) {
    return _AscentButtonInternal(
      type: type,
      label: label,
      icon: icon,
      onPressed: onPressed,
      loading: loading,
      expanded: expanded,
      compact: compact,
      tooltip: tooltip,
      semanticLabel: semanticLabel,
      iconAtEnd: iconAtEnd,
      strongOutline: strongOutline,
    );
  }
}

class _AscentButtonInternal extends StatefulWidget {
  const _AscentButtonInternal({
    required this.type,
    this.label,
    this.icon,
    this.onPressed,
    required this.loading,
    required this.expanded,
    required this.compact,
    this.tooltip,
    this.semanticLabel,
    this.iconAtEnd = false,
    this.strongOutline = false,
  });

  final AscentButtonType type;
  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final bool compact;
  final String? tooltip;
  final String? semanticLabel;
  final bool iconAtEnd;
  final bool strongOutline;

  @override
  State<_AscentButtonInternal> createState() => _AscentButtonInternalState();
}

class _AscentButtonInternalState extends State<_AscentButtonInternal> {
  bool _pressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.loading;

  void _triggerTap() {
    if (!_isEnabled) return;
    if (widget.type == AscentButtonType.destructive) {
      HapticFeedback.mediumImpact();
    } else {
      HapticFeedback.lightImpact();
    }
    widget.onPressed?.call();
  }

  void _onTapDown(TapDownDetails _) {
    if (!_isEnabled) return;
    setState(() => _pressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    if (!_isEnabled) return;
    setState(() => _pressed = false);
    _triggerTap();
  }

  void _onTapCancel() {
    if (!_isEnabled) return;
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    final isPrimary =
        widget.type == AscentButtonType.primary ||
        widget.type == AscentButtonType.fab;
    final isDestructive = widget.type == AscentButtonType.destructive;
    final isTonal =
        widget.type == AscentButtonType.tonal ||
        widget.type == AscentButtonType.secondary;
    final isOutlined = widget.type == AscentButtonType.outlined;
    final isGhost = widget.type == AscentButtonType.ghost;
    final isIcon = widget.type == AscentButtonType.icon;
    final isNavigation = widget.type == AscentButtonType.navigation;

    // Normal colors
    Color bg;
    Color fg;
    Border? border;

    if (!_isEnabled) {
      bg = isGhost || isIcon || isNavigation
          ? Colors.transparent
          : g.disabledBg;
      fg = g.disabledFg;
      border = isOutlined
          ? Border.all(
              color: g.disabledFg.withValues(alpha: 0.3),
              width: AscentDimensions.controlOutlineWidth,
            )
          : null;
    } else if (isNavigation) {
      bg = _pressed ? g.recessed : Colors.transparent;
      fg = g.ink;
    } else if (isPrimary) {
      final blue = Theme.of(context).brightness == Brightness.dark
          ? SharedControlColors.actionBlueDark
          : SharedControlColors.actionBlue;
      bg = Color.alphaBlend(
        blue.withValues(
          alpha: _pressed ? (g.monochrome != null ? .14 : .18) : .10,
        ),
        Theme.of(context).colorScheme.surface,
      );
      fg =
          g.monochrome != null &&
              Theme.of(context).brightness == Brightness.light
          ? SharedControlColors.actionBlueInkLight
          : blue;
      border = Border.all(color: blue.withValues(alpha: .18), width: .8);
    } else if (isDestructive) {
      bg = _pressed ? g.destructivePressed : g.destructiveBg;
      fg = g.destructiveFg;
    } else if (isTonal) {
      final baseBg = g.tonalBg;
      bg = _pressed
          ? Color.alphaBlend(g.ink.withValues(alpha: 0.06), baseBg)
          : baseBg;
      fg = g.tonalFg;
    } else if (isOutlined) {
      const baseBg = Colors.transparent;
      bg = _pressed
          ? Color.alphaBlend(g.ink.withValues(alpha: 0.06), baseBg)
          : baseBg;
      fg = g.ink;
      border = Border.all(
        color: widget.strongOutline ? g.ink : g.controlOutline,
        width: AscentDimensions.controlOutlineWidth,
      );
    } else if (isGhost) {
      bg = _pressed ? g.ink.withValues(alpha: 0.06) : Colors.transparent;
      fg = g.primaryButtonBg;
    } else {
      // isIcon
      bg = _pressed ? g.ink.withValues(alpha: 0.06) : Colors.transparent;
      fg = g.actionInk;
    }

    // Geometry. The drawn shape is slim and crisp (36 / 32 px); the invisible
    // outer wrapper below still guarantees the 48 px accessible tap region.
    final visualHeight = widget.compact
        ? AscentDimensions.buttonVisualHeightCompact
        : AscentDimensions.buttonVisualHeight;

    final horizontalPadding = isNavigation
        ? 8.0
        : (widget.compact ? 12.0 : 14.0);

    Widget buttonContent;

    if (widget.type == AscentButtonType.fab) {
      buttonContent = Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        alignment: Alignment.center,
        child: Icon(widget.icon, size: 24, color: fg),
      );
    } else if (isIcon) {
      buttonContent = Container(
        width: AscentDimensions.minTouchTarget,
        height: AscentDimensions.minTouchTarget,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AscentDimensions.radiusMd),
        ),
        alignment: Alignment.center,
        child: Icon(widget.icon, size: 20, color: fg),
      );
    } else {
      // Regular button with text and optional icon / spinner
      final textStyle = isNavigation || g.monochrome != null
          ? AscentTextStyles.interfaceNavigation.copyWith(color: fg)
          : AscentTextStyles.buttonLabel.copyWith(
              color: fg,
              fontSize: widget.compact ? 13.5 : 14.5,
            );

      buttonContent = Container(
        width: widget.expanded ? double.infinity : null,
        constraints: BoxConstraints(
          minHeight: visualHeight,
          minWidth: widget.compact ? 48.0 : 64.0,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AscentDimensions.radiusMd),
          border: border,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: horizontalPadding,
          vertical: 5,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.loading) ...[
              SizedBox(
                width: widget.compact ? 14 : 16,
                height: widget.compact ? 14 : 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                ),
              ),
              const SizedBox(width: AscentDimensions.spaceSm),
            ] else if (widget.icon != null && !widget.iconAtEnd) ...[
              Icon(widget.icon, size: widget.compact ? 15 : 17, color: fg),
              const SizedBox(width: AscentDimensions.spaceSm),
            ],
            Flexible(
              child: Text(
                widget.label ?? '',
                textAlign: TextAlign.center,
                style: textStyle,
                maxLines: g.monochrome != null ? null : 2,
                overflow: g.monochrome != null
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
              ),
            ),
            if (!widget.loading && widget.icon != null && widget.iconAtEnd) ...[
              const SizedBox(width: 6),
              Icon(widget.icon, size: 16, color: fg),
            ],
          ],
        ),
      );
    }

    // Outer hit region wrapper: minimum 48x48
    Widget interactiveWidget = Container(
      constraints: const BoxConstraints(
        minHeight: AscentDimensions.minTouchTarget,
        minWidth: AscentDimensions.minTouchTarget,
      ),
      child: Center(
        widthFactor: 1,
        heightFactor: 1,
        child: AnimatedScale(
          scale: (!disableAnimations && _pressed) ? 0.98 : 1.0,
          duration: Duration(milliseconds: _pressed ? 100 : 140),
          curve: Curves.easeOutCubic,
          child: buttonContent,
        ),
      ),
    );

    if (widget.expanded && !isIcon && widget.type != AscentButtonType.fab) {
      interactiveWidget = SizedBox(
        width: double.infinity,
        child: interactiveWidget,
      );
    }

    final effectiveLabel =
        widget.semanticLabel ?? widget.tooltip ?? widget.label;

    Widget result = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: Semantics(
        excludeSemantics: true,
        button: true,
        enabled: _isEnabled,
        label: widget.loading
            ? '${effectiveLabel ?? ''}, busy'
            : effectiveLabel,
        onTap: _isEnabled ? _triggerTap : null,
        child: interactiveWidget,
      ),
    );

    if (widget.tooltip != null) {
      result = Tooltip(message: widget.tooltip!, child: result);
    }

    return result;
  }
}
