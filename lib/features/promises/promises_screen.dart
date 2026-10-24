import 'package:flutter/material.dart';
import '../../shared/widgets/coming_soon_screen.dart';

class PromisesScreen extends StatelessWidget {
  const PromisesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ComingSoonScreen(
      title: 'Promises',
      subtitle:
          'A sacred commitment contract with accountability partners. Undergoing redesign for a seamless Apple glass experience.',
      icon: Icons.handshake_rounded,
    );
  }
}
