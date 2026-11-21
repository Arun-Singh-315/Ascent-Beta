import 'package:flutter/material.dart';

import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../core/constants/app_constants.dart';
import 'ascent_composer.dart';

/// Assistant chat input: [AscentComposer] in a safe-area aware dock, with an
/// optional actions button.
class AppComposer extends StatelessWidget {
  const AppComposer({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    this.assistantName = AppConstants.assistantName,
    this.onPlusPressed,
    this.isLoading = false,
    this.onMic,
    this.listening = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onSubmitted;
  final String assistantName;
  final VoidCallback? onPlusPressed;
  final bool isLoading;
  final VoidCallback? onMic;
  final bool listening;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpace.s16,
          AppSpace.s8,
          AppSpace.s16,
          AppSpace.s8,
        ),
        child: AscentComposer(
          controller: controller,
          focusNode: focusNode,
          hint: 'Message $assistantName…',
          busy: isLoading,
          onSend: (text) => onSubmitted(text.trim()),
          onMic: onMic,
          listening: listening,
          sendKey: const ValueKey('chat_send_button'),
          sendTooltip: 'Send message',
          inputFormatters: const [],
          glass: true,
          leading: onPlusPressed == null
              ? null
              : SizedBox(
                  width: 48,
                  height: 48,
                  child: IconButton(
                    key: const ValueKey('chat_plus_button'),
                    tooltip: 'Actions',
                    onPressed: onPlusPressed,
                    icon: Icon(
                      Icons.add_rounded,
                      size: 24,
                      color: g.inkSecondary,
                    ),
                  ),
                ),
        ),
      ),
    );
  }
}
