import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';

/// Centralized modal bottom sheet utility for Ascent.
///
/// Ensures consistent top drag handles, 24px corner radii, theme-aware surface backgrounds,
/// keyboard avoidance, and accessible constraints across all feature sheets.
class AscentBottomSheet extends StatelessWidget {
  const AscentBottomSheet({
    super.key,
    this.title,
    this.titleWidget,
    this.subtitle,
    required this.child,
    this.actions,
    this.padding,
    this.showDragHandle = true,
  });

  final String? title;
  final Widget? titleWidget;
  final String? subtitle;
  final Widget child;
  final List<Widget>? actions;
  final EdgeInsetsGeometry? padding;
  final bool showDragHandle;

  /// Shows an Ascent-standard modal bottom sheet.
  static Future<T?> show<T>({
    required BuildContext context,
    String? title,
    Widget? titleWidget,
    String? subtitle,
    required Widget child,
    List<Widget>? actions,
    EdgeInsetsGeometry? padding,
    bool isScrollControlled = true,
    bool isDismissible = true,
    bool enableDrag = true,
    double maxChildSize = 0.92,
  }) {
    HapticFeedback.lightImpact();

    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(ctx).size.height * maxChildSize,
        ),
        child: AscentBottomSheet(
          title: title,
          titleWidget: titleWidget,
          subtitle: subtitle,
          actions: actions,
          padding: padding,
          child: child,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: AscentRadii.sheetTop,
        border: Border.all(
          color: g.edge.withValues(alpha: context.isDark ? 0.4 : 0.8),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: g.shadow.withValues(alpha: context.isDark ? 0.45 : 0.12),
            blurRadius: 24,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomInset),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // ── Drag Handle ───────────────────────────────────────────────
              if (showDragHandle) ...[
                const SizedBox(height: 10),
                Center(
                  child: Container(
                    width: 38,
                    height: 4,
                    decoration: BoxDecoration(
                      color: context.divider.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ] else ...[
                const SizedBox(height: 16),
              ],

              // ── Header Title (if provided) ────────────────────────────────
              if (title != null || titleWidget != null) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AscentDimensions.spaceXl),
                  child: Row(
                    children: [
                      Expanded(
                        child: titleWidget ??
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  title!,
                                  style: AscentTextStyles.displaySmall.copyWith(
                                    color: context.textPrimary,
                                  ),
                                ),
                                if (subtitle != null && subtitle!.isNotEmpty) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    subtitle!,
                                    style: AscentTextStyles.bodySmall.copyWith(
                                      color: context.textMuted,
                                    ),
                                  ),
                                ],
                              ],
                            ),
                      ),
                      ...?actions,
                    ],
                  ),
                ),
                const SizedBox(height: AscentDimensions.spaceMd),
                Divider(color: context.divider.withValues(alpha: 0.6), height: 1),
              ],

              // ── Body Content ──────────────────────────────────────────────
              Flexible(
                child: Padding(
                  padding: padding ?? const EdgeInsets.all(AscentDimensions.spaceXl),
                  child: child,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
