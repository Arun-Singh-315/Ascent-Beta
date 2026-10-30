import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../app/theme/shared_control_tokens.dart';
import 'ascent_snack_bar.dart';

/// A binary user choice; importance is never inferred from due dates.
class AscentStarButton extends StatefulWidget {
  const AscentStarButton({super.key, required this.selected, this.onChanged});
  final bool selected;
  final FutureOr<void> Function(bool)? onChanged;
  @override
  State<AscentStarButton> createState() => _AscentStarButtonState();
}

class _AscentStarButtonState extends State<AscentStarButton> {
  bool _busy = false;
  Future<void> _toggle() async {
    if (_busy || widget.onChanged == null) return;
    setState(() => _busy = true);
    try {
      await widget.onChanged!(!widget.selected);
      HapticFeedback.selectionClick();
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: 'Could not save star. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Semantics(
    toggled: widget.selected,
    child: SizedBox(
      width: 32,
      height: 32,
      child: IconButton(
        tooltip: widget.selected ? 'Remove star' : 'Star activity',
        onPressed: widget.onChanged == null || _busy ? null : _toggle,
        padding: EdgeInsets.zero,
        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
        color: widget.selected
            ? SharedControlColors.actionBlue
            : const Color(0xFF8E8E93),
        icon: Icon(
          widget.selected ? Icons.star_rounded : Icons.star_outline_rounded,
          size: 18,
        ),
      ),
    ),
  );
}
