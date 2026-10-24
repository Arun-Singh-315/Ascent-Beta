import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import 'ascent_scaffold.dart';
import 'glass_surface.dart';

/// A reusable, Apple-glass-styled "Coming Soon" screen for features
/// undergoing architectural upgrade or scheduled for future release.
class ComingSoonScreen extends StatelessWidget {
  const ComingSoonScreen({
    super.key,
    required this.title,
    required this.subtitle,
    required this.icon,
    this.badgeText = 'Coming Soon',
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String badgeText;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return AscentScaffold(
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  IconButton(
                    tooltip: 'Back',
                    icon: Icon(Icons.arrow_back_rounded, color: g.ink),
                    onPressed: () {
                      HapticFeedback.lightImpact();
                      if (context.canPop()) {
                        context.pop();
                      } else {
                        context.go('/home');
                      }
                    },
                  ),
                  const Spacer(),
                ],
              ),
            ),

            Expanded(
              child: Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      // Glowing Glass Icon Container
                      GlassSurface(
                        radius: 28,
                        padding: const EdgeInsets.all(24),
                        child: Icon(
                          icon,
                          size: 48,
                          color: g.clay,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // Coming Soon Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: g.clay.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: g.clay.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          badgeText,
                          style: TextStyle(
                            color: g.clay,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Feature Title
                      Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AscentTextStyles.homeTitle.copyWith(
                          color: g.ink,
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 10),

                      // Subtitle / Description
                      Text(
                        subtitle,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: g.inkMuted,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Return Home Button
                      ElevatedButton.icon(
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          context.go('/home');
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: g.clay,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 24,
                            vertical: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        icon: const Icon(Icons.home_rounded, size: 18),
                        label: const Text(
                          'Back to Home',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
