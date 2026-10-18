import 'dart:ui' show ImageFilter;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/color_tokens.dart';
import '../../app/theme/surface_tokens.dart';

/// The single grouped-content surface. Existing glass geometry is retained.
class AppCard extends StatelessWidget {
  static Widget materialSurface({Key? key, Color? color, ShapeBorder? shape,
    Clip clipBehavior = Clip.none, required Widget child}) => Builder(
      builder: (context) => context.surfaces.outlined
        ? AppCard(key: key, child: child)
        : Material(key: key, color: color, shape: shape,
            clipBehavior: clipBehavior, child: child));

  static Widget material({
    Key? key,
    Widget? child,
    EdgeInsetsGeometry? margin,
  }) => Builder(
    builder: (context) => context.surfaces.outlined
        ? AppCard(key: key, margin: margin, child: child)
        : Card(key: key, margin: margin, child: child),
  );

  const AppCard({
    super.key,
    this.child,
    this.padding,
    this.margin,
    this.width,
    this.height,
    this.constraints,
    this.alignment,
    this.onTap,
    this.onLongPress,
    this.nightDecoration,
    this.selected = false,
    this.role = AppSurfaceRole.card,
    this.clipBehavior = Clip.none,
    this.transform,
    this.transformAlignment,
    this.foregroundDecoration,
  });
  final Widget? child;
  final EdgeInsetsGeometry? padding, margin;
  final double? width, height;
  final BoxConstraints? constraints;
  final AlignmentGeometry? alignment, transformAlignment;
  final VoidCallback? onTap, onLongPress;
  final BoxDecoration? nightDecoration;
  final Decoration? foregroundDecoration;
  final bool selected;
  final AppSurfaceRole role;
  final Clip clipBehavior;
  final Matrix4? transform;
  static BoxDecoration decoration(
    BuildContext context, {
    BoxDecoration? night,
    bool selected = false,
  }) => context.surfaces.decoration(
    AppSurfaceRole.card,
    night: night,
    selected: selected,
  );
  @override
  Widget build(BuildContext context) {
    final tokens = context.surfaces;
    final decoration = tokens.decoration(
      role,
      night: nightDecoration,
      selected: selected,
    );
    final tappable =
        onTap != null || onLongPress != null || role == AppSurfaceRole.pill;
    final minimum = tokens.outlined && tappable ? tokens.minTapTarget : 0.0;
    Widget content = Container(
      width: width?.clamp(minimum, double.infinity),
      height: height?.clamp(minimum, double.infinity),
      constraints: minimum > 0
          ? (constraints ?? const BoxConstraints()).copyWith(
              minWidth: (constraints?.minWidth ?? 0).clamp(
                minimum,
                double.infinity,
              ),
              minHeight: (constraints?.minHeight ?? 0).clamp(
                minimum,
                double.infinity,
              ),
              maxWidth: (constraints?.maxWidth ?? double.infinity).clamp(
                minimum,
                double.infinity,
              ),
              maxHeight: (constraints?.maxHeight ?? double.infinity).clamp(
                minimum,
                double.infinity,
              ),
            )
          : constraints,
      padding: padding,
      alignment: alignment,
      decoration: decoration,
      clipBehavior: clipBehavior,
      foregroundDecoration: foregroundDecoration,
      child: child,
    );
    if (onTap != null || onLongPress != null) {
      content = Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: decoration.borderRadius?.resolve(
            Directionality.of(context),
          ),
          onTap: onTap == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onTap!();
                },
          onLongPress: onLongPress,
          child: content,
        ),
      );
    }
    return Container(
      margin: margin,
      transform: transform,
      transformAlignment: transformAlignment,
      child: content,
    );
  }
}

class AppPill extends AppCard {
  static Widget choice({
    Key? key,
    required Widget label,
    required bool selected,
    ValueChanged<bool>? onSelected,
    Color? selectedColor,
    Color? backgroundColor,
    TextStyle? labelStyle,
    Color? checkmarkColor,
    BorderSide? side,
    OutlinedBorder? shape,
  }) => Builder(
    builder: (context) {
      if (!context.surfaces.outlined) {
        final effectiveLabelStyle = labelStyle ??
            (selected
                ? const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)
                : TextStyle(color: context.surfaces.ink));
        return ChoiceChip(
          key: key,
          label: label,
          selected: selected,
          onSelected: onSelected,
          selectedColor: selectedColor ?? context.accentPrimary,
          backgroundColor: backgroundColor,
          labelStyle: effectiveLabelStyle,
          side: side,
          shape: shape,
          checkmarkColor: checkmarkColor ?? Colors.white,
        );
      }
      return _dayChip(
        context,
        key: key,
        label: label,
        selected: selected,
        onTap: onSelected == null ? null : () => onSelected(!selected),
      );
    },
  );
  static Widget filter({
    Key? key,
    required Widget label,
    required bool selected,
    ValueChanged<bool>? onSelected,
    Color? selectedColor,
    Color? backgroundColor,
    TextStyle? labelStyle,
    Color? checkmarkColor,
    BorderSide? side,
    OutlinedBorder? shape,
  }) => Builder(
    builder: (context) {
      if (!context.surfaces.outlined) {
        final effectiveLabelStyle = labelStyle ??
            (selected
                ? const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)
                : TextStyle(color: context.surfaces.ink));
        return FilterChip(
          key: key,
          label: label,
          selected: selected,
          onSelected: onSelected,
          selectedColor: selectedColor ?? context.accentPrimary,
          backgroundColor: backgroundColor,
          labelStyle: effectiveLabelStyle,
          side: side,
          shape: shape,
          checkmarkColor: checkmarkColor ?? Colors.white,
        );
      }
      return _dayChip(
        context,
        key: key,
        label: label,
        selected: selected,
        onTap: onSelected == null ? null : () => onSelected(!selected),
      );
    },
  );
  static Widget action({
    Key? key,
    required Widget label,
    VoidCallback? onPressed,
    Widget? avatar,
    Color? backgroundColor,
    EdgeInsetsGeometry? padding,
    TextStyle? labelStyle,
    BorderSide? side,
    OutlinedBorder? shape,
  }) => Builder(
    builder: (context) {
      if (!context.surfaces.outlined) {
        return ActionChip(
          key: key,
          label: label,
          onPressed: onPressed,
          avatar: avatar,
          backgroundColor: backgroundColor,
          padding: padding,
          labelStyle: labelStyle,
          side: side,
          shape: shape,
        );
      }
      return _dayChip(
        context,
        key: key,
        label: label,
        onTap: onPressed,
        avatar: avatar,
      );
    },
  );
  static Widget _dayChip(
    BuildContext context, {
    Key? key,
    required Widget label,
    bool selected = false,
    VoidCallback? onTap,
    Widget? avatar,
  }) {
    final s = context.surfaces;
    final color = selected ? s.onAccent : s.ink;
    final textStyle = Theme.of(
      context,
    ).textTheme.labelSmall!.copyWith(color: color);
    final content = label is Text && label.data != null
        ? Text(
            label.data!,
            style: textStyle,
            textAlign: label.textAlign,
            semanticsLabel: label.semanticsLabel,
          )
        : label;
    return AppPill(
      key: key,
      selected: selected,
      onTap: onTap,
      padding: EdgeInsets.symmetric(horizontal: s.padding, vertical: s.spacing),
      child: DefaultTextStyle(
        style: textStyle,
        child: IconTheme(
          data: IconThemeData(color: color),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (avatar != null) ...[avatar, SizedBox(width: s.spacing)],
              Flexible(child: content),
            ],
          ),
        ),
      ),
    );
  }

  const AppPill({
    super.key,
    super.child,
    super.padding,
    super.margin,
    super.width,
    super.height,
    super.constraints,
    super.alignment,
    super.onTap,
    super.onLongPress,
    super.nightDecoration,
    super.selected,
    super.clipBehavior,
    super.transform,
    super.transformAlignment,
    super.foregroundDecoration,
  }) : super(role: AppSurfaceRole.pill);
  static BoxDecoration decoration(
    BuildContext context, {
    BoxDecoration? night,
    bool selected = false,
  }) => context.surfaces.decoration(
    AppSurfaceRole.pill,
    night: night,
    selected: selected,
  );
}

class AppTag extends AppCard {
  static Widget label({
    Key? key,
    required Widget label,
    Color? backgroundColor,
    TextStyle? labelStyle,
    BorderSide? side,
    VoidCallback? onDeleted,
    Widget? deleteIcon,
  }) => Builder(
    builder: (context) {
      if (!context.surfaces.outlined) {
        return Chip(
          key: key,
          label: label,
          backgroundColor: backgroundColor,
          labelStyle: labelStyle,
          side: side,
          onDeleted: onDeleted,
          deleteIcon: deleteIcon,
        );
      }
      final s = context.surfaces;
      final style = Theme.of(
        context,
      ).textTheme.labelSmall!.copyWith(color: s.accent);
      return AppTag(
        key: key,
        padding: EdgeInsets.symmetric(
          horizontal: s.spacing,
          vertical: s.spacing,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: label is Text && label.data != null
                  ? Text(label.data!, style: style)
                  : label,
            ),
            if (onDeleted != null)
              IconButton(
                onPressed: onDeleted,
                icon: deleteIcon ?? const Icon(Icons.close_rounded),
              ),
          ],
        ),
      );
    },
  );

  const AppTag({
    super.key,
    super.child,
    super.padding,
    super.margin,
    super.width,
    super.height,
    super.constraints,
    super.alignment,
    super.nightDecoration,
    super.clipBehavior,
    super.transform,
    super.transformAlignment,
    super.foregroundDecoration,
  }) : super(role: AppSurfaceRole.tag);
  static BoxDecoration decoration(
    BuildContext context, {
    BoxDecoration? night,
  }) => context.surfaces.decoration(AppSurfaceRole.tag, night: night);
}

class AppDivider extends StatelessWidget {
  const AppDivider({
    super.key,
    this.height,
    this.indent,
    this.endIndent,
    this.color,
    this.thickness,
  });
  final double? height, indent, endIndent, thickness;
  final Color? color;
  @override
  Widget build(BuildContext context) => Divider(
    height: height,
    indent: indent,
    endIndent: endIndent,
    color: context.surfaces.outlined ? context.surfaces.dividerColor : color,
    thickness: context.surfaces.outlined
        ? context.surfaces.dividerWidth
        : thickness,
  );
}

/// One header row in day mode; preserves the established glass header layout.
class AppHomeHeaderRow extends StatelessWidget {
  const AppHomeHeaderRow({
    super.key,
    required this.date,
    required this.actions,
  });
  final Widget date;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    if (!s.outlined) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          date,
          SizedBox(height: s.spacing),
          Wrap(
            key: const ValueKey('home_header_actions'),
            alignment: WrapAlignment.end,
            spacing: s.spacing,
            runSpacing: s.spacing,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: actions,
          ),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(flex: 2, child: date),
        SizedBox(width: s.spacing),
        Expanded(
          flex: 5,
          child: Row(
            key: const ValueKey('home_header_actions'),
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) SizedBox(width: s.spacing),
                if (i == actions.length - 1)
                  actions[i]
                else
                  Flexible(child: actions[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class AppDisplayName extends StatelessWidget {
  const AppDisplayName(this.name, {super.key, required this.style});
  final String name;
  final TextStyle style;
  @override
  Widget build(BuildContext context) => Text(
    name,
    style: style,
    softWrap: true,
    maxLines: context.surfaces.outlined ? null : 1,
    overflow: context.surfaces.outlined
        ? TextOverflow.visible
        : TextOverflow.ellipsis,
  );
}

/// Drops surface blur in day mode while retaining the exact night filter.
class AppSurfaceBlur extends StatelessWidget {
  const AppSurfaceBlur({super.key, required this.filter, required this.child});
  final ImageFilter filter;
  final Widget child;
  @override
  Widget build(BuildContext context) => context.surfaces.outlined
      ? child
      : BackdropFilter(filter: filter, child: child);
}

/// Custom night separators can retain their shape without a day gradient.
class AppSeparator extends StatelessWidget {
  const AppSeparator({super.key, required this.night});
  final Widget night;
  @override
  Widget build(BuildContext context) =>
      context.surfaces.outlined ? const AppDivider() : night;
}

class AppProgress extends AppCard {
  const AppProgress({
    super.key,
    super.child,
    super.padding,
    super.margin,
    super.width,
    super.height,
    super.constraints,
    super.alignment,
    super.nightDecoration,
    bool filled = false,
  }) : super(
         role: filled
             ? AppSurfaceRole.progressFill
             : AppSurfaceRole.progressTrack,
       );
}

class AppIndicator extends AppCard {
  const AppIndicator({
    super.key,
    super.selected,
    super.child,
    super.padding,
    super.margin,
    super.width,
    super.height,
    super.constraints,
    super.alignment,
    super.nightDecoration,
  }) : super(role: AppSurfaceRole.indicator);
}

/// Day metadata headers can wrap while the glass layout remains unchanged.
class AppResponsiveRow extends StatelessWidget {
  const AppResponsiveRow({
    super.key,
    required this.children,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.crossAxisAlignment = CrossAxisAlignment.center,
  });
  final List<Widget> children;
  final MainAxisAlignment mainAxisAlignment;
  final CrossAxisAlignment crossAxisAlignment;
  @override
  Widget build(BuildContext context) => context.surfaces.outlined
      ? Wrap(
          spacing: context.surfaces.spacing,
          runSpacing: context.surfaces.spacing,
          alignment: mainAxisAlignment == MainAxisAlignment.spaceBetween
              ? WrapAlignment.spaceBetween
              : WrapAlignment.start,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: children,
        )
      : Row(
          mainAxisAlignment: mainAxisAlignment,
          crossAxisAlignment: crossAxisAlignment,
          children: children,
        );
}

/// Accessible day hit areas; callbacks and night hit geometry stay unchanged.
class AppTapArea extends StatelessWidget {
  const AppTapArea({
    super.key,
    this.child,
    this.onTap,
    this.onLongPress,
    this.borderRadius,
    this.customBorder,
    this.splashColor,
    this.highlightColor,
  });
  final Widget? child;
  final VoidCallback? onTap, onLongPress;
  final BorderRadius? borderRadius;
  final ShapeBorder? customBorder;
  final Color? splashColor, highlightColor;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    onLongPress: onLongPress,
    borderRadius: borderRadius,
    customBorder: customBorder,
    splashColor: splashColor,
    highlightColor: highlightColor,
    child: context.surfaces.outlined && (onTap != null || onLongPress != null)
        ? ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: context.surfaces.minTapTarget,
              minHeight: context.surfaces.minTapTarget,
            ),
            child: Center(widthFactor: 1, heightFactor: 1, child: child),
          )
        : child,
  );
}

class AppGestureTap extends StatelessWidget {
  const AppGestureTap({
    super.key,
    this.child,
    this.onTap,
    this.onTapDown,
    this.onTapUp,
    this.onTapCancel,
    this.behavior,
  });
  final Widget? child;
  final VoidCallback? onTap, onTapCancel;
  final void Function(TapDownDetails)? onTapDown;
  final void Function(TapUpDetails)? onTapUp;
  final HitTestBehavior? behavior;
  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: onTap,
    onTapDown: onTapDown,
    onTapUp: onTapUp,
    onTapCancel: onTapCancel,
    behavior: behavior,
    child: context.surfaces.outlined && onTap != null
        ? ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: context.surfaces.minTapTarget,
              minHeight: context.surfaces.minTapTarget,
            ),
            child: Center(widthFactor: 1, heightFactor: 1, child: child),
          )
        : child,
  );
}

class AppHeatmapViewport extends StatelessWidget {
  const AppHeatmapViewport({
    super.key,
    required this.columns,
    required this.child,
  });
  final int columns;
  final Widget child;
  @override
  Widget build(BuildContext context) => context.surfaces.outlined
      ? SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SizedBox(
            width:
                columns *
                (context.surfaces.minTapTarget + context.surfaces.spacing),
            child: child,
          ),
        )
      : child;
}
