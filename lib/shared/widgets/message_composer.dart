import 'package:flutter/material.dart';

import 'ascent_composer.dart';

/// Thought and message capture: [AscentComposer] with the checklist button,
/// so a thought only gets tick circles where the user adds them.
class MessageComposer extends StatelessWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSend,
    this.busy = false,
    this.focusNode,
    this.autofocus = false,
    this.quiet = false,
    this.maxLines = 6,
    this.minHeight,
    this.onMic,
    this.listening = false,
    this.accessory,
    this.checklist = true,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSend;
  final bool busy;
  final bool autofocus;

  /// Kept for callers; the composer has one look now.
  final bool quiet;
  final int maxLines;

  /// Kept for callers; the composer is always at least 56 pt tall.
  final double? minHeight;
  final FocusNode? focusNode;
  final VoidCallback? onMic;
  final bool listening;
  final Widget? accessory;
  final bool checklist;

  @override
  Widget build(BuildContext context) => AscentComposer(
    controller: controller,
    focusNode: focusNode,
    hint: hint,
    onSend: onSend,
    busy: busy,
    autofocus: autofocus,
    maxLines: maxLines,
    checklist: checklist,
    onMic: onMic,
    listening: listening,
    accessory: accessory,
    sendKey: const ValueKey('message_composer_send'),
    micKey: const ValueKey('message_composer_mic'),
    sendTooltip: 'Send message',
  );
}
