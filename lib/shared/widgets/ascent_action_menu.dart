import 'package:flutter/material.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/shared_control_tokens.dart';
import 'ascent_dialog.dart';

class AscentAction<T> {
  const AscentAction(
    this.value,
    this.label,
    this.icon, {
    this.destructive = false,
  });
  final T value;
  final String label;
  final IconData icon;
  final bool destructive;
}

/// One calm, centered action dialog for three-dots and overflow entry points.
/// Appears directly in the viewport center with a frosted background,
/// completely eliminating awkward bottom-bezel reaches.
Future<T?> showAscentActionMenu<T>({
  required BuildContext context,
  required String title,
  required List<AscentAction<T>> actions,
}) => showAscentFrostedDialog<T>(
  context: context,
  builder: (ctx) {
    final g = ctx.glass;
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 360),
        child: Container(
          decoration: BoxDecoration(
            color: g.elevated,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: g.line,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: g.isDark ? 0.35 : 0.10),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: g.ink,
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          height: 1.30,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      tooltip: 'Close actions',
                      onPressed: () => Navigator.pop(ctx),
                      icon: Icon(Icons.close_rounded, color: g.inkMuted, size: 20),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                for (final action in actions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Builder(
                      builder: (_) {
                        final ink = action.destructive
                            ? SharedControlColors.errorInk(g.isDark)
                            : (g.isDark
                                ? SharedControlColors.actionBlueDark
                                : SharedControlColors.actionBlue);
                        return Material(
                          color: action.destructive
                              ? SharedControlColors.errorSoftBg(
                                  g.isDark,
                                ).withValues(alpha: .55)
                              : g.ink.withValues(alpha: .035),
                          borderRadius: BorderRadius.circular(16),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () => Navigator.pop(ctx, action.value),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: Row(
                                children: [
                                  Icon(action.icon, size: 20, color: ink),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      action.label,
                                      style: TextStyle(
                                        color: action.destructive ? ink : g.ink,
                                        fontSize: 14.5,
                                        fontWeight: FontWeight.w600,
                                        height: 1.35,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    Icons.chevron_right_rounded,
                                    size: 16,
                                    color: ink.withValues(alpha: .6),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  },
);
