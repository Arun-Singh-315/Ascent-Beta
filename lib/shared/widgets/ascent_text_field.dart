import 'package:flutter/material.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';

/// Style variants for [AscentTextField].
enum AscentTextFieldVariant {
  /// Standard rectangular form input with rounded corners (12px).
  standard,

  /// Capsule / pill shaped input with rounded ends (999px). Great for chat and search bars.
  pill,

  /// Minimal borderless input for inline editing.
  borderless,
}

/// Standardized, theme-aware text field for the Ascent design system.
///
/// Automatically handles light and dark mode colors, focus ring highlights,
/// clear helper/error typography, and unified padding.
class AscentTextField extends StatelessWidget {
  const AscentTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.helperText,
    this.errorText,
    this.prefixIcon,
    this.suffixIcon,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.sentences,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.variant = AscentTextFieldVariant.standard,
    this.fillColor,
  });

  /// Search pill convenience constructor.
  const AscentTextField.search({
    super.key,
    this.controller,
    this.focusNode,
    this.hintText = 'Search...',
    this.labelText,
    this.helperText,
    this.errorText,
    this.prefixIcon = const Icon(Icons.search_rounded, size: 20),
    this.suffixIcon,
    this.obscureText = false,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.keyboardType,
    this.textInputAction = TextInputAction.search,
    this.textCapitalization = TextCapitalization.none,
    this.minLines,
    this.maxLines = 1,
    this.onChanged,
    this.onSubmitted,
    this.onTap,
    this.validator,
    this.fillColor,
  }) : variant = AscentTextFieldVariant.pill;

  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final String? helperText;
  final String? errorText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final bool obscureText;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final int? minLines;
  final int? maxLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onTap;
  final FormFieldValidator<String>? validator;
  final AscentTextFieldVariant variant;
  final Color? fillColor;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = context.isDark;

    final effectiveRadius = variant == AscentTextFieldVariant.pill
        ? BorderRadius.circular(AscentDimensions.radiusFull)
        : BorderRadius.circular(AscentDimensions.radiusMd);

    final effectiveFillColor = fillColor ??
        (variant == AscentTextFieldVariant.borderless
            ? Colors.transparent
            : (isDark ? context.bgSurface : context.bgSurfaceElevated));

    final baseBorder = variant == AscentTextFieldVariant.borderless
        ? InputBorder.none
        : OutlineInputBorder(
            borderRadius: effectiveRadius,
            borderSide: BorderSide(
              color: g.edge.withValues(alpha: isDark ? 0.35 : 0.65),
              width: 1.0,
            ),
          );

    final focusedBorder = variant == AscentTextFieldVariant.borderless
        ? InputBorder.none
        : OutlineInputBorder(
            borderRadius: effectiveRadius,
            borderSide: BorderSide(
              color: context.accentPrimary,
              width: 1.4,
            ),
          );

    final errorBorder = variant == AscentTextFieldVariant.borderless
        ? InputBorder.none
        : OutlineInputBorder(
            borderRadius: effectiveRadius,
            borderSide: BorderSide(
              color: context.stateDanger,
              width: 1.2,
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (labelText != null && labelText!.isNotEmpty) ...[
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 6),
            child: Text(
              labelText!,
              style: AscentTextStyles.labelMedium.copyWith(
                color: context.textPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
        TextFormField(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
          readOnly: readOnly,
          autofocus: autofocus,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          textCapitalization: textCapitalization,
          minLines: minLines,
          maxLines: maxLines,
          onChanged: onChanged,
          onFieldSubmitted: onSubmitted,
          onTap: onTap,
          validator: validator,
          cursorColor: context.accentPrimary,
          style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
          decoration: InputDecoration(
            filled: variant != AscentTextFieldVariant.borderless,
            fillColor: effectiveFillColor,
            hintText: hintText,
            hintStyle: AscentTextStyles.bodyMedium.copyWith(
              color: context.textMuted.withValues(alpha: 0.7),
            ),
            helperText: helperText,
            helperStyle: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
            errorText: errorText,
            errorStyle: AscentTextStyles.bodySmall.copyWith(color: context.stateDanger),
            prefixIcon: prefixIcon,
            suffixIcon: suffixIcon,
            contentPadding: EdgeInsets.symmetric(
              horizontal: variant == AscentTextFieldVariant.pill ? 18 : 14,
              vertical: maxLines != null && maxLines! > 1 ? 12 : 11,
            ),
            border: baseBorder,
            enabledBorder: baseBorder,
            focusedBorder: focusedBorder,
            errorBorder: errorBorder,
            focusedErrorBorder: errorBorder,
            isDense: true,
          ),
        ),
      ],
    );
  }
}
