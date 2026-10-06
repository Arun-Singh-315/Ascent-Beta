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
      // 1. Insert user message
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
          text: "I analyzed your request. Your on-device data is fully synced. What would you like to plan or work on next?",
        ),
      );

      // 3. Serialize proposed action if any
      String? actionType;
      String? actionPayload;
      if (response.proposedAction != null) {
        actionType = response.proposedAction!.type.name;
        actionPayload = jsonEncode({
          'title': response.proposedAction!.title,
          'summary': response.proposedAction!.summary,
          'payload': response.proposedAction!.payload,
          'quickOptions': response.clarifyingOptions,
        });
      } else if (response.clarifyingOptions.isNotEmpty) {
        actionPayload = jsonEncode({
          'quickOptions': response.clarifyingOptions,
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
    } catch (err) {
      await aiDao.insertMessage(
        AiChatMessageTableCompanion.insert(
          sender: 'assistant',
          message: "I encountered a minor glitch structuring that request. Let's try again — tap an option below or type what you need.",
          actionPayloadJson: drift.Value(jsonEncode({
            'quickOptions': ['Plan my day', 'Pending activities', 'Drink water'],
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

  Future<void> _executeApprovedAction(int messageId, String actionType, Map<String, dynamic> actionData) async {
    HapticFeedback.mediumImpact();
    final payload = actionData['payload'] as Map<String, dynamic>? ?? {};
    final name = ref.read(assistantNameProvider);

    setState(() {
      _executedActionMessageIds.add(messageId);
    });

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
            content: Text('Expense of ₹${amt.toStringAsFixed(0)} saved to finances!'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } else if (actionType == AiActionType.taskCreated.name || actionType == AiActionType.activityCreated.name) {
      final title = payload['title']?.toString() ?? 'Focus Activity';
      final planned = payload['plannedDate'] != null
          ? DateTime.parse(payload['plannedDate'])
          : DateTime.now();
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
        final reminderTime = DateTime.parse(payload['reminderTime']);
        final reminderId = await ref.read(reminderDaoProvider).insertReminder(
          ReminderTableCompanion.insert(
            title: title,
            scheduledAt: reminderTime,
            isActive: const drift.Value(true),
          ),
        );
        try {
          await NotificationService.instance.scheduleReminderNotification(
            id: reminderId,
            title: title,
            scheduledAt: reminderTime,
          );
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"$title" added to Activity Hub!'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        );
      }
    } else if (actionType == AiActionType.lectureMarkedComplete.name) {
      final rawIds = payload['lectureIds'] as List?;
      final lectureIds = rawIds?.map((e) => (e as num).toInt()).toList() ?? [];

      for (final id in lectureIds) {
        ref.read(learningHubProvider.notifier).markLectureCompleted(id, completed: true);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Marked ${lectureIds.length} lecture(s) completed in course! 🎉'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'Open Course',
              textColor: Colors.white,
              onPressed: () => context.push('/study-plan'),
            ),
          ),
        );
      }
    } else if (actionType == AiActionType.scheduleRearranged.name) {
      if (payload['taskId'] != null && payload['newDate'] != null) {
        final taskId = (payload['taskId'] as num).toInt();
        final newDate = DateTime.parse(payload['newDate']);
        final taskDao = ref.read(taskDaoProvider);
        await (taskDao.update(taskDao.taskTable)..where((t) => t.id.equals(taskId)))
            .write(TaskTableCompanion(plannedDate: drift.Value(newDate)));
      } else if (payload['taskIds'] != null && payload['newDate'] != null) {
        final taskIds = (payload['taskIds'] as List).map((e) => (e as num).toInt());
        final newDate = DateTime.parse(payload['newDate']);
        final taskDao = ref.read(taskDaoProvider);
        for (final tid in taskIds) {
          await (taskDao.update(taskDao.taskTable)..where((t) => t.id.equals(tid)))
              .write(TaskTableCompanion(plannedDate: drift.Value(newDate)));
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Schedule rearranged! Check Activity Hub.'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => Navigator.of(context).pop(),
            ),
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
          SnackBar(
            content: const Text('Daily plan active! Check Activity Hub.'),
            duration: const Duration(seconds: 3),
            action: SnackBarAction(
              label: 'View',
              textColor: Colors.white,
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
        );
      }
    } else if (actionType == AiActionType.generalResponse.name) {
      if (payload['action'] == 'open_study') {
        Navigator.of(context).pushNamed('/study-plan');
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
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: accentColor.withValues(alpha: 0.12),
              ),
              child: Icon(Icons.auto_awesome_rounded, color: accentColor, size: 17),
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
                  return _LiveBriefingDashboard(
                    assistantName: name,
                    onSelectPrompt: _handleSubmitted,
                  );
                }

                return ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length + (_isLoading ? 1 : 0),
                  itemBuilder: (context, index) {
                    if (index == messages.length) {
                      return _ThinkingBubble(name: name, accentColor: accentColor);
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

                    final isExecuted = _executedActionMessageIds.contains(msg.id);

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
                              maxWidth: MediaQuery.of(context).size.width * 0.85,
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

                          // Action confirmation / interactive card
                          if (!isUser && msg.actionType != null && actionData != null && actionData['title'] != null) ...[
                            const SizedBox(height: 8),
                            Container(
                              constraints: BoxConstraints(
                                maxWidth: MediaQuery.of(context).size.width * 0.88,
                              ),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isExecuted
                                    ? const Color(0xFF10B981).withValues(alpha: 0.08)
                                    : accentColor.withValues(alpha: 0.07),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: isExecuted
                                      ? const Color(0xFF10B981).withValues(alpha: 0.3)
                                      : accentColor.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        isExecuted ? Icons.check_circle_rounded : Icons.bolt_rounded,
                                        size: 16,
                                        color: isExecuted ? const Color(0xFF10B981) : accentColor,
                                      ),
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
                                    const SizedBox(height: 4),
                                    Text(
                                      actionData['summary'].toString(),
                                      style: AscentTextStyles.bodySmall.copyWith(color: context.textMuted),
                                    ),
                                  ],
                                  const SizedBox(height: 10),
                                  if (!isExecuted)
                                    Row(
                                      children: [
                                        AscentButton.primary(
                                          label: 'Confirm & Save',
                                          compact: true,
                                          onPressed: () => _executeApprovedAction(msg.id, msg.actionType!, actionData!),
                                        ),
                                      ],
                                    )
                                  else
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                                            borderRadius: BorderRadius.circular(6),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(Icons.check, size: 12, color: Color(0xFF10B981)),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Saved to SQLite',
                                                style: GoogleFonts.plusJakartaSans(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w600,
                                                  color: const Color(0xFF10B981),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const Spacer(),
                                        TextButton(
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            minimumSize: Size.zero,
                                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                          ),
                                          onPressed: () {
                                            if (msg.actionType == AiActionType.lectureMarkedComplete.name) {
                                              Navigator.of(context).pushNamed('/study-plan');
                                            } else {
                                              Navigator.of(context).pop();
                                            }
                                          },
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                msg.actionType == AiActionType.lectureMarkedComplete.name
                                                    ? 'Open Course'
                                                    : 'View in Hub',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  fontWeight: FontWeight.w600,
                                                  color: accentColor,
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              Icon(Icons.arrow_forward_rounded, size: 12, color: accentColor),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ),
                            ),
                          ],

                          // Clarifying action chips under assistant message
                          if (!isUser && messageQuickChips.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 4,
                              children: messageQuickChips.map((chipText) {
                                return ActionChip(
                                  label: Text(chipText, style: const TextStyle(fontSize: 11)),
                                  backgroundColor: context.bgSurface,
                                  side: BorderSide(color: accentColor.withValues(alpha: 0.3)),
                                  onPressed: () => _handleSubmitted(chipText),
                                );
                              }).toList(),
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
              statusColor: waterMl < 1000 ? Colors.orange : const Color(0xFF38BDF8),
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
