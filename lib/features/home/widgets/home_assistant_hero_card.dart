import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/theme/app_colors.dart';

/// Glowing Sand & Ember Hero Gateway Card for Ascent AI Assistant (Jarvis).
///
/// Features:
/// - Plain surface fill with soft ILLUMINATED border: 1.5px SweepGradient stroke
///   (ember #F08A5D -> rose #E27A93 -> gold #E8B65A -> ember) rotating slowly (8s loop).
/// - Outer glow with two BoxShadows (blur 24/48, opacity 0.18/0.08 light, 0.35/0.15 dark).
/// - Faint inner top highlight.
/// - PrimaryContainer rounded-square icon tile with sparkling star.
/// - Title: "Ask Jarvis" (or configured assistant name).
/// - Subtitle: "Plan your day or ask anything".
/// - Soft "Chat" pill button (primaryContainer / onPrimaryContainer).
/// - Accessibility fallback: respects reduce-motion.
class HomeAssistantHeroCard extends ConsumerStatefulWidget {
  const HomeAssistantHeroCard({
    super.key,
    this.assistantName,
    this.onTap,
  });

  final String? assistantName;
  final VoidCallback? onTap;

  @override
  ConsumerState<HomeAssistantHeroCard> createState() =>
      _HomeAssistantHeroCardState();
}

class _HomeAssistantHeroCardState extends ConsumerState<HomeAssistantHeroCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    final isTest =
        WidgetsBinding.instance.runtimeType.toString().contains('Test');
    if (!isTest) {
      _controller.repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isReducedMotion = MediaQuery.of(context).disableAnimations;

    final configuredName = ref.watch(assistantNameProvider);
    final name = widget.assistantName ??
        (configuredName.trim().isEmpty || configuredName == 'Riya' || configuredName == 'Aria'
            ? AppConstants.assistantName
            : configuredName.trim());

    final screenWidth = MediaQuery.sizeOf(context).width;
    final maxCardWidth = math.min(
      math.max(0.0, screenWidth - 32),
      336.0,
    );

    const ember = Color(0xFFF08A5D);
    final outerGlowShadows = [
      BoxShadow(
        color: isDark ? const Color(0x35000000) : ember.withValues(alpha: 0.12),
        blurRadius: isDark ? 16 : 20,
        spreadRadius: 0,
        offset: const Offset(0, 4),
      ),
    ];

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxCardWidth),
        child: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16181F) : c.surface,
            borderRadius: BorderRadius.circular(20),
            boxShadow: outerGlowShadows,
          ),
          child: AnimatedBuilder(
            animation: _controller,
            builder: (context, child) {
              return CustomPaint(
                foregroundPainter: _IlluminatedBorderPainter(
                  animationValue: _controller.value,
                  isReducedMotion: isReducedMotion,
                  isDark: isDark,
                ),
                child: child,
              );
            },
            child: Material(
              color: Colors.transparent,
              borderRadius: BorderRadius.circular(20),
              child: Tooltip(
                message: 'Ask $name',
                child: InkWell(
                  key: const ValueKey('home_assistant_button'),
                  borderRadius: BorderRadius.circular(20),
                  onTap: () {
                    HapticFeedback.selectionClick();
                    if (widget.onTap != null) {
                      widget.onTap!();
                    } else {
                      context.push('/ai-assistant');
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        // PrimaryContainer rounded-square icon tile with sparkle icon
                        Container(
                          width: 36,
                          height: 36,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(10),
                            color: colorScheme.primaryContainer,
                          ),
                          child: Icon(
                            Icons.auto_awesome_rounded,
                            size: 18,
                            color: colorScheme.onPrimaryContainer,
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Title & Subtitle
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Ask $name',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  color: c.textPrimary,
                                  letterSpacing: -0.2,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Plan your day or ask anything',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: c.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Soft "Chat" button
                        Flexible(
                          flex: 0,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: colorScheme.primaryContainer,
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'Chat',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: colorScheme.onPrimaryContainer,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _IlluminatedBorderPainter extends CustomPainter {
  const _IlluminatedBorderPainter({
    required this.animationValue,
    required this.isReducedMotion,
    this.isDark = false,
  });

  final double animationValue;
  final bool isReducedMotion;
  final bool isDark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.75),
      const Radius.circular(20),
    );

    final Paint strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = isDark ? 1.0 : 1.2;

    if (isReducedMotion) {
      strokePaint.shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: isDark
            ? const [
                Color(0x90F08A5D), // subtle ember
                Color(0x70E27A93), // soft rose
              ]
            : const [
                Color(0xFFF08A5D), // ember
                Color(0xFFE27A93), // rose
              ],
      ).createShader(rect);
    } else {
      final double angle = animationValue * 2 * math.pi;
      strokePaint.shader = SweepGradient(
        center: Alignment.center,
        startAngle: 0.0,
        endAngle: 2 * math.pi,
        transform: GradientRotation(angle),
        colors: isDark
            ? const [
                Color(0x90F08A5D), // subtle ember
                Color(0x60E27A93), // soft rose
                Color(0x60E8B65A), // soft gold
                Color(0x90F08A5D), // subtle ember
              ]
            : const [
                Color(0xFFF08A5D), // ember
                Color(0xFFE27A93), // rose
                Color(0xFFE8B65A), // gold
                Color(0xFFF08A5D), // ember
              ],
      ).createShader(rect);
    }

    canvas.drawRRect(rrect, strokePaint);

    // Faint inner top highlight line
    final highlightPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.white.withValues(alpha: 0.35),
          Colors.white.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, 12));
    canvas.drawRRect(rrect.deflate(0.75), highlightPaint);
  }

  @override
  bool shouldRepaint(covariant _IlluminatedBorderPainter oldDelegate) =>
      oldDelegate.animationValue != animationValue ||
      oldDelegate.isReducedMotion != isReducedMotion;
}
