import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../utils/smart_list_input_formatter.dart';
import 'glass_chrome.dart';
import 'note_list_button.dart';

/// The one capture and chat input (CLAUDE.md §2.3, §6.5).
///
/// Tap, write, go: a single enclosure at least 56 pt tall with 17 pt text,
/// an example placeholder, a 1 px action border on focus, a mic while empty
/// and a send button that springs in once there is text. Everything else is
/// optional:
///
/// * [checklist] shows a checklist button that starts a "☐ " line, so a
///   thought only gets tick circles where the user asks for them.
/// * [onMic] shows a mic in place of Send while the field is empty.
/// * [accessory] sits above the field (parsed chips, a paste chip, …).
/// * [submitOnEnter] sends on Enter for single-line quick add; otherwise
///   Enter makes a new line and Ctrl/Cmd+Enter sends.
class AscentComposer extends StatefulWidget {
  const AscentComposer({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSend,
    this.focusNode,
    this.busy = false,
    this.autofocus = false,
    this.maxLines = 6,
    this.minLines = 1,
    this.minHeight = 56,
    this.checklist = false,
    this.onMic,
    this.listening = false,
    this.accessory,
    this.trailing,
    this.leading,
    this.submitOnEnter = false,
    this.onChanged,
    this.fieldKey,
    this.sendKey = const ValueKey('composer_send'),
    this.micKey = const ValueKey('composer_mic'),
    this.sendTooltip = 'Send',
    this.inputFormatters,
    this.glass = false,
  });

  final TextEditingController controller;

  /// An example, not a label: "e.g. Call mom at 6".
  final String hint;
  /// Lines the field shows before typing (a taller, Gemini-like box).
  final int minLines;

  /// Minimum height of the composer pill.
  final double minHeight;
  final ValueChanged<String> onSend;
  final FocusNode? focusNode;
  final bool busy;
  final bool autofocus;
  final int maxLines;
  final bool checklist;
  final VoidCallback? onMic;
  final bool listening;
  final Widget? accessory;

  /// Extra control before Send (e.g. a repeat toggle).
  final Widget? trailing;

  /// Replaces the checklist button (e.g. an attach button).
  final Widget? leading;
  final bool submitOnEnter;
  final ValueChanged<String>? onChanged;
  final Key? fieldKey;
  final Key sendKey;
  final Key micKey;
  final String sendTooltip;
  final List<TextInputFormatter>? inputFormatters;

  /// Docked over scrolling content: render the field as glass chrome.
  final bool glass;

  /// Starts a checklist line ("☐ ") at the caret, or continues the list.
  static void insertChecklistItem(TextEditingController controller) {
    final text = controller.text;
    final sel = controller.selection;
    final start = sel.isValid ? sel.start.clamp(0, text.length) : text.length;
    final end = sel.isValid ? sel.end.clamp(0, text.length) : text.length;
    final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
    final lineEnd = text.indexOf('\n', end) < 0
        ? text.length
        : text.indexOf('\n', end);
    final line = text.substring(lineStart, lineEnd);
    // Already on an empty checklist line: nothing to add.
    if (start == end && RegExp(r'^\s*[☐☑]\s*$').hasMatch(line)) {
      controller.selection = TextSelection.collapsed(offset: lineEnd);
      return;
    }
    // A plain line becomes a checklist line in place.
    if (start == end &&
        line.trim().isNotEmpty &&
        !RegExp(r'^\s*[☐☑•→\-*]').hasMatch(line)) {
      controller.value = TextEditingValue(
        text: text.replaceRange(lineStart, lineStart, '☐ '),
        selection: TextSelection.collapsed(offset: start + 2),
      );
      return;
    }
    final before = text.substring(0, start);
    final sep = before.isEmpty || before.endsWith('\n') ? '' : '\n';
    final marker = '$sep☐ ';
    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, marker),
      selection: TextSelection.collapsed(offset: start + marker.length),
    );
  }

  @override
  State<AscentComposer> createState() => _AscentComposerState();
}

class _AscentComposerState extends State<AscentComposer> {
  final _fieldKey = GlobalKey();
  FocusNode? _ownFocus;
  FocusNode get _focus => widget.focusNode ?? (_ownFocus ??= FocusNode());

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_revealCaret);
  }

  @override
  void didUpdateWidget(covariant AscentComposer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_revealCaret);
      widget.controller.addListener(_revealCaret);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_revealCaret);
    _ownFocus?.dispose();
    super.dispose();
  }

  void _revealCaret() =>
      NoteListButton.revealCaret(_fieldKey, widget.controller);

  bool get _canSend => !widget.busy && widget.controller.text.trim().isNotEmpty;

  void _send() {
    if (!_canSend) return;
    HapticFeedback.lightImpact();
    widget.onSend(widget.controller.text);
  }

  Widget _maybeGlass(Widget field) => widget.glass
      ? GlassChrome(borderRadius: BorderRadius.circular(24), child: field)
      : field;

  void _checklist() {
    HapticFeedback.selectionClick();
    AscentComposer.insertChecklistItem(widget.controller);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): _send,
        const SingleActivator(LogicalKeyboardKey.enter, meta: true): _send,
      },
      child: AnimatedBuilder(
        animation: Listenable.merge([widget.controller, _focus]),
        builder: (context, _) {
          final focused = _focus.hasFocus;
          final showMic =
              widget.onMic != null &&
              !widget.busy &&
              (widget.listening || widget.controller.text.trim().isEmpty);
          return Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.accessory != null) ...[
                widget.accessory!,
                const SizedBox(height: AppSpace.s8),
              ],
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  if (!_focus.hasFocus) _focus.requestFocus();
                },
                child: _maybeGlass(
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    constraints: BoxConstraints(minHeight: widget.minHeight),
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpace.s4,
                      vertical: AppSpace.s4,
                    ),
                    decoration: BoxDecoration(
                      color: widget.glass ? Colors.transparent : g.recessed,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: focused
                            ? g.actionInk
                            : (widget.glass ? Colors.transparent : g.line),
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (widget.leading != null)
                          widget.leading!
                        else if (widget.checklist)
                          _RoundIcon(
                            key: const ValueKey('composer_checklist'),
                            icon: Icons.checklist_rounded,
                            tooltip: 'Add a checklist item',
                            color: g.inkSecondary,
                            onPressed: widget.busy ? null : _checklist,
                          )
                        else
                          const SizedBox(width: AppSpace.s12),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppSpace.s12,
                            ),
                            child: TextField(
                              key: widget.fieldKey ?? _fieldKey,
                              controller: widget.controller,
                              focusNode: _focus,
                              autofocus: widget.autofocus,
                              minLines: widget.submitOnEnter
                                  ? 1
                                  : widget.minLines,
                              maxLines: widget.submitOnEnter
                                  ? 1
                                  : widget.maxLines,
                              keyboardType: widget.submitOnEnter
                                  ? TextInputType.text
                                  : TextInputType.multiline,
                              textInputAction: widget.submitOnEnter
                                  ? TextInputAction.done
                                  : TextInputAction.newline,
                              textCapitalization: TextCapitalization.sentences,
                              inputFormatters:
                                  widget.inputFormatters ??
                                  const [SmartListInputFormatter()],
                              onChanged: widget.onChanged,
                              onSubmitted: widget.submitOnEnter
                                  ? (_) => _send()
                                  : null,
                              cursorColor: g.actionInk,
                              style: AscentTextStyles.interfaceBody.copyWith(
                                color: g.ink,
                                height: 1.3,
                              ),
                              decoration: InputDecoration(
                                hintText: widget.hint,
                                hintStyle: AscentTextStyles.interfaceBody
                                    .copyWith(color: g.inkMuted),
                                hintMaxLines: 1,
                                isDense: true,
                                filled: false,
                                contentPadding: EdgeInsets.zero,
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
                        ?widget.trailing,
                        if (showMic)
                          _RoundIcon(
                            key: widget.micKey,
                            icon: widget.listening
                                ? Icons.stop_rounded
                                : Icons.mic_none_rounded,
                            tooltip: widget.listening
                                ? 'Stop dictation'
                                : 'Dictate',
                            color: widget.listening
                                ? g.tonalFg
                                : g.inkSecondary,
                            fill: widget.listening ? g.tonalBg : null,
                            onPressed: () {
                              HapticFeedback.selectionClick();
                              widget.onMic!();
                            },
                          )
                        else
                          _SendButton(
                            key: widget.sendKey,
                            tooltip: widget.sendTooltip,
                            visible: _canSend || widget.busy,
                            busy: widget.busy,
                            onPressed: _canSend ? _send : null,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _RoundIcon extends StatelessWidget {
  const _RoundIcon({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onPressed,
    this.fill,
  });
  final IconData icon;
  final String tooltip;
  final Color color;
  final Color? fill;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 48,
    height: 48,
    child: IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: fill ?? Colors.transparent,
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
      ),
      icon: Icon(icon, size: 24, color: color),
    ),
  );
}

/// Filled action circle that springs in when there is something to send.
class _SendButton extends StatelessWidget {
  const _SendButton({
    super.key,
    required this.tooltip,
    required this.visible,
    required this.busy,
    required this.onPressed,
  });
  final String tooltip;
  final bool visible;
  final bool busy;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final button = IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        backgroundColor: g.primaryButtonBg,
        disabledBackgroundColor: g.primaryButtonBg.withValues(alpha: .4),
        shape: const CircleBorder(),
        padding: EdgeInsets.zero,
      ),
      icon: busy
          ? CupertinoActivityIndicator(radius: 9, color: g.primaryButtonFg)
          : Icon(
              Icons.arrow_upward_rounded,
              size: 22,
              color: g.primaryButtonFg,
            ),
    );
    return SizedBox(
      width: 48,
      height: 48,
      child: !visible
          ? const SizedBox.shrink()
          // Springs in from 80 % so it is tappable from the first frame.
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: reduceMotion ? 1 : .8, end: 1),
              duration: reduceMotion
                  ? Duration.zero
                  : const Duration(milliseconds: 260),
              curve: Curves.easeOutBack,
              builder: (context, t, child) => Opacity(
                opacity: ((t - .8) / .2).clamp(0, 1),
                child: Transform.scale(scale: t, child: child),
              ),
              child: button,
            ),
    );
  }
}
