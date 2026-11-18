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
    this.isLoading = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final String assistantName;
  final VoidCallback? onPlusPressed;
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
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            if (!widget.focusNode.hasFocus) {
              widget.focusNode.requestFocus();
            }
          },
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF16181F) : const Color(0xFFF7F5F0),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(
                color: _isFocused
                    ? colorScheme.primary
                    : (isDark ? const Color(0xFF262933) : const Color(0xFFDCD6CC)),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Leading "+" action button
                SizedBox(
                  width: 38,
                  height: 38,
                  child: IconButton(
                    key: const ValueKey('chat_plus_button'),
                    padding: EdgeInsets.zero,
                    icon: Icon(
                      Icons.add_rounded,
                      color: c.textSecondary,
                      size: 22,
                    ),
                    tooltip: 'Actions',
                    onPressed: widget.isLoading ? null : widget.onPlusPressed,
                  ),
                ),
                // Single borderless TextField in perfect horizontal & vertical sync
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: TextField(
                      controller: widget.controller,
                      focusNode: widget.focusNode,
                      minLines: 1,
                      maxLines: 5,
                      textAlignVertical: TextAlignVertical.center,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _handleSend(),
                      cursorColor: colorScheme.primary,
                      style: TextStyle(
                        fontSize: 15,
                        color: c.textPrimary,
                        height: 1.30,
                      ),
                      decoration: InputDecoration(
                        hintText: 'Message ${widget.assistantName}…',
                        hintStyle: TextStyle(
                          fontSize: 15,
                          color: c.textTertiary,
                        ),
                        border: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        errorBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        focusedErrorBorder: InputBorder.none,
                        isDense: true,
                        filled: false,
                        contentPadding: const EdgeInsets.fromLTRB(4, 7, 4, 9),
                      ),
                    ),
                  ),
                ),
                // Trailing action: High-speed Send button (No dummy mic)
                SizedBox(
                  width: 38,
                  height: 38,
                  child: Center(
                    child: ScaleTransition(
                      scale: Tween<double>(begin: 0.90, end: 1.0).animate(
                        _sendScaleAnimation,
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 180),
                        curve: Curves.easeOutCubic,
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _hasText
                              ? colorScheme.primary
                              : (isDark
                                  ? const Color(0xFF262933)
                                  : const Color(0xFFE2E8F0)),
                        ),
                        child: IconButton(
                          key: const ValueKey('chat_send_button'),
                          padding: EdgeInsets.zero,
                          tooltip: _hasText ? 'Send message' : null,
                          icon: Icon(
                            Icons.arrow_upward_rounded,
                            size: 18,
                            color: _hasText
                                ? colorScheme.onPrimary
                                : (isDark
                                    ? const Color(0xFF64748B)
                                    : const Color(0xFF94A3B8)),
                          ),
                          onPressed: (_hasText && !widget.isLoading)
                              ? _handleSend
                              : null,
                        ),
                      ),
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
