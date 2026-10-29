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
/// - Radius 12px, screen margins 16px, minHeight 48px
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
      content: Container(
        constraints: const BoxConstraints(
          minHeight: AscentDimensions.buttonHeightStandard,
        ),
        decoration: BoxDecoration(
          color: g.elevated,
          borderRadius: BorderRadius.circular(AscentDimensions.radiusMd),
          border: Border.all(
            color: isError ? g.errorInk : g.line,
            width: AscentDimensions.contentOutlineWidth,
          ),
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: AscentDimensions.spaceLg,
          vertical: AscentDimensions.spaceSm,
        ),
        child: Row(
          children: [
            Expanded(
              child: DefaultTextStyle(
                style: AscentTextStyles.body.copyWith(color: g.ink),
                child: content,
              ),
            ),
            if (action != null) ...[
              const SizedBox(width: AscentDimensions.spaceSm),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  action.onPressed();
                },
                style: TextButton.styleFrom(
                  foregroundColor: g.actionInk,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AscentDimensions.spaceSm,
                  ),
                  minimumSize: const Size(48, 36),
                ),
                child: Text(
                  action.label,
                  style: AscentTextStyles.buttonLabel.copyWith(
                    color: g.actionInk,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
      duration: duration,
      persist: false,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      elevation: 0,
      padding: EdgeInsets.zero,
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
    messenger.removeCurrentSnackBar();

    final g = context.glass;

    messenger.showSnackBar(
      build(
        context,
        isError: isError,
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(
                icon,
                size: 20,
                color: isError ? g.errorInk : g.actionInk,
              ),
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
    Duration duration = const Duration(seconds: 4),
  }) => show(
    context,
    message: message,
    icon: Icons.delete_outline_rounded,
    duration: duration,
    actionLabel: 'Undo',
    onAction: onUndo,
  );
}
