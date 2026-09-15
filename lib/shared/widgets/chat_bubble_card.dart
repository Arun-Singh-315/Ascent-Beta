import 'package:flutter/material.dart';
import '../../app/theme/color_tokens.dart';

enum BubbleTailPosition {
  none,
  topLeft,
  topRight,
  bottomLeft,
  bottomRight,
}

/// A card with speech-bubble styling specified in Ascent V1 Upgrade §11.
/// Features 20px radii on three corners and 4px on the tail corner,
/// subtle background gradient, accent-tinted border, and optional pulsing border.
class ChatBubbleCard extends StatefulWidget {
  const ChatBubbleCard({
    super.key,
    required this.child,
    this.tailPosition = BubbleTailPosition.bottomLeft,
    this.borderColor,
    this.accentTint,
    this.isPulsing = false,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
  });

  final Widget child;
  final BubbleTailPosition tailPosition;
  final Color? borderColor;
  final Color? accentTint;
  final bool isPulsing;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;

  @override
  State<ChatBubbleCard> createState() => _ChatBubbleCardState();
}

class _ChatBubbleCardState extends State<ChatBubbleCard>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;
  Animation<double>? _pulseAnimation;

  @override
  void initState() {
    super.initState();
    if (widget.isPulsing) {
      _startPulse();
    }
  }

  @override
  void didUpdateWidget(covariant ChatBubbleCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isPulsing && !oldWidget.isPulsing) {
      _startPulse();
    } else if (!widget.isPulsing && oldWidget.isPulsing) {
      _pulseController?.stop();
      _pulseController?.dispose();
      _pulseController = null;
    }
  }

  void _startPulse() {
    _pulseController ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.35, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController!, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController?.dispose();
    super.dispose();
  }

  BorderRadius _getBorderRadius() {
    return switch (widget.tailPosition) {
      BubbleTailPosition.none => BorderRadius.circular(20),
      BubbleTailPosition.topLeft => const BorderRadius.only(
          topLeft: Radius.circular(4),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      BubbleTailPosition.topRight => const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(4),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
      BubbleTailPosition.bottomLeft => const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(20),
        ),
      BubbleTailPosition.bottomRight => const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(4),
        ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final borderRadius = _getBorderRadius();
    final tint = widget.accentTint ?? context.accentPrimary;
    final baseBorderColor =
        widget.borderColor ?? tint.withValues(alpha: 0.3);

    Widget buildDecoratedCard(Color currentBorderColor) {
      return Container(
        decoration: BoxDecoration(
          borderRadius: borderRadius,
          border: Border.all(
            color: currentBorderColor,
            width: 1.5,
          ),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              context.bgSurface,
              Color.lerp(context.bgSurface, tint, 0.04) ?? context.bgSurface,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: context.isDark
                  ? AscentColors.shadowDark.withValues(alpha: 0.2)
                  : AscentColors.shadow.withValues(alpha: 0.06),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          borderRadius: borderRadius,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: borderRadius,
            child: Padding(
              padding: widget.padding,
              child: widget.child,
            ),
          ),
        ),
      );
    }

    if (widget.isPulsing && _pulseController != null) {
      return AnimatedBuilder(
        animation: _pulseController!,
        builder: (context, _) {
          final alphaVal = _pulseAnimation?.value ?? 1.0;
          final pulseColor = baseBorderColor.withValues(
            alpha: (baseBorderColor.a * alphaVal).clamp(0.0, 1.0),
          );
          return buildDecoratedCard(pulseColor);
        },
      );
    }

    return buildDecoratedCard(baseBorderColor);
  }
}
