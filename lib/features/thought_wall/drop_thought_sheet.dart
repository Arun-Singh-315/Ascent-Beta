import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;
import 'package:shared_preferences/shared_preferences.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/ascent_button.dart';

/// Interactive modal for dropping or editing a thought, idea, or me-to-me self reflection.
///
/// When [initialMood] is 'promise' (or for existing promise edits), this renders
/// as a focused centered Promise dialog — no tag picker, no distractions.
/// For all other moods it renders as the standard bottom sheet.
class DropThoughtSheet extends ConsumerStatefulWidget {
  final String? initialPrompt;
  final String? initialMood;
  final Thought? existingThought;

  const DropThoughtSheet({
    super.key,
    this.initialPrompt,
    this.initialMood,
    this.existingThought,
  });

  /// Show a centered Promise dialog — clean, focused, no tag picker.
  static Future<void> showPromise(BuildContext context) {
    return showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.6),
      barrierDismissible: true,
      builder: (ctx) => const _PromiseDialog(),
    );
  }

  /// Show the general thought entry bottom sheet.
  static Future<void> show(
    BuildContext context, {
    String? initialPrompt,
    String? initialMood,
    Thought? existingThought,
  }) {
    // Route promise entries to the dedicated centered dialog.
    if (initialMood == 'promise' && existingThought == null) {
      return showPromise(context);
    }

    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => DropThoughtSheet(
        initialPrompt: initialPrompt,
        initialMood: initialMood,
        existingThought: existingThought,
      ),
    );
  }

  @override
  ConsumerState<DropThoughtSheet> createState() => _DropThoughtSheetState();
}

// ─────────────────────────────────────────────────────────────────────────────
// Promise Dialog — centered, focused, no distractions
// ─────────────────────────────────────────────────────────────────────────────

class _PromiseDialog extends ConsumerStatefulWidget {
  const _PromiseDialog();

  @override
  ConsumerState<_PromiseDialog> createState() => _PromiseDialogState();
}

class _PromiseDialogState extends ConsumerState<_PromiseDialog>
    with SingleTickerProviderStateMixin {
  final _contentController = TextEditingController();
  final _daysController = TextEditingController(text: '30');
  bool _isSaving = false;
  String? _saveError;
  late final AnimationController _fadeCtrl;
  late final Animation<double> _fadeAnim;

  @override
  void initState() {
    super.initState();
    _fadeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
    )..forward();
    _fadeAnim = CurvedAnimation(parent: _fadeCtrl, curve: Curves.easeOut);
  }

  @override
  void dispose() {
    _contentController.dispose();
    _daysController.dispose();
    _fadeCtrl.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _contentController.text.trim();
    if (text.isEmpty) return;

    final validityDays = int.tryParse(_daysController.text.trim());
    if (validityDays == null || validityDays < 1 || validityDays > 365) {
      setState(() => _saveError = 'Choose a duration from 1 to 365 days.');
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    try {
      await ref.read(promiseServiceProvider).create(
            content: text,
            validityDays: validityDays,
          );

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Promise added — $validityDays daily reminders set'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = 'Could not save your promise. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return FadeTransition(
      opacity: _fadeAnim,
      child: Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Container(
              decoration: BoxDecoration(
                color: (context.isDark
                        ? const Color(0xFF10141D)
                        : const Color(0xFFF8FAFC))
                    .withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: g.edge.withValues(alpha: 0.35),
                  width: 1.0,
                ),
              ),
              padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header ──────────────────────────────────────────
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: const Color(0xFF7C3AED).withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: const Color(0xFF7C3AED).withValues(alpha: 0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.handshake_rounded,
                          color: Color(0xFF7C3AED),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Make a Promise',
                              style: AscentTextStyles.headlineMedium.copyWith(
                                color: context.textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Set a commitment to yourself.',
                              style: AscentTextStyles.bodySmall.copyWith(
                                color: context.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Close
                      IconButton(
                        icon: Icon(Icons.close_rounded, color: g.inkMuted, size: 20),
                        onPressed: () => Navigator.of(context).pop(),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                    ],
                  ),

                  const SizedBox(height: 22),

                  // ── Commitment text field ────────────────────────────
                  TextField(
                    controller: _contentController,
                    autofocus: true,
                    maxLength: 300,
                    maxLines: 4,
                    style: AscentTextStyles.bodyMedium.copyWith(
                      color: context.textPrimary,
                      height: 1.4,
                    ),
                    decoration: InputDecoration(
                      hintText: 'What will you complete? Make it specific.',
                      hintStyle: AscentTextStyles.bodyMedium.copyWith(
                        color: context.textMuted.withValues(alpha: 0.7),
                      ),
                      counterStyle: AscentTextStyles.captionMedium.copyWith(
                        color: context.textMuted,
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
                        borderSide: const BorderSide(
                          color: Color(0xFF7C3AED),
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // ── Days accountability ──────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Keep me accountable for',
                              style: AscentTextStyles.labelMedium.copyWith(
                                color: context.textPrimary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            Text(
                              'Daily reminder at 9:00 AM',
                              style: AscentTextStyles.captionMedium.copyWith(
                                color: context.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      // Compact days stepper
                      Container(
                        decoration: BoxDecoration(
                          color: context.bgBase,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: context.divider),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _StepButton(
                              icon: Icons.remove_rounded,
                              onTap: () {
                                final v = int.tryParse(_daysController.text) ?? 30;
                                if (v > 1) {
                                  _daysController.text = '${v - 1}';
                                }
                              },
                            ),
                            SizedBox(
                              width: 52,
                              child: TextField(
                                controller: _daysController,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                inputFormatters: [
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(3),
                                ],
                                style: AscentTextStyles.labelLarge.copyWith(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.w700,
                                ),
                                decoration: InputDecoration(
                                  border: InputBorder.none,
                                  isDense: true,
                                  contentPadding: const EdgeInsets.symmetric(vertical: 10),
                                  suffix: Text(
                                    'd',
                                    style: AscentTextStyles.captionMedium.copyWith(
                                      color: context.textMuted,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            _StepButton(
                              icon: Icons.add_rounded,
                              onTap: () {
                                final v = int.tryParse(_daysController.text) ?? 30;
                                if (v < 365) {
                                  _daysController.text = '${v + 1}';
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  if (_saveError != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _saveError!,
                      style: AscentTextStyles.bodySmall.copyWith(
                        color: Colors.redAccent,
                      ),
                    ),
                  ],

                  const SizedBox(height: 22),

                  // ── Action buttons ───────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: g.inkMuted,
                            side: BorderSide(color: g.line),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Cancel'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 2,
                        child: FilledButton.icon(
                          onPressed: _isSaving ? null : _save,
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7C3AED),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          icon: _isSaving
                              ? const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : const Icon(Icons.handshake_rounded, size: 18),
                          label: Text(_isSaving ? 'Saving…' : 'Add Promise'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small +/- stepper button for the days field.
class _StepButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _StepButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Icon(icon, size: 16, color: context.textMuted),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// General Thought Bottom Sheet (unchanged, used for all non-promise moods)
// ─────────────────────────────────────────────────────────────────────────────

class _DropThoughtSheetState extends ConsumerState<DropThoughtSheet> {
  final _contentController = TextEditingController();
  final _promiseDaysController = TextEditingController(text: '30');
  String _selectedMood = 'me_to_me';
  bool _isPinned = false;
  bool _isSaving = false;
  String? _saveError;
  String? _activePrompt;

  final List<String> _prompts = [
    'What is one honest truth you needed to hear today?',
    'What gave you unexpected energy today?',
    'What is one small win nobody else noticed?',
    'If your future self could whisper advice right now, what would it say?',
    'What is currently taking up unnecessary space in your mind?',
    'What is a skill or realization you developed the hard way?',
  ];

  final List<Map<String, dynamic>> _moods = const [
    {
      'key': 'me_to_me',
      'label': 'Me to Me',
      'icon': Icons.psychology_alt_rounded,
      'color': Color(0xFF6366F1),
    },
    {
      'key': 'thought',
      'label': 'Raw Thought',
      'icon': Icons.insights_rounded,
      'color': Color(0xFF0284C7),
    },
    {
      'key': 'idea',
      'label': 'Idea',
      'icon': Icons.lightbulb_rounded,
      'color': Color(0xFFD97706),
    },
    {
      'key': 'win',
      'label': 'Daily Win',
      'icon': Icons.emoji_events_rounded,
      'color': Color(0xFF16A34A),
    },
    {
      'key': 'future',
      'label': 'To Future Me',
      'icon': Icons.schedule_send_rounded,
      'color': Color(0xFFEA580C),
    },
  ];

  static const _kDraftContent = 'thought_wall_draft_content';
  static const _kDraftMood = 'thought_wall_draft_mood';
  static const _kDraftPrompt = 'thought_wall_draft_prompt';

  bool _isDraftRestored = false;

  List<Map<String, dynamic>> get _availableMoods {
    if (widget.existingThought?.mood == 'promise') {
      // Promise edits stay in their own flow (this sheet shouldn't be reached,
      // but guard just in case).
      return _moods;
    }
    return _moods;
  }

  @override
  void initState() {
    super.initState();
    if (widget.existingThought != null) {
      _contentController.text = widget.existingThought!.content;
      _selectedMood = widget.existingThought!.mood == 'promise'
          ? 'me_to_me'
          : widget.existingThought!.mood;
      _isPinned = widget.existingThought!.isPinned;
      _activePrompt = widget.existingThought!.promptQuestion;
    } else {
      _activePrompt = widget.initialPrompt;
      if (widget.initialMood != null &&
          _moods.any((mood) => mood['key'] == widget.initialMood)) {
        _selectedMood = widget.initialMood!;
      }
      _loadDraft();
    }
    _contentController.addListener(_onTextChanged);
  }

  void _onTextChanged() {
    if (widget.existingThought == null) {
      _autoSaveDraft();
    }
  }

  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final draft = prefs.getString(_kDraftContent);
      if (draft != null &&
          draft.trim().isNotEmpty &&
          _contentController.text.isEmpty) {
        final savedMood = prefs.getString(_kDraftMood);
        final savedPrompt = prefs.getString(_kDraftPrompt);
        if (mounted) {
          setState(() {
            _contentController.text = draft;
            if (savedMood != null && widget.initialMood == null) {
              _selectedMood = savedMood;
            }
            if (savedPrompt != null && _activePrompt == null) {
              _activePrompt = savedPrompt;
            }
            _isDraftRestored = true;
          });
        }
      }
    } catch (_) {}
  }

  Future<void> _autoSaveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final text = _contentController.text;
      if (text.trim().isNotEmpty) {
        await prefs.setString(_kDraftContent, text);
        await prefs.setString(_kDraftMood, _selectedMood);
        if (_activePrompt != null) {
          await prefs.setString(_kDraftPrompt, _activePrompt!);
        }
      } else {
        await _clearDraft();
      }
    } catch (_) {}
  }

  Future<void> _clearDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_kDraftContent);
      await prefs.remove(_kDraftMood);
      await prefs.remove(_kDraftPrompt);
    } catch (_) {}
  }

  @override
  void dispose() {
    _contentController.removeListener(_onTextChanged);
    _contentController.dispose();
    _promiseDaysController.dispose();
    super.dispose();
  }

  void _cyclePrompt() {
    HapticFeedback.lightImpact();
    setState(() {
      final rand = Random();
      _activePrompt = _prompts[rand.nextInt(_prompts.length)];
    });
    if (widget.existingThought == null) {
      _autoSaveDraft();
    }
  }

  Future<void> _saveThought() async {
    final text = _contentController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.mediumImpact();
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    final moodInfo = _moods.firstWhere(
      (m) => m['key'] == _selectedMood,
      orElse: () => _moods.first,
    );
    final color = (moodInfo['color'] as Color).toARGB32().toRadixString(16);

    try {
      if (widget.existingThought != null) {
        await ref
            .read(thoughtDaoProvider)
            .updateThought(
              widget.existingThought!
                  .toCompanion(true)
                  .copyWith(
                    content: drift.Value(text),
                    mood: drift.Value(_selectedMood),
                    colorHex: drift.Value('#$color'),
                    isPinned: drift.Value(_isPinned),
                    promptQuestion: drift.Value(_activePrompt),
                  ),
            );
      } else {
        await ref
            .read(thoughtDaoProvider)
            .insertThought(
              ThoughtTableCompanion.insert(
                content: text,
                mood: drift.Value(_selectedMood),
                colorHex: drift.Value('#$color'),
                isPinned: drift.Value(_isPinned),
                promptQuestion: drift.Value(_activePrompt),
              ),
            );
        await _clearDraft();
      }

      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              widget.existingThought != null
                  ? 'Updated reflection in Mind Space'
                  : 'Pinned to your Thought Wall',
            ),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _isSaving = false;
          _saveError = 'Could not save this thought. Please try again.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
        child: Container(
          decoration: BoxDecoration(
            color: (context.isDark
                    ? const Color(0xFF10141D)
                    : const Color(0xFFF8FAFC))
                .withValues(alpha: 0.90),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(
              color: g.edge.withValues(alpha: 0.4),
              width: 1.0,
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
                      color: context.accentPrimary.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: context.accentPrimary.withValues(alpha: 0.3),
                      ),
                    ),
                    child: Icon(
                      Icons.psychology_alt_rounded,
                      color: context.accentPrimary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.existingThought != null
                              ? 'Edit Reflection'
                              : 'Drop on Thought Wall',
                          style: AscentTextStyles.headlineMedium.copyWith(
                            color: context.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          widget.existingThought != null
                              ? 'Refine your thoughts in Mind Space.'
                              : 'Honest talk from you, to you.',
                          style: AscentTextStyles.bodySmall.copyWith(
                            color: context.textMuted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: Icon(
                      _isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      color: _isPinned
                          ? context.accentPrimary
                          : context.textMuted,
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

              // Self-reflection prompts
              InkWell(
                onTap: _cyclePrompt,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 9,
                  ),
                  decoration: BoxDecoration(
                    color: context.bgBase,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.divider),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 15,
                        color: context.accentPrimary,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _activePrompt ??
                              'Tap for a thoughtful self-reflection prompt ›',
                          style: AscentTextStyles.bodySmall.copyWith(
                            color: _activePrompt != null
                                ? context.textPrimary
                                : context.textMuted,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.refresh_rounded,
                        size: 14,
                        color: context.textMuted,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 12),

              // Mood / Tag Selector
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _availableMoods.map((m) {
                    final isSelected = _selectedMood == m['key'];
                    final color = m['color'] as Color;
                    final icon = m['icon'] as IconData;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        selected: isSelected,
                        showCheckmark: false,
                        label: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              icon,
                              size: 14,
                              color: isSelected ? color : context.textMuted,
                            ),
                            const SizedBox(width: 6),
                            Text(m['label'] as String),
                          ],
                        ),
                        backgroundColor: context.bgBase,
                        selectedColor: color.withValues(alpha: 0.14),
                        labelStyle: AscentTextStyles.labelMedium.copyWith(
                          color: isSelected ? color : context.textMuted,
                          fontWeight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                        ),
                        side: BorderSide(
                          color: isSelected ? color : context.divider,
                          width: isSelected ? 1.5 : 1,
                        ),
                        onSelected: (val) {
                          HapticFeedback.lightImpact();
                          setState(
                            () => _selectedMood = m['key'] as String,
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              if (_isDraftRestored) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: context.accentPrimary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.history_rounded,
                        size: 13,
                        color: context.accentPrimary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Draft restored',
                        style: AscentTextStyles.captionMedium.copyWith(
                          color: context.accentPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () async {
                          _contentController.clear();
                          await _clearDraft();
                          if (mounted) setState(() => _isDraftRestored = false);
                        },
                        child: Text(
                          'Clear',
                          style: AscentTextStyles.captionMedium.copyWith(
                            color: context.textMuted,
                            fontSize: 11,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 10),

              if (_saveError != null) ...[
                Text(
                  _saveError!,
                  style: AscentTextStyles.bodySmall.copyWith(
                    color: Colors.redAccent,
                  ),
                ),
                const SizedBox(height: 8),
              ],

              // Content TextField
              TextField(
                controller: _contentController,
                autofocus: true,
                readOnly: false,
                maxLines: 4,
                style: AscentTextStyles.bodyMedium.copyWith(
                  color: context.textPrimary,
                  height: 1.4,
                ),
                decoration: InputDecoration(
                  hintText:
                      'Speak your mind freely... unfiltered reflections, moments of clarity, or what you want to remember.',
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
                    borderSide: BorderSide(
                      color: context.accentPrimary,
                      width: 1.5,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 18),

              // Submit Button
              AscentButton.primary(
                label: _isSaving
                    ? 'Saving…'
                    : widget.existingThought != null
                    ? 'Save Changes'
                    : (_isPinned
                          ? 'Pin to Wall (Pinned)'
                          : 'Pin to Thought Wall'),
                expanded: true,
                icon: widget.existingThought != null
                    ? Icons.check_rounded
                    : Icons.push_pin_rounded,
                onPressed: _isSaving ? null : _saveThought,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
