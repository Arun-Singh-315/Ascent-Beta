import 'package:flutter/material.dart';

import '../../app/theme/glass_theme.dart';
import 'ascent_composer.dart';

/// Quick add bar (Things, Home capture, search). A thin layer over
/// [AscentComposer] so every capture field looks and behaves the same.
class AppInputBar extends StatelessWidget {
  const AppInputBar({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSubmit,
    this.textFieldKey,
    this.submitTooltip,
    this.leadingIcon,
    this.leadingTooltip,
    this.onLeadingTap,
    this.extraAction,
    this.focusNode,
    this.onChanged,
    this.checklist = false,
    this.singleLine = false,
    this.onMic,
    this.listening = false,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmit;
  final Key? textFieldKey;
  final String? submitTooltip;

  /// Optional leading control (e.g. search, add next item).
  final IconData? leadingIcon;
  final String? leadingTooltip;
  final VoidCallback? onLeadingTap;

  /// Extra control before Send (e.g. repeat toggle for to-dos).
  final Widget? extraAction;
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  /// Show the checklist button (thoughts) instead of [leadingIcon].
  final bool checklist;

  /// Enter submits (search fields) instead of starting a new line.
  final bool singleLine;
  final VoidCallback? onMic;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return AscentComposer(
      controller: controller,
      focusNode: focusNode,
      hint: hint,
      onSend: (_) => onSubmit(),
      fieldKey: textFieldKey,
      sendTooltip: submitTooltip ?? 'Add',
      onChanged: onChanged,
      submitOnEnter: singleLine,
      checklist: checklist,
      onMic: onMic,
      listening: listening,
      trailing: extraAction,
      leading: leadingIcon == null || checklist
          ? null
          : SizedBox(
              width: 48,
              height: 48,
              child: IconButton(
                tooltip: leadingTooltip ?? 'Add next item',
                onPressed: onLeadingTap ?? focusNode?.requestFocus,
                icon: Icon(leadingIcon, size: 24, color: g.inkSecondary),
              ),
            ),
    );
  }
}
