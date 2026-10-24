import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
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
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppCard(
                  constraints: const BoxConstraints(minHeight: 48),
                  nightDecoration: BoxDecoration(
                    color: context.isDark
                        ? context.bgSurfaceElevated
                        : (g.merlot
                              ? MerlotPalette.surface
                              : (g.frozen
                                    ? const Color(0xFFFFFFFF)
                                    : const Color(0xFFFFFFFF))),
                    borderRadius: AppGeometry.roundedr24,
                    border: Border.all(
                      color: _focus.hasFocus
                          ? g.clay
                          : g.ink.withValues(alpha: context.isDark ? .48 : .42),
                      width: _focus.hasFocus ? 2.6 : 2.0,
                    ),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: InlineListAddButton(
                          controller: widget.controller,
                          focusNode: _focus,
                          enabled: !widget.busy,
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          key: _fieldKey,
                          controller: widget.controller,
                          focusNode: _focus,
                          minLines: 1,
                          maxLines: 4,
                          keyboardType: TextInputType.multiline,
                          textInputAction: TextInputAction.newline,
                          textCapitalization: TextCapitalization.sentences,
                          cursorColor: context.isDark && g.merlot
                              ? g.inkSecondary
                              : g.clay,
                          style: AscentTextStyles.bodyMedium.copyWith(
                            color: g.ink,
                          ),
                          decoration: InputDecoration(
                            hintText: widget.hint,
                            hintStyle: AscentTextStyles.bodyMedium.copyWith(
                              color: g.inkMuted,
                            ),
                            contentPadding: const EdgeInsets.only(
                              right: AppSpace.s16,
                              top: AppSpace.s14,
                              bottom: AppSpace.s14,
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
                    ],
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
                  style: context.surfaces.buttonStyle(
                    IconButton.styleFrom(
                      backgroundColor: g.clay,
                      foregroundColor: AppPalette.white,
                      disabledBackgroundColor: g.fill,
                      disabledForegroundColor: g.inkMuted,
                    ),
                    filled: true,
                    icon: true,
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
