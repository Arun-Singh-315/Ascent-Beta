import 'package:flutter/material.dart';
import '../utils/smart_list_input_formatter.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_tokens.dart';

class AppInputBar extends StatelessWidget {
  const AppInputBar({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSubmit,
    this.textFieldKey,
    this.submitTooltip,
    this.leadingIcon,
    this.onLeadingTap,
    this.extraAction,
    this.focusNode,
    this.onChanged,
  });

  final TextEditingController controller;
  final String hint;
  final VoidCallback onSubmit;
  final Key? textFieldKey;
  final String? submitTooltip;
  final IconData? leadingIcon; // e.g. Icons.search
  final VoidCallback? onLeadingTap;
  final Widget? extraAction; // e.g. repeat toggle for to-dos
  final FocusNode? focusNode;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    return Row(
      children: [
        if (leadingIcon != null) ...[
          Material(
            color: c.accentTint,
            shape: const CircleBorder(),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onLeadingTap ??
                  (focusNode != null ? () => focusNode!.requestFocus() : null),
              child: SizedBox(
                width: 46,
                height: 46,
                child: Icon(leadingIcon!, size: 20, color: c.accent),
              ),
            ),
          ),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: ListenableBuilder(
            listenable: controller,
            builder: (context, _) {
              return TextField(
                key: textFieldKey,
                controller: controller,
                focusNode: focusNode,
                minLines: 1,
                maxLines: 4,
                keyboardType: TextInputType.multiline,
                inputFormatters: const [SmartListInputFormatter()],
                onChanged: onChanged,
                onSubmitted: (_) => onSubmit(),
                style: TextStyle(fontSize: 14, color: c.textPrimary),
                decoration: InputDecoration(
                  hintText: hint,
                  hintStyle: TextStyle(fontSize: 14, color: c.textTertiary),
                  isDense: true,
                  filled: true,
                  fillColor: c.surfaceAlt,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Rd.field),
                    borderSide: BorderSide(color: c.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Rd.field),
                    borderSide: BorderSide(color: c.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(Rd.field),
                    borderSide: BorderSide(color: c.accent, width: 1.5),
                  ),
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                ),
              );
            },
          ),
        ),
        if (extraAction != null) ...[const SizedBox(width: 6), extraAction!],
        const SizedBox(width: 10),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) {
            final hasText = controller.text.trim().isNotEmpty;
            return _RoundIconButton(
              icon: Icons.arrow_forward,
              tooltip: submitTooltip,
              onTap: hasText ? onSubmit : null,
              filled: true,
              enabled: hasText,
            );
          },
        ),
      ],
    );
  }
}

class _RoundIconButton extends StatelessWidget {
  const _RoundIconButton({
    required this.icon,
    required this.onTap,
    required this.filled,
    this.enabled = true,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool filled;
  final bool enabled;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final bgColor = filled
        ? (enabled ? c.accent : c.accent.withValues(alpha: 0.4))
        : c.accentTint;
    final fgColor = filled
        ? (enabled ? c.onAccent : c.onAccent.withValues(alpha: 0.6))
        : c.accent;

    return IconButton(
      tooltip: tooltip,
      onPressed: enabled ? onTap : null,
      icon: Icon(icon, size: 20),
      color: fgColor,
      disabledColor: fgColor,
      style: IconButton.styleFrom(
        backgroundColor: bgColor,
        minimumSize: const Size(46, 46),
        padding: EdgeInsets.zero,
        shape: const CircleBorder(),
      ),
    );
  }
}
