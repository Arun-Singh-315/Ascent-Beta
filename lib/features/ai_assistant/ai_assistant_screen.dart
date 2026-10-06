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
import '../../core/walk/walk_tracking_service.dart';

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
    'Need to call Saurabh at 2',
    'Complete Java Spring Boot today',
    'Study Java for 2 hours today',
    'Finished first two lectures',
    'Spent ₹120 on lunch',
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
      body: Column(
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
                  return _LiveBriefingDashboard(
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

    // Telegram-style translucent styling:
    // User bubble: soft translucent blue tint with 1px crisp border
    // Bot bubble: translucent surface card with 1px subtle border
    final userBubbleColor = isDark
        ? const Color(0xFF1E3A5F).withValues(alpha: 0.35)
        : const Color(0xFF3B82F6).withValues(alpha: 0.12);
    final userBorderColor = isDark
        ? const Color(0xFF60A5FA).withValues(alpha: 0.38)
        : const Color(0xFF2563EB).withValues(alpha: 0.35);

    final botBubbleColor = isDark
        ? const Color(0xFF161B22).withValues(alpha: 0.7)
        : Colors.white.withValues(alpha: 0.88);
    final botBorderColor = context.divider.withValues(alpha: 0.8);

    final timeString = "${msg.createdAt.hour % 12 == 0 ? 12 : msg.createdAt.hour % 12}:${msg.createdAt.minute.toString().padLeft(2, '0')} ${msg.createdAt.hour >= 12 ? 'PM' : 'AM'}";

    return Column(
      crossAxisAlignment: isUser ? CrossAxisAlignment.end : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Message Container
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            color: isUser ? userBubbleColor : botBubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isUser ? 16 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 16),
            ),
            border: Border.all(
              color: isUser ? userBorderColor : botBorderColor,
              width: 1.0,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
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
                const SizedBox(height: 6),
              ],

              // Message Body
              Text(
                msg.message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: context.textPrimary,
                  height: 1.45,
                ),
              ),

              const SizedBox(height: 4),

              // Telegram-Style Micro Timestamp Row
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Spacer(),
                  Text(
                    timeString,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 9.5,
                      color: context.textMuted.withValues(alpha: 0.8),
                    ),
                  ),
                  if (isUser) ...[
                    const SizedBox(width: 3),
                    Icon(
                      Icons.done_all_rounded,
                      size: 11,
                      color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF2563EB),
                    ),
                  ],
                ],
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
// Live Telemetry Briefing Dashboard (Opening State)
// ---------------------------------------------------------------------------

class _LiveBriefingDashboard extends ConsumerWidget {
  final String assistantName;
  final ValueChanged<String> onSelectPrompt;

  const _LiveBriefingDashboard({
    required this.assistantName,
    required this.onSelectPrompt,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(userProfileStreamProvider).value;
    final userName = profile?.name.isNotEmpty == true ? profile!.name : 'Arun';

    final waterMl = ref.watch(todayWaterMlStreamProvider).value ?? 0;
    final waterGoal = ref.watch(dailyWaterGoalStreamProvider).value ?? 2500;

    final walkState = ref.watch(walkTrackingProvider);
    final todayWalkMeters = ref.watch(todayWalkDistanceStreamProvider).value ?? 0.0;
    final isWalkActive = walkState.status == WalkTrackingStatus.tracking;

    final learningState = ref.watch(learningHubProvider);
    final course = learningState.course;

    final todaySpending = ref.watch(todaySpendingStreamProvider).value ?? 0.0;
    final nextReminder = ref.watch(nextUpcomingReminderProvider).value;

    final accent = context.accentPrimary;

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      children: [
        // 1. Header Card with Live Status Badge
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: context.bgSurface.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.divider.withValues(alpha: 0.8), width: 1.0),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                  border: Border.all(color: accent.withValues(alpha: 0.4)),
                ),
                child: Icon(Icons.auto_awesome_rounded, color: accent, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'AI STATUS · $assistantName',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                            color: accent,
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 5,
                                height: 5,
                                decoration: const BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: Color(0xFF10B981),
                                ),
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'ONLINE',
                                style: GoogleFonts.plusJakartaSans(
                                  fontSize: 9,
                                  fontWeight: FontWeight.w800,
                                  color: const Color(0xFF10B981),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'Live Telemetry Briefing for $userName',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: context.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 14),

        // 2. Real-Time Telemetry Grid
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.8,
          children: [
            // Hydration Telemetry
            _TelemetryCard(
              title: 'Hydration',
              value: '$waterMl / $waterGoal mL',
              status: waterMl < 1000 ? 'Drink water!' : 'Healthy',
              statusColor: waterMl < 1000 ? context.stateWarning : const Color(0xFF38BDF8),
              icon: Icons.water_drop_rounded,
              iconColor: const Color(0xFF38BDF8),
              onTap: () => onSelectPrompt('Log 250ml water'),
            ),

            // Walk Telemetry
            _TelemetryCard(
              title: 'Walk & Activity',
              value: isWalkActive
                  ? '${(walkState.distanceKm).toStringAsFixed(2)} km'
                  : '${(todayWalkMeters / 1000.0).toStringAsFixed(1)} km today',
              status: isWalkActive ? 'Active GPS walk' : (todayWalkMeters > 0 ? 'Logged' : 'Pending walk'),
              statusColor: isWalkActive ? const Color(0xFF22C55E) : const Color(0xFF10B981),
              icon: Icons.directions_walk_rounded,
              iconColor: const Color(0xFF10B981),
              onTap: () => onSelectPrompt('Walk status and tips'),
            ),

            // Learning Telemetry
            _TelemetryCard(
              title: 'Learning Hub',
              value: '${course.completedLectures}/${course.totalLectures} lectures',
              status: '${course.remainingLectures} left in course',
              statusColor: const Color(0xFF6366F1),
              icon: Icons.school_rounded,
              iconColor: const Color(0xFF6366F1),
              onTap: () => onSelectPrompt('What should I study next?'),
            ),

            // Reminder & Money Telemetry
            _TelemetryCard(
              title: 'Reminders & Finance',
              value: '₹${todaySpending.toStringAsFixed(0)} today',
              status: nextReminder != null ? nextReminder.title : 'No pending alarms',
              statusColor: const Color(0xFFF59E0B),
              icon: Icons.notifications_active_rounded,
              iconColor: const Color(0xFFF59E0B),
              onTap: () => onSelectPrompt('Show my pending tasks and reminders'),
            ),
          ],
        ),

        const SizedBox(height: 18),

        Text(
          'INTELLIGENT COMMANDS',
          style: AscentTextStyles.labelSmall.copyWith(
            color: context.textMuted,
            letterSpacing: 1.1,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),

        // 3. Highlight "Plan My Day" button
        InkWell(
          onTap: () => onSelectPrompt('Plan my day'),
          borderRadius: BorderRadius.circular(14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  accent.withValues(alpha: 0.18),
                  accent.withValues(alpha: 0.08),
                ],
              ),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: accent.withValues(alpha: 0.5), width: 1.2),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: accent.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.bolt_rounded, size: 18, color: accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '⚡ Plan My Day',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.textPrimary,
                        ),
                      ),
                      Text(
                        'Synthesize activities, walk goals, hydration & lectures',
                        style: AscentTextStyles.captionMedium.copyWith(color: context.textMuted),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded, size: 12, color: accent),
              ],
            ),
          ),
        ),

        const SizedBox(height: 10),

        // Quick prompts list
        ...[
          'What tasks are pending today?',
          'Log 250ml water',
          'Explain Dynamic Programming',
          'Move my workout to the evening',
        ].map((p) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: InkWell(
                onTap: () => onSelectPrompt(p),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: context.bgSurface.withValues(alpha: 0.6),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: context.divider.withValues(alpha: 0.7)),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.chat_bubble_outline_rounded, size: 14, color: accent),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          p,
                          style: AscentTextStyles.bodyMedium.copyWith(
                            color: context.textPrimary,
                            fontSize: 13,
                          ),
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
}

class _TelemetryCard extends StatelessWidget {
  final String title;
  final String value;
  final String status;
  final Color statusColor;
  final IconData icon;
  final Color iconColor;
  final VoidCallback onTap;

  const _TelemetryCard({
    required this.title,
    required this.value,
    required this.status,
    required this.statusColor,
    required this.icon,
    required this.iconColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: context.bgSurface.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: context.divider.withValues(alpha: 0.6), width: 0.8),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w700,
                      color: context.textMuted,
                    ),
                  ),
                  Icon(icon, size: 14, color: iconColor),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: context.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 1),
                  Text(
                    status,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
