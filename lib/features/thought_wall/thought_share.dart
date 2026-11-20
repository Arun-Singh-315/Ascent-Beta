import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/database/app_database.dart';

/// Formats thought content cleanly for WhatsApp, messages, and external sharing.
String formatThoughtForShare(Thought thought) {
  final buffer = StringBuffer();
  if (thought.promptQuestion != null &&
      thought.promptQuestion!.trim().isNotEmpty &&
      thought.promptQuestion!.trim().toLowerCase() !=
          thought.content.trim().toLowerCase()) {
    buffer.writeln('💭 Prompt: ${thought.promptQuestion!.trim()}\n');
  }
  buffer.writeln('"${thought.content.trim()}"');
  buffer.writeln('\n— Mindspace · Ascent');
  return buffer.toString();
}

/// Formats multiple selected thoughts cleanly for WhatsApp and messaging apps.
String formatMultipleThoughtsForShare(List<Thought> thoughts) {
  if (thoughts.isEmpty) return '';
  if (thoughts.length == 1) {
    return formatThoughtForShare(thoughts.first);
  }

  final buffer = StringBuffer();
  buffer.writeln('✦ MIND SPACE REFLECTIONS ✦');
  buffer.writeln('Ascent · Notes to Myself\n');

  for (int i = 0; i < thoughts.length; i++) {
    final t = thoughts[i];
    buffer.writeln('── [Note ${i + 1}/${thoughts.length}] ──');
    if (t.promptQuestion != null &&
        t.promptQuestion!.trim().isNotEmpty &&
        t.promptQuestion!.trim().toLowerCase() !=
            t.content.trim().toLowerCase()) {
      buffer.writeln('💭 Prompt: ${t.promptQuestion!.trim()}');
    }
    buffer.writeln('"${t.content.trim()}"');
    buffer.writeln();
  }
  buffer.writeln('— Shared from Mindspace · Ascent');
  return buffer.toString().trim();
}

/// Triggers system share sheet to share thought directly to WhatsApp or any installed app.
Future<void> shareThought(Thought thought) async {
  HapticFeedback.lightImpact();
  final text = formatThoughtForShare(thought);
  await SharePlus.instance.share(
    ShareParams(text: text, subject: 'Mindspace Reflection'),
  );
}

/// Triggers system share sheet to batch-share thoughts directly to WhatsApp or any installed app.
Future<void> shareMultipleThoughts(List<Thought> thoughts) async {
  if (thoughts.isEmpty) return;
  HapticFeedback.lightImpact();
  final text = formatMultipleThoughtsForShare(thoughts);
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      subject: 'Mindspace Reflections (${thoughts.length} notes)',
    ),
  );
}
