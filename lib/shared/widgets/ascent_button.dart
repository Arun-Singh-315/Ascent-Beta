import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
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
    this.expanded = true,
    this.compact = false,
    this.tooltip,
    this.semanticLabel,
  });

  // ── Named constructors ────────────────────────────────────────────────────

  const AscentButton.primary({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = true,
    this.compact = false,
    this.tooltip,
    this.semanticLabel,
  }) : type = AscentButtonType.primary;

  const AscentButton.secondary({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = true,
    this.compact = false,
    this.tooltip,
    this.semanticLabel,
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
  }) : type = AscentButtonType.ghost;

  const AscentButton.icon({
    super.key,
    required IconData this.icon,
    this.onPressed,
    this.compact = false,
    this.tooltip,
    this.semanticLabel,
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
  }) : type = AscentButtonType.destructive;

  // ── Fields ────────────────────────────────────────────────────────────────

  final AscentButtonType type;
  final String? label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final bool compact;
  final String? tooltip;
  final String? semanticLabel;

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

  @override
  State<_AscentButtonInternal> createState() => _AscentButtonInternalState();
}

class _AscentButtonInternalState extends State<_AscentButtonInternal> {
  bool _pressed = false;

  bool get _isEnabled => widget.onPressed != null && !widget.loading;

  void _onTapDown(TapDownDetails _) {
    if (!_isEnabled) return;
    setState(() => _pressed = true);
  }

  void _onTapUp(TapUpDetails _) {
    if (!_isEnabled) return;
    setState(() => _pressed = false);
    HapticFeedback.lightImpact();
    widget.onPressed?.call();
  }

  void _onTapCancel() {
    if (!_isEnabled) return;
    setState(() => _pressed = false);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    final isPrimary = widget.type == AscentButtonType.primary || widget.type == AscentButtonType.fab;
    final isDestructive = widget.type == AscentButtonType.destructive;
    final isTonal = widget.type == AscentButtonType.tonal || widget.type == AscentButtonType.secondary;
    final isOutlined = widget.type == AscentButtonType.outlined;
    final isGhost = widget.type == AscentButtonType.ghost;
    final isIcon = widget.type == AscentButtonType.icon;

    // Normal colors
    Color bg;
    Color fg;
    Border? border;

    if (!_isEnabled) {
      bg = isGhost || isIcon ? Colors.transparent : g.disabledBg;
      fg = g.disabledFg;
      border = isOutlined
          ? Border.all(color: g.disabledFg.withValues(alpha: 0.3), width: AscentDimensions.controlOutlineWidth)
          : null;
    } else if (isPrimary) {
      bg = _pressed ? g.primaryButtonPressed : g.primaryButtonBg;
      fg = g.primaryButtonFg;
    } else if (isDestructive) {
      bg = _pressed ? g.destructivePressed : g.destructiveBg;
      fg = g.destructiveFg;
    } else if (isTonal) {
      final baseBg = g.tonalBg;
      bg = _pressed ? Color.alphaBlend(g.ink.withValues(alpha: 0.06), baseBg) : baseBg;
      fg = g.tonalFg;
    } else if (isOutlined) {
      final baseBg = g.surface;
      bg = _pressed ? Color.alphaBlend(g.ink.withValues(alpha: 0.06), baseBg) : baseBg;
      fg = g.ink;
      border = Border.all(
        color: g.controlOutline,
        width: AscentDimensions.controlOutlineWidth,
      );
    } else if (isGhost) {
      bg = _pressed ? g.ink.withValues(alpha: 0.06) : Colors.transparent;
      fg = g.actionInk;
    } else {
      // isIcon
      bg = _pressed ? g.ink.withValues(alpha: 0.06) : Colors.transparent;
      fg = g.actionInk;
    }

    // Geometry
    final visualHeight = widget.compact
        ? AscentDimensions.buttonHeightCompact
        : AscentDimensions.buttonHeightStandard;

    final horizontalPadding = widget.compact ? 12.0 : 16.0;

    Widget buttonContent;

    if (widget.type == AscentButtonType.fab) {
      buttonContent = Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
        ),
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
      final textStyle = AscentTextStyles.buttonLabel.copyWith(color: fg);

      buttonContent = Container(
        constraints: BoxConstraints(
          minHeight: visualHeight,
          minWidth: widget.compact ? 48.0 : 64.0,
        ),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(AscentDimensions.radiusMd),
          border: border,
        ),
        padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
        alignment: Alignment.center,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.loading) ...[
              SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(fg),
                ),
              ),
              const SizedBox(width: AscentDimensions.spaceSm),
            ] else if (widget.icon != null) ...[
              Icon(widget.icon, size: widget.compact ? 16 : 18, color: fg),
              const SizedBox(width: AscentDimensions.spaceSm),
            ],
            Flexible(
              child: Text(
                widget.label ?? '',
                textAlign: TextAlign.center,
                style: textStyle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
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
      alignment: Alignment.center,
      child: AnimatedScale(
        scale: (!disableAnimations && _pressed) ? 0.98 : 1.0,
        duration: Duration(milliseconds: _pressed ? 100 : 140),
        curve: Curves.easeOutCubic,
        child: buttonContent,
      ),
    );

    if (widget.expanded && !isIcon && widget.type != AscentButtonType.fab) {
      interactiveWidget = SizedBox(
        width: double.infinity,
        child: interactiveWidget,
      );
    }

    final effectiveLabel = widget.semanticLabel ?? widget.tooltip ?? widget.label;

    Widget result = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: Semantics(
        button: true,
        enabled: _isEnabled,
        label: effectiveLabel,
        child: interactiveWidget,
      ),
    );

    if (widget.tooltip != null) {
      result = Tooltip(
        message: widget.tooltip!,
        child: result,
      );
    }

    return result;
  }
}
