import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

/// The canonical single-enclosure text input widget across Ascent.
///
/// Follows the Global Input Rule:
/// - ONE input = ONE container.
/// - Single [TextField] (or [TextFormField]) with [InputDecoration].
/// - Filled with `surfaceAlt` (`#F4EEE6` in Sand & Dusk).
/// - 1px warm hairline border (`#E9E1D5`).
/// - 14px corner radius ([Rd.field]).
/// - [prefixIcon] and [suffixIcon] rendered inside the decoration, NOT outside.
/// - NEVER wrap this in another bordered or filled container.
class AppTextField extends StatelessWidget {
  const AppTextField({
    super.key,
    this.controller,
    this.initialValue,
    this.focusNode,
    this.hintText,
    this.labelText,
    this.prefixIcon,
    this.suffixIcon,
    this.keyboardType,
    this.textInputAction,
    this.textCapitalization = TextCapitalization.none,
    this.obscureText = false,
    this.enabled = true,
    this.autofocus = false,
    this.maxLines = 1,
    this.minLines,
    this.onChanged,
    this.onSubmitted,
    this.validator,
    this.inputFormatters,
    this.fillColor,
    this.contentPadding,
    this.style,
    this.hintStyle,
  });

  final TextEditingController? controller;
  final String? initialValue;
  final FocusNode? focusNode;
  final String? hintText;
  final String? labelText;
  final Widget? prefixIcon;
  final Widget? suffixIcon;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final TextCapitalization textCapitalization;
  final bool obscureText;
  final bool enabled;
  final bool autofocus;
  final int? maxLines;
  final int? minLines;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FormFieldValidator<String>? validator;
  final List<TextInputFormatter>? inputFormatters;
  final Color? fillColor;
  final EdgeInsetsGeometry? contentPadding;
  final TextStyle? style;
  final TextStyle? hintStyle;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final colorScheme = Theme.of(context).colorScheme;

    final resolvedFill = fillColor ?? c.surfaceAlt;
    final resolvedBorderColor = c.border;
    final resolvedFocusColor = colorScheme.secondary;
    final resolvedErrorColor = colorScheme.error;

    final defaultBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Rd.field),
      borderSide: BorderSide(
        color: resolvedBorderColor,
        width: 1.0,
      ),
    );

    final focusedBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Rd.field),
      borderSide: BorderSide(
        color: resolvedFocusColor,
        width: 1.5,
      ),
    );

    final errorBorder = OutlineInputBorder(
      borderRadius: BorderRadius.circular(Rd.field),
      borderSide: BorderSide(
        color: resolvedErrorColor,
        width: 1.0,
      ),
    );

    final effectiveTextStyle = style ??
        TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
          color: c.textPrimary,
          letterSpacing: -0.1,
        );

    final effectiveHintStyle = hintStyle ??
        TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w400,
          color: c.textTertiary,
          letterSpacing: -0.1,
        );

    final decoration = InputDecoration(
      isDense: true,
      filled: true,
      fillColor: resolvedFill,
      hintText: hintText,
      hintStyle: effectiveHintStyle,
      labelText: labelText,
      labelStyle: effectiveHintStyle,
      prefixIcon: prefixIcon,
      suffixIcon: suffixIcon,
      contentPadding: contentPadding ??
          EdgeInsets.symmetric(
            horizontal: prefixIcon != null ? 12 : 16,
            vertical: 14,
          ),
      border: defaultBorder,
      enabledBorder: defaultBorder,
      focusedBorder: focusedBorder,
      errorBorder: errorBorder,
      focusedErrorBorder: errorBorder.copyWith(
        borderSide: BorderSide(color: resolvedErrorColor, width: 1.5),
      ),
      disabledBorder: defaultBorder.copyWith(
        borderSide: BorderSide(
          color: resolvedBorderColor.withValues(alpha: 0.5),
          width: 1.0,
        ),
      ),
    );

    if (validator != null) {
      return TextFormField(
        controller: controller,
        initialValue: initialValue,
        focusNode: focusNode,
        keyboardType: keyboardType,
        textInputAction: textInputAction,
        textCapitalization: textCapitalization,
        obscureText: obscureText,
        enabled: enabled,
        autofocus: autofocus,
        maxLines: maxLines,
        minLines: minLines,
        onChanged: onChanged,
        onFieldSubmitted: onSubmitted,
        validator: validator,
        inputFormatters: inputFormatters,
        style: effectiveTextStyle,
        decoration: decoration,
      );
    }

    return TextField(
      controller: controller,
      focusNode: focusNode,
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      textCapitalization: textCapitalization,
      obscureText: obscureText,
      enabled: enabled,
      autofocus: autofocus,
      maxLines: maxLines,
      minLines: minLines,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      inputFormatters: inputFormatters,
      style: effectiveTextStyle,
      decoration: decoration,
    );
  }
}
