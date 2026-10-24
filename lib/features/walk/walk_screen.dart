import 'package:flutter/material.dart';
import '../../shared/widgets/coming_soon_screen.dart';

class WalkScreen extends StatelessWidget {
  const WalkScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Walk & Pacing',
      subtitle:
          'Lightweight outdoor pacing and walking sessions. Map engine and tracking are being optimized for ultra-low battery footprint.',
      icon: Icons.directions_walk_rounded,
    );
  }
}
