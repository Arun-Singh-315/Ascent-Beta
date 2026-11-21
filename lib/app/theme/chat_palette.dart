import 'package:flutter/material.dart';

/// Assistant chat colours (CLAUDE.md §3.1, §5.4), light and dark as one swap.
///
/// Grouped canvas, an action-tint bubble for the user, no bubble for the
/// assistant and recessed suggestion tiles on a plain canvas. Literals live
/// here only.
@immutable
class ChatPalette {
  const ChatPalette._({
    required this.canvas,
    required this.surface,
    required this.elevated,
    required this.recessed,
    required this.separator,
    required this.label,
    required this.labelSecondary,
    required this.labelTertiary,
    required this.action,
    required this.userBubble,
    required this.userText,
    required this.assistantName,
    required this.highlightInk,
  });

  final Color canvas;
  final Color surface;
  final Color elevated;
  final Color recessed;
  final Color separator;
  final Color label;
  final Color labelSecondary;
  final Color labelTertiary;
  final Color action;
  final Color userBubble;
  final Color userText;
  final Color assistantName;
  final Color highlightInk;

  static const light = ChatPalette._(
    canvas: Color(0xFFF2F2F7),
    surface: Color(0xFFFFFFFF),
    elevated: Color(0xFFFFFFFF),
    recessed: Color(0xFFE9E9EE),
    separator: Color(0x99C6C6C8),
    label: Color(0xFF1D1D1F),
    labelSecondary: Color(0xFF6E6E73),
    labelTertiary: Color(0xFF8E8E93),
    action: Color(0xFF007AFF),
    userBubble: Color(0xFFE5F0FF),
    userText: Color(0xFF1D1D1F),
    assistantName: Color(0xFF5E5CE6),
    highlightInk: Color(0xFF92400E),
  );

  static const dark = ChatPalette._(
    canvas: Color(0xFF000000),
    surface: Color(0xFF1C1C1E),
    elevated: Color(0xFF2C2C2E),
    recessed: Color(0xFF2C2C2E),
    separator: Color(0xFF38383A),
    label: Color(0xFFF5F5F7),
    labelSecondary: Color(0xFFAEAEB2),
    labelTertiary: Color(0xFF8E8E93),
    action: Color(0xFF0A84FF),
    userBubble: Color(0xFF0A2A4D),
    userText: Color(0xFFF5F5F7),
    assistantName: Color(0xFF8E8CFF),
    highlightInk: Color(0xFFFDE68A),
  );

  static ChatPalette of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? dark : light;

  /// Soft shadow for light cards only (dark uses fill + hairline).
  List<BoxShadow> cardShadow(bool isDark) => isDark
      ? const []
      : const [
          BoxShadow(
            color: Color(0x0D000000),
            blurRadius: 12,
            offset: Offset(0, 2),
          ),
        ];
}
