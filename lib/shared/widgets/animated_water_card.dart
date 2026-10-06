import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/providers/database_provider.dart';
import 'ascent_card.dart';

/// Animated Water Hydration Cockpit Card
/// Features continuous sinusoidal fluid wave physics, smooth fill transitions,
/// animated volume counter, haptic feedback, and 1-tap quick action chips.
class AnimatedWaterCard extends ConsumerStatefulWidget {
  const AnimatedWaterCard({super.key});

  @override
  ConsumerState<AnimatedWaterCard> createState() => _AnimatedWaterCardState();
}

class _AnimatedWaterCardState extends ConsumerState<AnimatedWaterCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _waveController;

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  void _logWater(int ml) async {
    HapticFeedback.mediumImpact();
    await ref.read(waterDaoProvider).addWater(ml);
  }

  void _undoLast() async {
    HapticFeedback.lightImpact();
    final logs = await ref.read(todayWaterLogsStreamProvider.future);
    if (logs.isNotEmpty) {
      await ref.read(waterDaoProvider).deleteWater(logs.first.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final todayWaterAsync = ref.watch(todayWaterMlStreamProvider);
    final goalAsync = ref.watch(dailyWaterGoalStreamProvider);

    final currentMl = todayWaterAsync.value ?? 0;
    final targetMl = goalAsync.value ?? 2500;
    final progress = (currentMl / targetMl).clamp(0.0, 1.2);
    final isGoalMet = currentMl >= targetMl;

    return AscentCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF0096C7).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF0096C7).withValues(alpha: 0.28),
                  ),
                ),
                child: const Icon(
                  Icons.water_drop_rounded,
                  color: Color(0xFF0096C7),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'DAILY HYDRATION',
                          style: AscentTextStyles.labelSmall.copyWith(
                            letterSpacing: 1.1,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF0096C7),
                          ),
                        ),
                        if (isGoalMet) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38664D).withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'GOAL REACHED! 🎉',
                              style: AscentTextStyles.labelSmall.copyWith(
                                color: const Color(0xFF5FA070),
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: currentMl),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      builder: (context, val, _) {
                        return RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: '$val ',
                                style: AscentTextStyles.headlineMedium.copyWith(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 22,
                                ),
                              ),
                              TextSpan(
                                text: '/ $targetMl mL',
                                style: AscentTextStyles.bodyMedium.copyWith(
                                  color: context.textMuted,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              // Percentage Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFF0096C7).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: const Color(0xFF0096C7).withValues(alpha: 0.2),
                  ),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: AscentTextStyles.monoCode.copyWith(
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFF0096C7),
                    fontSize: 14,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Fluid Wave Tank / Vessel
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Container(
              height: 54,
              width: double.infinity,
              decoration: BoxDecoration(
                color: context.bgBase,
                border: Border.all(color: context.divider.withValues(alpha: 0.6)),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Stack(
                children: [
                  // Animated Sinusoidal Wave
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      return TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: progress),
                        duration: const Duration(milliseconds: 700),
                        curve: Curves.easeOutCubic,
                        builder: (context, animatedFill, _) {
                          return CustomPaint(
                            size: Size.infinite,
                            painter: _FluidWavePainter(
                              fillLevel: animatedFill,
                              wavePhase: _waveController.value * 2 * math.pi,
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // Overlay Guideline markings (25%, 50%, 75%)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildGuideline('0 mL'),
                          _buildGuideline('${(targetMl * 0.5).toInt()} mL'),
                          _buildGuideline('$targetMl mL'),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 14),

          // 1-Tap Quick Hydration Logging Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _QuickWaterButton(
                  label: '+250 mL',
                  sub: 'Glass',
                  icon: Icons.local_drink_rounded,
                  onTap: () => _logWater(250),
                ),
                const SizedBox(width: 8),
                _QuickWaterButton(
                  label: '+500 mL',
                  sub: 'Bottle',
                  icon: Icons.sports_bar_rounded,
                  onTap: () => _logWater(500),
                ),
                const SizedBox(width: 8),
                _QuickWaterButton(
                  label: '+150 mL',
                  sub: 'Cup',
                  icon: Icons.coffee_rounded,
                  onTap: () => _logWater(150),
                ),
                const SizedBox(width: 8),
                _QuickWaterButton(
                  label: '+750 mL',
                  sub: 'Flask',
                  icon: Icons.water_rounded,
                  onTap: () => _logWater(750),
                ),
                if (currentMl > 0) ...[
                  const SizedBox(width: 8),
                  InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: _undoLast,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.bgBase,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: context.divider),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.undo_rounded, size: 14, color: context.textMuted),
                          const SizedBox(width: 4),
                          Text(
                            'Undo',
                            style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGuideline(String text) {
    return Text(
      text,
      style: AscentTextStyles.labelSmall.copyWith(
        fontSize: 10,
        fontWeight: FontWeight.w600,
        color: context.textMuted.withValues(alpha: 0.6),
      ),
    );
  }
}

class _QuickWaterButton extends StatefulWidget {
  final String label;
  final String sub;
  final IconData icon;
  final VoidCallback onTap;

  const _QuickWaterButton({
    required this.label,
    required this.sub,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_QuickWaterButton> createState() => _QuickWaterButtonState();
}

class _QuickWaterButtonState extends State<_QuickWaterButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.94 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOutCubic,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0096C7).withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: const Color(0xFF0096C7).withValues(alpha: 0.25),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: const Color(0xFF0096C7)),
              const SizedBox(width: 6),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.label,
                    style: AscentTextStyles.labelMedium.copyWith(
                      fontWeight: FontWeight.bold,
                      color: context.textPrimary,
                    ),
                  ),
                  Text(
                    widget.sub,
                    style: AscentTextStyles.labelSmall.copyWith(
                      fontSize: 9,
                      color: context.textMuted,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Custom painter that draws animated sine waves representing fluid water.
class _FluidWavePainter extends CustomPainter {
  final double fillLevel; // 0.0 to 1.0+
  final double wavePhase;

  _FluidWavePainter({
    required this.fillLevel,
    required this.wavePhase,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fillLevel <= 0.0) return;

    final baseHeight = size.height * (1.0 - fillLevel.clamp(0.0, 1.0));
    const waveAmplitude = 4.0;
    const waveFrequency = 0.025;

    // Secondary wave (lighter translucent back layer)
    final backPath = Path();
    backPath.moveTo(0, size.height);
    backPath.lineTo(0, baseHeight);
    for (double x = 0; x <= size.width; x += 3) {
      final y = baseHeight + math.sin(x * waveFrequency + wavePhase + 1.2) * (waveAmplitude * 0.7);
      backPath.lineTo(x, y);
    }
    backPath.lineTo(size.width, size.height);
    backPath.close();

    final backPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF48CAE4).withValues(alpha: 0.35),
          const Color(0xFF0096C7).withValues(alpha: 0.5),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(backPath, backPaint);

    // Primary wave (foreground crisp water)
    final frontPath = Path();
    frontPath.moveTo(0, size.height);
    frontPath.lineTo(0, baseHeight);
    for (double x = 0; x <= size.width; x += 3) {
      final y = baseHeight + math.sin(x * waveFrequency + wavePhase) * waveAmplitude;
      frontPath.lineTo(x, y);
    }
    frontPath.lineTo(size.width, size.height);
    frontPath.close();

    final frontPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          const Color(0xFF00B4D8).withValues(alpha: 0.85),
          const Color(0xFF0077B6).withValues(alpha: 0.95),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(frontPath, frontPaint);
  }

  @override
  bool shouldRepaint(covariant _FluidWavePainter oldDelegate) {
    return oldDelegate.fillLevel != fillLevel || oldDelegate.wavePhase != wavePhase;
  }
}
