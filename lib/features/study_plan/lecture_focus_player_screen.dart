import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'lecture_focus_player_sheet.dart';

/// Full-screen route wrapper for the Lecture Focus Player.
/// Seamlessly renders the exact Lecture Focus Player design.
class LectureFocusPlayerScreen extends ConsumerWidget {
  const LectureFocusPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: context.surfaces.playerBackdrop,
      body: const SafeArea(child: LectureFocusPlayerSheet()),
    );
  }
}
