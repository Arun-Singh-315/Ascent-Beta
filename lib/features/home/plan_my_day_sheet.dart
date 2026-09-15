import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../shared/widgets/chat_bubble_card.dart';

class CapturedPlanItem {
  final String title;
  final String category;
  final int estimatedMinutes;

  const CapturedPlanItem({
    required this.title,
    required this.category,
    required this.estimatedMinutes,
  });
}

class _ChatMessage {
  final String text;
  final bool isUser;
  final CapturedPlanItem? capturedItem;

  const _ChatMessage({
    required this.text,
    required this.isUser,
    this.capturedItem,
  });
}

/// On-device deterministic categorizer and duration extractor (§4.2).
class PlanMyDayClassifier {
  static final _dsaKeywords = RegExp(
    r'\b(leetcode|dsa|tree|graph|dp|dynamic programming|array|string|binary search|linked list|recursion|backtracking|greedy|neetcode|codeforces|algo|algorithm|problem|problems)\b',
    caseSensitive: false,
  );

  static final _pipelineKeywords = RegExp(
    r'\b(apply|application|resume|cv|recruiter|cold email|reach out|interview|follow up|job|referral|hiring|portal|company|screening)\b',
    caseSensitive: false,
  );

  static final _breakKeywords = RegExp(
    r'\b(break|movie|game|gaming|walk|gym|lunch|dinner|snack|relax|music|nap|rest|tea|coffee)\b',
    caseSensitive: false,
  );

  static final _studyKeywords = RegExp(
    r'\b(study|revise|learn|read|system design|hld|lld|oops|dbms|sql|operating system|course|video|lecture|chapter|book|mock|prep)\b',
    caseSensitive: false,
  );

  static CapturedPlanItem parse(String input) {
    final text = input.trim();

    // 1. Detect duration
    int duration = 30; // default reasonable block
    final hourMatch = RegExp(r'(\d+(?:\.\d+)?)\s*(?:hours?|hrs?|h\b)', caseSensitive: false).firstMatch(text);
    final minMatch = RegExp(r'(\d+)\s*(?:mins?|minutes?|m\b)', caseSensitive: false).firstMatch(text);

    if (hourMatch != null) {
      final hrs = double.tryParse(hourMatch.group(1) ?? '1') ?? 1.0;
      duration = (hrs * 60).round();
    } else if (minMatch != null) {
      duration = int.tryParse(minMatch.group(1) ?? '30') ?? 30;
    }

    // 2. Clean title: strip duration text if clean
    var cleanedTitle = text
        .replaceAll(RegExp(r'\b(?:for\s+)?\d+(?:\.\d+)?\s*(?:hours?|hrs?|h\b|mins?|minutes?|m\b)', caseSensitive: false), '')
        .trim();
    if (cleanedTitle.isEmpty) {
      cleanedTitle = text;
    }

    // Capitalize first letter
    cleanedTitle = cleanedTitle[0].toUpperCase() + cleanedTitle.substring(1);

    // 3. Detect category
    String category = 'General';
    if (_dsaKeywords.hasMatch(text)) {
      category = 'DSA';
    } else if (_pipelineKeywords.hasMatch(text)) {
      category = 'Pipeline';
    } else if (_studyKeywords.hasMatch(text)) {
      category = 'Study';
    } else if (_breakKeywords.hasMatch(text)) {
      category = 'Break';
    }

    return CapturedPlanItem(
      title: cleanedTitle,
      category: category,
      estimatedMinutes: duration,
    );
  }
}

class PlanMyDaySheet extends ConsumerStatefulWidget {
  const PlanMyDaySheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const PlanMyDaySheet(),
    );
  }

  @override
  ConsumerState<PlanMyDaySheet> createState() => _PlanMyDaySheetState();
}

class _PlanMyDaySheetState extends ConsumerState<PlanMyDaySheet> {
  final TextEditingController _textController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final List<_ChatMessage> _messages = [];
  final List<CapturedPlanItem> _capturedItems = [];
  bool _isCommitting = false;

  @override
  void initState() {
    super.initState();
    _messages.add(const _ChatMessage(
      text: "Hey! What's on your plate today?\nType what you want to get done (e.g., 'Revise DP patterns 45 min', 'Apply to Stripe') and I'll queue them up for you.",
      isUser: false,
    ));
  }

  @override
  void dispose() {
    _textController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  void _sendMessage() {
    final text = _textController.text.trim();
    if (text.isEmpty) return;

    _textController.clear();
    final parsed = PlanMyDayClassifier.parse(text);

    setState(() {
      _messages.add(_ChatMessage(text: text, isUser: true));
      _capturedItems.add(parsed);
      _messages.add(_ChatMessage(
        text: "Added to today's activities: \"${parsed.title}\" (${parsed.category}, ~${parsed.estimatedMinutes}m)",
        isUser: false,
        capturedItem: parsed,
      ));
    });

    _scrollToBottom();
  }

  Future<void> _commitAndClose() async {
    if (_capturedItems.isEmpty) {
      Navigator.of(context).pop();
      return;
    }

    setState(() => _isCommitting = true);
    final taskDao = ref.read(taskDaoProvider);
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);

    for (final item in _capturedItems) {
      await taskDao.insertTask(
        TaskTableCompanion.insert(
          title: item.title,
          plannedDate: drift.Value(startOfToday),
          estimatedMinutes: drift.Value(item.estimatedMinutes),
          priority: drift.Value(item.category == 'DSA' || item.category == 'Pipeline' ? 'high' : 'normal'),
          notes: drift.Value('Category: ${item.category}'),
        ),
      );
    }

    ref.invalidate(todayFocusTaskProvider);
    if (mounted) {
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Added ${_capturedItems.length} activities to your day!'),
          backgroundColor: Theme.of(context).colorScheme.primary,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: context.bgSurface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          children: [
            // Handle bar
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: context.divider,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // Header
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: context.accentPrimary.withValues(alpha: 0.12),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(Icons.chat_bubble_outline_rounded, color: context.accentPrimary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Plan My Day',
                          style: AscentTextStyles.labelLarge.copyWith(
                            color: context.textPrimary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'WhatsApp-style fast capture',
                          style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                        ),
                      ],
                    ),
                  ),
                  if (_capturedItems.isNotEmpty)
                    TextButton.icon(
                      onPressed: _isCommitting ? null : _commitAndClose,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text('Done (${_capturedItems.length})'),
                      style: TextButton.styleFrom(
                        foregroundColor: context.accentPrimary,
                        textStyle: AscentTextStyles.labelMedium.copyWith(fontWeight: FontWeight.bold),
                      ),
                    )
                  else
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      color: context.textMuted,
                    ),
                ],
              ),
            ),
            const Divider(height: 1),

            // Chat conversation
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  if (msg.isUser) {
                    return Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12, left: 48),
                        child: ChatBubbleCard(
                          tailPosition: BubbleTailPosition.bottomRight,
                          accentTint: context.accentPrimary,
                          borderColor: context.accentPrimary.withValues(alpha: 0.4),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Text(
                            msg.text,
                            style: AscentTextStyles.bodyMedium.copyWith(
                              color: context.textPrimary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ),
                    );
                  } else {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12, right: 48),
                        child: ChatBubbleCard(
                          tailPosition: BubbleTailPosition.bottomLeft,
                          accentTint: context.accentInfo,
                          borderColor: context.divider,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                msg.capturedItem != null
                                    ? Icons.add_task_rounded
                                    : Icons.assistant_rounded,
                                size: 18,
                                color: context.accentPrimary,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Text(
                                  msg.text,
                                  style: AscentTextStyles.bodySmall.copyWith(
                                    color: context.textPrimary,
                                    height: 1.4,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }
                },
              ),
            ),

            // Pinned chips of captured items so far
            if (_capturedItems.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                color: context.bgSurfaceElevated,
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _capturedItems.map((item) {
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Chip(
                          label: Text('${item.title} (~${item.estimatedMinutes}m)'),
                          labelStyle: AscentTextStyles.bodySmall.copyWith(fontSize: 11),
                          backgroundColor: context.bgBase,
                          deleteIcon: const Icon(Icons.close, size: 14),
                          onDeleted: () {
                            setState(() {
                              _capturedItems.remove(item);
                            });
                          },
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
            ],

            // Input bar
            Container(
              padding: EdgeInsets.fromLTRB(16, 10, 16, 10 + bottomInset),
              decoration: BoxDecoration(
                color: context.bgSurface,
                border: Border(top: BorderSide(color: context.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _sendMessage(),
                      decoration: InputDecoration(
                        hintText: "e.g., 'Solve 2 DP questions 45 mins'...",
                        hintStyle: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        filled: true,
                        fillColor: context.bgBase,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: context.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: context.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide(color: context.accentPrimary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    onPressed: _sendMessage,
                    style: IconButton.styleFrom(
                      backgroundColor: context.accentPrimary,
                      foregroundColor: context.textOnPrimary,
                      padding: const EdgeInsets.all(12),
                    ),
                    icon: const Icon(Icons.send_rounded, size: 18),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
