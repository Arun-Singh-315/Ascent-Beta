import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';

import '../../app/theme/color_tokens.dart';
import '../../shared/widgets/message_composer.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/ai/ai_service.dart';
import '../../core/ai/riya_capabilities.dart';
import '../../core/ai/riya_intents.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../core/notifications/notification_service.dart';
import '../../core/database/app_database.dart';
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
  bool _hasInputText = false;
  RiyaIntentResolver? _resolver;
  late final Stream<List<AiChatMessage>> _messagesStream;

  @override
  void initState() {
    super.initState();
    _textController.addListener(_onTextChanged);
    _messagesStream = ref.read(aiAssistantDaoProvider).watchRecentMessages();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      try {
        await ref.read(aiAssistantDaoProvider).recoverCommandResponses();
      } catch (_) {
        /* Normal error states remain available. */
      }
    });
  }

  void _onTextChanged() {
    final hasText = _textController.text.trim().isNotEmpty;
    if (_hasInputText != hasText) {
      setState(() => _hasInputText = hasText);
    }
  }

  @override
  void dispose() {
    _textController.removeListener(_onTextChanged);
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
      final userMessageId = await aiDao.insertMessage(
        AiChatMessageTableCompanion.insert(sender: 'user', message: prompt),
      );
      if (!mounted) return;
      _scrollToBottom();

      final db = ref.read(databaseProvider);
      final resolution = await (_resolver ??= RiyaIntentResolver(
        db,
      )).resolve(prompt).timeout(const Duration(seconds: 5));
      if (!mounted) return;
      String reply;
      RiyaCommand? command = resolution?.command;
      List<String> options = resolution?.options ?? [];
      if (resolution == null) {
        if (RegExp(
          r'^(delete|remove|reset|transfer|share)\b',
          caseSensitive: false,
        ).hasMatch(prompt)) {
          reply =
              'That action is not available through Riya. Use the relevant feature screen to review it safely.';
        } else {
          final response = await ref
              .read(aiEngineProvider)
              .processUserPrompt(prompt, ref)
              .timeout(const Duration(seconds: 5));
          if (!mounted) return;
          reply = response.text;
          options = response.clarifyingOptions;
          final action = response.proposedAction;
          if (action != null) {
            command = _commandFromProposal(action);
            if (action.type == AiActionType.lectureMarkedComplete) {
              reply =
                  'Review and complete these lectures in Learning. I have not changed your course.';
              options = ['Open Learning'];
            }
          }
        }
      } else {
        reply = resolution.message ?? 'Review this action.';
      }
      String? actionType;
      final data = <String, dynamic>{'quickOptions': options};
      if (command != null) {
        final executor = RiyaExecutor(db);
        executor.validate(command);
        final capability = command.capability;
        bool approved = !capability.requiresConfirmation;
        if (capability.requiresConfirmation && mounted) {
          approved =
              await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: Text(capability.description),
                  content: SingleChildScrollView(child: Text(command!.preview)),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Cancel'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Confirm'),
                    ),
                  ],
                ),
              ) ==
              true;
        }
        if (approved && mounted) {
          final requestId = 'chat:$userMessageId';
          RiyaResult? savedResult;
          try {
            // Attach the existing Focus stream/ticker before creating a session.
            if (command.id.startsWith('focus.')) ref.read(timeTrackingProvider);
            final result = await executor.execute(
              command,
              requestId: requestId,
              approved: approved,
            );
            savedResult = result;
            reply = result.message;
            if (result.reminderIds.isNotEmpty) {
              var alertsScheduled = true;
              for (final id in result.reminderIds) {
                try {
                  final reminder = await db.reminderDao.getReminderById(id);
                  if (reminder == null) {
                    alertsScheduled = false;
                    continue;
                  }
                  if (command.id == 'reminders.edit') {
                    await NotificationService.instance.cancel(id);
                  }
                  final permission = await NotificationService.instance
                      .areNotificationsEnabled();
                  final scheduled =
                      permission &&
                      await NotificationService.instance
                          .scheduleReminderNotificationChecked(
                            id: id,
                            title: reminder.title,
                            scheduledAt: reminder.scheduledAt,
                            scheduleFollowUp: false,
                          );
                  alertsScheduled = alertsScheduled && scheduled;
                } catch (_) {
                  alertsScheduled = false;
                }
              }
              reply =
                  '${result.message.replaceFirst(' Device alert scheduling has not been verified.', '')}\n${alertsScheduled ? 'Device alerts are scheduled.' : 'Device alerts could not be scheduled. Check notification permissions in Settings.'}';
            }
            actionType = command.id;
            data.addAll({
              'title': capability.description,
              'summary': reply,
              'route': result.route,
              'executionStatus': 'verified',
              'requestId': requestId,
              'write': capability.write,
            });
            if (command.id == 'navigation.open' && mounted) {
              context.push(result.route);
            }
          } catch (_) {
            reply = savedResult != null
                ? '${savedResult.message} Device alerts could not be verified.'
                : command.id == 'focus.start' &&
                      await db.timeSessionDao.getActiveFocusSession() != null
                ? 'A Focus session is already active. Open Focus to continue or finish it.'
                : 'I could not verify that change. No new change was committed by this request. Please try again.';
            data['executionStatus'] = 'failed';
          }
        } else {
          reply = 'Cancelled. No changes were made.';
        }
      }
      await aiDao.insertMessage(
        AiChatMessageTableCompanion.insert(
          sender: 'assistant',
          message: reply,
          actionType: drift.Value(actionType),
          actionPayloadJson: drift.Value(jsonEncode(data)),
        ),
      );
    } catch (_) {
      try {
        await aiDao.insertMessage(
          AiChatMessageTableCompanion.insert(
            sender: 'assistant',
            message:
                'I could not finish that response. Check the relevant screen before retrying any change.',
          ),
        );
      } catch (_) {
        if (mounted) {
          if (_textController.text.isEmpty) _textController.text = prompt;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Chat could not be saved. Your message is still here.',
              ),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
        _scrollToBottom();
      }
    }
  }

  RiyaCommand? _commandFromProposal(AiProposedAction action) {
    final id = switch (action.type) {
      AiActionType.taskCreated ||
      AiActionType.activityCreated => 'tasks.create',
      AiActionType.expenseLogged => 'expenses.create',
      AiActionType.waterLogged => 'hydration.log',
      AiActionType.scheduleRearranged => 'tasks.reschedule',
      _ => null,
    };
    if (id == null) return null;
    final schema = riyaCapabilities.firstWhere((c) => c.id == id).schema;
    final payload = <String, dynamic>{};
    for (final key in schema.keys) {
      if (action.payload[key] != null) payload[key] = action.payload[key];
    }
    if (id == 'tasks.reschedule' &&
        payload['taskIds'] == null &&
        action.payload['taskId'] != null) {
      payload['taskIds'] = [action.payload['taskId']];
    }
    return RiyaCommand(id, payload);
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = ref.watch(assistantNameProvider);
    final messagesStream = _messagesStream;
    final accentColor = context.accentPrimary;

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        flexibleSpace: ClipRect(
          child: BackdropFilter(
            filter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF181009).withValues(alpha: 0.72)
                    : Colors.white.withValues(alpha: 0.82),
                border: Border(
                  bottom: BorderSide(
                    color: (isDark ? Colors.white : Colors.black).withValues(
                      alpha: 0.06,
                    ),
                    width: 1.0,
                  ),
                ),
              ),
            ),
          ),
        ),
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: context.textPrimary,
            size: 19,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        titleSpacing: 0,
        title: Row(
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.25),
                        const Color(0xFF8B6A4F).withValues(alpha: 0.25),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    border: Border.all(
                      color: accentColor.withValues(alpha: 0.45),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: Icon(
                      Icons.auto_awesome_rounded,
                      color: accentColor,
                      size: 17,
                    ),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? const Color(0xFF181009) : Colors.white,
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF10B981).withValues(alpha: 0.6),
                          blurRadius: 4,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      name,
                      style: GoogleFonts.plusJakartaSans(
                        color: context.textPrimary,
                        fontSize: 16.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
                Text(
                  'Intelligent · On-Device · Private',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w500,
                    color: context.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: Icon(
              Icons.delete_sweep_outlined,
              color: context.textMuted,
              size: 21,
            ),
            tooltip: 'Clear chat history',
            onPressed: () async {
              HapticFeedback.lightImpact();
              await ref.read(aiAssistantDaoProvider).clearChatHistory();
            },
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Breathtaking Night & Day Atmospheric Background
          _AtmosphericChatBackground(isDark: isDark, accentColor: accentColor),
          // Main Chat Interface
          StreamBuilder<List<AiChatMessage>>(
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
              final hasMessages = messages.isNotEmpty;

              return Column(
                children: [
                  // Chat stream
                  Expanded(
                    child: messages.isEmpty
                        ? _SoftChatWelcome(
                            assistantName: name,
                            onSelectPrompt: _handleSubmitted,
                          )
                        : ListView.builder(
                            controller: _scrollController,
                            padding: EdgeInsets.fromLTRB(
                              14,
                              MediaQuery.paddingOf(context).top +
                                  kToolbarHeight +
                                  8,
                              14,
                              12,
                            ),
                            physics: const AlwaysScrollableScrollPhysics(),
                            itemCount: messages.length + (_isLoading ? 1 : 0),
                            itemBuilder: (context, index) {
                              if (index == messages.length) {
                                return KeyedSubtree(
                                  key: const ValueKey('chat_loading_indicator'),
                                  child: _ThinkingBubble(
                                    name: name,
                                    accentColor: accentColor,
                                  ),
                                );
                              }

                              final msg = messages[index];
                              final isUser = msg.sender == 'user';

                              Map<String, dynamic>? actionData;
                              List<String> messageQuickChips = [];
                              if (msg.actionPayloadJson != null) {
                                try {
                                  actionData = jsonDecode(
                                    msg.actionPayloadJson!,
                                  );
                                  if (actionData?['quickOptions'] is List) {
                                    messageQuickChips =
                                        (actionData!['quickOptions'] as List)
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
                                    alignment: isUser
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: ConstrainedBox(
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.sizeOf(context).width *
                                            0.84,
                                      ),
                                      child: _TelegramMessageBubble(
                                        msg: msg,
                                        isUser: isUser,
                                        assistantName: name,
                                        accentColor: accentColor,
                                        actionData: actionData,
                                        messageQuickChips: messageQuickChips,
                                        onSelectChip: _handleSubmitted,
                                        onOpenCourse: () =>
                                            context.push('/study-plan'),
                                        onOpenHub: () => context.push(
                                          actionData?['route'] as String? ??
                                              '/today',
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
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
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: accentColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '$name is thinking...',
                            style: TextStyle(
                              fontSize: 12,
                              color: context.textMuted,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Quick suggestion chips: shown ONLY when chat is empty to prevent "box over box" clutter
                  if (!hasMessages) ...[
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 4,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildQuickChip(
                              'Plan my day',
                              Icons.wb_sunny_rounded,
                              () => _handleSubmitted('Plan my day'),
                              context,
                              accentColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildQuickChip(
                              'Today\'s agenda',
                              Icons.checklist_rounded,
                              () =>
                                  _handleSubmitted('What are my tasks today?'),
                              context,
                              accentColor,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: _buildQuickChip(
                              'Medicines',
                              Icons.medication_rounded,
                              () => _handleSubmitted(
                                'What are my medicines today?',
                              ),
                              context,
                              accentColor,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                  ] else ...[
                    const SizedBox(height: 4),
                  ],

                  // Thought Wall Consistent Input Box (Glass fill + Pill + Animated Send Circle)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: g.fill,
                      border: Border(
                        top: BorderSide(
                          color: g.edge.withValues(alpha: 0.5),
                          width: 0.8,
                        ),
                      ),
                    ),
                    child: SafeArea(
                      top: false,
                      child: MessageComposer(
                        controller: _textController,
                        hint: 'Message $name...',
                        busy: _isLoading,
                        onSend: _handleSubmitted,
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ],
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
          padding: const EdgeInsets.symmetric(vertical: 7.5, horizontal: 8),
          decoration: BoxDecoration(
            color: isDark
                ? const Color(0xFF2D1F13).withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF4B3726) : const Color(0xFFE2E8F0),
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: accentColor),
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

    final userBgColor = isDark
        ? const Color(0xFF3B2C1E).withValues(alpha: 0.60)
        : Colors.transparent;
    final userBorderColor = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : const Color(0xFF3B2C1E);

    final botBubbleColor = isDark
        ? const Color(0xFF2D1F13).withValues(alpha: 0.90)
        : Colors.white.withValues(alpha: 0.95);
    final botBorderColor = isDark
        ? const Color(0xFF4B3726)
        : const Color(0xFFE2E8F0);

    final timeString =
        "${msg.createdAt.hour % 12 == 0 ? 12 : msg.createdAt.hour % 12}:${msg.createdAt.minute.toString().padLeft(2, '0')} ${msg.createdAt.hour >= 12 ? 'PM' : 'AM'}";

    return Column(
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Main Message Container (User: Transparent/Glass • Riya: Translucent Card)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isUser ? userBgColor : botBubbleColor,
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(isUser ? 18 : 4),
              bottomRight: Radius.circular(isUser ? 4 : 18),
            ),
            border: Border.all(
              color: isUser ? userBorderColor : botBorderColor,
              width: 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: isUser
                    ? (isDark
                          ? Colors.black.withValues(alpha: 0.22)
                          : Colors.transparent)
                    : Colors.black.withValues(alpha: isDark ? 0.25 : 0.06),
                blurRadius: isUser ? (isDark ? 8 : 0) : 8,
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
                    Icon(
                      Icons.auto_awesome_rounded,
                      size: 12,
                      color: accentColor,
                    ),
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
                  color: isUser
                      ? (isDark ? Colors.white : const Color(0xFF2A1C0F))
                      : (isDark
                            ? const Color(0xFFF1F5F9)
                            : const Color(0xFF3B2C1E)),
                  height: 1.45,
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
                            ? (isDark
                                  ? Colors.white.withValues(alpha: 0.65)
                                  : const Color(0xFF8B7664))
                            : context.textMuted.withValues(alpha: 0.8),
                      ),
                    ),
                    if (isUser) ...[
                      const SizedBox(width: 3),
                      Icon(
                        Icons.done_all_rounded,
                        size: 11,
                        color: isDark
                            ? Colors.white.withValues(alpha: 0.75)
                            : const Color(0xFF8B7664),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        // Attached Action Confirmation Capsule (Executed Directly)
        if (!isUser &&
            msg.actionType != null &&
            actionData != null &&
            actionData!['executionStatus'] == 'verified' &&
            actionData!['title'] != null) ...[
          const SizedBox(height: 6),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF10B981).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF10B981).withValues(alpha: 0.35),
                width: 1.0,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  actionData?['write'] == true
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  size: 15,
                  color: Color(0xFF10B981),
                ),
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
                    if (msg.actionType ==
                        AiActionType.lectureMarkedComplete.name) {
                      onOpenCourse();
                    } else {
                      onOpenHub();
                    }
                  },
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          msg.actionType ==
                                  AiActionType.lectureMarkedComplete.name
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF332416).withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.90),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: accentColor.withValues(alpha: 0.4),
                        width: 0.9,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.touch_app_rounded,
                          size: 12,
                          color: accentColor,
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: Text(
                            chipText,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: context.textPrimary,
                            ),
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

  const _ThinkingBubble({required this.name, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.18),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.auto_awesome_rounded,
              color: accentColor,
              size: 14,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF2D1F13).withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF4B3726)
                    : const Color(0xFFE2E8F0),
                width: 1.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: isDark ? 0.20 : 0.04),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
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
    final userName = profile?.name.isNotEmpty == true
        ? profile!.name.split(' ').first
        : 'there';
    final accent = context.accentPrimary;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final hour = DateTime.now().hour;
    final greetingTime = hour < 12
        ? 'Good morning'
        : (hour < 17 ? 'Good afternoon' : 'Good evening');

    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          MediaQuery.paddingOf(context).top + kToolbarHeight + 16,
          24,
          24,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Soft glowing avatar
            Container(
              width: 68,
              height: 68,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [
                    accent.withValues(alpha: 0.25),
                    const Color(0xFF8B6A4F).withValues(alpha: 0.25),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                border: Border.all(
                  color: accent.withValues(alpha: 0.5),
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: accent.withValues(alpha: isDark ? 0.35 : 0.18),
                    blurRadius: 24,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Center(
                child: Icon(
                  Icons.auto_awesome_rounded,
                  color: accent,
                  size: 28,
                ),
              ),
            ),
            const SizedBox(height: 14),

            // Minimal status indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2D1F13).withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF4B3726)
                      : const Color(0xFFE2E8F0),
                  width: 0.8,
                ),
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
                    '$assistantName · Always by your side',
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
              '$greetingTime, $userName',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: context.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'I\'m $assistantName, your personal assistant. How can I help you today?',
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 13.5,
                color: context.textMuted,
                height: 1.4,
              ),
            ),

            const SizedBox(height: 24),

            // Soft suggestion pills
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children:
                  [
                    'Plan my day',
                    'Log 250ml water',
                    'What are my tasks today?',
                    'Check my walk status',
                    'Medicine schedule',
                    'Explain Dynamic Programming',
                  ].map((prompt) {
                    return Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () {
                          HapticFeedback.lightImpact();
                          onSelectPrompt(prompt);
                        },
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9.5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(
                                    0xFF2D1F13,
                                  ).withValues(alpha: 0.85)
                                : Colors.white.withValues(alpha: 0.90),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? const Color(0xFF4B3726)
                                  : const Color(0xFFE2E8F0),
                              width: 1.0,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.20 : 0.04,
                                ),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
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

// ---------------------------------------------------------------------------
// Atmospheric Night & Day Chat Background with Celestial Stardust
// ---------------------------------------------------------------------------

class _AtmosphericChatBackground extends StatelessWidget {
  final bool isDark;
  final Color accentColor;

  const _AtmosphericChatBackground({
    required this.isDark,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    if (isDark) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Base cosmic midnight canvas
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFF181009),
                  Color(0xFF22160C),
                  Color(0xFF100B06),
                ],
              ),
            ),
          ),
          // Ambient Indigo/Violet Aura (Top-Left)
          Positioned(
            top: -60,
            left: -60,
            width: 320,
            height: 320,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFF8B6A4F).withValues(alpha: 0.16),
                    const Color(0xFFE59046).withValues(alpha: 0.08),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Ethereal Sky/Cyan Aurora (Top-Right)
          Positioned(
            top: 40,
            right: -80,
            width: 300,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFE9740E).withValues(alpha: 0.13),
                    const Color(0xFF6E8565).withValues(alpha: 0.05),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Deep Nebula Rose/Purple Aurora (Bottom-Left)
          Positioned(
            bottom: 60,
            left: -80,
            width: 340,
            height: 340,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFF7A155).withValues(alpha: 0.10),
                    const Color(0xFFEA8833).withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.55, 1.0],
                ),
              ),
            ),
          ),
          // Custom Celestial Shimmer Dust (Deterministic, zero CPU/GPU overhead)
          const CustomPaint(painter: _CelestialStardustPainter(isDark: true)),
        ],
      );
    } else {
      // Day Mode: Luminous Pearl & Morning Serenity
      return Stack(
        fit: StackFit.expand,
        children: [
          // Base serene porcelain & alabaster canvas
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Color(0xFFFAFBFD),
                  Color(0xFFF1F5F9),
                  Color(0xFFEDF2F7),
                ],
              ),
            ),
          ),
          // Morning Sky Mist Glow (Top-Left)
          Positioned(
            top: -60,
            left: -50,
            width: 320,
            height: 320,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFF89238).withValues(alpha: 0.12),
                    const Color(0xFF6E8565).withValues(alpha: 0.04),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Soft Lavender / Orchid Warmth (Top-Right)
          Positioned(
            top: 60,
            right: -60,
            width: 280,
            height: 280,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFABF8B).withValues(alpha: 0.09),
                    const Color(0xFFF6A45C).withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.5, 1.0],
                ),
              ),
            ),
          ),
          // Morning Sunbeam Gold Sheen (Bottom-Right)
          Positioned(
            bottom: 40,
            right: -40,
            width: 300,
            height: 300,
            child: Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    const Color(0xFFFDE68A).withValues(alpha: 0.09),
                    const Color(0xFFF59E0B).withValues(alpha: 0.03),
                    Colors.transparent,
                  ],
                  stops: const [0.0, 0.6, 1.0],
                ),
              ),
            ),
          ),
          // Custom Pearl Shimmer Dust (Deterministic)
          const CustomPaint(painter: _CelestialStardustPainter(isDark: false)),
        ],
      );
    }
  }
}

// ---------------------------------------------------------------------------
// Deterministic Micro Stardust & Pearl Shimmer Painter
// ---------------------------------------------------------------------------

class _CelestialStardustPainter extends CustomPainter {
  final bool isDark;
  const _CelestialStardustPainter({required this.isDark});

  // Deterministic star coordinates so they never flicker or recompute randomly
  static const _stars = [
    Offset(0.12, 0.08),
    Offset(0.28, 0.14),
    Offset(0.45, 0.06),
    Offset(0.72, 0.11),
    Offset(0.88, 0.09),
    Offset(0.18, 0.22),
    Offset(0.62, 0.25),
    Offset(0.82, 0.28),
    Offset(0.08, 0.35),
    Offset(0.38, 0.38),
    Offset(0.76, 0.42),
    Offset(0.92, 0.46),
    Offset(0.15, 0.52),
    Offset(0.52, 0.56),
    Offset(0.85, 0.60),
    Offset(0.22, 0.68),
    Offset(0.68, 0.72),
    Offset(0.10, 0.76),
    Offset(0.40, 0.78),
    Offset(0.80, 0.75),
    Offset(0.25, 0.62),
    Offset(0.55, 0.48),
    Offset(0.90, 0.65),
    Offset(0.33, 0.45),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < _stars.length; i++) {
      final s = _stars[i];
      final pos = Offset(s.dx * size.width, s.dy * size.height);
      final radius = (i % 3 == 0) ? 1.4 : (i % 2 == 0 ? 1.0 : 0.7);
      final alpha = isDark
          ? ((i % 4 == 0) ? 0.38 : (i % 2 == 0 ? 0.22 : 0.14))
          : ((i % 4 == 0) ? 0.16 : 0.08);

      paint.color = (isDark ? Colors.white : const Color(0xFF8B6A4F))
          .withValues(alpha: alpha);
      canvas.drawCircle(pos, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CelestialStardustPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
