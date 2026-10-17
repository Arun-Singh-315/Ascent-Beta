import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/providers/database_provider.dart';
import '../home/widgets/life_checkin_popup_dialog.dart';

/// Interactive Freeze-Screen Hydration Pop-up Dialog
/// Displays a frosted glass blur overlay freezing the background,
/// showing current intake, motivation, and quick drink buttons (+150ml, +250ml, +350ml, +500ml).
class HydrationPopupDialog extends ConsumerStatefulWidget {
  const HydrationPopupDialog({super.key});

  static Future<void> show(BuildContext context) {
    return LifeCheckInPopupDialog.show(
      context,
      initialTab: LifeCheckInTab.hydration,
    );
  }

  @override
  ConsumerState<HydrationPopupDialog> createState() =>
      _HydrationPopupDialogState();
}

class _HydrationPopupDialogState extends ConsumerState<HydrationPopupDialog> {
  final TextEditingController _customController = TextEditingController();
  bool _showCustomInput = false;

  @override
  void dispose() {
    _customController.dispose();
    super.dispose();
  }

  Future<void> _logIntake(int ml) async {
    if (ml <= 0) return;
    HapticFeedback.heavyImpact();
    await ref.read(waterDaoProvider).addWater(ml);

    if (!mounted) return;
    Navigator.of(context).pop();

    final g = context.glass;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.water_drop_rounded, color: g.clay, size: 20),
            const SizedBox(width: 8),
            Text(
              'Hydrated! Added +$ml mL to your daily log',
              style: AppTypeRoles.typeRole8,
            ),
          ],
        ),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final todayWaterAsync = ref.watch(todayWaterMlStreamProvider);
    final goalAsync = ref.watch(dailyWaterGoalStreamProvider);

    final currentMl = todayWaterAsync.value ?? 0;
    final targetMl = goalAsync.value ?? 2500;
    final percent = ((currentMl / targetMl) * 100).toInt();

    final g = context.glass;

    return AppSurfaceBlur(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpace.s20,
            vertical: AppSpace.s24,
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Material(
              color: AppPalette.transparent,
              child: AppCard(
                padding: const EdgeInsets.all(AppSpace.s24),
                nightDecoration: BoxDecoration(
                  color: context.bgSurface.withValues(
                    alpha: context.isDark ? 0.85 : 0.95,
                  ),
                  borderRadius: AppGeometry.roundedr28,
                  border: Border.all(
                    color: g.line,
                    width: AppBorderScale.w1point2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppPalette.black.withValues(
                        alpha: context.isDark ? 0.35 : 0.08,
                      ),
                      blurRadius: 32,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Water Emblem
                    Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [g.clay, g.clay.withValues(alpha: 0.8)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: g.clay.withValues(alpha: 0.35),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.water_drop_rounded,
                          size: 34,
                          color: AppPalette.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      'Hydration Alert',
                      style: AppTypography.plusJakartaSans20W80064(
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pause for a second and take a sip! Your brain and body run on hydration.',
                      textAlign: TextAlign.center,
                      style: AppTypography.plusJakartaSans125Regular65(
                        color: context.textMuted,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Progress Pill
                    AppCard(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s14,
                        vertical: AppSpace.s8,
                      ),
                      nightDecoration: BoxDecoration(
                        color: context.bgBase,
                        borderRadius: AppGeometry.roundedr16,
                        border: Border.all(
                          color: context.divider.withValues(alpha: 0.8),
                          width: AppBorderScale.w0point8,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$currentMl / $targetMl mL',
                            style: AppTypography.jetBrainsMono13W70066(
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          AppTag(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.s6,
                              vertical: AppSpace.s2,
                            ),
                            nightDecoration: BoxDecoration(
                              color: g.claySoft,
                              borderRadius: AppGeometry.roundedr8,
                            ),
                            child: Text(
                              '$percent%',
                              style: AppTypography.jetBrainsMono11W80067(
                                color: g.clay,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Quick Log Buttons Title
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'HOW MUCH DID YOU DRINK?',
                        style: AppTypography.jetBrainsMono105W70068(
                          color: context.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Grid of 4 Quick Drink Buttons
                    Row(
                      children: [
                        Expanded(
                          child: _DrinkOptionButton(
                            amountMl: 150,
                            label: 'Small Sip',
                            icon: Icons.coffee_rounded,
                            onTap: () => _logIntake(150),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DrinkOptionButton(
                            amountMl: 250,
                            label: 'Standard Glass',
                            icon: Icons.local_drink_rounded,
                            onTap: () => _logIntake(250),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: _DrinkOptionButton(
                            amountMl: 350,
                            label: 'Mug / Bottle',
                            icon: Icons.emoji_food_beverage_rounded,
                            onTap: () => _logIntake(350),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _DrinkOptionButton(
                            amountMl: 500,
                            label: 'Full Sipper',
                            icon: Icons.sports_bar_rounded,
                            onTap: () => _logIntake(500),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),

                    // Custom input toggle
                    if (_showCustomInput) ...[
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _customController,
                              keyboardType: TextInputType.number,
                              autofocus: true,
                              style: AppTypography.jetBrainsMono14W70069(
                                color: context.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter mL (e.g. 400)',
                                hintStyle: AppTypeRoles.typeRole27.copyWith(
                                  color: context.textMuted,
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.s12,
                                  vertical: AppSpace.s10,
                                ),
                                filled: true,
                                fillColor: context.bgBase,
                                border: OutlineInputBorder(
                                  borderRadius: AppGeometry.roundedr12,
                                  borderSide: BorderSide(
                                    color: context.divider,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: context.surfaces.buttonStyle(
                              ElevatedButton.styleFrom(
                                backgroundColor: g.clay,
                                foregroundColor: AppPalette.white,
                                elevation: 0,
                                shape: RoundedRectangleBorder(
                                  borderRadius: AppGeometry.roundedr12,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppSpace.s14,
                                  vertical: AppSpace.s11,
                                ),
                              ),
                              filled: true,
                              icon: false,
                            ),
                            onPressed: () {
                              final val =
                                  int.tryParse(_customController.text.trim()) ??
                                  0;
                              _logIntake(val);
                            },
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ] else ...[
                      TextButton.icon(
                        onPressed: () {
                          setState(() {
                            _showCustomInput = true;
                          });
                        },
                        icon: Icon(Icons.tune_rounded, size: 14, color: g.clay),
                        label: Text(
                          'Custom Amount',
                          style: AppTypeRoles.typeRole17.copyWith(
                            color: g.clay,
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Dismiss / Later Button
                    SizedBox(
                      width: double.infinity,
                      child: TextButton(
                        onPressed: () {
                          HapticFeedback.lightImpact();
                          Navigator.of(context).pop();
                        },
                        style: context.surfaces.buttonStyle(
                          TextButton.styleFrom(
                            foregroundColor: context.textMuted,
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpace.s10,
                            ),
                          ),
                          filled: false,
                          icon: false,
                        ),
                        child: const Text(
                          'Remind me later',
                          style: AppTypeRoles.typeRole43,
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
    );
  }
}

class _DrinkOptionButton extends StatelessWidget {
  final int amountMl;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _DrinkOptionButton({
    required this.amountMl,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppPalette.transparent,
      child: AppTapArea(
        onTap: onTap,
        borderRadius: AppGeometry.roundedr16,
        child: AppCard(
          padding: const EdgeInsets.symmetric(
            vertical: AppSpace.s12,
            horizontal: AppSpace.s10,
          ),
          nightDecoration: BoxDecoration(
            color: context.bgBase,
            borderRadius: AppGeometry.roundedr16,
            border: Border.all(
              color: context.divider.withValues(alpha: 0.8),
              width: AppBorderScale.w1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: context.glass.clay),
              const SizedBox(height: 6),
              Text(
                '+$amountMl mL',
                style: AppTypography.jetBrainsMono13W80070(
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: AppTypeRoles.typeRole44.copyWith(
                  color: context.textMuted,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
