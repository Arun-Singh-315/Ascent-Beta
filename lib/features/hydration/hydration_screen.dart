import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_card.dart';
import '../../shared/widgets/ascent_dialog.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/history_action.dart';

/// Apple iPhone Health-inspired Hydration Tracker Screen.
/// Minimalist, high-performance, informative, zero scroll lag,
/// with high-volume structured history protection and 100% overflow immunity.
class HydrationScreen extends ConsumerStatefulWidget {
  const HydrationScreen({super.key});

  @override
  ConsumerState<HydrationScreen> createState() => _HydrationScreenState();
}

class _HydrationScreenState extends ConsumerState<HydrationScreen> {
  final TextEditingController _goalController = TextEditingController();
  final TextEditingController _customMlController = TextEditingController();
  bool _showAllLogs = false;

  @override
  void dispose() {
    _goalController.dispose();
    _customMlController.dispose();
    super.dispose();
  }

  void _showSetGoalDialog(int currentGoal) {
    _goalController.text = currentGoal.toString();
    showAscentFrostedDialog<void>(
      context: context,
      builder: (ctx) {
        final g = ctx.glass;
        return AlertDialog(
          backgroundColor: ctx.bgSurfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: ctx.divider.withValues(alpha: 0.8),
              width: 1,
            ),
          ),
          title: Text(
            'Daily Water Target',
            style: AscentTextStyles.cardTitle.copyWith(
              color: ctx.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Set your daily hydration goal in milliliters (mL):',
                style: AscentTextStyles.bodyMedium.copyWith(
                  color: ctx.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _goalController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: AscentTextStyles.displaySmall.copyWith(
                  color: g.clay,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  suffixText: 'mL',
                  suffixStyle: TextStyle(color: ctx.textMuted),
                  filled: true,
                  fillColor: ctx.bgSurface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: ctx.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: g.clay, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: ctx.textMuted)),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: g.tonalBg,
                foregroundColor: g.tonalFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
              ),
              onPressed: () async {
                final newGoal = int.tryParse(_goalController.text.trim());
                if (newGoal != null && newGoal > 0) {
                  HapticFeedback.mediumImpact();
                  await ref.read(waterDaoProvider).setDailyWaterGoal(newGoal);
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Save Target'),
            ),
          ],
        );
      },
    );
  }

  void _showCustomIntakeDialog() {
    _customMlController.clear();
    showAscentFrostedDialog<void>(
      context: context,
      builder: (ctx) {
        final g = ctx.glass;
        return AlertDialog(
          backgroundColor: ctx.bgSurfaceElevated,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(
              color: ctx.divider.withValues(alpha: 0.8),
              width: 1,
            ),
          ),
          title: Text(
            'Log Custom Amount',
            style: AscentTextStyles.cardTitle.copyWith(
              color: ctx.textPrimary,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter fluid amount consumed:',
                style: AscentTextStyles.bodyMedium.copyWith(
                  color: ctx.textMuted,
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _customMlController,
                keyboardType: TextInputType.number,
                autofocus: true,
                style: AscentTextStyles.displaySmall.copyWith(
                  color: g.clay,
                  fontWeight: FontWeight.w700,
                ),
                decoration: InputDecoration(
                  hintText: '350',
                  suffixText: 'mL',
                  suffixStyle: TextStyle(color: ctx.textMuted),
                  filled: true,
                  fillColor: ctx.bgSurface,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: ctx.divider),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: g.clay, width: 1.5),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: Text('Cancel', style: TextStyle(color: ctx.textMuted)),
            ),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                backgroundColor: g.tonalBg,
                foregroundColor: g.tonalFg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 10,
                ),
              ),
              onPressed: () async {
                final amount = int.tryParse(_customMlController.text.trim());
                if (amount != null && amount > 0) {
                  HapticFeedback.mediumImpact();
                  await ref.read(waterDaoProvider).addWater(amount);
                }
                if (ctx.mounted) Navigator.of(ctx).pop();
              },
              child: const Text('Add Intake'),
            ),
          ],
        );
      },
    );
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
    final logsAsync = ref.watch(todayWaterLogsStreamProvider);
    final historyAsync = ref.watch(past7DaysHydrationStreamProvider);

    final currentMl = todayWaterAsync.value ?? 0;
    final targetMl = math.max(1, goalAsync.value ?? 2500);
    final progress = (currentMl / targetMl).clamp(0.0, 1.0);
    final percent = ((currentMl / targetMl) * 100).toInt();
    final remainingMl = math.max(0, targetMl - currentMl);
    final isGoalMet = currentMl >= targetMl;

    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textScale = MediaQuery.textScalerOf(context).scale(1.0);

    return AscentScaffold(
      title: 'Hydration',
      subtitle: 'Daily fluid health & vitality',
      glow2: g.slateSoft,
      actions: [
        const HistoryAction(module: 'hydration'),
        IconButton(
          tooltip: 'Edit Daily Target',
          icon: Icon(Icons.settings_outlined, color: g.clay),
          onPressed: () {
            HapticFeedback.lightImpact();
            _showSetGoalDialog(targetMl);
          },
        ),
      ],
      body: ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s16,
          vertical: AppSpace.s12,
        ),
        children: [
          // ── 1. Apple Health-Style Circular Intake Gauge Hero Card ───
          AscentCard(
            padding: const EdgeInsets.all(AppSpace.s16),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final isStacked =
                    constraints.maxWidth < 270 || textScale >= 1.5;

                final ringWidget = SizedBox(
                  width: isStacked ? 100 : 110,
                  height: isStacked ? 100 : 110,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      TweenAnimationBuilder<double>(
                        tween: Tween<double>(begin: 0.0, end: progress),
                        duration: const Duration(milliseconds: 650),
                        curve: Curves.easeOutCubic,
                        builder: (context, animatedVal, _) {
                          return CustomPaint(
                            size: Size(
                              isStacked ? 100 : 110,
                              isStacked ? 100 : 110,
                            ),
                            painter: _AppleHealthRingPainter(
                              progress: animatedVal,
                              trackColor: isDark
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.06),
                              ringColor: isGoalMet
                                  ? AppPalette.colorFF10B981
                                  : g.clay,
                            ),
                          );
                        },
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isGoalMet
                                ? Icons.check_circle_rounded
                                : Icons.water_drop_rounded,
                            size: 20,
                            color: isGoalMet
                                ? AppPalette.colorFF10B981
                                : g.clay,
                          ),
                          const SizedBox(height: 2),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            child: Text(
                              currentMl == 0 ? 'First sip' : '$percent%',
                              style: AscentTextStyles.cardTitle.copyWith(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                );

                final detailsWidget = Column(
                  crossAxisAlignment: isStacked
                      ? CrossAxisAlignment.center
                      : CrossAxisAlignment.start,
                  children: [
                    Text(
                      'TODAY\'S INTAKE',
                      style: AscentTextStyles.labelSmall.copyWith(
                        color: g.clay,
                        letterSpacing: 1.1,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    TweenAnimationBuilder<int>(
                      tween: IntTween(begin: 0, end: currentMl),
                      duration: const Duration(milliseconds: 650),
                      curve: Curves.easeOutCubic,
                      builder: (context, val, _) {
                        return FittedBox(
                          fit: BoxFit.scaleDown,
                          child: RichText(
                            text: TextSpan(
                              children: [
                                TextSpan(
                                  text: '$val',
                                  style: AscentTextStyles.displaySmall.copyWith(
                                    color: context.textPrimary,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: -0.5,
                                  ),
                                ),
                                TextSpan(
                                  text: ' / $targetMl mL',
                                  style: AscentTextStyles.bodyMedium.copyWith(
                                    color: context.textMuted,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isGoalMet
                            ? AppPalette.colorFF10B981.withValues(alpha: 0.14)
                            : g.claySoft,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          isGoalMet
                              ? 'Daily Goal Achieved'
                              : (currentMl == 0
                                  ? 'Record your first sip below'
                                  : '$remainingMl mL to daily goal'),
                          style: AscentTextStyles.captionMedium.copyWith(
                            color: isGoalMet
                                ? AppPalette.colorFF10B981
                                : g.clay,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                );

                return Column(
                  children: [
                    if (isStacked) ...[
                      ringWidget,
                      const SizedBox(height: 14),
                      detailsWidget,
                    ] else ...[
                      Row(
                        children: [
                          ringWidget,
                          const SizedBox(width: 16),
                          Expanded(child: detailsWidget),
                        ],
                      ),
                    ],
                    if (currentMl > 0) ...[
                      const SizedBox(height: 14),
                      Divider(height: 1, color: g.line.withValues(alpha: 0.5)),
                      const SizedBox(height: 10),
                      Wrap(
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          Text(
                            'Logged ${logsAsync.value?.length ?? 0} drinks today',
                            style: AscentTextStyles.captionMedium.copyWith(
                              color: context.textMuted,
                            ),
                          ),
                          GestureDetector(
                            onTap: _undoLast,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.05)
                                    : Colors.black.withValues(alpha: 0.04),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: g.line.withValues(alpha: 0.4),
                                  width: 0.8,
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.undo_rounded,
                                    size: 14,
                                    color: context.textMuted,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Undo Last',
                                    style: AscentTextStyles.captionMedium
                                        .copyWith(
                                          color: context.textMuted,
                                          fontWeight: FontWeight.w600,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),

          const SizedBox(height: 16),

          // ── 2. Apple Health Quick Intake Grid ───────────────────────
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'QUICK LOG',
                style: AscentTextStyles.labelSmall.copyWith(
                  color: context.textMuted,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              GestureDetector(
                onTap: _showCustomIntakeDialog,
                child: Text(
                  '+ Custom mL',
                  style: AscentTextStyles.captionMedium.copyWith(
                    color: g.clay,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          LayoutBuilder(
            builder: (context, constraints) {
              final isNarrow = constraints.maxWidth < 360;
              final buttonWidth =
                  (constraints.maxWidth - (isNarrow ? 8 : 24)) /
                  (isNarrow ? 2 : 4);

              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final item in const [
                    (150, 'Cup', Icons.local_cafe_outlined),
                    (250, 'Glass', Icons.local_drink_rounded),
                    (500, 'Bottle', Icons.water_drop_rounded),
                    (750, 'Flask', Icons.water_rounded),
                  ])
                    SizedBox(
                      width: buttonWidth,
                      child: _AppleQuickIntakeButton(
                        amount: item.$1,
                        label: item.$2,
                        icon: item.$3,
                        onTap: () => _logWater(item.$1),
                      ),
                    ),
                ],
              );
            },
          ),

          const SizedBox(height: 20),

          // ── 3. 7-Day Hydration Insights (Apple Health Bars) ───────────
          historyAsync.when(
            data: (history) => _AppleHydrationWeeklyInsights(
              history: history,
              targetMl: targetMl,
            ),
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
          ),

          const SizedBox(height: 20),

          // ── 4. Structured High-Volume Today's Logs Card ───────────────
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                'TODAY\'S LOGS',
                style: AscentTextStyles.labelSmall.copyWith(
                  color: context.textMuted,
                  letterSpacing: 1.1,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                '${logsAsync.value?.length ?? 0} entries',
                style: AscentTextStyles.captionMedium.copyWith(
                  color: context.textMuted,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          logsAsync.when(
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(AppSpace.s20),
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
            error: (err, _) => Padding(
              padding: const EdgeInsets.all(AppSpace.s16),
              child: Text(
                'Unable to load logs: $err',
                style: TextStyle(color: context.textMuted),
              ),
            ),
            data: (logs) {
              if (logs.isEmpty) {
                return AscentCard(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppSpace.s32,
                    horizontal: AppSpace.s20,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.water_drop_outlined,
                          size: 32,
                          color: context.textMuted.withValues(alpha: 0.4),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'No drinks logged yet today',
                          style: AscentTextStyles.bodyMedium.copyWith(
                            color: context.textMuted,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Tap the quick intake buttons to log water',
                          style: AscentTextStyles.captionMedium.copyWith(
                            color: context.textMuted.withValues(alpha: 0.7),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }

              // High-volume protection: cap initial preview to top 4 logs
              final visibleLogs = _showAllLogs ? logs : logs.take(4).toList();

              return AscentCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s16,
                  vertical: AppSpace.s8,
                ),
                child: Column(
                  children: [
                    ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: visibleLogs.length,
                      separatorBuilder: (_, _) => Divider(
                        height: 1,
                        color: g.line.withValues(alpha: 0.4),
                      ),
                      itemBuilder: (ctx, index) {
                        final log = visibleLogs[index];
                        final timeStr = DateFormat(
                          'h:mm a',
                        ).format(log.timestamp);

                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            children: [
                              Container(
                                width: 34,
                                height: 34,
                                decoration: BoxDecoration(
                                  color: g.claySoft,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.local_drink_rounded,
                                  size: 16,
                                  color: g.clay,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '+${log.amountMl} mL',
                                      style: AscentTextStyles.bodyMedium
                                          .copyWith(
                                            color: context.textPrimary,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    const SizedBox(height: 1),
                                    Text(
                                      timeStr,
                                      style: AscentTextStyles.captionMedium
                                          .copyWith(color: context.textMuted),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: Icon(
                                  Icons.delete_outline_rounded,
                                  size: 18,
                                  color: context.textMuted,
                                ),
                                tooltip: 'Delete Log',
                                onPressed: () async {
                                  HapticFeedback.lightImpact();
                                  await ref
                                      .read(waterDaoProvider)
                                      .deleteWater(log.id);
                                },
                              ),
                            ],
                          ),
                        );
                      },
                    ),

                    // Expand / Collapse Toggle for High-Volume Data
                    if (logs.length > 4) ...[
                      Divider(height: 1, color: g.line.withValues(alpha: 0.4)),
                      InkWell(
                        onTap: () {
                          HapticFeedback.selectionClick();
                          setState(() => _showAllLogs = !_showAllLogs);
                        },
                        borderRadius: BorderRadius.circular(10),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  _showAllLogs
                                      ? 'Show Less'
                                      : 'Show All ${logs.length} Entries',
                                  style: AscentTextStyles.captionMedium
                                      .copyWith(
                                        color: g.clay,
                                        fontWeight: FontWeight.w700,
                                      ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(
                                _showAllLogs
                                    ? Icons.keyboard_arrow_up_rounded
                                    : Icons.keyboard_arrow_down_rounded,
                                size: 16,
                                color: g.clay,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],

                    Divider(height: 1, color: g.line.withValues(alpha: 0.4)),
                    // Direct Link to Full History Module
                    InkWell(
                      onTap: () => context.push('/history?module=hydration'),
                      borderRadius: BorderRadius.circular(10),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.history_rounded,
                              size: 15,
                              color: context.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'View Full Hydration History',
                                style: AscentTextStyles.captionMedium.copyWith(
                                  color: context.textMuted,
                                  fontWeight: FontWeight.w600,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// Custom painter for Apple Health-style circular progress ring
class _AppleHealthRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color ringColor;

  _AppleHealthRingPainter({
    required this.progress,
    required this.trackColor,
    required this.ringColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 16) / 2;
    const strokeWidth = 10.0;

    // Background Track
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress <= 0.0) return;

    // Foreground Progress Ring
    final sweepAngle = (progress * 2 * math.pi).clamp(0.0, 2 * math.pi);
    final ringPaint = Paint()
      ..color = ringColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -math.pi / 2,
      sweepAngle,
      false,
      ringPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _AppleHealthRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.trackColor != trackColor ||
        oldDelegate.ringColor != ringColor;
  }
}

/// Tactile Apple-style quick intake button
class _AppleQuickIntakeButton extends StatefulWidget {
  final int amount;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _AppleQuickIntakeButton({
    required this.amount,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  State<_AppleQuickIntakeButton> createState() =>
      _AppleQuickIntakeButtonState();
}

class _AppleQuickIntakeButtonState extends State<_AppleQuickIntakeButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
          constraints: const BoxConstraints(minHeight: 74),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.05)
                : Colors.white.withValues(alpha: 0.65),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: g.line.withValues(alpha: 0.5),
              width: 0.8,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: g.claySoft,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Icon(widget.icon, size: 15, color: g.clay),
                ),
              ),
              const SizedBox(height: 5),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '+${widget.amount}',
                  style: AscentTextStyles.bodyMedium.copyWith(
                    color: context.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 12.5,
                  ),
                ),
              ),
              const SizedBox(height: 1),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  widget.label,
                  style: AscentTextStyles.captionMedium.copyWith(
                    color: context.textMuted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Apple Health 7-day Weekly Trend Bars
class _AppleHydrationWeeklyInsights extends StatelessWidget {
  final List<DailyHydrationRecord> history;
  final int targetMl;

  const _AppleHydrationWeeklyInsights({
    required this.history,
    required this.targetMl,
  });

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    if (history.isEmpty) return const SizedBox.shrink();

    final totalVolume = history.fold<int>(0, (sum, r) => sum + r.totalMl);
    final avgVolume = (totalVolume / history.length).round();
    final daysMet = history.where((r) => r.isGoalMet).length;

    final maxVal = history.fold<int>(
      targetMl,
      (max, r) => math.max(max, math.max(r.totalMl, r.goalMl)),
    );

    return AscentCard(
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: g.claySoft,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.insights_rounded,
                      size: 15,
                      color: g.clay,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'WEEKLY INSIGHTS',
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: context.textPrimary,
                      letterSpacing: 1.1,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: daysMet >= 4
                      ? AppPalette.colorFF10B981.withValues(alpha: 0.14)
                      : g.claySoft,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$daysMet/7 Met',
                  style: AscentTextStyles.captionMedium.copyWith(
                    color: daysMet >= 4 ? AppPalette.colorFF10B981 : g.clay,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 7-day Apple Health Capsule Bars
          FittedBox(
            fit: BoxFit.scaleDown,
            child: SizedBox(
              height: 110,
              width: 290,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: history.map((record) {
                  final heightFactor = (record.totalMl / maxVal).clamp(
                    0.06,
                    1.0,
                  );
                  final now = DateTime.now();
                  final isToday =
                      record.date.day == now.day &&
                      record.date.month == now.month &&
                      record.date.year == now.year;
                  final dayLabel = DateFormat(
                    'E',
                  ).format(record.date).substring(0, 1);

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        record.totalMl > 0
                            ? '${(record.totalMl / 1000).toStringAsFixed(1)}L'
                            : '0',
                        style: AscentTextStyles.captionMedium.copyWith(
                          color: record.isGoalMet
                              ? AppPalette.colorFF10B981
                              : context.textMuted,
                          fontSize: 9.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Container(
                        width: 22,
                        height: (60 * heightFactor).toDouble(),
                        decoration: BoxDecoration(
                          color: record.isGoalMet
                              ? AppPalette.colorFF10B981
                              : (isToday
                                    ? g.clay
                                    : g.clay.withValues(alpha: 0.35)),
                          borderRadius: BorderRadius.circular(6),
                          border: isToday
                              ? Border.all(
                                  color: context.textPrimary,
                                  width: 1.2,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isToday ? 'Today' : dayLabel,
                        style: AscentTextStyles.captionMedium.copyWith(
                          color: isToday ? g.clay : context.textMuted,
                          fontWeight: isToday
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 10.5,
                        ),
                      ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Divider(height: 1, color: g.line.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 4,
            children: [
              Text(
                '7-Day Avg: $avgVolume mL/day',
                style: AscentTextStyles.captionMedium.copyWith(
                  color: context.textMuted,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                'Total: ${(totalVolume / 1000).toStringAsFixed(1)} L',
                style: AscentTextStyles.captionMedium.copyWith(
                  color: g.clay,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
