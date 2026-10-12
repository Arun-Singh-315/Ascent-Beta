import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import 'glass_surface.dart';

/// Floating, theme-aware glass feedback with optional recovery actions.
class AscentSnackBar {
  AscentSnackBar._();

  static SnackBar build(
    BuildContext context, {
    required Widget content,
    Duration duration = const Duration(milliseconds: 2500),
    SnackBarAction? action,
  }) => SnackBar(
    content: GlassSurface(
      radius: 18,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: DefaultTextStyle(
        style: AscentTextStyles.bodyMedium.copyWith(color: context.glass.ink),
        child: Row(
          children: [
            Expanded(child: content),
            ?action,
          ],
        ),
      ),
    ),
    duration: duration,
    persist: false,
    behavior: SnackBarBehavior.floating,
    backgroundColor: Colors.transparent,
    elevation: 0,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
    padding: EdgeInsets.zero,
    margin: const EdgeInsets.fromLTRB(16, 0, 16, 74),
  );

  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 2500),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    HapticFeedback.lightImpact();
    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();
    messenger.showSnackBar(
      build(
        context,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: context.glass.clay),
              const SizedBox(width: 10),
            ],
            Expanded(child: Text(message)),
          ],
        ),
        duration: duration,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: context.glass.clay,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onAction();
                },
              )
            : null,
      ),
    );
  }

  static void success(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 2500),
  }) => show(
    context,
    message: message,
    icon: Icons.check_circle_rounded,
    duration: duration,
  );

  static void error(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 3000),
  }) => show(
    context,
    message: message,
    icon: Icons.error_outline_rounded,
    duration: duration,
  );

  static void undo(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 4),
  }) => show(
    context,
    message: message,
    icon: Icons.delete_outline_rounded,
    duration: duration,
    actionLabel: 'UNDO',
    onAction: onUndo,
  );
}
