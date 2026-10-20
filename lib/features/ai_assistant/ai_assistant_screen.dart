import '../../core/copy/app_copy.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/frozen_palette.dart';
import '../../shared/widgets/ascent_atmosphere.dart';
import '../../shared/widgets/message_composer.dart';
import '../../shared/widgets/glass_surface.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/ai/riya_learning_actions.dart';
import '../../core/services/home_capture_service.dart';
import '../home/widgets/home_schedule_sheet.dart';
import '../../core/ai/ai_service.dart';
import '../../core/ai/riya_capabilities.dart';
import '../../core/ai/riya_intents.dart';
import '../../core/ai/riya_alert_effects.dart';
import '../../core/learning_hub/learning_hub_provider.dart';
import '../../core/providers/home_layout_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';

class AiAssistantScreen extends ConsumerStatefulWidget {
  const AiAssistantScreen({
    super.key,
    this.initialPrompt,
    this.sourceThoughtId,
  });
  final String? initialPrompt;
  final int? sourceThoughtId;

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
    _textController.text = widget.initialPrompt ?? '';
    _hasInputText = _textController.text.trim().isNotEmpty;
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
      final homeProposal = HomeCaptureProposal.parse(prompt, DateTime.now());
      if (homeProposal.scheduledIntent &&
          (homeProposal.at != null ||
              homeProposal.followUp ||
              RegExp(
                r'\bremind me\b',
                caseSensitive: false,
              ).hasMatch(prompt))) {
        Thought? source;
        if (widget.sourceThoughtId != null) {
          final selected = await db.thoughtDao.getThoughtById(
            widget.sourceThoughtId!,
          );
          if (selected?.content.trim() == prompt) source = selected;
        }
        final sourceId =
            source?.id ??
            await db.thoughtDao.insertThought(
              ThoughtTableCompanion.insert(content: prompt),
            );
        source ??= await db.thoughtDao.getThoughtById(sourceId);
        if (!mounted || source == null) return;
        await showHomeSchedule(context, source);
        final plan = (await HomeCaptureService(db).plans())
            .where((p) => p.requestId == 'home.schedule:$sourceId')
            .firstOrNull;
        await aiDao.insertMessage(
          AiChatMessageTableCompanion.insert(
            sender: 'assistant',
            message: plan == null
                ? 'Your thought is saved. Finish scheduling from Home when ready.'
                : 'Your plan is saved and linked on Home. Check its alert status there.',
          ),
        );
        if (mounted) _textController.clear();
        return;
      }
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
        final executor = RiyaExecutor(
          db,
          external: _workspaceCommand,
          expectedWorkspaceRevision: db.workspaceRevision,
          verifyExternal: _verifyWorkspaceCommand,
        );
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
            _resolver?.rememberResult(result);
            options = result.options;
            data['quickOptions'] = options;
            if (result.reminderIds.isNotEmpty ||
                result.cancelReminderIds.isNotEmpty) {
              final verified = await RiyaAlertEffects.device(
                db,
              ).syncRequest(requestId);
              reply =
                  '${result.message.replaceFirst(' Device alert scheduling has not been verified.', '')}\n${verified ? 'Device alert changes verified.' : 'Device alert changes are pending and will be retried.'}';
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
          } catch (error) {
            if (error is RiyaCommittedActionError) {
              savedResult = error.result;
              data['requestId'] = requestId;
              data['route'] = error.result.route;
            }
            reply = savedResult != null
                ? '${savedResult.message} Confirmation history or device effects are pending verification.'
                : command.id == 'focus.start' &&
                      await db.timeSessionDao.getActiveFocusSession() != null
                ? 'A Focus session is already active. Open Focus to continue or finish it.'
                : error is StateError
                ? error.message.toString()
                : 'I could not verify that change. Check the relevant screen before trying again.';
            data['executionStatus'] = savedResult == null
                ? 'failed'
                : 'recovery_pending';
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
            AscentSnackBar.build(
              context,
              content: const Text(
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

  Future<RiyaResult?> _verifyWorkspaceCommand(RiyaCommand command) async {
    if (command.id == 'home.visibility') {
      final layout = ref.read(homeLayoutProvider);
      if (layout.visible.contains(command.arguments['section']) !=
          command.arguments['visible']) {
        return null;
      }
      return RiyaResult('Home visibility verified.', '/home');
    }
    final notifier = ref.read(learningHubProvider.notifier);
    if (riyaLearningCapabilities.any((c) => c.id == command.id)) {
      return RiyaLearningActions(
        notifier,
        () => ref.read(learningHubProvider),
        DateTime.now,
        db: ref.read(databaseProvider),
      ).verify(command);
    }
    await notifier.ready;
    final state = ref.read(learningHubProvider);
    if (command.id == 'learning.complete') {
      final course = state.courses
          .where((c) => c.id == command.arguments['courseId'])
          .firstOrNull;
      if (course?.modules
              .expand((m) => m.lectures)
              .any(
                (l) => l.id == command.arguments['lectureId'] && l.isCompleted,
              ) !=
          true) {
        return null;
      }
      return const RiyaResult('Lecture completion verified.', '/learning');
    }
    if (command.id == 'learning.pause' && !state.isPlaying) {
      return const RiyaResult('Learning pause verified.', '/learning');
    }
    if (command.id == 'learning.resume' && state.isPlaying) {
      return const RiyaResult('Learning resume verified.', '/learning');
    }
    return null;
  }

  Future<RiyaResult> _workspaceCommand(RiyaCommand command) async {
    final args = command.arguments;
    if (command.id.startsWith('home.')) {
      final layout = ref.read(homeLayoutProvider);
      if (command.id == 'home.layout') {
        return RiyaResult(
          'Home: ${layout.order.where(layout.visible.contains).map((id) => homeSections[id]).join(', ')}. Quick capture stays available.',
          '/home',
        );
      }
      final section = args['section'] as String;
      if (!homeSections.containsKey(section)) {
        throw ArgumentError('Choose a supported Home card');
      }
      final visible = {...layout.visible};
      args['visible'] == true ? visible.add(section) : visible.remove(section);
      await ref
          .read(homeLayoutProvider.notifier)
          .save(layout.copyWith(visible: visible));
      return RiyaResult(
        '${args['visible'] == true ? 'Showing' : 'Hidden'} ${homeSections[section]}. Records and services are unchanged.',
        '/home',
      );
    }
    final notifier = ref.read(learningHubProvider.notifier);
    if (riyaLearningCapabilities.any((c) => c.id == command.id)) {
      return RiyaLearningActions(
        notifier,
        () => ref.read(learningHubProvider),
        DateTime.now,
        db: ref.read(databaseProvider),
      ).run(command);
    }
    await notifier.ready;
    final state = ref.read(learningHubProvider);
    switch (command.id) {
      case 'learning.list':
        return RiyaResult(
          'Learning:\n${state.courses.take(3).map((c) => '${c.title} (${c.id}): ${c.completedLectures}/${c.totalLectures} completed').join('\n')}${state.courses.length > 3 ? '\nOpen Learning for all courses.' : ''}',
          '/learning',
        );
      case 'learning.complete':
        final completed = await notifier.markLectureCompleted(
          args['lectureId'],
          courseId: args['courseId'],
        );
        if (!completed) {
          throw StateError(
            'The study target has not been met, or progress could not be saved',
          );
        }
        return const RiyaResult('Lecture completion saved.', '/learning');
      case 'learning.pause':
        notifier.pause();
        return const RiyaResult('Learning paused.', '/learning');
      case 'learning.resume':
        notifier.play();
        if (!ref.read(learningHubProvider).isPlaying) {
          throw StateError('Select a lecture first');
        }
        return const RiyaResult(
          'Learning resumed. Study time is tracked; external video watching is not verified.',
          '/learning',
        );
      default:
        throw UnsupportedError('Unsupported workspace action');
    }
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
                    ? context.bgBase.withValues(alpha: 0.72)
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
                        context.glass.clay.withValues(alpha: 0.25),
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
                      color: context.glass.sage,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? context.bgBase : Colors.white,
                        width: 1.8,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: context.glass.sage.withValues(alpha: 0.6),
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
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: context.textPrimary,
                            fontSize: 16.5,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    'Intelligent · On-Device · Private',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: context.textMuted,
                    ),
                  ),
                ],
              ),
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
                            '$name is thinking',
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
                        hint: AppCopy.messageHint(name),
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
                ? context.bgSurface.withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? context.glass.edge : context.divider,
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

    final timeString =
        "${msg.createdAt.hour % 12 == 0 ? 12 : msg.createdAt.hour % 12}:${msg.createdAt.minute.toString().padLeft(2, '0')} ${msg.createdAt.hour >= 12 ? 'PM' : 'AM'}";

    return Column(
      crossAxisAlignment: isUser
          ? CrossAxisAlignment.end
          : CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        GlassSurface(
          key: ValueKey('chat-glass-${msg.id}'),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 18 : 6),
            bottomRight: Radius.circular(isUser ? 6 : 18),
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
                  color: context.glass.ink,
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
                        color: context.glass.inkMuted,
                      ),
                    ),
                    if (isUser) ...[
                      const SizedBox(width: 3),
                      Icon(
                        Icons.done_all_rounded,
                        size: 11,
                        color: context.glass.inkMuted,
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
          GlassSurface(
            radius: 14,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  actionData?['write'] == true
                      ? Icons.check_circle_rounded
                      : Icons.info_outline_rounded,
                  size: 15,
                  color: context.glass.sage,
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
                            color: context.glass.sage,
                          ),
                        ),
                        const SizedBox(width: 2),
                        Icon(
                          Icons.arrow_forward_ios_rounded,
                          size: 9,
                          color: context.glass.sage,
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
                          ? context.bgSurface.withValues(alpha: 0.85)
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
                  ? context.bgSurface.withValues(alpha: 0.88)
                  : Colors.white.withValues(alpha: 0.92),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isDark
                    ? context.glass.edge
                    : context.divider,
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
                    context.glass.clay.withValues(alpha: 0.25),
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
                    ? context.bgSurface.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark
                      ? context.glass.edge
                      : context.divider,
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 6,
                    height: 6,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: context.glass.sage,
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
                                ? context.bgSurface.withValues(alpha: 0.85)
                                : Colors.white.withValues(alpha: 0.90),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: isDark
                                  ? context.glass.edge
                                  : context.divider,
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
    if (context.glass.frozen) {
      return DecoratedBox(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              FrozenPalette.surface,
              FrozenPalette.canvas,
              FrozenPalette.elevated,
            ],
          ),
        ),
        child: const AscentAtmosphereBackground(child: SizedBox.expand()),
      );
    }
    return AscentAtmosphereBackground(
      glow1: isDark ? context.glass.glow1 : context.glass.claySoft,
      glow2: isDark ? context.glass.glow2 : context.glass.slateSoft,
      child: const SizedBox.expand(),
    );
  }
}
