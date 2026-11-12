import 'package:flutter/material.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/shared_control_tokens.dart';
import 'ascent_sheet.dart';

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

/// One calm, scrollable action surface for long-press and overflow entry points.
Future<T?> showAscentActionMenu<T>({
  required BuildContext context,
  required String title,
  required List<AscentAction<T>> actions,
}) => showAscentSheet<T>(
  context: context,
  builder: (ctx) {
    final g = ctx.glass;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 4, 18),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: g.ink,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Close actions',
                  onPressed: () => Navigator.pop(ctx),
                  icon: Icon(Icons.close_rounded, color: g.inkMuted),
                ),
              ],
            ),
          ),
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
                    borderRadius: BorderRadius.circular(22),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(22),
                      onTap: () => Navigator.pop(ctx, action.value),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 16,
                        ),
                        child: Row(
                          children: [
                            Icon(action.icon, size: 22, color: ink),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Text(
                                action.label,
                                style: TextStyle(
                                  color: action.destructive ? ink : g.ink,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                  height: 1.4,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Icon(
                              Icons.chevron_right_rounded,
                              size: 18,
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
    );
  },
);
