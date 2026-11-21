import 'package:flutter/material.dart';

import 'calm_blue_palette.dart';

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

  // Every role is a Calm Blue role, so chat matches the rest of the app.
  static const light = ChatPalette._(
    canvas: CalmBluePalette.canvas,
    surface: CalmBluePalette.surface,
    elevated: CalmBluePalette.elevated,
    recessed: CalmBluePalette.recessed,
    separator: CalmBluePalette.separator,
    label: CalmBluePalette.label,
    labelSecondary: CalmBluePalette.labelSecondary,
    labelTertiary: CalmBluePalette.labelTertiary,
    action: CalmBluePalette.action,
    userBubble: CalmBluePalette.actionTint,
    userText: CalmBluePalette.label,
    assistantName: Color(0xFF5E5CE6),
    highlightInk: CalmBluePalette.warning,
  );

  static const dark = ChatPalette._(
    canvas: CalmBluePalette.darkCanvas,
    surface: CalmBluePalette.darkSurface,
    elevated: CalmBluePalette.darkElevated,
    recessed: CalmBluePalette.darkRecessed,
    separator: CalmBluePalette.darkSeparator,
    label: CalmBluePalette.darkLabel,
    labelSecondary: CalmBluePalette.darkLabelSecondary,
    labelTertiary: CalmBluePalette.darkLabelTertiary,
    action: CalmBluePalette.darkAction,
    userBubble: CalmBluePalette.darkActionTint,
    userText: CalmBluePalette.darkLabel,
    assistantName: Color(0xFFA9A7FF),
    highlightInk: CalmBluePalette.darkWarning,
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
