import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/surface_tokens.dart';
import '../../app/theme/color_tokens.dart';

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

/// Modern In-Line '+' Button for composers:
/// Sits directly on the input line, auto-inserts '--> ' on click,
/// and offers an interactive discovery balloon on long-press or tap.
class InlineListAddButton extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final bool enabled;
  final IconData icon;

  const InlineListAddButton({
    super.key,
    required this.controller,
    this.focusNode,
    this.enabled = true,
    this.icon = Icons.add_rounded,
  });

  static Future<void> maybeShowFirstTimeDiscovery(
    BuildContext context, {
    SharedPreferences? prefs,
  }) async {
    // Avoid interrupting automated test runners
    try {
      if (Platform.environment.containsKey('FLUTTER_TEST')) return;
    } catch (_) {}
    try {
      if (prefs != null) {
        if (prefs.getBool('ascent_syntax_tip_shown_v1') == true) return;
        await prefs.setBool('ascent_syntax_tip_shown_v1', true);
      }
      if (context.mounted) {
        showHelperDialog(context);
      }
    } catch (_) {
      // Best-effort check; suppress if preferences unreadable
    }
  }

  static void showHelperDialog(BuildContext context) {
    HapticFeedback.lightImpact();
    final g = context.glass;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(AppSpace.s20),
        decoration: BoxDecoration(
          color: ctx.bgSurfaceElevated,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border.all(color: g.line),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: g.clay.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          Icons.playlist_add_rounded,
                          color: g.clay,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        'Smart Planning & Lists',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: ctx.textPrimary,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Why write multiple tasks this way? Instead of opening endless dialogs, Ascent lets you type naturally like a note. Tap "+" anytime on the input line to insert the next item!',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.4,
                  color: ctx.textMuted,
                ),
              ),
              const SizedBox(height: 14),
              _buildGuideTile(
                ctx,
                g,
                symbol: '-->',
                title: 'Plan Activity',
                desc:
                    'Creates a scheduled activity or focus task with optional duration, alarms, and timers.',
              ),
              const SizedBox(height: 10),
              _buildGuideTile(
                ctx,
                g,
                symbol: '--',
                title: 'Simple To-Do',
                desc:
                    'Creates a fast checkbox to-do item for everyday quick completions without timers.',
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  style: FilledButton.styleFrom(
                    backgroundColor: g.clay,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Got it!'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildGuideTile(
    BuildContext context,
    AscentGlass g, {
    required String symbol,
    required String title,
    required String desc,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.bgBase,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: context.divider.withValues(alpha: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: g.clay.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              symbol,
              style: TextStyle(
                fontFamily: 'monospace',
                fontWeight: FontWeight.w700,
                color: g.clay,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                    color: context.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: TextStyle(
                    fontSize: 11,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    return Tooltip(
      message: 'Add plan item (-->) • Long press for guide',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: enabled
              ? () {
                  HapticFeedback.lightImpact();
                  NoteListButton.insertNextItem(controller);
                  focusNode?.requestFocus();
                }
              : null,
          onLongPress: () => showHelperDialog(context),
          child: Padding(
            padding: const EdgeInsets.all(8.0),
            child: Icon(
              icon,
              size: 22,
              color: enabled ? g.clay : g.inkMuted,
            ),
          ),
        ),
      ),
    );
  }
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
