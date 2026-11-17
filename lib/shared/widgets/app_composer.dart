import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/constants/app_constants.dart';
import '../../core/theme/app_colors.dart';

/// The canonical single-enclosure chat composer for Ascent.
///
/// Follows the Non-Negotiable Input Rule:
/// - ONE input = ONE container.
/// - Single container with `surfaceAlt` fill, 1px hairline border (`c.border` -> `c.primary` on focus).
/// - NO inner borders, no Material blue focus border / underline anywhere.
/// - Continuous corners radius 24.
/// - Leading "+" action button.
/// - Trailing: mic icon when empty; animates (scale 0 -> 1) into a primary circular send button when text is entered.
/// - Safe-area aware.
class AppComposer extends StatefulWidget {
  const AppComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    this.assistantName = AppConstants.assistantName,
    this.onPlusPressed,
    this.onMicPressed,
    this.isLoading = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final String assistantName;
  final VoidCallback? onPlusPressed;
  final VoidCallback? onMicPressed;
  final bool isLoading;

  @override
  State<AppComposer> createState() => _AppComposerState();
}

class _AppComposerState extends State<AppComposer>
    with SingleTickerProviderStateMixin {
  bool _hasText = false;
  bool _isFocused = false;
  late final AnimationController _sendScaleController;
  late final Animation<double> _sendScaleAnimation;

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    _sendScaleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
      value: _hasText ? 1.0 : 0.0,
    );
    _sendScaleAnimation = CurvedAnimation(
      parent: _sendScaleController,
      curve: Curves.easeOutCubic,
    );

    widget.controller.addListener(_onTextChanged);
    widget.focusNode.addListener(_onFocusChanged);
  }

  void _onTextChanged() {
    final hasText = widget.controller.text.trim().isNotEmpty;
    if (_hasText != hasText) {
      setState(() => _hasText = hasText);
      if (hasText) {
        _sendScaleController.forward();
      } else {
        _sendScaleController.reverse();
      }
    }
  }

  void _onFocusChanged() {
    if (_isFocused != widget.focusNode.hasFocus) {
      setState(() => _isFocused = widget.focusNode.hasFocus);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onTextChanged);
    widget.focusNode.removeListener(_onFocusChanged);
    _sendScaleController.dispose();
    super.dispose();
  }

  void _handleSend() {
    final text = widget.controller.text.trim();
    if (text.isEmpty || widget.isLoading) return;
    HapticFeedback.selectionClick();
    widget.onSubmitted(text);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final colorScheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF16181F) : c.surfaceAlt,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: _isFocused
                  ? colorScheme.primary
                  : (isDark ? const Color(0xFF2C303B) : c.border),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isDark ? const Color(0x30000000) : c.warmShadow,
                blurRadius: 12,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Leading "+" action button
              Padding(
                padding: const EdgeInsets.only(left: 4, bottom: 4),
                child: IconButton(
                  key: const ValueKey('chat_plus_button'),
                  icon: Icon(
                    Icons.add_rounded,
                    color: c.textSecondary,
                    size: 22,
                  ),
                  tooltip: 'Actions',
                  onPressed: widget.isLoading ? null : widget.onPlusPressed,
                ),
              ),
              // Single borderless TextField
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: TextField(
                    controller: widget.controller,
                    focusNode: widget.focusNode,
                    minLines: 1,
                    maxLines: 5,
                    textCapitalization: TextCapitalization.sentences,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _handleSend(),
                    cursorColor: colorScheme.primary,
                    style: TextStyle(
                      fontSize: 15,
                      color: c.textPrimary,
                      height: 1.35,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Message ${widget.assistantName}…',
                      hintStyle: TextStyle(
                        fontSize: 15,
                        color: c.textTertiary,
                      ),
                      // EXPLICITLY disable all inner borders
                      border: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      isDense: true,
                      filled: false,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 6,
                      ),
                    ),
                  ),
                ),
              ),
              // Trailing action: Mic or Scale-animated Send button
              Padding(
                padding: const EdgeInsets.only(right: 6, bottom: 6),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // Mic button when empty
                    if (!_hasText)
                      IconButton(
                        key: const ValueKey('chat_mic_button'),
                        icon: Icon(
                          Icons.mic_none_rounded,
                          color: c.textSecondary,
                          size: 22,
                        ),
                        tooltip: 'Voice input',
                        onPressed: widget.isLoading
                            ? null
                            : () {
                                HapticFeedback.lightImpact();
                                widget.onMicPressed?.call();
                              },
                      ),
                    // Scale-animated send button
                    ScaleTransition(
                      scale: _sendScaleAnimation,
                      child: Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: colorScheme.primary,
                        ),
                        child: IconButton(
                          key: const ValueKey('chat_send_button'),
                          padding: EdgeInsets.zero,
                          icon: Icon(
                            Icons.arrow_upward_rounded,
                            size: 20,
                            color: colorScheme.onPrimary,
                          ),
                          onPressed: widget.isLoading ? null : _handleSend,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
