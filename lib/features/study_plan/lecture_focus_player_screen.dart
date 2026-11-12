import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'lecture_focus_player_sheet.dart';

/// Full-screen route wrapper for the Lecture Focus Player.
/// Seamlessly renders the exact Lecture Focus Player design.
class LectureFocusPlayerScreen extends ConsumerWidget {
  const LectureFocusPlayerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = GoRouter.maybeOf(context);
    final canPopNow = router != null ? router.canPop() : Navigator.of(context).canPop();

    return PopScope(
      canPop: canPopNow,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (router != null) {
            router.go('/home');
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        backgroundColor: context.surfaces.playerBackdrop,
        body: const SafeArea(child: LectureFocusPlayerSheet()),
      ),
    );
  }
}
