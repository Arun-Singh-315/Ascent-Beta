import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../models/promise_model.dart';
import '../providers/promise_providers.dart';
import '../services/promise_intent_parser.dart';
import 'promise_proposal_card.dart';

/// Chat-first Promise Composer dialog.
/// Minimal interaction, low writing friction, intelligent coaching reflection,
/// and instant deterministic fallback.
class PromiseChatComposer extends ConsumerStatefulWidget {
  const PromiseChatComposer({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const PromiseChatComposer(),
    );
  }

  @override
  ConsumerState<PromiseChatComposer> createState() => _PromiseChatComposerState();
}

class _PromiseChatComposerState extends ConsumerState<PromiseChatComposer> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();
  final _scrollController = ScrollController();

  final List<_ChatMessage> _messages = [];
  PromiseProposal? _currentProposal;
  bool _isSaving = false;

  int _selectedCategoryIndex = 0;
  final List<String> _categories = const ['All', 'Health', 'Peace', 'Habits', 'Growth', 'Family'];

  static const List<Map<String, String>> _allSuggestions = [
    {
      'category': 'Health',
      'text': 'I want to drink 2 litres of water every day',
      'subtitle': 'Build daily cellular hydration',
      'icon': 'water_drop_outlined',
    },
    {
      'category': 'Health',
      'text': 'I want to exercise or stretch 4 times a week',
      'subtitle': 'Physical vitality and energy',
      'icon': 'fitness_center_rounded',
    },
    {
      'category': 'Health',
      'text': 'I want to walk 8,000 steps daily',
      'subtitle': 'Consistent low-impact movement',
      'icon': 'directions_walk_rounded',
    },
    {
      'category': 'Peace',
      'text': 'I want to meditate for 10 minutes every morning',
      'subtitle': 'Calm awareness before the day starts',
      'icon': 'self_improvement_rounded',
    },
    {
      'category': 'Peace',
      'text': 'I want to write in my gratitude journal every night',
      'subtitle': 'Reflect on 3 wins each day',
      'icon': 'edit_note_rounded',
    },
    {
      'category': 'Habits',
      'text': 'I want to stop wasting time scrolling at night',
      'subtitle': 'Screens off 30 minutes before sleep',
      'icon': 'bedtime_outlined',
    },
    {
      'category': 'Growth',
      'text': 'I want to read 20 pages of a book before bed',
      'subtitle': 'Compound knowledge and quiet focus',
      'icon': 'menu_book_rounded',
    },
    {
      'category': 'Growth',
      'text': 'I want to spend 45 minutes on focused learning every day',
      'subtitle': 'Dedicated undistracted deep work',
      'icon': 'school_outlined',
    },
    {
      'category': 'Family',
      'text': 'I promise myself to call my parents every Sunday',
      'subtitle': 'Nurture bonds that matter most',
      'icon': 'favorite_border_rounded',
    },
  ];

  final List<String> _promptPlaceholders = const [
    'I want to drink 2 litres of water every day',
    'I want to exercise 4 times a week',
    'I promise myself to call my parents every Sunday',
    'I want to stop scrolling at night',
    'I want to read 20 pages before bed',
    'I want to meditate for 10 minutes, keep this private',
  ];
  int _placeholderIndex = 0;
  Timer? _placeholderTimer;

  @override
  void initState() {
    super.initState();
    _placeholderTimer = Timer.periodic(const Duration(seconds: 4), (_) {
      if (mounted) {
        setState(() {
          _placeholderIndex = (_placeholderIndex + 1) % _promptPlaceholders.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _placeholderTimer?.cancel();
    _inputController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _handleSubmit() {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    HapticFeedback.lightImpact();
    _inputController.clear();

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));

      if (_currentProposal == null) {
        // Initial commitment parse
        _currentProposal = PromiseIntentParser.parse(text);
      } else {
        // Natural language edit / adjustment
        _currentProposal = PromiseIntentParser.applyAdjustment(_currentProposal!, text);
      }
    });

    _scrollToBottom();
  }

  void _handleInlineModify(String prompt) {
    setState(() {
      _messages.add(_ChatMessage(text: prompt, isUser: true));
      if (_currentProposal != null) {
        _currentProposal = PromiseIntentParser.applyAdjustment(_currentProposal!, prompt);
      }
    });
    _scrollToBottom();
  }

  Future<void> _handleAccept() async {
    if (_currentProposal == null || _isSaving) return;

    setState(() => _isSaving = true);
    HapticFeedback.heavyImpact();

    try {
      final repo = ref.read(promiseRepositoryProvider);
      await repo.createPromise(
        title: _currentProposal!.title,
        intention: _currentProposal!.intention,
        category: _currentProposal!.category,
        trackingType: _currentProposal!.trackingType,
        targetValue: _currentProposal!.targetValue,
        unit: _currentProposal!.unit,
        frequencyPerWeek: _currentProposal!.frequencyPerWeek,
        targetDate: _currentProposal!.targetDate,
        isPrivate: _currentProposal!.isPrivate,
        reminderTime: _currentProposal!.reminderTime,
        reminderDays: _currentProposal!.reminderDays,
      );

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Promise sealed: "${_currentProposal!.title}"'),
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save promise right now. Please try again.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboardInset),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: screenHeight * 0.88,
        ),
        child: GlassSurface(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              // Apple Grab Handle
              Center(
                child: Container(
                  width: 38,
                  height: 4.5,
                  margin: const EdgeInsets.only(top: 10),
                  decoration: BoxDecoration(
                    color: g.ink.withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),

              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 16, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: g.ink.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        Icons.handshake_rounded,
                        size: 18,
                        color: g.ink,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'A promise to yourself',
                            style: AscentTextStyles.homeTitle.copyWith(
                              color: g.ink,
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            'Speak freely. We will turn it into a realistic rhythm.',
                            style: TextStyle(
                              color: g.inkMuted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded, color: g.inkMuted, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ),

              Divider(height: 1, color: g.ink.withValues(alpha: 0.08)),

              // Chat history or subtle suggestions
              Expanded(
                child: _messages.isEmpty && _currentProposal == null
                    ? _buildStarterView(g)
                    : ListView(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(16),
                        children: [
                          for (final msg in _messages) _buildMessageBubble(msg, g),
                          if (_currentProposal != null) ...[
                            const SizedBox(height: 10),
                            PromiseProposalCard(
                              proposal: _currentProposal!,
                              onAccept: _handleAccept,
                              onModify: _handleInlineModify,
                              isSaving: _isSaving,
                            ),
                          ],
                        ],
                      ),
              ),

              // Unified Single Enclosure Glass Input Bar (Rule 19 Compliant)
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                decoration: BoxDecoration(
                  color: g.bg.withValues(alpha: 0.75),
                  border: Border(
                    top: BorderSide(
                      color: g.edge.withValues(alpha: 0.12),
                      width: 0.8,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        height: 48,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: g.ink.withValues(alpha: 0.04),
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                            color: g.edge.withValues(alpha: 0.18),
                            width: 1,
                          ),
                        ),
                        child: Center(
                          child: TextField(
                            controller: _inputController,
                            focusNode: _focusNode,
                            style: TextStyle(color: g.ink, fontSize: 14.5),
                            maxLines: 1,
                            textInputAction: TextInputAction.send,
                            onSubmitted: (_) => _handleSubmit(),
                            decoration: InputDecoration(
                              border: InputBorder.none,
                              hintText: _currentProposal == null
                                  ? _promptPlaceholders[_placeholderIndex]
                                  : 'Adjust: e.g. "Make it 30 mins" or "Private"...',
                              hintStyle: TextStyle(
                                color: g.inkMuted.withValues(alpha: 0.6),
                                fontSize: 13.5,
                              ),
                              isDense: true,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _handleSubmit,
                      borderRadius: BorderRadius.circular(24),
                      child: Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: g.ink,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: g.ink.withValues(alpha: 0.18),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: g.bg,
                          size: 22,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStarterView(AscentGlass g) {
    final selectedCategory = _categories[_selectedCategoryIndex];
    final filtered = selectedCategory == 'All'
        ? _allSuggestions
        : _allSuggestions.where((s) => s['category'] == selectedCategory).toList();

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Category Selector Pills
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: List.generate(_categories.length, (index) {
                final cat = _categories[index];
                final isSelected = index == _selectedCategoryIndex;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: InkWell(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedCategoryIndex = index);
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? g.ink
                            : g.ink.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: isSelected
                              ? g.ink
                              : g.edge.withValues(alpha: 0.12),
                          width: 1,
                        ),
                      ),
                      child: Text(
                        cat,
                        style: TextStyle(
                          color: isSelected ? g.bg : g.ink,
                          fontSize: 12.5,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 18),

          Text(
            'Try committing to something meaningful:',
            style: TextStyle(
              color: g.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 12),

          // Apple Glass Suggestion Cards
          for (final suggestion in filtered)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _inputController.text = suggestion['text']!;
                  _handleSubmit();
                },
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: g.fill.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: g.edge.withValues(alpha: 0.14),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.02),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: g.ink.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(
                          _iconDataFor(suggestion['icon']!),
                          size: 18,
                          color: g.ink,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              suggestion['text']!,
                              style: TextStyle(
                                color: g.ink,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            if (suggestion['subtitle'] != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                suggestion['subtitle']!,
                                style: TextStyle(
                                  color: g.inkMuted,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        Icons.arrow_forward_ios_rounded,
                        size: 13,
                        color: g.inkMuted.withValues(alpha: 0.5),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  IconData _iconDataFor(String iconName) {
    switch (iconName) {
      case 'water_drop_outlined':
        return Icons.water_drop_outlined;
      case 'fitness_center_rounded':
        return Icons.fitness_center_rounded;
      case 'directions_walk_rounded':
        return Icons.directions_walk_rounded;
      case 'self_improvement_rounded':
        return Icons.self_improvement_rounded;
      case 'edit_note_rounded':
        return Icons.edit_note_rounded;
      case 'bedtime_outlined':
        return Icons.bedtime_outlined;
      case 'menu_book_rounded':
        return Icons.menu_book_rounded;
      case 'school_outlined':
        return Icons.school_outlined;
      case 'favorite_border_rounded':
        return Icons.favorite_border_rounded;
      default:
        return Icons.handshake_outlined;
    }
  }

  Widget _buildMessageBubble(_ChatMessage msg, AscentGlass g) {
    return Align(
      alignment: msg.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: const BoxConstraints(maxWidth: 280),
        decoration: BoxDecoration(
          color: msg.isUser ? g.ink : g.ink.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          msg.text,
          style: TextStyle(
            color: msg.isUser ? g.bg : g.ink,
            fontSize: 13.5,
          ),
        ),
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({
    required this.text,
    required this.isUser,
  });

  final String text;
  final bool isUser;
}
