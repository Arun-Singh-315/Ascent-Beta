import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/text_styles.dart';
import '../../core/ai/ai_service.dart';
import '../../core/database/app_database.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({super.key});

  @override
  ConsumerState<AiAssistantScreen> createState() => _AiAssistantScreenState();
}

class _AiAssistantScreenState extends ConsumerState<AiAssistantScreen> {
  final _textController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isLoading = false;
  final Set<int> _executedActionMessageIds = {};

  List<String> get _quickPrompts => [
    'Plan my day',
    'Today\'s agenda',
    'Medicines',
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

    HapticFeedback.lightImpact();
    _textController.clear();
    setState(() => _isLoading = true);

    final aiDao = ref.read(aiAssistantDaoProvider);

    try {
      // 1. Insert user message with unique timestamp
      await aiDao.insertMessage(
        AiChatMessageTableCompanion.insert(
          sender: 'user',
          message: prompt,
        ),
      );
      _scrollToBottom();

      // 2. Process via Deterministic AI Engine (guarded with 5s timeout)
      final engine = ref.read(aiEngineProvider);
      final response = await engine.processUserPrompt(prompt, ref).timeout(
        const Duration(seconds: 5),
        onTimeout: () => const AiResponse(
          text: "I processed your request and checked your synced data. What would you like to plan or work on next?",
        ),
      );

      // 3. Auto-execute proposed action directly to control app features!
      String? actionType;
      String? actionPayload;
      if (response.proposedAction != null) {
        actionType = response.proposedAction!.type.name;
        final pData = {
          'title': response.proposedAction!.title,
          'summary': response.proposedAction!.summary,
          'payload': response.proposedAction!.payload,
          'quickOptions': response.clarifyingOptions,
        };
        actionPayload = jsonEncode(pData);

        // Directly execute action so feature control is instant and effortless!
        await _performAction(actionType, pData);
      } else if (response.clarifyingOptions.isNotEmpty) {
        actionPayload = jsonEncode({
          'quickOptions': response.clarifyingOptions,
        });
      }

      // 4. Save assistant response
      final assistantMsgId = await aiDao.insertMessage(
        AiChatMessageTableCompanion.insert(
          sender: 'assistant',
          message: response.text,
          actionType: drift.Value(actionType),
          actionPayloadJson: drift.Value(actionPayload),
        ),
      );

      if (actionType != null) {
        _executedActionMessageIds.add(assistantMsgId);
      }
    } catch (err) {
      await aiDao.insertMessage(
        AiChatMessageTableCompanion.insert(
          sender: 'assistant',
          message: "I encountered a minor glitch structuring that request. Let's try again — tap an option below or type what you need.",
          actionPayloadJson: drift.Value(jsonEncode({
            'quickOptions': ['Plan my day', 'Log 250ml water', 'Check activities'],
          })),
        ),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  Future<void> _performAction(String actionType, Map<String, dynamic> actionData) async {
    try {
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
      } else if (actionType == AiActionType.taskCreated.name || actionType == AiActionType.activityCreated.name) {
        final title = payload['title']?.toString() ?? 'Focus Activity';
        DateTime planned = DateTime.now();
        if (payload['plannedDate'] != null) {
          try {
            planned = DateTime.parse(payload['plannedDate']);
          } catch (_) {}
        }
        final priority = payload['priority']?.toString() ?? 'medium';
        final estimatedMinutes = (payload['estimatedMinutes'] as num?)?.toInt();

        await ref.read(taskDaoProvider).insertTask(
          TaskTableCompanion.insert(
            title: title,
            plannedDate: drift.Value(planned),
            priority: drift.Value(priority),
            estimatedMinutes: drift.Value(estimatedMinutes),
          ),
        );

        // Handle reminder if specified
        if (payload['reminderTime'] != null) {
          try {
            final reminderTime = DateTime.parse(payload['reminderTime']);
            final reminderId = await ref.read(reminderDaoProvider).insertReminder(
              ReminderTableCompanion.insert(
                title: title,
                scheduledAt: reminderTime,
                isActive: const drift.Value(true),
              ),
            );
            await NotificationService.instance.scheduleReminderNotification(
              id: reminderId,
              title: title,
              scheduledAt: reminderTime,
            );
          } catch (_) {}
        }
      } else if (actionType == AiActionType.lectureMarkedComplete.name) {
        final rawIds = payload['lectureIds'] as List?;
        final lectureIds = rawIds?.map((e) => (e as num).toInt()).toList() ?? [];
        for (final id in lectureIds) {
          ref.read(learningHubProvider.notifier).markLectureCompleted(id, completed: true);
        }
      } else if (actionType == AiActionType.waterLogged.name) {
        final ml = (payload['amountMl'] as num?)?.toInt() ?? 250;
        await ref.read(waterDaoProvider).addWater(ml);
      } else if (actionType == AiActionType.scheduleRearranged.name) {
        if (payload['taskId'] != null && payload['newDate'] != null) {
          try {
            final taskId = (payload['taskId'] as num).toInt();
            final newDate = DateTime.parse(payload['newDate']);
            final taskDao = ref.read(taskDaoProvider);
            await (taskDao.update(taskDao.taskTable)..where((t) => t.id.equals(taskId)))
                .write(TaskTableCompanion(plannedDate: drift.Value(newDate)));
          } catch (_) {}
        } else if (payload['taskIds'] != null && payload['newDate'] != null) {
          try {
            final taskIds = (payload['taskIds'] as List).map((e) => (e as num).toInt());
            final newDate = DateTime.parse(payload['newDate']);
            final taskDao = ref.read(taskDaoProvider);
            for (final tid in taskIds) {
              await (taskDao.update(taskDao.taskTable)..where((t) => t.id.equals(tid)))
                  .write(TaskTableCompanion(plannedDate: drift.Value(newDate)));
            }
          } catch (_) {}
        }
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final name = ref.watch(assistantNameProvider);
    final messagesStream = ref.watch(aiAssistantDaoProvider).watchRecentMessages();
    final accentColor = context.accentPrimary;

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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.15),
                border: Border.all(color: accentColor.withValues(alpha: 0.3)),
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
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF0C1017)
              : const Color(0xFFF8FAFC),
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: Theme.of(context).brightness == Brightness.dark
                ? [
                    const Color(0xFF101724),
                    const Color(0xFF0B0F17),
                  ]
                : [
                    const Color(0xFFFFFFFF),
                    const Color(0xFFF1F5F9),
                  ],
          ),
        ),
        child: Column(
          children: [
          // Chat stream
          Expanded(
            child: StreamBuilder<List<AiChatMessage>>(
              stream: messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Text(
                        'Connecting to memory...',
                        style: TextStyle(color: context.textMuted, fontSize: 13),
                      ),
                    ),
                  );
                }

                final messages = snapshot.data ?? [];

                if (messages.isEmpty) {
                  return _SoftChatWelcome(
                    assistantName: name,
                    onSelectPrompt: _handleSubmitted,
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  physics: const AlwaysScrollableScrollPhysics(),
                  itemCount: messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return KeyedSubtree(
                        key: const ValueKey('chat_loading_indicator'),
                        child: _ThinkingBubble(name: name, accentColor: accentColor),
                      );
                    }

                    final msg = messages[index];
                    final isUser = msg.sender == 'user';

                    Map<String, dynamic>? actionData;
                    List<String> messageQuickChips = [];
                    if (msg.actionPayloadJson != null) {
                      try {
                        actionData = jsonDecode(msg.actionPayloadJson!);
                        if (actionData?['quickOptions'] is List) {
                          messageQuickChips = (actionData!['quickOptions'] as List)
                              .map((e) => e.toString())
                              .toList();
                        }
                      } catch (_) {}
                    }

                    return KeyedSubtree(
                      key: ValueKey('chat_item_${msg.id}'),
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Align(
                          alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              maxWidth: MediaQuery.sizeOf(context).width * 0.84,
                            ),
                            child: _TelegramMessageBubble(
                              msg: msg,
                              isUser: isUser,
                              assistantName: name,
                              accentColor: accentColor,
                              actionData: actionData,
                              messageQuickChips: messageQuickChips,
                              onSelectChip: _handleSubmitted,
                              onOpenCourse: () => context.push('/study-plan'),
                              onOpenHub: () => Navigator.of(context).pop(),
                            ),
                          ),
                        ),
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

          // Quick suggestion chips (Fit on-screen, no horizontal scrolling)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
            child: Row(
              children: [
                Expanded(
                  child: _buildQuickChip('Plan my day', Icons.wb_sunny_outlined, () => _handleSubmitted('Plan my day'), context, accentColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickChip('Today\'s agenda', Icons.checklist_rounded, () => _handleSubmitted('What are my tasks today?'), context, accentColor),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _buildQuickChip('Medicines', Icons.health_and_safety_outlined, () => _handleSubmitted('What are my medicines today?'), context, accentColor),
                ),
              ],
            ),
          ),
          const SizedBox(height: 6),

          // Text input bar (WhatsApp Style: pill input + equal height send button, brain inside input, no top divider line)
          SafeArea(
            child: Container(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 10),
              color: Colors.transparent,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Box 1: Rounded input pill with brain inside
                  Expanded(
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        color: Theme.of(context).brightness == Brightness.dark
                            ? const Color(0xFF1E2633)
                            : Colors.white,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(
                          color: Theme.of(context).brightness == Brightness.dark
                              ? const Color(0xFF2E384D)
                              : const Color(0xFFE2E8F0),
                          width: 1.0,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(
                              alpha: Theme.of(context).brightness == Brightness.dark ? 0.25 : 0.05,
                            ),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 14, right: 8),
                            child: Icon(
                              Icons.psychology_rounded,
                              size: 22,
                              color: accentColor,
                            ),
                          ),
                          Expanded(
                            child: TextField(
                              controller: _textController,
                              style: GoogleFonts.plusJakartaSans(
                                color: context.textPrimary,
                                fontSize: 14,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Message $name...',
                                hintStyle: GoogleFonts.plusJakartaSans(
                                  color: context.textMuted,
                                  fontSize: 13.5,
                                ),
                                border: InputBorder.none,
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                isDense: true,
                              ),
                              onSubmitted: _handleSubmitted,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Box 2: Circular send button (48dp height - equal to input capsule!)
                  GestureDetector(
                    onTap: () => _handleSubmitted(_textController.text),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: accentColor,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: accentColor.withValues(alpha: 0.35),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(Icons.send_rounded, size: 20, color: Colors.white),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

  Widget _buildQuickChip(
    String label,
    IconData icon,
    VoidCallback onTap,
    BuildContext context,
    Color accentColor,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.lightImpact();
          onTap();
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E2633) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF2E384D) : const Color(0xFFE2E8F0),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 13, color: accentColor),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: context.textPrimary,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Telegram-Style Translucent Message Bubble with Border
// ---------------------------------------------------------------------------

class _TelegramMessageBubble extends StatelessWidget {
  final AiChatMessage msg;
  final bool isUser;
  final String assistantName;
  final Color accentColor;
  final Map<String, dynamic>? actionData;
  final List<String> messageQuickChips;
  final ValueChanged<String> onSelectChip;
  final VoidCallback onOpenCourse;
  final VoidCallback onOpenHub;

  const _TelegramMessageBubble({
    required this.msg,
    required this.isUser,
    required this.assistantName,
    required this.accentColor,
    required this.actionData,
    required this.messageQuickChips,
    required this.onSelectChip,
    required this.onOpenCourse,
    required this.onOpenHub,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final userBubbleColor = const Color(0xFF007AFF);
    final userTextColor = Colors.white;

    final botBubbleColor = isDark
        ? const Color(0xFF1E2633)
        : Colors.white;
    final botBorderColor = isDark
        ? const Color(0xFF2C374A)
        : const Color(0xFFE2E8F0);

    final timeString = "${msg.createdAt.hour % 12 == 0 ? 12 : msg.createdAt.hour % 12}:${msg.createdAt.minute.toString().padLeft(2, '0')} ${msg.createdAt.hour >= 12 ? 'PM' : 'AM'}";

    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Message Container (Apple iMessage style shrink-wrapped bubble)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser ? userBubbleColor : botBubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            border: isUser
                ? null
                : Border.all(
                    color: botBorderColor,
                    width: 1.0,
                  ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.25 : 0.05),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Assistant Header Tag
              if (!isUser) ...[
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.auto_awesome_rounded, size: 12, color: accentColor),
                    const SizedBox(width: 5),
                    Text(
                      assistantName,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: accentColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
              ],

              // Message Body
              Text(
                msg.message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w400,
                  color: isUser ? userTextColor : context.textPrimary,
                  height: 1.42,
                ),
              ),

              const SizedBox(height: 4),

              // Micro Timestamp Row (Shrink-wrapped, NO Spacer)
              Align(
                alignment: Alignment.bottomRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      timeString,
                      style: GoogleFonts.jetBrainsMono(
                        fontSize: 9.5,
                        color: isUser
                            ? Colors.white.withValues(alpha: 0.75)
                            : context.textMuted.withValues(alpha: 0.8),
                      ),
                    ),
                    if (isUser) ...[
                      const SizedBox(width: 3),
                      const Icon(
                        Icons.done_all_rounded,
                        size: 11,
                        color: Colors.white,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Attached Action Confirmation Capsule (Executed Directly)
        if (!isUser && msg.actionType != null && actionData != null && actionData!['title'] != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.check_circle_rounded, size: 15, color: Color(0xFF10B981)),
                const SizedBox(width: 7),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        actionData!['title'].toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (actionData!['summary'] != null)
                        Text(
                          actionData!['summary'].toString(),
                          style: TextStyle(
                            fontSize: 10.5,
                            color: context.textMuted,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    if (msg.actionType == AiActionType.lectureMarkedComplete.name) {
                      onOpenCourse();
                    } else {
                      onOpenHub();
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          msg.actionType == AiActionType.lectureMarkedComplete.name
                              ? 'Open Course'
                              : 'View',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF10B981),
                          ),
                        ),
                        const SizedBox(width: 2),
                        const Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9,
                          color: Color(0xFF10B981),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],

        // Clarifying Interactive Quick Action Chips
        if (!isUser && messageQuickChips.isNotEmpty) ...[
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 5,
            children: messageQuickChips.map((chipText) {
              return Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onSelectChip(chipText);
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                    decoration: BoxDecoration(
                      color: context.bgSurface.withValues(alpha: 0.8),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.35),
                        width: 1.0,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.touch_app_rounded, size: 12, color: accentColor),
                        const SizedBox(width: 5),
                        Text(
                          chipText,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: context.textPrimary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Inline Animated Thinking Bubble
// ---------------------------------------------------------------------------

class _ThinkingBubble extends StatelessWidget {
  final String name;
  final Color accentColor;

  const _ThinkingBubble({
    required this.name,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.auto_awesome_rounded, color: accentColor, size: 14),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: context.bgSurface.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.divider, width: 0.8),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(accentColor),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '$name is thinking & parsing your data...',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 12.5,
                    fontStyle: FontStyle.italic,
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
}

// ---------------------------------------------------------------------------
// Soft Minimalist Conversational Welcome (Opening State)
// ---------------------------------------------------------------------------

class _SoftChatWelcome extends ConsumerWidget {
  final String assistantName;
  final ValueChanged<String> onSelectPrompt;

  const _SoftChatWelcome({
    required this.assistantName,
    required this.onSelectPrompt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileStreamProvider).value;
    final userName = profile?.name.isNotEmpty == true ? profile!.name.split(' ').first : 'there';
    final accent = context.accentPrimary;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Soft glowing avatar
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: context.bgSurfaceElevated,
                border: Border.all(color: context.divider, width: 1.2),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.08),
                    blurRadius: 18,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: Icon(Icons.auto_awesome_rounded, color: accent, size: 26),
              ),
            ),
            const SizedBox(height: 14),

            // Minimal status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.bgSurfaceElevated,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.divider, width: 0.8),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    '$assistantName · Private & On-Device',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: context.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),

            Text(
              'Hi $userName 👋',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'How can I help you today?',
              style: AscentTextStyles.bodyMedium.copyWith(color: context.textMuted),
            ),

            const SizedBox(height: 24),

            // Soft suggestion pills
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: [
                '⚡ Plan my day',
                '💧 Log 250ml water',
                '🎯 What are my tasks today?',
                '💡 Explain Dynamic Programming',
                '🏃 Check my walk status',
              ].map((prompt) {
                return InkWell(
                  onTap: () {
                    HapticFeedback.lightImpact();
                    onSelectPrompt(prompt);
                  },
                  borderRadius: BorderRadius.circular(20),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                    decoration: BoxDecoration(
                      color: context.bgSurfaceElevated,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: context.divider, width: 1.0),
                    ),
                    child: Text(
                      prompt,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: context.textPrimary,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ),
      ),
    );
  }
}
