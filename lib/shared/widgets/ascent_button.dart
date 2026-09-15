import 'package:flutter/material.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';

/// The five core button variants in the Ascent design system.
enum AscentButtonType {
  /// Filled sage-green — primary CTA.
  primary,

  /// Transparent with a sage-green border — secondary CTA.
  secondary,

  /// No border, no fill — tertiary / inline action.
  ghost,

  /// 44×44 circular transparent tap target — icon-only.
  icon,

  /// 56×56 filled circle, peach — floating action.
  fab,

  /// Danger-coloured ghost — irreversible / destructive action.
  destructive,
}

/// A unified button widget covering all Ascent button variants.
///
/// Prefer the named constructors for readability:
/// ```dart
/// AscentButton.primary(label: 'Save', onPressed: _save)
/// AscentButton.fab(icon: Icons.add, onPressed: _create)
/// ```
class AscentButton extends StatelessWidget {
  const AscentButton({
    super.key,
    required this.type,
    this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = true,
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
  }) : type = AscentButtonType.primary;

  /// Outlined secondary button.
  const AscentButton.secondary({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = true,
  }) : type = AscentButtonType.secondary;

  /// Ghost / text-only button.
  const AscentButton.ghost({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = false,
  }) : type = AscentButtonType.ghost;

  /// 44×44 icon-only button.
  const AscentButton.icon({
    super.key,
    required IconData this.icon,
    this.onPressed,
  })  : type = AscentButtonType.icon,
        label = null,
        loading = false,
        expanded = false;

  /// 56×56 floating action button (peach fill).
  const AscentButton.fab({
    super.key,
    required IconData this.icon,
    this.onPressed,
  })  : type = AscentButtonType.fab,
        label = null,
        loading = false,
        expanded = false;

  /// Destructive solid button (red fill, 52px).
  const AscentButton.destructive({
    super.key,
    required String this.label,
    this.icon,
    this.onPressed,
    this.loading = false,
    this.expanded = false,
  }) : type = AscentButtonType.destructive;

  // ── Fields ────────────────────────────────────────────────────────────────

  final AscentButtonType type;

  /// Text label — required for [primary], [secondary], [ghost], [destructive].
  final String? label;

  /// Icon — optional for [primary], [secondary], [ghost], [destructive]; required for [icon] and [fab].
  final IconData? icon;

  /// Tap callback. When null the button is disabled.
  final VoidCallback? onPressed;

  /// Replaces the label with a 16×16 [CircularProgressIndicator] in the
  /// button's foreground colour. The button remains non-interactive.
  final bool loading;

  /// When true the button stretches to [double.infinity] width. Only
  /// meaningful for [primary], [secondary], and [destructive].
  final bool expanded;

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
        ),
      AscentButtonType.secondary => _SecondaryButton(
          label: label!,
          icon: icon,
          onPressed: loading ? null : onPressed,
          loading: loading,
          expanded: expanded,
        ),
      AscentButtonType.ghost => _GhostButton(
          label: label!,
          icon: icon,
          onPressed: loading ? null : onPressed,
          loading: loading,
        ),
      AscentButtonType.icon => _IconButton(
          icon: icon!,
          onPressed: onPressed,
        ),
      AscentButtonType.fab => _FabButton(
          icon: icon!,
          onPressed: onPressed,
        ),
      AscentButtonType.destructive => _DestructiveButton(
          label: label!,
          icon: icon,
          onPressed: loading ? null : onPressed,
          loading: loading,
          expanded: expanded,
        ),
    };

    return _TapScaleWrapper(
      enabled: onPressed != null && !loading,
      child: child,
    );
  }
}

// ── Private implementations ────────────────────────────────────────────────────

class _TapScaleWrapper extends StatefulWidget {
  const _TapScaleWrapper({
    required this.child,
    this.enabled = true,
  });

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
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.97 : 1.0,
        duration: const Duration(milliseconds: 120),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  const _PrimaryButton({
    required this.label,
    this.icon,
    required this.onPressed,
    required this.loading,
    required this.expanded,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !loading;
    final bg = isEnabled ? context.accentPrimaryBright : context.accentPrimaryDim;
    final fg = context.textOnPrimary;

    Widget child = loading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: fg,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(label, style: AscentTextStyles.labelLarge.copyWith(color: fg)),
            ],
          );

    Widget button = SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: context.accentPrimaryDim,
          disabledForegroundColor: fg.withValues(alpha: 0.6),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          minimumSize: expanded
              ? const Size(double.infinity, 52)
              : const Size(120, 52),
          textStyle: AscentTextStyles.labelLarge,
        ),
        child: child,
      ),
    );

    return expanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

class _SecondaryButton extends StatelessWidget {
  const _SecondaryButton({
    required this.label,
    this.icon,
    required this.onPressed,
    required this.loading,
    required this.expanded,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final isEnabled = onPressed != null && !loading;
    final accent = isEnabled ? context.accentPrimaryBright : context.accentPrimaryDim;

    Widget child = loading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: accent,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: AscentTextStyles.labelLarge.copyWith(color: accent)),
            ],
          );

    Widget button = SizedBox(
      height: 52,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          foregroundColor: accent,
          disabledForegroundColor: context.accentPrimaryDim,
          side: BorderSide(color: accent, width: 1.5),
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          minimumSize: expanded
              ? const Size(double.infinity, 52)
              : const Size(120, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          textStyle: AscentTextStyles.labelLarge,
        ),
        child: child,
      ),
    );

    return expanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

class _GhostButton extends StatelessWidget {
  const _GhostButton({
    required this.label,
    this.icon,
    required this.onPressed,
    required this.loading,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final accent = context.accentPrimary;

    Widget child = loading
        ? SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2, color: accent),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: 8),
              ],
              Text(label,
                  style: AscentTextStyles.labelLarge.copyWith(color: accent)),
            ],
          );

    return SizedBox(
      height: 44,
      child: TextButton(
        onPressed: onPressed,
        style: TextButton.styleFrom(
          foregroundColor: accent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(12)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          textStyle: AscentTextStyles.labelLarge,
        ),
        child: child,
      ),
    );
  }
}

class _IconButton extends StatelessWidget {
  const _IconButton({required this.icon, required this.onPressed});

  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final surface = context.bgSurface;
    final fg = context.textPrimary;

    return SizedBox(
      width: 44,
      height: 44,
      child: Material(
        color: Colors.transparent,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          splashColor: surface.withValues(alpha: 0.2),
          highlightColor: surface.withValues(alpha: 0.12),
          child: Center(
            child: Icon(icon, color: fg, size: 22),
          ),
        ),
      ),
    );
  }
}

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
    final bg = _pressed
        ? context.accentSecondaryBright
        : context.accentSecondary;
    final shadow = context.isDark
        ? AscentColors.shadowDark
        : AscentColors.shadow;

    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onPressed,
      child: Container(
        width: 56,
        height: 56,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: shadow.withValues(alpha: 0.18),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: Icon(widget.icon, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _DestructiveButton extends StatelessWidget {
  const _DestructiveButton({
    required this.label,
    this.icon,
    required this.onPressed,
    required this.loading,
    required this.expanded,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final bool loading;
  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final bg = context.stateDangerBright;
    const fg = Colors.white;

    Widget child = loading
        ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: fg,
            ),
          )
        : Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: fg),
                const SizedBox(width: 8),
              ],
              Text(label, style: AscentTextStyles.labelLarge.copyWith(color: fg)),
            ],
          );

    Widget button = SizedBox(
      height: 52,
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: bg,
          foregroundColor: fg,
          disabledBackgroundColor: bg.withValues(alpha: 0.5),
          disabledForegroundColor: fg.withValues(alpha: 0.6),
          elevation: 0,
          shadowColor: Colors.transparent,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(16)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 24),
          minimumSize: expanded
              ? const Size(double.infinity, 52)
              : const Size(120, 52),
          textStyle: AscentTextStyles.labelLarge,
        ),
        child: child,
      ),
    );

    return expanded
        ? SizedBox(width: double.infinity, child: button)
        : button;
  }
}

