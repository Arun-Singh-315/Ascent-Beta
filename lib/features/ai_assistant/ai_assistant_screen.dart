import '../../core/ai/riya_conversation_provider.dart';
import '../../features/promises/models/promise_model.dart';
import '../../features/promises/services/promise_intent_parser.dart';
import 'riya_entity_card.dart';
import 'dart:convert';
import 'dart:ui' as ui;
import 'package:intl/intl.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/frozen_palette.dart';
import '../../app/theme/merlot_palette.dart';
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
    this.compact = false,
  });
  final bool compact;
  static Future<void> showFromHome(
    BuildContext context,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    enableDrag: false,
    builder: (context) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SizedBox(
        height:
            (MediaQuery.sizeOf(context).height * .88 -
                    MediaQuery.viewInsetsOf(context).bottom)
                .clamp(240, MediaQuery.sizeOf(context).height * .88),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          child: const AiAssistantScreen(compact: true),
        ),
      ),
    ),
  );
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
  final _composerFocus = FocusNode();
  RiyaIntentResolver get _conversation {
    final resolver = _resolver ?? ref.read(riyaConversationProvider);
    _resolver = resolver;
    return _resolver!;
  }

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
    _composerFocus.dispose();
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
      await _expireReviews(aiDao);
      // 1. Insert user message with unique timestamp
      final userMessageId = await aiDao.insertMessage(
        AiChatMessageTableCompanion.insert(sender: 'user', message: prompt),
      );
      if (!mounted) return;
      _scrollToBottom();

      final db = ref.read(databaseProvider);
      final resolution = await _conversation
          .resolve(prompt)
          .timeout(const Duration(seconds: 5));
      final homeProposal = HomeCaptureProposal.parse(prompt, DateTime.now());
      final isConversational = RegExp(
        r'^(talk to me|hey|hi|hello|help me|how are you|good morning|what should i do)\b',
        caseSensitive: false,
      ).hasMatch(prompt.trim());

      if (resolution == null &&
          !isConversational &&
          homeProposal.scheduledIntent &&
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
          expectedWorkspaceRevision: db.workspaceRevision,
        );
        executor.validate(command);
        if (command.capability.requiresConfirmation) {
          actionType = command.id;
          reply = _reviewCopy(command);
          data.addAll({
            'pendingCommand': {
              'id': command.id,
              'arguments': command.arguments,
            },
            'executionStatus': 'proposed',
            'requestId': 'chat:$userMessageId',
            'workspaceRevision': db.workspaceRevision,
            'title': command.capability.description,
          });
        } else {
          final executed = await _executeCommand(
            command,
            'chat:$userMessageId',
          );
          reply = executed.$1;
          data.addAll(executed.$2);
          actionType = command.id;
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
    } catch (error) {
      try {
        await aiDao.insertMessage(
          AiChatMessageTableCompanion.insert(
            sender: 'assistant',
            message: error is ArgumentError
                ? error.message.toString()
                : 'I could not finish that response. Recover saved results before trying again.',
            actionPayloadJson: drift.Value(
              jsonEncode({
                'executionStatus': 'failed',
                'title': 'Response interrupted',
                'recoverable': true,
              }),
            ),
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
        try {
          await ref
              .read(sharedPreferencesProvider)
              .setString(
                riyaConversationKey,
                jsonEncode(_resolver?.conversationState ?? {}),
              );
        } catch (_) {}
        if (mounted) {
          setState(() => _isLoading = false);
          _scrollToBottom();
        }
      }
    }
  }

  void _editDraft(Map<String, dynamic> data) {
    if (_isLoading) return;
    final raw = Map<String, dynamic>.from(data['pendingCommand'] as Map);
    final args = Map<String, dynamic>.from(raw['arguments'] as Map);
    final id = raw['id'] as String;
    _textController.text = id == 'promises.create'
        ? 'Create a promise to ${args['text']}'
        : id == 'tasks.create'
        ? 'Create a todo to ${args['title']}'
        : id.endsWith('.edit')
        ? 'Edit ${id.startsWith('promises') ? 'promise' : 'task'} #${args['id']} to ${args['title']}'
        : '';
    _textController.selection = TextSelection.collapsed(
      offset: _textController.text.length,
    );
    _composerFocus.requestFocus();
  }

  String _reviewCopy(RiyaCommand command) {
    final a = command.arguments;
    if (command.id == 'promises.create') {
      final p = PromiseIntentParser.parse(a['text'] as String);
      return '“${p.title}”\n${p.schedule?.summary ?? 'Once'} · ${p.trackingType.name == 'duration' ? '${p.targetValue.toInt()} minutes' : 'Check-in'}\n${p.reminderTime == null ? 'No reminder. You can add one later.' : 'Reminder: ${p.reminderTime}'}';
    }
    if (command.id.endsWith('.delete')) {
      return 'Delete “${a['expectedTitle'] ?? 'the selected item'}”?${command.id.startsWith('tasks.') ? '\nLinked reminders and records will also be removed.' : '\nIts progress history will also be removed.'}';
    }
    if (command.id == 'tasks.create') {
      return 'Add “${a['title']}” to your Todos?\nDay: ${(a['plannedDate'] as String?)?.split('T').first ?? 'Today'}';
    }
    if (a['expectedTitle'] != null) {
      if (a['title'] != null) {
        return 'Rename “${a['expectedTitle']}” to “${a['title']}”?';
      }
      if (a['newDate'] != null || a['day'] != null) {
        return 'Move “${a['expectedTitle']}” to ${(a['newDate'] ?? a['day']).toString().split('T').first}?';
      }
      return '${command.capability.description}: “${a['expectedTitle']}”';
    }
    return command.preview;
  }

  Future<void> _saveResponse(
    AppDatabase db,
    int id,
    String text,
    Map<String, dynamic> data,
  ) async {
    await (db.update(
      db.aiChatMessageTable,
    )..where((m) => m.id.equals(id))).write(
      AiChatMessageTableCompanion(
        message: drift.Value(text),
        actionPayloadJson: drift.Value(jsonEncode(data)),
      ),
    );
  }

  Future<void> _expireReviews(AiAssistantDao dao) async {
    final db = ref.read(databaseProvider);
    final pending =
        await (db.select(db.aiChatMessageTable)..where(
              (m) => m.actionPayloadJson.like('%"executionStatus":"proposed"%'),
            ))
            .get();
    for (final message in pending) {
      try {
        final data = Map<String, dynamic>.from(
          jsonDecode(message.actionPayloadJson!) as Map,
        );
        data.remove('pendingCommand');
        data['executionStatus'] = 'superseded';
        await _saveResponse(
          db,
          message.id,
          'Replaced by your newer request. Nothing saved from this review.',
          data,
        );
      } catch (_) {
        /* Leave malformed legacy messages readable. */
      }
    }
  }

  Future<(String, Map<String, dynamic>)> _executeCommand(
    RiyaCommand command,
    String requestId,
  ) async {
    final db = ref.read(databaseProvider);
    final resolver = _conversation;
    final executor = RiyaExecutor(
      db,
      external: _workspaceCommand,
      verifyExternal: _verifyWorkspaceCommand,
      expectedWorkspaceRevision: db.workspaceRevision,
    );
    final data = <String, dynamic>{
      'title': command.capability.description,
      'requestId': requestId,
      'route': command.capability.route,
      'write': command.capability.write,
    };
    RiyaResult? committed;
    try {
      if (command.id.startsWith('focus.')) ref.read(timeTrackingProvider);
      final result = await executor.execute(
        command,
        requestId: requestId,
        approved: true,
      );
      committed = result;
      resolver.rememberResult(result);
      var reply = result.message;
      if (result.reminderIds.isNotEmpty ||
          result.cancelReminderIds.isNotEmpty ||
          result.promiseEffectIds.isNotEmpty) {
        final synced = await ref
            .read(riyaAlertEffectsProvider)
            .syncRequest(requestId);
        if (!synced) {
          data['alertsPending'] = true;
          reply += '\nSaved. Device alerts are pending and will be retried.';
        }
      }
      data.addAll({
        'summary': reply,
        'route': result.targetRoute,
        'executionStatus': 'verified',
        'entityType': result.entityType,
        'entityId': result.entityId,
        'records': result.records,
        'quickOptions': result.options,
      });
      if (command.id == 'navigation.open' && mounted) {
        context.push(result.route);
      }
      return (reply, data);
    } catch (error) {
      if (error is RiyaCommittedActionError) committed = error.result;
      data['executionStatus'] = committed == null
          ? 'failed'
          : 'recovery_pending';
      if (committed != null) {
        data['route'] = committed.targetRoute;
        data['entityType'] = committed.entityType;
        data['entityId'] = committed.entityId;
      }
      return (
        committed != null
            ? '${committed.message} Confirmation history or alerts still need verification.'
            : error is StateError
            ? error.message.toString()
            : error is ArgumentError
            ? error.message.toString()
            : 'I could not verify this change. Your records were kept.',
        data,
      );
    }
  }

  Future<void> _reviewMessage(
    AiChatMessage message,
    Map<String, dynamic> original,
    bool approved,
  ) async {
    if (_isLoading || original['executionStatus'] != 'proposed') return;
    final db = ref.read(databaseProvider);
    setState(() => _isLoading = true);
    try {
      final fresh = await (db.select(
        db.aiChatMessageTable,
      )..where((m) => m.id.equals(message.id))).getSingleOrNull();
      if (fresh == null) return;
      final data = Map<String, dynamic>.from(
        jsonDecode(fresh.actionPayloadJson!) as Map,
      );
      if (data['executionStatus'] != 'proposed') return;
      if (!approved) {
        data.remove('pendingCommand');
        data['executionStatus'] = 'cancelled';
        await _saveResponse(
          db,
          message.id,
          'Cancelled. Nothing changed.',
          data,
        );
        await _conversation.resolve('Cancel');
        return;
      }
      if (data['workspaceRevision'] != db.workspaceRevision) {
        throw StateError('The workspace changed. Ask again before saving.');
      }
      final raw = Map<String, dynamic>.from(data['pendingCommand'] as Map);
      final command = RiyaCommand(
        raw['id'] as String,
        Map<String, dynamic>.from(raw['arguments'] as Map),
      );
      final result = await _executeCommand(
        command,
        data['requestId'] as String,
      );
      await _saveResponse(db, message.id, result.$1, result.$2);
    } catch (error) {
      final data = {...original}..remove('pendingCommand');
      data['executionStatus'] = 'failed';
      await _saveResponse(
        db,
        message.id,
        error is StateError
            ? error.message.toString()
            : 'Could not finish. Ask again to review a fresh action.',
        data,
      );
    } finally {
      if (mounted) {
        try {
          await ref
              .read(sharedPreferencesProvider)
              .setString(
                riyaConversationKey,
                jsonEncode(_resolver?.conversationState ?? {}),
              );
        } catch (_) {}
        if (mounted) setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _recoverMessage(Map<String, dynamic>? data) async {
    if (_isLoading) return;
    setState(() => _isLoading = true);
    try {
      final request = data?['requestId'];
      if (request is String) {
        await ref.read(riyaAlertEffectsProvider).syncRequest(request);
      }
      await ref.read(aiAssistantDaoProvider).recoverCommandResponses();
      if (!mounted) return;
      final route = data?['route'];
      if (route is String &&
          !['tasks', 'promises'].contains(data?['entityType'])) {
        context.push(route);
      } else {
        AscentSnackBar.show(
          context,
          message:
              'Saved results checked. Your message can now be reviewed and sent again.',
        );
      }
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: 'Recovery is still pending. Try Recover again.',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

    return PopScope(
      canPop: !_isLoading,
      child: Scaffold(
        resizeToAvoidBottomInset: !widget.compact,
        extendBodyBehindAppBar: true,
        backgroundColor: isDark
            ? context.bgBase
            : (g.merlot
                  ? MerlotPalette.canvas
                  : (g.frozen ? FrozenPalette.canvas : context.bgBase)),
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
                      : context.bgBase.withValues(alpha: 0.82),
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
            onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
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
            if (widget.compact)
              IconButton(
                tooltip: 'Expand conversation',
                icon: const Icon(Icons.open_in_full_rounded),
                onPressed: _isLoading
                    ? null
                    : () {
                        final router = GoRouter.of(context);
                        Navigator.pop(context);
                        router.push(
                          Uri(
                            path: '/ai-assistant',
                            queryParameters: _textController.text.isEmpty
                                ? null
                                : {'prompt': _textController.text},
                          ).toString(),
                        );
                      },
              ),
            IconButton(
              icon: Icon(
                Icons.delete_sweep_outlined,
                color: context.textMuted,
                size: 21,
              ),
              tooltip: 'Clear chat history',
              onPressed: _isLoading
                  ? null
                  : () async {
                      HapticFeedback.lightImpact();
                      final confirmed = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          title: const Text('Clear chat history?'),
                          content: const Text(
                            'This removes your conversation with Riya. Your saved thoughts, tasks and reminders will stay available.',
                          ),
                          actions: [
                            TextButton(
                              onPressed: () => Navigator.pop(ctx, false),
                              child: const Text('Cancel'),
                            ),
                            FilledButton(
                              onPressed: () => Navigator.pop(ctx, true),
                              child: const Text('Clear history'),
                            ),
                          ],
                        ),
                      );
                      if (confirmed == true && mounted) {
                        await ref
                            .read(aiAssistantDaoProvider)
                            .clearChatHistory();
                        ref.read(riyaConversationProvider).resetConversation();
                        await ref
                            .read(sharedPreferencesProvider)
                            .remove(riyaConversationKey);
                      }
                    },
            ),
            const SizedBox(width: 6),
          ],
        ),
        body: Stack(
          fit: StackFit.expand,
          children: [
            // Breathtaking Night & Day Atmospheric Background
            _AtmosphericChatBackground(
              isDark: isDark,
              accentColor: accentColor,
            ),
            // Main Chat Interface
            StreamBuilder<List<AiChatMessage>>(
              stream: messagesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(AscentSpacing.xl),
                      child: Text(
                        'Connecting to memory...',
                        style: TextStyle(
                          color: context.textMuted,
                          fontSize: 13,
                        ),
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
                                    key: const ValueKey(
                                      'chat_loading_indicator',
                                    ),
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
                                    padding: const EdgeInsets.only(
                                      bottom: AscentSpacing.md,
                                    ),
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
                                        child: _ConversationMessageBubble(
                                          msg: msg,
                                          isUser: isUser,
                                          assistantName: name,
                                          accentColor: accentColor,
                                          actionData: actionData,
                                          messageQuickChips: messageQuickChips,
                                          onSelectChip: _handleSubmitted,
                                          busy: _isLoading,
                                          onEditDraft: () =>
                                              _editDraft(actionData!),
                                          onReview: (approved) =>
                                              _reviewMessage(
                                                msg,
                                                actionData!,
                                                approved,
                                              ),
                                          onRecover: () =>
                                              _recoverMessage(actionData),
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

                    // Quick suggestion chips: shown ONLY when chat is empty to prevent "box over box" clutter
                    if (!hasMessages) ...[
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: AscentSpacing.xs,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: _buildQuickChip(
                                widget.compact ? 'Todos' : 'Plan my day',
                                Icons.wb_sunny_rounded,
                                () => _handleSubmitted(
                                  widget.compact ? 'Show todos' : 'Plan my day',
                                ),
                                context,
                                accentColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildQuickChip(
                                widget.compact ? 'Promises' : 'Today\'s agenda',
                                Icons.checklist_rounded,
                                () => _handleSubmitted(
                                  widget.compact
                                      ? 'Show promises'
                                      : 'What are my tasks today?',
                                ),
                                context,
                                accentColor,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: _buildQuickChip(
                                widget.compact ? 'New Todo' : 'Medicines',
                                widget.compact
                                    ? Icons.add_rounded
                                    : Icons.medication_rounded,
                                () => _handleSubmitted(
                                  widget.compact
                                      ? 'New todo'
                                      : 'What are my medicines today?',
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
                        vertical: AscentSpacing.sm,
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
                          focusNode: _composerFocus,
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
        borderRadius: AscentRadii.borderLg,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: 7.5,
            horizontal: AscentSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: isDark
                ? context.bgSurface.withValues(alpha: 0.88)
                : Colors.white.withValues(alpha: 0.92),
            borderRadius: AscentRadii.borderLg,
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

class _ConversationMessageBubble extends StatelessWidget {
  final AiChatMessage msg;
  final bool isUser;
  final String assistantName;
  final Color accentColor;
  final Map<String, dynamic>? actionData;
  final List<String> messageQuickChips;
  final ValueChanged<String> onSelectChip;
  final VoidCallback onOpenCourse;
  final VoidCallback onOpenHub;
  final VoidCallback onRecover;
  final ValueChanged<bool> onReview;
  final bool busy;
  final VoidCallback onEditDraft;

  const _ConversationMessageBubble({
    required this.msg,
    required this.isUser,
    required this.assistantName,
    required this.accentColor,
    required this.actionData,
    required this.messageQuickChips,
    required this.onSelectChip,
    required this.onOpenCourse,
    required this.onOpenHub,
    required this.onRecover,
    required this.onReview,
    required this.busy,
    required this.onEditDraft,
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
          fillColor: isUser
              ? accentColor.withValues(alpha: isDark ? .22 : .10)
              : null,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isUser ? 22 : 7),
            bottomRight: Radius.circular(isUser ? 7 : 22),
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
                (actionData?['records'] as List? ?? []).isNotEmpty
                    ? (msg.actionType?.startsWith('promises.') == true
                          ? 'Here are your Promises.'
                          : 'Here are your Todos. Choose a card below.')
                    : msg.message,
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isUser
                      ? (isDark ? Colors.white : context.glass.ink)
                      : context.glass.ink,
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
                        color: context.glass.inkSecondary,
                      ),
                    ),
                    if (isUser) ...[
                      const SizedBox(width: 3),
                      Icon(
                        Icons.done_all_rounded,
                        size: 11,
                        color: context.glass.inkSecondary,
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),

        if (!isUser && actionData?['executionStatus'] == 'proposed')
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Builder(
              builder: (context) {
                final rawText = (actionData?['pendingCommand']?['arguments']?['text'] as String?) ?? '';
                final proposal = msg.actionType == 'promises.create' && rawText.isNotEmpty
                    ? PromiseIntentParser.parse(rawText)
                    : null;
                final taskTitle = msg.actionType == 'tasks.create'
                    ? (actionData?['pendingCommand']?['arguments']?['title'] as String?)
                    : null;
                final taskDate = msg.actionType == 'tasks.create'
                    ? (actionData?['pendingCommand']?['arguments']?['plannedDate'] as String?)?.split('T').first
                    : null;

                return GlassSurface(
                  radius: 18,
                  enableBlur: false,
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
                            decoration: BoxDecoration(
                              color: accentColor.withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              msg.actionType?.startsWith('promises.') == true
                                  ? 'PROMISE PREVIEW'
                                  : (msg.actionType?.startsWith('tasks.') == true
                                      ? 'TODO PREVIEW'
                                      : 'REVIEW ACTION'),
                              style: TextStyle(
                                fontSize: 10.5,
                                letterSpacing: 1.0,
                                color: accentColor,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        proposal?.title ?? taskTitle ?? (actionData?['title'] as String? ?? 'Review'),
                        style: TextStyle(
                          color: context.glass.ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          height: 1.25,
                        ),
                      ),
                      if (proposal != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: context.glass.fill.withValues(alpha: isDark ? 0.25 : 0.45),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: context.glass.line, width: 0.8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Icon(Icons.event_outlined, size: 14, color: accentColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      proposal.targetDate != null
                                          ? 'Target Date: ${proposal.targetDate!.day} ${DateFormat.MMM().format(proposal.targetDate!)} ${proposal.targetDate!.year}'
                                          : (proposal.schedule?.summary != null
                                              ? 'Schedule: ${proposal.schedule!.summary}'
                                              : 'Schedule: Every day (Daily)'),
                                      style: TextStyle(
                                        color: context.glass.ink,
                                        fontSize: 13,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(Icons.timer_outlined, size: 14, color: accentColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      proposal.trackingType == PromiseTrackingType.duration
                                          ? '${proposal.targetValue.toInt()} minutes per session'
                                          : (proposal.trackingType == PromiseTrackingType.frequency
                                              ? '${proposal.frequencyPerWeek} times a week'
                                              : 'Daily check-in commitment'),
                                      style: TextStyle(
                                        color: context.glass.inkSecondary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Row(
                                children: [
                                  Icon(Icons.notifications_active_outlined, size: 14, color: accentColor),
                                  const SizedBox(width: 6),
                                  Expanded(
                                    child: Text(
                                      proposal.reminderTime != null
                                          ? 'Reminder: ${proposal.reminderTime}'
                                          : 'No reminder',
                                      style: TextStyle(
                                        color: context.glass.inkSecondary,
                                        fontSize: 12.5,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ] else if (taskDate != null) ...[
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 14, color: accentColor),
                            const SizedBox(width: 6),
                            Text(
                              'Planned: $taskDate',
                              style: TextStyle(
                                color: context.glass.inkSecondary,
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          FilledButton.icon(
                            onPressed: busy ? null : () => onReview(true),
                            icon: Icon(
                              msg.actionType?.endsWith('.delete') == true
                                  ? Icons.delete_outline_rounded
                                  : Icons.check_rounded,
                              size: 16,
                            ),
                            label: Text(
                              msg.actionType?.endsWith('.delete') == true
                                  ? 'Delete'
                                  : 'Save',
                            ),
                          ),
                          if (msg.actionType?.endsWith('.create') == true ||
                              msg.actionType?.endsWith('.edit') == true)
                            TextButton.icon(
                              onPressed: busy ? null : onEditDraft,
                              icon: const Icon(Icons.edit_outlined, size: 14),
                              label: const Text('Change words'),
                            ),
                          TextButton(
                            onPressed: busy ? null : () => onReview(false),
                            child: const Text('Cancel'),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        if (!isUser)
          for (final record in (actionData?['records'] as List? ?? []))
            if (record is Map &&
                ['tasks', 'promises'].contains(record['type']) &&
                record['id'] is int)
              RiyaEntityCard(
                type: record['type'] as String,
                id: record['id'] as int,
                onCommand: onSelectChip,
                busy: busy,
              ),
        if (!isUser &&
            ['tasks', 'promises'].contains(actionData?['entityType']) &&
            actionData?['entityId'] is int &&
            (actionData?['records'] as List? ?? []).isEmpty)
          RiyaEntityCard(
            type: actionData!['entityType'] as String,
            id: actionData!['entityId'] as int,
            onCommand: onSelectChip,
            busy: busy,
          ),

        if (!isUser &&
                const [
                  'failed',
                  'recovery_pending',
                ].contains(actionData?['executionStatus']) ||
            (!isUser && actionData?['alertsPending'] == true))
          Padding(
            padding: const EdgeInsets.only(top: AscentSpacing.sm),
            child: GlassSurface(
              radius: AscentDimensions.radiusMd,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    actionData?['executionStatus'] == 'recovery_pending'
                        ? 'Verification pending'
                        : 'Action needs attention',
                    style: TextStyle(
                      color: context.textPrimary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    'Review saved changes before sending this request again.',
                    style: TextStyle(color: context.textMuted),
                  ),
                  TextButton.icon(
                    onPressed: onRecover,
                    icon: const Icon(Icons.restore_rounded),
                    label: const Text('Recover'),
                  ),
                ],
              ),
            ),
          ),

        // Attached Action Confirmation Capsule (Executed Directly)
        if (!isUser &&
            msg.actionType != null &&
            !['tasks', 'promises'].contains(actionData?['entityType']) &&
            (actionData?['records'] as List? ?? []).isEmpty &&
            actionData != null &&
            actionData!['executionStatus'] == 'verified' &&
            actionData!['title'] != null) ...[
          const SizedBox(height: 6),
          GlassSurface(
            radius: 14,
            padding: const EdgeInsets.symmetric(
              horizontal: AscentSpacing.md,
              vertical: 10,
            ),
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
                  borderRadius: AscentRadii.borderSm,
                  child: Container(
                    constraints: const BoxConstraints(
                      minWidth: AscentDimensions.minTouchTarget,
                      minHeight: AscentDimensions.minTouchTarget,
                    ),
                    alignment: Alignment.center,
                    padding: const EdgeInsets.all(AscentSpacing.sm),
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
                  borderRadius: AscentRadii.borderLg,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 11,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? context.bgSurface.withValues(alpha: 0.85)
                          : Colors.white.withValues(alpha: 0.90),
                      borderRadius: AscentRadii.borderLg,
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
  const _ThinkingBubble({required this.name, required this.accentColor});
  final String name;
  final Color accentColor;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.centerLeft,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 300),
      child: GlassSurface(
        radius: 18,
        enableBlur: false,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: accentColor,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '$name is checking…',
                style: TextStyle(color: context.glass.inkMuted, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    ),
  );
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
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: AscentSpacing.xs,
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? context.bgSurface.withValues(alpha: 0.85)
                    : Colors.white.withValues(alpha: 0.90),
                borderRadius: AscentRadii.borderMd,
                border: Border.all(
                  color: isDark ? context.glass.edge : context.divider,
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
                  Flexible(
                    child: Text(
                      '$assistantName · Always by your side',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: context.textMuted,
                      ),
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
                        borderRadius: AscentRadii.borderXl,
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 9.5,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? context.bgSurface.withValues(alpha: 0.85)
                                : Colors.white.withValues(alpha: 0.90),
                            borderRadius: AscentRadii.borderXl,
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
    final g = context.glass;
    final BoxDecoration decor;

    if (g.frozen) {
      decor = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? const [
                  FrozenPalette.darkCanvas,
                  FrozenPalette.darkSurface,
                  FrozenPalette.darkCanvas,
                ]
              : const [
                  FrozenPalette.surface,
                  FrozenPalette.canvas,
                  FrozenPalette.elevated,
                ],
        ),
      );
    } else if (g.merlot) {
      decor = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  MerlotPalette.darkCanvas,
                  MerlotPalette.darkSurface,
                  MerlotPalette.darkCanvas,
                ]
              : [
                  MerlotPalette.canvas,
                  MerlotPalette.surface,
                  MerlotPalette.canvas,
                ],
        ),
      );
    } else {
      decor = BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: isDark
              ? [
                  AscentColors.bgBaseDark,
                  AscentColors.bgSurfaceDark,
                  AscentColors.bgBaseDark,
                ]
              : [
                  AscentColors.bgBase,
                  AscentColors.bgSurface,
                  AscentColors.bgBase,
                ],
        ),
      );
    }

    return DecoratedBox(
      decoration: decor,
      child: AscentAtmosphereBackground(
        glow1: isDark ? g.glow1 : g.claySoft,
        glow2: isDark ? g.glow2 : g.slateSoft,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CustomPaint(painter: _CelestialStardustPainter(isDark: isDark)),
          ],
        ),
      ),
    );
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

      paint.color = (isDark ? Colors.white : AscentColors.accentSecondary)
          .withValues(alpha: alpha);
      canvas.drawCircle(pos, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _CelestialStardustPainter oldDelegate) =>
      oldDelegate.isDark != isDark;
}
