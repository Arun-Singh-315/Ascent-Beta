import 'package:flutter/material.dart';
import '../../app/theme/surface_tokens.dart';

/// Visible list entry: users never need to know the keyboard marker syntax.
class NoteListButton extends StatelessWidget {
  const NoteListButton({
    super.key,
    required this.controller,
    this.focusNode,
    this.compact = false,
    this.enabled = true,
  });
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool compact, enabled;

  static void insertNextItem(TextEditingController controller) {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.isValid
        ? selection.start.clamp(0, text.length)
        : text.length;
    final end = selection.isValid
        ? selection.end.clamp(0, text.length)
        : text.length;
    final lineStart = start == 0 ? 0 : text.lastIndexOf('\n', start - 1) + 1;
    final nextBreak = text.indexOf('\n', end);
    final lineEnd = nextBreak < 0 ? text.length : nextBreak;
    final currentLine = text.substring(lineStart, lineEnd);
    if (start == end &&
        RegExp(r'^\s*(?:-->|→|--|-|•)\s*$').hasMatch(currentLine)) {
      controller.selection = TextSelection.collapsed(offset: lineEnd);
      return;
    }
    final marker = start == 0 || text.substring(0, start).endsWith('\n')
        ? '--> '
        : '\n--> ';
    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, marker),
      selection: TextSelection.collapsed(offset: start + marker.length),
    );
  }

  void _add() {
    insertNextItem(controller);
    focusNode?.requestFocus();
  }

  @override
  Widget build(BuildContext context) => compact
      ? IconButton(
          tooltip: 'Add next item on a new line',
          onPressed: enabled ? _add : null,
          icon: const Icon(Icons.playlist_add_rounded),
        )
      : TextButton.icon(
          onPressed: enabled ? _add : null,
          icon: const Icon(Icons.playlist_add_rounded),
          label: const Text('Add next item'),
        );
}

class NoteListToolbar extends StatelessWidget {
  const NoteListToolbar({
    super.key,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.helperText = 'One line per item. Tap Plan to review your list.',
  });
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final String helperText;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: AppSpace.s4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        NoteListButton(
          controller: controller,
          focusNode: focusNode,
          enabled: enabled,
        ),
        Padding(
          padding: const EdgeInsets.only(
            left: AppSpace.s12,
            right: AppSpace.s12,
            bottom: AppSpace.s8,
          ),
          child: Text(helperText, style: Theme.of(context).textTheme.bodySmall),
        ),
      ],
    ),
  );
}
