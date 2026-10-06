import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../app/theme/color_tokens.dart';
import '../../core/providers/database_provider.dart';

/// Interactive Freeze-Screen Hydration Pop-up Dialog
/// Displays a frosted glass blur overlay freezing the background,
/// showing current intake, motivation, and quick drink buttons (+150ml, +250ml, +350ml, +500ml).
class HydrationPopupDialog extends ConsumerStatefulWidget {
  const HydrationPopupDialog({super.key});

  static Future<void> show(BuildContext context) {
    HapticFeedback.mediumImpact();
    return showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (ctx) => const HydrationPopupDialog(),
    );
  }

  @override
  ConsumerState<HydrationPopupDialog> createState() => _HydrationPopupDialogState();
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

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.water_drop_rounded, color: Color(0xFF38BDF8), size: 20),
            const SizedBox(width: 8),
            Text(
              'Hydrated! Added +$ml mL to your daily log 💧',
              style: const TextStyle(fontWeight: FontWeight.w600),
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

    return BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
      child: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Material(
              color: Colors.transparent,
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: context.bgSurface.withValues(alpha: context.isDark ? 0.85 : 0.95),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: const Color(0xFF38BDF8).withValues(alpha: 0.35),
                    width: 1.2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
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
                        gradient: const LinearGradient(
                          colors: [Color(0xFF38BDF8), Color(0xFF0284C7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFF38BDF8).withValues(alpha: 0.4),
                            blurRadius: 18,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: const Center(
                        child: Icon(
                          Icons.water_drop_rounded,
                          size: 34,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Title
                    Text(
                      'Hydration Alert! 💧',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                        color: context.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Pause for a second and take a sip! Your brain and body run on hydration.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        color: context.textMuted,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Progress Pill
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: context.bgBase,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: context.divider.withValues(alpha: 0.8),
                          width: 0.8,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            '$currentMl / $targetMl mL',
                            style: GoogleFonts.jetBrainsMono(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                              color: context.textPrimary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: const Color(0xFF38BDF8).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '$percent%',
                              style: GoogleFonts.jetBrainsMono(
                                fontWeight: FontWeight.w800,
                                fontSize: 11,
                                color: const Color(0xFF38BDF8),
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
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: context.textMuted,
                          letterSpacing: 0.8,
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
                              style: GoogleFonts.jetBrainsMono(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: context.textPrimary,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Enter mL (e.g. 400)',
                                hintStyle: TextStyle(color: context.textMuted, fontSize: 12),
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                filled: true,
                                fillColor: context.bgBase,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  borderSide: BorderSide(color: context.divider),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF38BDF8),
                              foregroundColor: Colors.white,
                              elevation: 0,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            ),
                            onPressed: () {
                              final val = int.tryParse(_customController.text.trim()) ?? 0;
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
                        icon: const Icon(Icons.tune_rounded, size: 14, color: Color(0xFF38BDF8)),
                        label: const Text(
                          'Custom Amount',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.w600,
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
                        style: TextButton.styleFrom(
                          foregroundColor: context.textMuted,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                        ),
                        child: const Text(
                          'Remind me later',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w500),
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
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: context.bgBase,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: context.divider.withValues(alpha: 0.8),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF38BDF8)),
              const SizedBox(height: 6),
              Text(
                '+$amountMl mL',
                style: GoogleFonts.jetBrainsMono(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: context.textPrimary,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(
                  fontSize: 10,
                  color: context.textMuted,
                  fontWeight: FontWeight.w500,
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
