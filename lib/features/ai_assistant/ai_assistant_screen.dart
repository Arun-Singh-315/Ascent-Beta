import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' as drift;
import 'package:intl/intl.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/ai/ai_service.dart';
import '../../core/database/app_database.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/widgets/ascent_button.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;

  List<String> get _quickPrompts => [
    'Plan my day',
    'Spent ₹120 on lunch',
    'Remind me to study tomorrow',
    'How am I doing today?',
    'Log 500ml water',
  ];

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

  Future<void> _handleSubmitted(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _isLoading) return;

    _textController.clear();
    setState(() => _isLoading = true);

    final aiDao = ref.read(aiAssistantDaoProvider);
    final name = ref.read(assistantNameProvider);

    // 1. Insert user message
    await aiDao.insertMessage(
      AiChatMessageTableCompanion.insert(
        sender: 'user',
        message: prompt,
      ),
    );
    _scrollToBottom();

    // 2. Check for reminder intent first (handled locally without full AI engine)
    final lower = prompt.toLowerCase();
    if (lower.startsWith('remind') || lower.contains('remind me')) {
      await _processReminderIntent(prompt, name);
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
      return;
    }

    // 3. Process via Local Deterministic AI Engine
    final engine = ref.read(aiEngineProvider);
    final response = await engine.processUserPrompt(prompt, ref);

    // 4. Serialize proposed action if any
    String? actionType;
    String? actionPayload;
    if (response.proposedAction != null) {
      actionType = response.proposedAction!.type.name;
      actionPayload = jsonEncode({
        'title': response.proposedAction!.title,
        'summary': response.proposedAction!.summary,
        'payload': response.proposedAction!.payload,
      });
    }

    // 5. Save assistant response
    await aiDao.insertMessage(
      AiChatMessageTableCompanion.insert(
        sender: 'assistant',
        message: response.text,
        actionType: drift.Value(actionType),
        actionPayloadJson: drift.Value(actionPayload),
      ),
    );

    if (mounted) {
      setState(() => _isLoading = false);
      _scrollToBottom();
    }
  }

  Future<void> _processReminderIntent(String text, String assistantName) async {
    final lower = text.toLowerCase();

    Duration offset = const Duration(minutes: 30);
    final minMatch = RegExp(r'in\s+(\d+)\s*(?:mins?|minutes?|m\b)', caseSensitive: false).firstMatch(lower);
    final hourMatch = RegExp(r'in\s+(\d+)\s*(?:hours?|hrs?|h\b)', caseSensitive: false).firstMatch(lower);

    if (minMatch != null) {
      final mins = int.tryParse(minMatch.group(1) ?? '30') ?? 30;
      offset = Duration(minutes: mins);
    } else if (hourMatch != null) {
      final hrs = int.tryParse(hourMatch.group(1) ?? '1') ?? 1;
      offset = Duration(hours: hrs);
    }

    String title = text;
    final remindToMatch = RegExp(r'remind\s+(?:me\s+)?(?:to\s+)?(.+?)(?:\s+in\s+\d+|\s+at\s+|$)', caseSensitive: false).firstMatch(text);
    if (remindToMatch != null) {
      title = remindToMatch.group(1)?.trim() ?? text;
    }
    if (title.isEmpty) title = 'Task reminder';
    if (title.isNotEmpty) title = title[0].toUpperCase() + title.substring(1);

    final scheduledAt = DateTime.now().add(offset);
    final reminderDao = ref.read(reminderDaoProvider);

    final id = await reminderDao.insertReminder(
      ReminderTableCompanion.insert(
        title: title,
        scheduledAt: scheduledAt,
        isActive: const drift.Value(true),
      ),
    );

    try {
      await NotificationService.instance.scheduleReminderNotification(
        id: id,
        title: title,
        scheduledAt: scheduledAt,
      );
    } catch (_) {}

    final timeStr = DateFormat('HH:mm').format(scheduledAt);
    final replyText = '$assistantName: Scheduled reminder "$title" for today at $timeStr. I\'ll notify you on time.';

    final aiDao = ref.read(aiAssistantDaoProvider);
    await aiDao.insertMessage(
      AiChatMessageTableCompanion.insert(
        sender: 'assistant',
        message: replyText,
      ),
    );
  }

  Future<void> _executeApprovedAction(String actionType, Map<String, dynamic> actionData) async {
    final payload = actionData['payload'] as Map<String, dynamic>? ?? {};
    final name = ref.read(assistantNameProvider);

    if (actionType == AiActionType.expenseLogged.name) {
      final amt = (payload['amount'] as num?)?.toDouble() ?? 0.0;
      final title = payload['title']?.toString() ?? 'Expense';
      final cat = payload['category']?.toString() ?? 'Other';
      final acc = payload['account']?.toString() ?? 'UPI';

      await ref.read(financeDaoProvider).insertTransaction(
        FinanceTransactionTableCompanion.insert(
          title: title,
          amount: amt,
          category: drift.Value(cat),
          account: drift.Value(acc),
          date: DateTime.now(),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Expense ₹${amt.toStringAsFixed(0)} saved!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (actionType == AiActionType.taskCreated.name) {
      final title = payload['title']?.toString() ?? 'Task';
      final planned = payload['plannedDate'] != null
          ? DateTime.parse(payload['plannedDate'])
          : DateTime.now();
      final priority = payload['priority']?.toString() ?? 'medium';

      await ref.read(taskDaoProvider).insertTask(
        TaskTableCompanion.insert(
          title: title,
          plannedDate: drift.Value(planned),
          priority: drift.Value(priority),
        ),
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Task "$title" added!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (actionType == AiActionType.waterLogged.name) {
      final ml = (payload['amountMl'] as num?)?.toInt() ?? 250;
      await ref.read(waterDaoProvider).addWater(ml);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$name: +$ml mL water logged! 💧'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (actionType == AiActionType.dailyPlanSuggested.name) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily plan noted! Check your Activity Hub.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(assistantNameProvider);
    final messagesStream = ref.watch(aiAssistantDaoProvider).watchRecentMessages();
    final accentColor = const Color(0xFF4A90E2);

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        backgroundColor: context.bgBase,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: context.textPrimary),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Row(
          children: [
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.auto_awesome_rounded, color: accentColor, size: 16),
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: GoogleFonts.plusJakartaSans(
                    color: context.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  'On-device · Private · Free',
                  style: TextStyle(fontSize: 10, color: context.textMuted),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_sweep_outlined, color: context.textMuted, size: 20),
            tooltip: 'Clear chat history',
            onPressed: () async {
              await ref.read(aiAssistantDaoProvider).clearChatHistory();
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          // Chat stream
          Expanded(
            child: StreamBuilder<List<AiChatMessage>>(
              stream: messagesStream,
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 16),
                      Center(
                        child: Container(
                          width: 60,
                          height: 60,
                          decoration: BoxDecoration(
                            color: accentColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.auto_awesome_rounded, color: accentColor, size: 28),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Hi, I\'m $name!',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.plusJakartaSans(
                          color: context.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Your personal AI assistant. I can log expenses, add tasks, track water, plan your day, and more — all on your device, completely private.',
                        textAlign: TextAlign.center,
                        style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted, height: 1.45),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'Try asking:',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: context.textMuted,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      ..._quickPrompts.map((p) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: InkWell(
                          onTap: () => _handleSubmitted(p),
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
                            decoration: BoxDecoration(
                              color: context.bgSurface,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: context.divider),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.chat_bubble_outline_rounded, size: 15, color: accentColor),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    p,
                                    style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                                  ),
                                ),
                                Icon(Icons.arrow_forward_rounded, size: 13, color: context.textMuted),
                              ],
                            ),
                          ),
                        ),
                      )),
                    ],
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    final isUser = msg.sender == 'user';

                    Map<String, dynamic>? actionData;
                    if (msg.actionPayloadJson != null) {
                      try {
                        actionData = jsonDecode(msg.actionPayloadJson!);
                      } catch (_) {}
                    }

                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Column(
                        crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                        children: [
                          if (!isUser) ...[
                            Padding(
                              padding: const EdgeInsets.only(left: 2, bottom: 4),
                              child: Text(
                                name,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: accentColor,
                                ),
                              ),
                            ),
                          ],
                          Container(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.of(context).size.width * 0.82,
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isUser ? accentColor : context.bgSurface,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(14),
                                topRight: const Radius.circular(14),
                                bottomLeft: Radius.circular(isUser ? 14 : 4),
                                bottomRight: Radius.circular(isUser ? 4 : 14),
                              ),
                              border: isUser ? null : Border.all(color: context.divider),
                            ),
                            child: Text(
                              msg.message,
                              style: AscentTextStyles.bodyMedium.copyWith(
                                color: isUser ? Colors.white : context.textPrimary,
                                height: 1.4,
                              ),
                            ),
                          ),

                          // Action confirmation card
                          if (!isUser && msg.actionType != null && actionData != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.85,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: accentColor.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: accentColor.withValues(alpha: 0.25)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.bolt_rounded, size: 15, color: accentColor),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          actionData['title']?.toString() ?? 'Action proposed',
                                          style: AscentTextStyles.labelMedium.copyWith(
                                            color: context.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  if (actionData['summary'] != null) ...[
                                    const SizedBox(height: 3),
                                    Text(
                                      actionData['summary'].toString(),
                                      style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  AscentButton.primary(
                                    label: 'Confirm & Save',
                                    compact: true,
                                    onPressed: () => _executeApprovedAction(msg.actionType!, actionData!),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),

          if (_isLoading)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Row(
                children: [
                  const SizedBox(width: 16),
                  SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$name is thinking...',
                    style: TextStyle(fontSize: 12, color: context.textMuted),
                  ),
                ],
              ),
            ),

          // Quick suggestion chips
          SizedBox(
            height: 38,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: _quickPrompts.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final prompt = _quickPrompts[index];
                return ActionChip(
                  label: Text(prompt, style: const TextStyle(fontSize: 11)),
                  backgroundColor: context.bgSurface,
                  side: BorderSide(color: context.divider),
                  onPressed: () => _handleSubmitted(prompt),
                );
              },
            ),
          ),
          const SizedBox(height: 6),

          // Text input bar
          SafeArea(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: context.bgSurface,
                border: Border(top: BorderSide(color: context.divider)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _textController,
                      style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                      decoration: InputDecoration(
                        hintText: 'Message $name...',
                        hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                        filled: true,
                        fillColor: context.bgBase,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: context.divider),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: context.divider),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: accentColor),
                        ),
                      ),
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () => _handleSubmitted(_textController.text),
                    child: Container(
                      width: 38,
                      height: 38,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.send_rounded, size: 17, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
