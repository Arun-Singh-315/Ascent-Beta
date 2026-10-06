import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';

/// Interactive modal for dropping a thought, idea, or me-to-me self reflection.
class DropThoughtSheet extends ConsumerStatefulWidget {
  final String? initialPrompt;

  const DropThoughtSheet({super.key, this.initialPrompt});

  static Future<void> show(BuildContext context, {String? initialPrompt}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DropThoughtSheet(initialPrompt: initialPrompt),
    );
  }

  @override
  ConsumerState<DropThoughtSheet> createState() => _DropThoughtSheetState();
}

class _DropThoughtSheetState extends ConsumerState<DropThoughtSheet> {
  final _contentController = TextEditingController();
  String _selectedMood = 'me_to_me';
  bool _isPinned = false;
  String? _activePrompt;

  final List<String> _prompts = [
    'What is one honest truth you needed to hear today?',
    'What gave you unexpected energy today?',
    'What is one small win nobody else noticed?',
    'If your future self could whisper advice right now, what would it say?',
    'What is currently taking up unnecessary space in your mind?',
    'What is a skill or realization you developed the hard way?',
  ];

  final List<Map<String, dynamic>> _moods = [
    {'key': 'me_to_me', 'label': 'Me to Me', 'emoji': '🪞', 'color': Color(0xFF8338EC)},
    {'key': 'thought', 'label': 'Raw Thought', 'emoji': '💭', 'color': Color(0xFF3A86FF)},
    {'key': 'idea', 'label': 'Spark / Idea', 'emoji': '💡', 'color': Color(0xFFFFB703)},
    {'key': 'win', 'label': 'Daily Win', 'emoji': '🏆', 'color': Color(0xFF5FA070)},
    {'key': 'future', 'label': 'To Future Me', 'emoji': '🔮', 'color': Color(0xFFFB5607)},
  ];

  @override
  void initState() {
    super.initState();
    _activePrompt = widget.initialPrompt;
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _cyclePrompt() {
    HapticFeedback.lightImpact();
    setState(() {
      final rand = Random();
      _activePrompt = _prompts[rand.nextInt(_prompts.length)];
    });
  }

  void _saveThought() async {
    final text = _contentController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();
    final moodInfo = _moods.firstWhere((m) => m['key'] == _selectedMood);
    final color = (moodInfo['color'] as Color).toARGB32().toRadixString(16);

    await ref.read(thoughtDaoProvider).insertThought(
      ThoughtTableCompanion.insert(
        content: text,
        mood: drift.Value(_selectedMood),
        colorHex: drift.Value('#$color'),
        isPinned: drift.Value(_isPinned),
        promptQuestion: drift.Value(_activePrompt),
      ),
    );

    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✨ Pinned to your Thought Wall!'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: context.divider, width: 1.5),
        ),
      ),
      padding: EdgeInsets.only(
        top: 20,
        left: 20,
        right: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: context.divider,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Header
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: const Color(0xFF8338EC).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: const Color(0xFF8338EC).withValues(alpha: 0.3),
                  ),
                ),
                child: const Icon(Icons.auto_awesome_rounded, color: Color(0xFF8338EC), size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Drop on Thought Wall',
                      style: AscentTextStyles.headlineMedium.copyWith(
                        color: context.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      'Honest talk from you, to you.',
                      style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                    ),
                  ],
                ),
              ),
              // Pin toggle
              IconButton(
                icon: Icon(
                  _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                  color: _isPinned ? context.accentPrimary : context.textMuted,
                  size: 22,
                ),
                tooltip: 'Pin to top',
                onPressed: () {
                  HapticFeedback.lightImpact();
                  setState(() => _isPinned = !_isPinned);
                },
              ),
            ],
          ),

          const SizedBox(height: 14),

          // Self-reflection prompt generator pill
          InkWell(
            onTap: _cyclePrompt,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: context.bgBase,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.divider),
              ),
              child: Row(
                children: [
                  const Text('🪄', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _activePrompt ?? 'Tap for a thoughtful self-reflection prompt ›',
                      style: AscentTextStyles.bodySmall.copyWith(
                        color: _activePrompt != null ? context.textPrimary : context.textMuted,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                  Icon(Icons.refresh_rounded, size: 14, color: context.textMuted),
                ],
              ),
            ),
          ),

          const SizedBox(height: 12),

          // Mood / Tag Selector
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _moods.map((m) {
                final isSelected = _selectedMood == m['key'];
                final color = m['color'] as Color;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: FilterChip(
                    selected: isSelected,
                    showCheckmark: false,
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(m['emoji'] as String, style: const TextStyle(fontSize: 13)),
                        const SizedBox(width: 5),
                        Text(m['label'] as String),
                      ],
                    ),
                    backgroundColor: context.bgBase,
                    selectedColor: color.withValues(alpha: 0.16),
                    labelStyle: AscentTextStyles.labelMedium.copyWith(
                      color: isSelected ? color : context.textMuted,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    ),
                    side: BorderSide(
                      color: isSelected ? color : context.divider,
                      width: isSelected ? 1.5 : 1,
                    ),
                    onSelected: (val) {
                      HapticFeedback.lightImpact();
                      setState(() => _selectedMood = m['key'] as String);
                    },
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 14),

          // Content TextField
          TextField(
            controller: _contentController,
            autofocus: true,
            maxLines: 4,
            style: AscentTextStyles.bodyMedium.copyWith(
              color: context.textPrimary,
              height: 1.4,
            ),
            decoration: InputDecoration(
              hintText: 'Speak your mind freely... unfiltered reflections, moments of clarity, or what you want to remember.',
              hintStyle: AscentTextStyles.bodyMedium.copyWith(
                color: context.textMuted.withValues(alpha: 0.7),
              ),
              filled: true,
              fillColor: context.bgBase,
              contentPadding: const EdgeInsets.all(14),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.divider),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: BorderSide(color: context.accentPrimary, width: 1.5),
              ),
            ),
          ),

          const SizedBox(height: 18),

          // Submit Button
          AscentButton.primary(
            label: _isPinned ? 'Pin to Wall (Pinned) ✨' : 'Pin to Thought Wall ✨',
            expanded: true,
            icon: Icons.push_pin_rounded,
            onPressed: _saveThought,
          ),
        ],
      ),
    );
  }
}
