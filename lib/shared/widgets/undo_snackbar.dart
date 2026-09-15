import 'package:flutter/material.dart';

import '../../app/theme/text_styles.dart';

/// Displays a floating [SnackBar] with an **Undo** action button.
///
/// The undo button fires [onUndo] and dismisses the snackbar immediately.
///
/// ```dart
/// showUndoSnackbar(
///   context,
///   message: 'Application removed',
///   onUndo: _restoreApplication,
/// );
/// ```
void showUndoSnackbar(
  BuildContext context, {
  required String message,
  required VoidCallback onUndo,
  Duration duration = const Duration(seconds: 4),
}) {
  final messenger = ScaffoldMessenger.of(context);

  // Dismiss any current snackbar before showing the new one.
  messenger.hideCurrentSnackBar();

  messenger.showSnackBar(
    SnackBar(
      duration: duration,
      content: Text(
        message,
        style: AscentTextStyles.bodyMedium.copyWith(color: Colors.white),
      ),
      action: SnackBarAction(
        label: 'Undo',
        onPressed: () {
          messenger.hideCurrentSnackBar();
          onUndo();
        },
      ),
    ),
  );
}
