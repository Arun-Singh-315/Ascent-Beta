import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/color_tokens.dart';
import '../../app/theme/merlot_palette.dart';
import '../../app/theme/text_styles.dart';
import 'note_list_button.dart';

class MessageComposer extends StatefulWidget {
  const MessageComposer({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSend,
    this.busy = false,
    this.focusNode,
    this.autofocus = false,
    this.quiet = false,
  });
  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSend;
  final bool busy;
  final bool autofocus;
  final bool quiet;
  final FocusNode? focusNode;
  @override
  State<MessageComposer> createState() => _MessageComposerState();
}

class _MessageComposerState extends State<MessageComposer> {
  final _fieldKey = GlobalKey();
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_revealCaret);
  }

  @override
  void didUpdateWidget(covariant MessageComposer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_revealCaret);
      widget.controller.addListener(_revealCaret);
    }
  }

  void _revealCaret() =>
      NoteListButton.revealCaret(_fieldKey, widget.controller);

  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  @override
  void dispose() {
    widget.controller.removeListener(_revealCaret);
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
          final isDark = context.isDark;
          final hasFocus = _focus.hasFocus;

          final containerBg = isDark
              ? (g.merlot ? const Color(0xFF1E171E) : const Color(0xFF181C25))
              : (g.merlot ? MerlotPalette.surface : const Color(0xFFFAFCFF));

          final borderColor = isDark
              ? (hasFocus
                    ? const Color(0xFF64B5F6)
                    : const Color(0xFF64B5F6).withValues(alpha: 0.28))
              : (hasFocus
                    ? const Color(0xFF2196F3)
                    : const Color(0xFF90CAF9).withValues(alpha: 0.55));

          return Container(
            decoration: BoxDecoration(
              color: containerBg,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: borderColor,
                width: hasFocus ? 1.5 : 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFF1E88E5,
                  ).withValues(alpha: isDark ? 0.12 : 0.07),
                  blurRadius: 18,
                  offset: const Offset(0, 4),
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Padding(
                  padding: const EdgeInsets.only(bottom: 2),
                  child: InlineListAddButton(
                    controller: widget.controller,
                    focusNode: _focus,
                    enabled: !widget.busy,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    child: TextField(
                      key: _fieldKey,
                      autofocus: widget.autofocus,
                      controller: widget.controller,
                      focusNode: _focus,
                      minLines: 1,
                      maxLines: 5,
                      keyboardType: TextInputType.multiline,
                      textInputAction: TextInputAction.newline,
                      textCapitalization: TextCapitalization.sentences,
                      cursorColor: isDark && g.merlot ? g.inkSecondary : g.clay,
                      style: AscentTextStyles.bodyLarge.copyWith(
                        color: g.ink,
                        height: 1.35,
                      ),
                      decoration: InputDecoration(
                        hintText: widget.hint,
                        hintStyle: AscentTextStyles.bodyMedium.copyWith(
                          color: g.inkMuted,
                        ),
                        isDense: true,
                        filled: false,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: AppSpace.s4,
                        ),
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
                SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    key: const ValueKey('message_composer_send'),
                    tooltip: 'Send message',
                    onPressed: canSend ? _send : null,
                    style: IconButton.styleFrom(
                      backgroundColor: canSend ? g.clay : Colors.transparent,
                      foregroundColor: canSend
                          ? AppPalette.white
                          : Colors.transparent,
                      shape: const CircleBorder(),
                      padding: EdgeInsets.zero,
                    ),
                    icon: widget.busy
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : AnimatedSwitcher(
                            duration: const Duration(milliseconds: 180),
                            transitionBuilder: (child, anim) =>
                                ScaleTransition(scale: anim, child: child),
                            child: canSend
                                ? const Icon(
                                    Icons.arrow_upward_rounded,
                                    key: ValueKey('send_icon'),
                                    size: 20,
                                    color: AppPalette.white,
                                  )
                                : const SizedBox.shrink(
                                    key: ValueKey('blank_icon'),
                                  ),
                          ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
