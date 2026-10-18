import 'package:flutter/material.dart';

/// Explicit list entry preserves ordinary note typing and prose arrows.
class NoteListButton extends StatelessWidget {
  const NoteListButton({
    super.key,
    required this.controller,
    this.compact = false,
  });
  final TextEditingController controller;
  final bool compact;
  void _add() {
    final text = controller.text;
    final selection = controller.selection;
    final start = selection.isValid ? selection.start : text.length;
    final end = selection.isValid ? selection.end : text.length;
    final marker = start == 0 || text.substring(0, start).endsWith('\n')
        ? '--> '
        : '\n--> ';
    controller.value = TextEditingValue(
      text: text.replaceRange(start, end, marker),
      selection: TextSelection.collapsed(offset: start + marker.length),
    );
  }

  @override
  Widget build(BuildContext context) => compact
      ? IconButton(
          tooltip: 'Add next checklist item',
          onPressed: _add,
          icon: const Icon(Icons.playlist_add_rounded),
        )
      : TextButton.icon(
          onPressed: _add,
          icon: const Icon(Icons.playlist_add_rounded),
          label: const Text('Add next item →'),
        );
}
