import 'package:flutter/material.dart';
import 'ascent_snack_bar.dart';

/// Displays a floating [SnackBar] with an **Undo** action button adhering to Section 5 (C08).
void showUndoSnackbar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 4),
}) {
  AscentSnackBar.undo(
    context,
    message: message,
    onUndo: onUndo,
    duration: duration,
  );
}
