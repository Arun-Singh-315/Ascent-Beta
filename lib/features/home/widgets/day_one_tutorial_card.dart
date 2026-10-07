import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../today/add_activity_sheet.dart';

/// Lightweight, dismissible Day-1 Quick Start Guide.
/// Replaces the old blocking modal dialog with a zero-freeze, ambient glass card
/// that introduces the core mental model of Ascent on first launch.
class DayOneTutorialCard extends ConsumerStatefulWidget {
  final String userName;

  const DayOneTutorialCard({super.key, required this.userName});

  @override
  ConsumerState<DayOneTutorialCard> createState() => _DayOneTutorialCardState();
}

class _DayOneTutorialCardState extends ConsumerState<DayOneTutorialCard> {
  bool _dismissed = false;

  static const String _prefKey = 'ascent_day_one_tutorial_dismissed';

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(sharedPreferencesProvider);
    _dismissed = prefs.getBool(_prefKey) ?? false;
  }

  void _dismissTutorial() {
    HapticFeedback.lightImpact();
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setBool(_prefKey, true);
    setState(() => _dismissed = true);
  }

  @override
  Widget build(BuildContext context) {
    if (_dismissed) return const SizedBox.shrink();

    final g = context.glass;
    final firstName = widget.userName.trim().split(' ').first;
    final displayName = firstName.isNotEmpty ? firstName : 'Friend';

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: GlassSurface(
        radius: 20,
        padding: const EdgeInsets.all(18),
        customBorder: Border.all(
          color: g.clay.withValues(alpha: 0.35),
          width: 1.1,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Tag badge + close button
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3.5),
                  decoration: BoxDecoration(
                    color: g.claySoft,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: g.clay.withValues(alpha: 0.3), width: 0.8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.auto_awesome_rounded, size: 12, color: g.clay),
                      const SizedBox(width: 5),
                      Text(
                        'QUICK START GUIDE',
                        style: GoogleFonts.jetBrainsMono(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: g.clay,
                          letterSpacing: 0.8,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, size: 18, color: g.inkMuted),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  tooltip: 'Dismiss guide',
                  onPressed: _dismissTutorial,
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Greeting
            Text(
              'Welcome, $displayName! Here\'s how Ascent works:',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15.5,
                fontWeight: FontWeight.w700,
                color: g.ink,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 12),

            // 3 Quick Points
            _tutorialRow(
              icon: Icons.check_circle_outline_rounded,
              iconColor: g.sage,
              title: 'To-Dos vs. Timed Focus',
              description: 'Quick tasks have checkboxes. Long study sessions have dedicated focus clocks.',
              g: g,
            ),
            const SizedBox(height: 10),

            _tutorialRow(
              icon: Icons.chat_bubble_outline_rounded,
              iconColor: g.clay,
              title: 'Riya AI Gateway',
              description: 'Tap the glowing Riya button above to plan your day or ask anything naturally.',
              g: g,
            ),
            const SizedBox(height: 10),

            _tutorialRow(
              icon: Icons.school_outlined,
              iconColor: g.slate,
              title: 'Learning Hub & Consistency',
              description: 'Track your structured course syllabus and build an uninterrupted daily streak.',
              g: g,
            ),
            const SizedBox(height: 16),

            // Actions row
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: g.clay,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                    ),
                    onPressed: () {
                      _dismissTutorial();
                      AddActivitySheet.show(context);
                    },
                    child: const Text(
                      'Add First Activity 🚀',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: g.edge),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    foregroundColor: g.ink,
                  ),
                  onPressed: _dismissTutorial,
                  child: const Text('Got it! 👍', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _tutorialRow({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String description,
    required AscentGlass g,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.14),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 14, color: iconColor),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: g.ink,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                description,
                style: TextStyle(
                  fontSize: 11.5,
                  color: g.inkMuted,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
