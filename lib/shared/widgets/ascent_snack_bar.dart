import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';

/// Floating, theme-aware feedback snackbar conforming to Section 5 (C08).
///
/// Features:
/// - Opaque elevated surface fill
/// - Primary text for message
/// - Action ink for Undo / actions
/// - Radius 16px, screen margins 16px, minHeight 48px
/// - Screen-reader / accessibility support with error preservation
class AscentSnackBar {
  AscentSnackBar._();

  static SnackBar build(
    BuildContext context, {
    required Widget content,
    Duration duration = const Duration(milliseconds: 2500),
    SnackBarAction? action,
    bool isError = false,
  }) {
    final g = context.glass;

    return SnackBar(
      content: ConstrainedBox(
        constraints: const BoxConstraints(
          minHeight: AscentDimensions.minTouchTarget,
        ),
        child: Align(
          alignment: Alignment.centerLeft,
          heightFactor: 1,
          child: DefaultTextStyle(
            style: AscentTextStyles.body.copyWith(color: g.ink, height: 1.5),
            child: content,
          ),
        ),
      ),
      // A native action participates in TalkBack timing and is single-use.
      action: action,
      actionOverflowThreshold: .25,
      duration: duration,
      persist: false,
      behavior: SnackBarBehavior.floating,
      backgroundColor: g.elevated,
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: isError ? g.errorInk : g.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      margin: const EdgeInsets.all(AscentDimensions.spaceLg),
    );
  }

  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 2500),
    String? actionLabel,
    VoidCallback? onAction,
    bool isError = false,
  }) {
    HapticFeedback.lightImpact();
    final messenger = ScaffoldMessenger.of(context);
    // Queue feedback so a later message cannot erase an available Undo action.

    final g = context.glass;

    messenger.showSnackBar(
      build(
        context,
        isError: isError,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 20, color: isError ? g.errorInk : g.actionInk),
              const SizedBox(width: AscentDimensions.spaceSm),
            ],
            Expanded(
              child: Text(
                message,
                style: AscentTextStyles.body.copyWith(color: g.ink),
              ),
            ),
          ],
        ),
        duration: duration,
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: g.actionInk,
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
    isError: true,
  );

  static void undo(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 8),
  }) => show(
    context,
    message: message,
    icon: Icons.undo_rounded,
    duration: duration,
    actionLabel: 'Undo',
    onAction: onUndo,
  );

  /// Celebrates completed commitments or achievements with tactile haptics & joyful applause.
  static void applaud(
    BuildContext context, {
    required String message,
    String? subtitle,
    VoidCallback? onUndo,
    Duration duration = const Duration(milliseconds: 2800),
  }) {
    HapticFeedback.mediumImpact();
    Future<void>.delayed(const Duration(milliseconds: 140), () {
      HapticFeedback.lightImpact();
    });

    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;

    final g = context.glass;

    messenger.showSnackBar(
      build(
        context,
        duration: duration,
        content: Row(
          children: [
            const Text('👏', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    message,
                    style: AscentTextStyles.body.copyWith(
                      color: g.ink,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 1),
                    Text(
                      subtitle,
                      style: TextStyle(color: g.inkMuted, fontSize: 11.5),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
        action: onUndo != null
            ? SnackBarAction(
                label: 'Undo',
                textColor: g.actionInk,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onUndo();
                },
              )
            : null,
      ),
    );
  }
}
