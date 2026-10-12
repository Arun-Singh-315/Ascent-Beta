import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSend,
    this.busy = false,
    this.focusNode,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSend;
  final bool busy;
  final FocusNode? focusNode;
  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  @override
  void dispose() {
    if (widget.focusNode == null) _focus.dispose();
    super.dispose();
  }

  void _send() {
    if (!widget.busy && widget.controller.text.trim().isNotEmpty) {
      widget.onSend(widget.controller.text);
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _send,
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.controller, _focus]),
        builder: (context, _) {
          final canSend =
              !widget.busy && widget.controller.text.trim().isNotEmpty;
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  decoration: BoxDecoration(
                    color: g.fill,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: _focus.hasFocus ? g.clay : g.edge,
                      width: _focus.hasFocus ? 1.5 : 1,
                    ),
                  ),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: _focus,
                    minLines: 1,
                    maxLines: 4,
                    keyboardType: TextInputType.multiline,
                    textInputAction: TextInputAction.newline,
                    textCapitalization: TextCapitalization.sentences,
                    cursorColor: g.clay,
                    style: AscentTextStyles.bodyMedium.copyWith(color: g.ink),
                    decoration: InputDecoration(
                      hintText: widget.hint,
                      hintStyle: AscentTextStyles.bodyMedium.copyWith(
                        color: g.inkMuted,
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      isDense: true,
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 48,
                height: 48,
                child: IconButton.filled(
                  key: const ValueKey('message_composer_send'),
                  tooltip: 'Send message',
                  onPressed: canSend ? _send : null,
                  style: IconButton.styleFrom(
                    backgroundColor: g.clay,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: g.fill,
                    disabledForegroundColor: g.inkMuted,
                  ),
                  icon: widget.busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 20),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
