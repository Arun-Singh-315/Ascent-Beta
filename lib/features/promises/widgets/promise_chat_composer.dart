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

  final List<String> _promptPlaceholders = const [
    'I want to study Spring Boot for 45 minutes every day',
    'I want to go to the gym 4 times a week',
    'I promise myself to call my parents every Sunday',
    'I want to stop wasting time scrolling at night',
    'I want to finish this course by the end of November',
    'I want to meditate for 15 minutes, keep this private',
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
              // Header
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
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

              // Composer input bar
              Container(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
                decoration: BoxDecoration(
                  color: g.bg.withValues(alpha: 0.6),
                  border: Border(
                    top: BorderSide(
                      color: g.ink.withValues(alpha: 0.08),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14),
                        decoration: BoxDecoration(
                          color: g.ink.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: g.ink.withValues(alpha: 0.1),
                            width: 1,
                          ),
                        ),
                        child: TextField(
                          controller: _inputController,
                          focusNode: _focusNode,
                          style: TextStyle(color: g.ink, fontSize: 14),
                          maxLines: 3,
                          minLines: 1,
                          textInputAction: TextInputAction.send,
                          onSubmitted: (_) => _handleSubmit(),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: _currentProposal == null
                                ? 'What do you want to commit to?'
                                : 'Adjust: e.g. "Make it 30 mins" or "Private"...',
                            hintStyle: TextStyle(
                              color: g.inkMuted.withValues(alpha: 0.55),
                              fontSize: 13.5,
                            ),
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    InkWell(
                      onTap: _handleSubmit,
                      borderRadius: BorderRadius.circular(22),
                      child: Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: g.ink,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_upward_rounded,
                          color: g.bg,
                          size: 20,
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
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Try saying something like:',
            style: TextStyle(
              color: g.inkMuted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 14),
          for (final suggestion in _promptPlaceholders.take(4))
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  _inputController.text = suggestion;
                  _handleSubmit();
                },
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  decoration: BoxDecoration(
                    color: g.ink.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: g.ink.withValues(alpha: 0.07),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.chat_bubble_outline_rounded,
                        size: 15,
                        color: g.inkMuted,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          suggestion,
                          style: TextStyle(
                            color: g.ink,
                            fontSize: 13,
                          ),
                        ),
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
