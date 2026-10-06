import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart' as drift;

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/ai/ai_service.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
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

  final List<String> _quickPrompts = const [
    'Plan my day',
    'Spent ₹120 on lunch',
    'Remind me to study Java tomorrow',
    'Show my progress and insights',
    'Explain Dynamic Programming',
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

    // 1. Insert user message
    await aiDao.insertMessage(
      AiChatMessageTableCompanion.insert(
        sender: 'user',
        message: prompt,
      ),
    );
    _scrollToBottom();

    // 2. Process via Local Deterministic AI Engine
    final engine = ref.read(aiEngineProvider);
    final response = await engine.processUserPrompt(prompt, ref);

    // 3. Serialize proposed action if any
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

    // 4. Save assistant response
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

  Future<void> _executeApprovedAction(String actionType, Map<String, dynamic> actionData) async {
    final payload = actionData['payload'] as Map<String, dynamic>? ?? {};

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
            content: Text('Expense ₹${amt.toStringAsFixed(0)} saved to database!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (actionType == AiActionType.taskCreated.name) {
      final title = payload['title']?.toString() ?? 'Task';
      final planned = payload['plannedDate'] != null ? DateTime.parse(payload['plannedDate']) : DateTime.now();
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
            content: Text('Task "$title" added to your task board!'),
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
            content: Text('💧 +$ml mL water logged! Keep hydrating.'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (actionType == AiActionType.dailyPlanSuggested.name) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Daily Life Plan confirmed! Check your Home overview.'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final messagesStream = ref.watch(aiAssistantDaoProvider).watchRecentMessages();

    return Scaffold(
      backgroundColor: context.bgBase,
      appBar: AppBar(
        backgroundColor: context.bgBase,
        elevation: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'AI Life Assistant',
              style: AscentTextStyles.displaySmall.copyWith(color: context.textPrimary, fontSize: 18),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.accentPrimary,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  'Local On-Device Engine • 100% Free & Private',
                  style: TextStyle(fontSize: 10, color: context.textMuted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.delete_sweep_outlined, color: context.textMuted),
            tooltip: 'Clear Chat History',
            onPressed: () async {
              await ref.read(aiAssistantDaoProvider).clearChatHistory();
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Column(
        children: [
          // ── Chat Stream List ─────────────────────────────────────────────
          Expanded(
            child: StreamBuilder<List<AiChatMessage>>(
              stream: messagesStream,
              builder: (context, snapshot) {
                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      const SizedBox(height: 24),
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: context.accentPrimary.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(Icons.auto_awesome_rounded, color: context.accentPrimary, size: 32),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your Personal AI Life Planner',
                        textAlign: TextAlign.center,
                        style: AscentTextStyles.headlineMedium.copyWith(color: context.textPrimary),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Ask me in natural language to plan your day, log an expense, add study tasks, or give you real-time insights from your database.',
                        textAlign: TextAlign.center,
                        style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Try asking:',
                        style: AscentTextStyles.labelSmall.copyWith(color: context.textMuted, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 10),
                      ..._quickPrompts.map((p) => Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: InkWell(
                              onTap: () => _handleSubmitted(p),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(
                                  color: context.bgSurface,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: context.divider),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.chat_bubble_outline_rounded, size: 16, color: context.accentPrimary),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        p,
                                        style: AscentTextStyles.bodyMedium.copyWith(color: context.textPrimary),
                                      ),
                                    ),
                                    Icon(Icons.arrow_forward_rounded, size: 14, color: context.textMuted),
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
                          Container(
                            constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.82),
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            decoration: BoxDecoration(
                              color: isUser ? context.accentPrimary : context.bgSurface,
                              borderRadius: BorderRadius.circular(14),
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

                          // Interactive Proposed Action Card
                          if (!isUser && msg.actionType != null && actionData != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.85),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: context.accentPrimary.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: context.accentPrimary.withValues(alpha: 0.3)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.bolt_rounded, size: 16, color: context.accentPrimary),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          actionData['title']?.toString() ?? 'Action Proposed',
                                          style: AscentTextStyles.labelMedium.copyWith(
                                            color: context.textPrimary,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    actionData['summary']?.toString() ?? '',
                                    style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                                  ),
                                  const SizedBox(height: 10),
                                  AscentButton.primary(
                                    label: 'Approve & Save',
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
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: context.accentPrimary),
                ),
              ),
            ),

          // ── Bottom Quick Suggestion Strip ─────────────────────────────────
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

          // ── Text Input Bar ───────────────────────────────────────────────
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
                        hintText: 'Ask AI or type an action...',
                        hintStyle: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
                        filled: true,
                        fillColor: context.bgBase,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(20),
                          borderSide: BorderSide(color: context.divider),
                        ),
                      ),
                      onSubmitted: _handleSubmitted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.send_rounded, color: context.accentPrimary),
                    onPressed: () => _handleSubmitted(_textController.text),
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
