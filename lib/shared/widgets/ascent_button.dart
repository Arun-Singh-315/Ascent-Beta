import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/frozen_palette.dart';

/// The core button variants in the Ascent design system.
enum AscentButtonType {
  /// Filled primary CTA.
  primary,

  /// Outlined with primary accent — secondary CTA.
  secondary,

  /// Tonal fill with action text — for Done, Later, Change time.
  tonal,

  /// Transparent with subtle border & dark/neutral text — signature outlined control.
  outlined,

  /// No border, no fill — tertiary / inline action.
  ghost,

  /// Circular or soft-square transparent tap target with outlined icon.
  icon,

  /// Floating action button with warm terracotta accent.
  fab,

  /// Restrained danger-coloured button — irreversible / destructive action.
  destructive,
}

/// A unified, refined button system covering all Ascent button variants.
///
/// Designed with compact heights (42px standard, 34px compact), restrained 10px radii,
/// micro-scale tap interaction, and transparent outlined controls.
class AscentButton extends StatelessWidget {
  const AscentButton({
    super.key,
    required this.type,
    this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = true,
    this.compact = false,
  });

  // ── Named constructors ────────────────────────────────────────────────────

  /// Filled primary button. Full-width by default.
  const AscentButton.primary({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = true,
    this.compact = false,
  }) : type = AscentButtonType.primary;

  /// Outlined secondary button with accent tint.
  const AscentButton.secondary({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = true,
    this.compact = false,
  }) : type = AscentButtonType.secondary;

  /// Tonal button with tint fill and action text.
  const AscentButton.tonal({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = false,
    this.compact = false,
  }) : type = AscentButtonType.tonal;

  /// Signature outlined button: transparent fill, subtle border, dark/neutral text.
  const AscentButton.outlined({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = false,
    this.compact = false,
  }) : type = AscentButtonType.outlined;

  /// Ghost / text-only button.
  const AscentButton.ghost({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = false,
    this.compact = false,
  }) : type = AscentButtonType.ghost;

  /// Compact icon-only button with transparent background & subtle border.
  const AscentButton.icon({
    super.key,
    required IconData this.icon,
    this.onPressed,
    this.compact = false,
  }) : type = AscentButtonType.icon,
       label = null,
       loading = false,
       expanded = false;

  /// Floating action button with subtle diffuse shadow.
  const AscentButton.fab({
    super.key,
    required IconData this.icon,
    this.onPressed,
  }) : type = AscentButtonType.fab,
       label = null,
       loading = false,
       expanded = false,
       compact = false;

  /// Destructive action button.
  const AscentButton.destructive({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = false,
    this.compact = false,
  }) : type = AscentButtonType.destructive;

  // ── Fields ────────────────────────────────────────────────────────────────

  final AscentButtonType type;

  /// Text label — required for text-bearing variants.
  final String? label;

  /// Icon — optional for text variants; required for [icon] and [fab].
  final IconData? icon;

  /// Tap callback. When null the button is disabled.
  final VoidCallback? onPressed;

  /// Replaces the label with a sleek spinner.
  final bool loading;

  /// When true the button stretches to full width.
  final bool expanded;

  /// When true uses 34px compact height with tighter padding.
  final bool compact;

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final child = switch (type) {
      AscentButtonType.primary => _PrimaryButton(
        label: label!,
        icon: icon,
        onPressed: loading ? null : onPressed,
        loading: loading,
        expanded: expanded,
        compact: compact,
      ),
      AscentButtonType.secondary => _SecondaryButton(
        label: label!,
        icon: icon,
        onPressed: loading ? null : onPressed,
        loading: loading,
        expanded: expanded,
        compact: compact,
      ),
      AscentButtonType.tonal => _TonalButton(
        label: label!,
        icon: icon,
        onPressed: loading ? null : onPressed,
        loading: loading,
        expanded: expanded,
        compact: compact,
      ),
      AscentButtonType.outlined => _OutlinedSignatureButton(
        label: label!,
        icon: icon,
        onPressed: loading ? null : onPressed,
        loading: loading,
        expanded: expanded,
        compact: compact,
      ),
      AscentButtonType.ghost => _GhostButton(
        label: label!,
        icon: icon,
        onPressed: loading ? null : onPressed,
        loading: loading,
        compact: compact,
      ),
      AscentButtonType.icon => _IconButton(
        icon: icon!,
        onPressed: onPressed,
        compact: compact,
      ),
      AscentButtonType.fab => _FabButton(icon: icon!, onPressed: onPressed),
      AscentButtonType.destructive => _DestructiveButton(
        label: label!,
        icon: icon,
        onPressed: loading ? null : onPressed,
        loading: loading,
        expanded: expanded,
        compact: compact,
      ),
    };

    return _TapScaleWrapper(
      enabled: onPressed != null && !loading,
      child: child,
    );
  }
}

// ── Tap Micro-Interaction ───────────────────────────────────────────────────

class _TapScaleWrapper extends StatefulWidget {
  const _TapScaleWrapper({required this.child, this.enabled = true});

  final Widget child;
  final bool enabled;

  @override
  State<_TapScaleWrapper> createState() => _TapScaleWrapperState();
}

class _TapScaleWrapperState extends State<_TapScaleWrapper> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;

    return Listener(
      onPointerDown: (_) {
        HapticFeedback.lightImpact();
        setState(() => _pressed = true);
      },
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

// ── Primary Button ──────────────────────────────────────────────────────────

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    this.icon,
    required this.onPressed,
    required this.loading,
    required this.expanded,
    required this.compact,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !loading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFrozen = context.isFrozen;
    final bg = isEnabled
        ? (isDark
              ? (isFrozen
                    ? FrozenPalette.darkAction
                    : context.bgSurfaceElevated.withValues(alpha: 0.92))
              : (isFrozen
                        ? FrozenPalette.action
                        : AppPalette.colorFF3B2C1E)
                    .withValues(alpha: 0.94))
        : (isFrozen
              ? (isDark ? FrozenPalette.darkTint : FrozenPalette.tint)
              : context.bgSurfaceElevated.withValues(alpha: 0.4));
    final fg = isDark
        ? (isFrozen ? Colors.white : context.textPrimary)
        : AppPalette.white;
    final disabledFg = isFrozen
        ? (isDark ? FrozenPalette.darkMutedInk : FrozenPalette.mutedInk)
        : fg.withValues(alpha: 0.4);
    final borderColor = isDark
        ? (isFrozen
              ? FrozenPalette.darkAction
              : context.textPrimary.withValues(alpha: 0.25))
        : (isFrozen ? FrozenPalette.action : AppPalette.colorFF2A1C0F)
              .withValues(alpha: 0.7);
    final disabledBorder = isFrozen
        ? (isDark ? FrozenPalette.darkLine : FrozenPalette.line)
        : context.divider;
    final height = isFrozen
        ? (compact ? 36.0 : 48.0)
        : (MediaQuery.textScalerOf(context).scale(compact ? 12 : 14) * 1.5 + 20)
            .clamp(48.0, 100.0);
    final radius = isFrozen ? (compact ? 18.0 : 24.0) : (compact ? 8.0 : 10.0);

    Widget content = loading
        ? SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 15 : 17, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style:
                      (compact
                              ? AscentTextStyles.labelSmall
                              : AscentTextStyles.labelMedium)
                          .copyWith(color: fg)
                          .merge(AppTypeRoles.typeRole2),
                ),
              ),
            ],
          );

    Widget button = ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: ElevatedButton(
        onPressed: onPressed,
        style: context.surfaces.buttonStyle(
          ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            disabledBackgroundColor: isFrozen
                ? (isDark ? FrozenPalette.darkTint : FrozenPalette.tint)
                : context.bgSurfaceElevated.withValues(alpha: 0.4),
            disabledForegroundColor: disabledFg,
            elevation: 0,
            shadowColor: AppPalette.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
              side: BorderSide(
                color: isEnabled ? borderColor : disabledBorder,
                width: AppBorderScale.w1point1,
              ),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpace.s12 : AppSpace.s18,
              vertical: AppSpace.s10,
            ),
            minimumSize: Size(compact ? 60 : 90, height),
          ),
          filled: true,
          icon: false,
        ),
        child: content,
      ),
    );

    if (!expanded) return button;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth.isInfinite) return button;
        return SizedBox(width: double.infinity, child: button);
      },
    );
  }
}

// ── Secondary Button ────────────────────────────────────────────────────────

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    this.icon,
    required this.onPressed,
    required this.loading,
    required this.expanded,
    required this.compact,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !loading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFrozen = context.isFrozen;
    final accent = isEnabled
        ? (isFrozen
            ? (isDark ? FrozenPalette.darkAction : FrozenPalette.action)
            : FrozenPalette.action)
        : context.textMuted;
    final height = isFrozen
        ? (compact ? 36.0 : 48.0)
        : (MediaQuery.textScalerOf(context).scale(compact ? 12 : 14) * 1.5 + 20)
            .clamp(48.0, 100.0);
    final radius = isFrozen ? (compact ? 18.0 : 24.0) : (compact ? 8.0 : 10.0);

    Widget content = loading
        ? SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 15 : 17, color: accent),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style:
                      (compact
                              ? AscentTextStyles.labelSmall
                              : AscentTextStyles.labelMedium)
                          .copyWith(color: accent)
                          .merge(AppTypeRoles.typeRole8),
                ),
              ),
            ],
          );

    Widget button = ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: OutlinedButton(
        onPressed: onPressed,
        style: context.surfaces.buttonStyle(
          OutlinedButton.styleFrom(
            foregroundColor: accent,
            backgroundColor: AppPalette.transparent,
            side: BorderSide(
              color: isFrozen
                  ? accent
                  : accent.withValues(alpha: 0.5),
              width: AppBorderScale.w1point0,
            ),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpace.s12 : AppSpace.s18,
              vertical: AppSpace.s10,
            ),
            minimumSize: Size(compact ? 60 : 90, height),
          ),
          filled: false,
          icon: false,
        ),
        child: content,
      ),
    );

    if (!expanded) return button;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth.isInfinite) return button;
        return SizedBox(width: double.infinity, child: button);
      },
    );
  }
}

// ── Tonal Button ───────────────────────────────────────────────────────────

class _TonalButton extends StatelessWidget {
  const _TonalButton({
    required this.label,
    this.icon,
    required this.onPressed,
    required this.loading,
    required this.expanded,
    required this.compact,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !loading;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFrozen = context.isFrozen;
    final bg = isEnabled
        ? (isFrozen
            ? (isDark ? FrozenPalette.darkTint : FrozenPalette.tint)
            : context.accentPrimaryDim)
        : context.bgSurfaceElevated.withValues(alpha: 0.3);
    final fg = isEnabled
        ? (isFrozen
            ? (isDark ? FrozenPalette.darkAction : FrozenPalette.action)
            : context.accentPrimary)
        : context.textMuted;
    final height = isFrozen
        ? (compact ? 36.0 : 42.0)
        : (MediaQuery.textScalerOf(context).scale(compact ? 12 : 14) * 1.5 + 20)
            .clamp(48.0, 100.0);
    final radius = isFrozen ? (compact ? 16.0 : 20.0) : (compact ? 8.0 : 10.0);

    Widget content = loading
        ? SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 15 : 17, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: (compact
                          ? AscentTextStyles.labelSmall
                          : AscentTextStyles.labelMedium)
                      .copyWith(color: fg, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          );

    Widget button = ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
            side: isFrozen
                ? BorderSide(
                    color: (isDark ? FrozenPalette.darkLine : FrozenPalette.line)
                        .withValues(alpha: 0.4),
                    width: 0.8,
                  )
                : BorderSide.none,
          ),
          padding: EdgeInsets.symmetric(
            horizontal: compact ? AppSpace.s12 : AppSpace.s16,
            vertical: AppSpace.s8,
          ),
          minimumSize: Size(compact ? 50 : 70, height),
        ),
        child: content,
      ),
    );

    if (!expanded) return button;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth.isInfinite) return button;
        return SizedBox(width: double.infinity, child: button);
      },
    );
  }
}

// ── Outlined Signature Button ───────────────────────────────────────────────

class _OutlinedSignatureButton extends StatelessWidget {
  const _OutlinedSignatureButton({
    required this.label,
    this.icon,
    required this.onPressed,
    required this.loading,
    required this.expanded,
    required this.compact,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fg = context.textPrimary;
    final border = context.divider;
    final height =
        (MediaQuery.textScalerOf(context).scale(compact ? 12 : 14) * 1.5 + 20)
            .clamp(48.0, 100.0);
    final radius = compact ? 8.0 : 10.0;

    Widget content = loading
        ? SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 15 : 17, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style:
                      (compact
                              ? AscentTextStyles.labelSmall
                              : AscentTextStyles.labelMedium)
                          .copyWith(color: fg)
                          .merge(AppTypeRoles.typeRole15),
                ),
              ),
            ],
          );

    Widget button = ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: OutlinedButton(
        onPressed: onPressed,
        style: context.surfaces.buttonStyle(
          OutlinedButton.styleFrom(
            foregroundColor: fg,
            backgroundColor: context.bgSurface.withValues(alpha: 0.4),
            side: BorderSide(color: border, width: AppBorderScale.w1point0),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpace.s12 : AppSpace.s16,
            ),
            minimumSize: Size(compact ? 50 : 80, height),
          ),
          filled: false,
          icon: false,
        ),
        child: content,
      ),
    );

    if (!expanded) return button;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth.isInfinite) return button;
        return SizedBox(width: double.infinity, child: button);
      },
    );
  }
}

// ── Ghost Button ────────────────────────────────────────────────────────────

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    this.icon,
    required this.onPressed,
    required this.loading,
    required this.compact,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isFrozen = context.isFrozen;
    final fg = isFrozen
        ? (isDark ? FrozenPalette.darkAction : FrozenPalette.action)
        : context.textSecondary;
    final height = isFrozen
        ? (compact ? 36.0 : 42.0)
        : (MediaQuery.textScalerOf(context).scale(compact ? 12 : 14) * 1.5 + 20)
            .clamp(48.0, 100.0);

    Widget content = loading
        ? SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 14 : 16, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style:
                      (compact
                              ? AscentTextStyles.labelSmall
                              : AscentTextStyles.labelMedium)
                          .copyWith(color: fg)
                          .merge(AppTypeRoles.typeRole15),
                ),
              ),
            ],
          );

    return ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: TextButton(
        onPressed: onPressed,
        style: context.surfaces.buttonStyle(
          TextButton.styleFrom(
            foregroundColor: fg,
            shape: RoundedRectangleBorder(borderRadius: AppGeometry.roundedr8),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpace.s10 : AppSpace.s14,
              vertical: AppSpace.s10,
            ),
          ),
          filled: false,
          icon: false,
        ),
        child: content,
      ),
    );
  }
}

// ── Icon Button ─────────────────────────────────────────────────────────────

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.onPressed,
    required this.compact,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final fg = context.textPrimary;
    final size = compact ? 34.0 : 40.0;
    final iconSize = compact ? 18.0 : 20.0;

    return AppCard(
      width: size,
      height: size,
      nightDecoration: BoxDecoration(
        color: context.bgSurface.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        border: Border.all(
          color: context.divider,
          width: AppBorderScale.w0point9,
        ),
      ),
      child: Material(
        color: AppPalette.transparent,
        borderRadius: BorderRadius.circular(compact ? 8 : 10),
        clipBehavior: Clip.antiAlias,
        child: AppTapArea(
          onTap: onPressed,
          child: Center(
            child: Icon(icon, color: fg, size: iconSize),
          ),
        ),
      ),
    );
  }
}

// ── Floating Action Button ──────────────────────────────────────────────────

class _FabButton extends StatefulWidget {
  const _FabButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  State<_FabButton> createState() => _FabButtonState();
}

class _FabButtonState extends State<_FabButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDark;
    final isFrozen = context.isFrozen;
    final bg = _pressed
        ? context.accentSecondaryBright
        : context.accentSecondary;
    final shadow = isFrozen
        ? (isDark
            ? Colors.black.withValues(alpha: 0.3)
            : const Color.fromRGBO(29, 100, 180, 0.16))
        : (isDark
            ? AscentColors.shadowDark.withValues(alpha: 0.16)
            : AscentColors.shadow.withValues(alpha: 0.16));

    final decoration = isFrozen
        ? BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                _pressed
                    ? (isDark
                        ? FrozenPalette.darkActionPressed
                        : FrozenPalette.actionPressed)
                    : (isDark
                        ? FrozenPalette.darkActionBright
                        : FrozenPalette.actionBright),
                _pressed
                    ? (isDark
                        ? FrozenPalette.darkActionPressed
                        : FrozenPalette.actionPressed)
                    : (isDark
                        ? FrozenPalette.darkAction
                        : FrozenPalette.action),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: shadow,
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          )
        : BoxDecoration(
            color: bg,
            borderRadius: AppGeometry.roundedr14,
            boxShadow: [
              BoxShadow(
                color: shadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          );

    return AppGestureTap(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: AppCard(
        width: 48,
        height: 48,
        nightDecoration: decoration,
        child: Center(
          child: Icon(widget.icon, color: AppPalette.white, size: 22),
        ),
      ),
    );
  }
}

// ── Destructive Button ──────────────────────────────────────────────────────

class _DestructiveButton extends StatelessWidget {
  const _DestructiveButton({
    required this.label,
    this.icon,
    required this.onPressed,
    required this.loading,
    required this.expanded,
    required this.compact,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final bg = context.stateDanger;
    const fg = AppPalette.white;
    final height =
        (MediaQuery.textScalerOf(context).scale(compact ? 12 : 14) * 1.5 + 20)
            .clamp(48.0, 100.0);
    final radius = compact ? 8.0 : 10.0;

    Widget content = loading
        ? const SizedBox(
            width: 14,
            height: 14,
            child: CircularProgressIndicator(strokeWidth: 2, color: fg),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: compact ? 15 : 17, color: fg),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style:
                      (compact
                              ? AscentTextStyles.labelSmall
                              : AscentTextStyles.labelMedium)
                          .copyWith(color: fg)
                          .merge(AppTypeRoles.typeRole8),
                ),
              ),
            ],
          );

    Widget button = ConstrainedBox(
      constraints: BoxConstraints(minHeight: height),
      child: ElevatedButton(
        onPressed: onPressed,
        style: context.surfaces.buttonStyle(
          ElevatedButton.styleFrom(
            backgroundColor: bg,
            foregroundColor: fg,
            elevation: 0,
            shadowColor: AppPalette.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(radius),
            ),
            padding: EdgeInsets.symmetric(
              horizontal: compact ? AppSpace.s12 : AppSpace.s18,
              vertical: AppSpace.s10,
            ),
            minimumSize: Size(compact ? 60 : 90, height),
          ),
          filled: true,
          icon: false,
        ),
        child: content,
      ),
    );

    if (!expanded) return button;
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth.isInfinite) return button;
        return SizedBox(width: double.infinity, child: button);
      },
    );
  }
}
