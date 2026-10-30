import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import 'ascent_snack_bar.dart';
import 'ascent_switch.dart';

/// Shared Apple-inspired settings switch row as specified in Section 5 (C02).
///
/// Features:
/// - Explicit CupertinoSwitch track & thumb colors on Android & iOS.
/// - Minimum height: 56px without helper, 72px with helper.
/// - Padding: horizontal 16px, vertical 12px; gap before switch: 12px.
/// - Single unified semantics node announcing label, helper, enabled state, and toggle value.
/// - Tapping any part of an enabled row or the switch changes it exactly once.
/// - Spinner in switch slot during asynchronous operations with rollback on failure.
/// - Emits one selectionClick haptic only on successful change.
class AscentSwitchRow extends StatefulWidget {
  const AscentSwitchRow({
    super.key,
    required this.title,
    this.helper,
    required this.value,
    this.onChanged,
    this.enabled = true,
    this.busy = false,
  });

  final String title;
  final String? helper;
  final bool value;
  final FutureOr<void> Function(bool)? onChanged;
  final bool enabled;
  final bool busy;

  @override
  State<AscentSwitchRow> createState() => _AscentSwitchRowState();
}

class _AscentSwitchRowState extends State<AscentSwitchRow> {
  bool _internalBusy = false;

  bool get _isEffectivelyBusy => widget.busy || _internalBusy;
  bool get _isInteractive =>
      widget.enabled && !_isEffectivelyBusy && widget.onChanged != null;

  Future<void> _handleToggle() async {
    if (!_isInteractive) return;

    final newValue = !widget.value;
    final callback = widget.onChanged;
    if (callback == null) return;

    try {
      final result = callback(newValue);
      if (result is Future) {
        setState(() => _internalBusy = true);
        await result;
        if (mounted) {
          setState(() => _internalBusy = false);
          HapticFeedback.selectionClick();
        }
      } else {
        HapticFeedback.selectionClick();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _internalBusy = false);
        AscentSnackBar.show(
          context,
          message: 'Could not update setting. Try again.',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final hasHelper = widget.helper != null && widget.helper!.trim().isNotEmpty;
    final minHeight = hasHelper
        ? AscentDimensions.settingsRowWithHelperHeight
        : AscentDimensions.settingsRowHeight;

    final primaryTextColor = widget.enabled ? g.ink : g.disabledFg;
    final helperTextColor = widget.enabled ? g.inkSecondary : g.disabledFg;

    final semanticsValue = widget.value ? 'on' : 'off';

    return MergeSemantics(
      child: Semantics(
        toggled: widget.value,
        enabled: widget.enabled,
        value: semanticsValue,
        label: hasHelper ? '${widget.title}, ${widget.helper}' : widget.title,
        button: true,
        child: InkWell(
          onTap: _isInteractive ? _handleToggle : null,
          child: Container(
            constraints: BoxConstraints(minHeight: minHeight),
            padding: const EdgeInsets.symmetric(
              horizontal: AscentDimensions.spaceLg,
              vertical: AscentDimensions.spaceMd,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.title,
                        style: AscentTextStyles.listRowTitle.copyWith(
                          color: primaryTextColor,
                        ),
                      ),
                      if (hasHelper) ...[
                        const SizedBox(height: AscentDimensions.spaceXs),
                        Text(
                          widget.helper!,
                          style: AscentTextStyles.supportingText.copyWith(
                            color: helperTextColor,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: AscentDimensions.spaceMd),
                SizedBox(
                  width: 51,
                  height: 31,
                  child: _isEffectivelyBusy
                      ? Center(
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: g.actionInk,
                            ),
                          ),
                        )
                      : ExcludeSemantics(
                          child: AscentSwitch(
                            value: widget.value,
                            onChanged: _isInteractive
                                ? (_) => _handleToggle()
                                : null,
                          ),
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
