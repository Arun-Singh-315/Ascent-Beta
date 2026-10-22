import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/frozen_palette.dart';
import '../../app/theme/merlot_palette.dart';
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

    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AscentCard(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            children: [
              AppCard(
                width: 38,
                height: 38,
                nightDecoration: BoxDecoration(
                  color: g.claySoft,
                  borderRadius: AppGeometry.roundedr12,
                  border: Border.all(color: g.clay.withValues(alpha: 0.35)),
                ),
                child: Icon(Icons.water_drop_rounded, color: g.clay, size: 20),
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
                          style: AscentTextStyles.labelSmall
                              .copyWith(letterSpacing: 1.1, color: g.clay)
                              .merge(AppTypeRoles.typeRole2),
                        ),
                        if (isGoalMet) ...[
                          const SizedBox(width: 6),
                          AppTag(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.s6,
                              vertical: AppSpace.s2,
                            ),
                            nightDecoration: BoxDecoration(
                              color: AppPalette.colorFF10B981.withValues(
                                alpha: 0.16,
                              ),
                              borderRadius: AppGeometry.roundedr6,
                            ),
                            child: Text(
                              'GOAL REACHED',
                              style: AscentTextStyles.labelSmall
                                  .copyWith(color: AppPalette.colorFF10B981)
                                  .merge(AppTypeRoles.typeRole55),
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
                                style: AscentTextStyles.headlineMedium
                                    .copyWith(color: context.textPrimary)
                                    .merge(AppTypeRoles.typeRole73),
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
              AppTag(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s10,
                  vertical: AppSpace.s6,
                ),
                nightDecoration: BoxDecoration(
                  color: g.claySoft,
                  borderRadius: AppGeometry.roundedr10,
                  border: Border.all(color: g.clay.withValues(alpha: 0.30)),
                ),
                child: Text(
                  '${(progress * 100).toInt()}%',
                  style: AscentTextStyles.monoCode
                      .copyWith(color: g.clay)
                      .merge(AppTypeRoles.typeRole74),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Fluid Wave Tank / Vessel
          ClipRRect(
            borderRadius: AppGeometry.roundedr14,
            child: AppCard(
              height: 54,
              width: double.infinity,
              nightDecoration: BoxDecoration(
                color: isDark
                    ? AppPalette.colorFF2A1C0F.withValues(alpha: 0.6)
                    : AppPalette.white.withValues(alpha: 0.5),
                border: Border.all(color: g.line.withValues(alpha: 0.7)),
                borderRadius: AppGeometry.roundedr14,
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
                              waveColorFront: g.clay,
                              waveColorBack: g.claySoft,
                              isDark: isDark,
                            ),
                          );
                        },
                      );
                    },
                  ),

                  // Overlay Guideline markings (25%, 50%, 75%)
                  Positioned.fill(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s12,
                      ),
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

          // Keep every quick action readable as available width and text size change.
          LayoutBuilder(
            builder: (context, constraints) {
              final columns =
                  constraints.maxWidth < 360 ||
                      MediaQuery.textScalerOf(context).scale(14) > 20
                  ? 2
                  : 4;
              return Wrap(
                spacing: AscentSpacing.sm,
                runSpacing: AscentSpacing.sm,
                children: [
                  for (final preset in const [
                    (150, 'Cup', Icons.water_drop_outlined),
                    (250, 'Glass', Icons.local_drink_rounded),
                    (500, 'Bottle', Icons.water_drop_rounded),
                    (750, 'Flask', Icons.water_rounded),
                  ])
                    SizedBox(
                      width:
                          (constraints.maxWidth -
                              (columns - 1) * AscentSpacing.sm) /
                          columns,
                      child: _QuickWaterButton(
                        label: '+${preset.$1} mL',
                        sub: preset.$2,
                        icon: preset.$3,
                        onTap: () => _logWater(preset.$1),
                      ),
                    ),
                ],
              );
            },
          ),
          if (currentMl > 0) ...[
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerRight,
              child: AppTapArea(
                borderRadius: AppGeometry.roundedr10,
                onTap: _undoLast,
                child: AppTag(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s10,
                    vertical: AppSpace.s6,
                  ),
                  nightDecoration: BoxDecoration(
                    color: context.bgBase,
                    borderRadius: AppGeometry.roundedr10,
                    border: Border.all(color: context.divider),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.undo_rounded,
                        size: 13,
                        color: context.textMuted,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Undo last intake',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: context.textMuted,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildGuideline(String text) {
    return Text(
      text,
      style: AscentTextStyles.labelSmall
          .copyWith(color: context.textMuted.withValues(alpha: 0.6))
          .merge(AppTypeRoles.typeRole51),
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
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardBg = isDark
        ? g.fill
        : (g.merlot
              ? MerlotPalette.pillSoft
              : (g.frozen ? FrozenPalette.pillSoft : const Color(0xFFF0F7FB)));
    final borderColor = isDark
        ? g.edge
        : (g.merlot
              ? MerlotPalette.lineSubtle
              : (g.frozen
                    ? FrozenPalette.lineSubtle
                    : const Color(0xFFD2E3F1)));
    final iconBg = isDark
        ? context.waterAccent.withValues(alpha: 0.18)
        : (g.merlot
              ? MerlotPalette.darkTint.withValues(alpha: 0.35)
              : const Color(0xFFE0EFF8));
    final iconColor = isDark
        ? context.waterAccent
        : (g.merlot ? MerlotPalette.action : const Color(0xFF0284C7));

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
          constraints: const BoxConstraints(minHeight: 80),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: borderColor,
              width: (g.merlot || g.frozen) ? 0.75 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark
                    ? Colors.black.withValues(alpha: 0.2)
                    : (g.merlot
                          ? MerlotPalette.shadowAmbient
                          : const Color.fromRGBO(2, 132, 199, 0.04)),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: iconBg,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(widget.icon, size: 15, color: iconColor),
                ),
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.label,
                  style: AppTypography.jetBrainsMono13W70066(
                    color: context.textPrimary,
                  ).copyWith(fontSize: 12.5, fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(height: 2),
              Text(
                widget.sub,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AscentTextStyles.labelSmall.copyWith(
                  color: context.textMuted,
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                ),
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
  final Color waveColorFront;
  final Color waveColorBack;
  final bool isDark;

  _FluidWavePainter({
    required this.fillLevel,
    required this.wavePhase,
    required this.waveColorFront,
    required this.waveColorBack,
    required this.isDark,
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
      final y =
          baseHeight +
          math.sin(x * waveFrequency + wavePhase + 1.2) * (waveAmplitude * 0.7);
      backPath.lineTo(x, y);
    }
    backPath.lineTo(size.width, size.height);
    backPath.close();

    final backPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                waveColorBack.withValues(alpha: 0.25),
                waveColorFront.withValues(alpha: 0.38),
              ]
            : [
                waveColorBack.withValues(alpha: 0.35),
                waveColorFront.withValues(alpha: 0.48),
              ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(backPath, backPaint);

    // Primary wave (foreground crisp liquid)
    final frontPath = Path();
    frontPath.moveTo(0, size.height);
    frontPath.lineTo(0, baseHeight);
    for (double x = 0; x <= size.width; x += 3) {
      final y =
          baseHeight + math.sin(x * waveFrequency + wavePhase) * waveAmplitude;
      frontPath.lineTo(x, y);
    }
    frontPath.lineTo(size.width, size.height);
    frontPath.close();

    final frontPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: isDark
            ? [
                waveColorFront.withValues(alpha: 0.65),
                waveColorBack.withValues(alpha: 0.85),
              ]
            : [
                waveColorFront.withValues(alpha: 0.75),
                waveColorFront.withValues(alpha: 0.95),
              ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(frontPath, frontPaint);
  }

  @override
  bool shouldRepaint(covariant _FluidWavePainter oldDelegate) {
    return oldDelegate.fillLevel != fillLevel ||
        oldDelegate.wavePhase != wavePhase ||
        oldDelegate.waveColorFront != waveColorFront ||
        oldDelegate.waveColorBack != waveColorBack ||
        oldDelegate.isDark != isDark;
  }
}
