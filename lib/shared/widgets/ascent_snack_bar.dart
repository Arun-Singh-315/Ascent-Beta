import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';

/// Centralized SnackBar utility for Ascent.
///
/// Ensures consistent floating elevation, 14px radii, theme-aware contrast,
/// tactile haptics, and instant "Undo" recovery actions.
class AscentSnackBar {
  AscentSnackBar._();

  /// Shows a general informational floating snackbar.
  static void show(
    BuildContext context, {
    required String message,
    IconData? icon,
    Duration duration = const Duration(milliseconds: 2500),
    String? actionLabel,
    VoidCallback? onAction,
  }) {
    HapticFeedback.lightImpact();

    final isDark = context.isDark;

    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (icon != null) ...[
              Icon(icon, size: 18, color: context.accentPrimary),
              const SizedBox(width: 10),
            ],
            Expanded(
              child: Text(
                message,
                style: AscentTextStyles.bodyMedium.copyWith(
                  color: isDark
                      ? const Color(0xFFF1F5F9)
                      : const Color(0xFFEFF2F6),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        action: actionLabel != null && onAction != null
            ? SnackBarAction(
                label: actionLabel,
                textColor: context.accentPrimary,
                onPressed: () {
                  HapticFeedback.mediumImpact();
                  onAction();
                },
              )
            : null,
        duration: duration,
        persist: false,
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2D251E).withValues(alpha: 0.96),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: Colors.white.withValues(alpha: isDark ? 0.16 : 0.08),
            width: 0.9,
          ),
        ),
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 74),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// Shows a success snackbar with a green checkmark icon.
  static void success(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 2500),
  }) {
    show(
      context,
      message: message,
      icon: Icons.check_circle_rounded,
      duration: duration,
    );
  }

  /// Shows an error / alert snackbar with a red warning icon.
  static void error(
    BuildContext context, {
    required String message,
    Duration duration = const Duration(milliseconds: 3000),
  }) {
    HapticFeedback.mediumImpact();

    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 18,
              color: context.stateDanger,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AscentTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        duration: duration,
        persist: false,
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF261919).withValues(alpha: 0.96),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: context.stateDanger.withValues(alpha: 0.4),
            width: 1.0,
          ),
        ),
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 74),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      ),
    );
  }

  /// Shows an undo snackbar allowing the user to recover accidentally deleted entities.
  static void undo(
    BuildContext context, {
    required String message,
    required VoidCallback onUndo,
    Duration duration = const Duration(seconds: 4),
  }) {
    HapticFeedback.lightImpact();

    final isDark = context.isDark;

    final messenger = ScaffoldMessenger.of(context);
    messenger.removeCurrentSnackBar();

    messenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: Colors.white70,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: AscentTextStyles.bodyMedium.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        action: SnackBarAction(
          label: 'UNDO',
          textColor: context.accentPrimary,
          onPressed: () {
            HapticFeedback.mediumImpact();
            onUndo();
          },
        ),
        duration: duration,
        persist: false,
        behavior: SnackBarBehavior.floating,
        backgroundColor: const Color(0xFF2D251E).withValues(alpha: 0.96),
        elevation: 6,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: Colors.white.withValues(alpha: isDark ? 0.20 : 0.10),
            width: 1.0,
          ),
        ),
        margin: const EdgeInsets.only(left: 20, right: 20, bottom: 74),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      ),
    );
  }
}
