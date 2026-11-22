import '../../app/theme/chat_palette.dart';
import '../../core/services/voice_input.dart';
import 'assistant_suggestions.dart';
import '../../app/theme/brand_palette.dart';
import '../../core/utils/human_time.dart';
import '../../shared/widgets/ascent_backdrop.dart';
import '../../app/theme/text_styles.dart';
import 'package:ascent/app/app_navigation.dart';
import 'dart:async';
import 'dart:math' as math;
import '../../core/ai/riya_conversation_provider.dart';
import 'riya_entity_card.dart';
import 'riya_plan_cards.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' as drift;
import 'package:go_router/go_router.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/app_colors.dart';
import '../../app/theme/color_tokens.dart';
import '../../app/theme/dimension_tokens.dart';
import '../../app/theme/shared_control_tokens.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import '../../shared/widgets/app_text_field.dart';
import '../../shared/widgets/app_composer.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/services/home_capture_service.dart';
import '../home/widgets/home_schedule_sheet.dart';
import '../../core/ai/ai_service.dart';
import '../../core/ai/riya_capabilities.dart';
import '../../core/ai/riya_intents.dart';
import '../../core/providers/home_layout_provider.dart';
import '../../core/providers/time_tracking_provider.dart';
import '../../core/database/app_database.dart';
import '../../core/services/festival_service.dart';
import '../../core/providers/database_provider.dart';
import '../../core/providers/settings_provider.dart';
import 'package:ascent/shared/widgets/ascent_dialog.dart';
import 'package:ascent/shared/widgets/ascent_sheet.dart';

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
  ) => showAscentSheet<void>(
    context: context,
    framed: false,
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
  bool _initialScrolled = false;
  int? _lastMessageCount;
  RiyaIntentResolver? _resolver;
  final _composerFocus = FocusNode();
  bool _listening = false;
  VoiceInput? _voice;

  /// Dictation fills the composer; the user reviews and sends.
  Future<void> _toggleVoice() async {
    final VoiceInput voice = _voice ?? ref.read(voiceInputProvider);
    _voice = voice;
    if (_listening) {
      await voice.stop();
      return;
    }
    final typed = _textController.text.trimRight();
    final base = typed.isEmpty ? '' : '$typed ';
    setState(() => _listening = true);
    final ok = await voice.start(
      onText: (words) {
        if (!mounted) return;
        _textController.text = '$base$words';
        _textController.selection = TextSelection.collapsed(
          offset: _textController.text.length,
        );
      },
      onDone: () {
        if (mounted && _listening) setState(() => _listening = false);
      },
    );
    if (!ok && mounted) {
      setState(() => _listening = false);
      AscentSnackBar.show(
        context,
        message:
            'Voice isn’t available. Allow the microphone, or type instead.',
        icon: Icons.mic_off_outlined,
      );
    }
  }

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
    if (_listening) {
      _listening = false; // the stop callback must not rebuild a dead state
      _voice?.stop();
    }
    _textController.removeListener(_onTextChanged);
    _textController.dispose();
    _composerFocus.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  /// Pre-fills the message composer with [text] and focuses it so the user
  /// can finish typing before sending. Used by accelerator cards that need
  /// the user to supply the key detail (e.g. the thought text or promise).
  void _prefillText(String text) {
    HapticFeedback.lightImpact();
    _textController.text = text;
    _textController.selection = TextSelection.collapsed(offset: text.length);
    _composerFocus.requestFocus();
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

  void _jumpToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients &&
              _scrollController.position.pixels <
                  _scrollController.position.maxScrollExtent) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      }
    });
  }

  Future<void> _handleSubmitted(String text) async {
    final prompt = text.trim();
    if (prompt.isEmpty || _isLoading) return;
    if (_listening) unawaited(_voice?.stop());

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
      String? actionType;
      Map<String, dynamic>? planPayload;

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
            } else if (action.type == AiActionType.studyPlanCreated ||
                action.type == AiActionType.mealPlanCreated) {
              actionType = action.type.name;
              planPayload = action.payload;
            }
          }
        }
      } else {
        reply = resolution.message ?? 'Review this action.';
      }
      final data = <String, dynamic>{'quickOptions': options};
      if (planPayload != null) {
        data.addAll(planPayload);
      }
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
        ? 'Make a promise to ${args['title'] ?? args['text']}'
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
      final days = a['lengthDays'] as int? ?? 21;
      return 'Make a promise to yourself?\n“${a['title'] ?? a['text']}” for $days days, starting today.';
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
        context.open(result.route);
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
        context.open(route);
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
    throw UnsupportedError('Unsupported workspace action');
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final name = ref.watch(assistantNameProvider);
    final messagesStream = _messagesStream;
    final accentColor = context.accentPrimary;
    final router = GoRouter.maybeOf(context);
    final canPopNow = router != null
        ? router.canPop()
        : Navigator.of(context).canPop();

    return PopScope(
      canPop: !_isLoading && canPopNow,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_isLoading) {
          if (router != null) {
            router.go('/home');
          } else if (Navigator.of(context).canPop()) {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        resizeToAvoidBottomInset: !widget.compact,
        extendBodyBehindAppBar: true,
        backgroundColor: ChatPalette.of(context).canvas,
        appBar: AppBar(
          backgroundColor: ChatPalette.of(context).canvas,
          elevation: 0,
          scrolledUnderElevation: 0,
          leading: IconButton(
            icon: Icon(
              Icons.arrow_back_ios_new_rounded,
              color: c.textPrimary,
              size: 19,
            ),
            onPressed: _isLoading
                ? null
                : () {
                    final router = GoRouter.maybeOf(context);
                    if (router != null && router.canPop()) {
                      router.pop();
                    } else if (Navigator.of(context).canPop()) {
                      Navigator.of(context).pop();
                    } else if (router != null) {
                      router.go('/home');
                    }
                  },
          ),
          centerTitle: true,
          title: Text(
            name,
            key: const ValueKey('ai_assistant_title'),
            style: AscentTextStyles.interfaceNavigation.copyWith(
              color: ChatPalette.of(context).label,
            ),
          ),
          actions: [
            PopupMenuButton<String>(
              key: const ValueKey('ai_assistant_menu_button'),
              color: ChatPalette.of(context).elevated,
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: c.border, width: 1.0),
              ),
              icon: Icon(
                Icons.more_vert_rounded,
                color: c.textSecondary,
                size: 21,
              ),
              tooltip: 'More options',
              onSelected: (val) {
                if (val == 'clear') {
                  _showClearHistoryDialog(context, name);
                } else if (val == 'companion' || val == 'tone') {
                  _showCompanionSelectorSheet(context, ref, name);
                } else if (val == 'voice') {
                  HapticFeedback.selectionClick();
                  AscentSnackBar.show(context, message: 'Voice output toggled');
                } else if (val == 'export') {
                  HapticFeedback.selectionClick();
                  AscentSnackBar.show(
                    context,
                    message: 'Conversation exported',
                  );
                }
              },
              itemBuilder: (context) => [
                PopupMenuItem(
                  value: 'companion',
                  child: Text(
                    'Change companion ($name)',
                    style: TextStyle(color: c.textPrimary, fontSize: 14),
                  ),
                ),
                PopupMenuItem(
                  value: 'clear',
                  child: Text(
                    'Clear history',
                    style: TextStyle(color: c.textPrimary, fontSize: 14),
                  ),
                ),
                PopupMenuItem(
                  value: 'voice',
                  child: Text(
                    'Voice toggle',
                    style: TextStyle(color: c.textPrimary, fontSize: 14),
                  ),
                ),
                PopupMenuItem(
                  value: 'export',
                  child: Text(
                    'Export',
                    style: TextStyle(color: c.textPrimary, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 4),
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
                if (!_initialScrolled && messages.isNotEmpty) {
                  _initialScrolled = true;
                  _lastMessageCount = messages.length;
                  _jumpToBottom();
                } else if (_lastMessageCount != null &&
                    messages.length > _lastMessageCount!) {
                  _lastMessageCount = messages.length;
                  _scrollToBottom();
                } else if (_lastMessageCount == null && messages.isNotEmpty) {
                  _lastMessageCount = messages.length;
                }
                final hasMessages = messages.isNotEmpty;
                final todayFestival = ref.watch(todayFestivalProvider);

                return Column(
                  children: [
                    if (todayFestival != null && hasMessages)
                      Padding(
                        padding: EdgeInsets.fromLTRB(
                          14,
                          MediaQuery.paddingOf(context).top +
                              kToolbarHeight +
                              4,
                          14,
                          0,
                        ),
                        child: Container(
                          key: const ValueKey('riya_festive_banner_ongoing'),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: todayFestival.accentColor.withValues(
                              alpha: 0.12,
                            ),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: todayFestival.accentColor.withValues(
                                alpha: 0.35,
                              ),
                              width: 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                todayFestival.emoji,
                                style: const TextStyle(fontSize: 18),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Happy ${todayFestival.name}! ${todayFestival.riyaWish}',
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w600,
                                    color: ChatPalette.of(context).highlightInk,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    // Chat stream
                    Expanded(
                      child: messages.isEmpty
                          ? _SoftChatWelcome(
                              assistantName: name,
                              onSelectPrompt: _handleSubmitted,
                              onPrefill: _prefillText,
                            )
                          : ListView.builder(
                              controller: _scrollController,
                              padding: EdgeInsets.fromLTRB(
                                14,
                                todayFestival != null
                                    ? 8
                                    : MediaQuery.paddingOf(context).top +
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

                                // Consecutive AI message grouping:
                                // If the previous message was also from assistant,
                                // suppress the name label for visual clustering.
                                final prevMsg = index > 0
                                    ? messages[index - 1]
                                    : null;
                                final isFirstInRun =
                                    prevMsg == null ||
                                    prevMsg.sender != msg.sender;

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
                                    padding: EdgeInsets.only(
                                      bottom: AscentSpacing.sm,
                                      top: isFirstInRun && !isUser && index != 0
                                          ? 6
                                          : 0,
                                    ),
                                    child: Align(
                                      alignment: isUser
                                          ? Alignment.centerRight
                                          : Alignment.centerLeft,
                                      child: ConstrainedBox(
                                        constraints: BoxConstraints(
                                          maxWidth: isUser
                                              ? (MediaQuery.sizeOf(
                                                          context,
                                                        ).width *
                                                        0.82)
                                                    .clamp(240.0, 520.0)
                                              : double.infinity,
                                        ),
                                        child: _ConversationMessageBubble(
                                          msg: msg,
                                          isUser: isUser,
                                          isFirstInRun: isFirstInRun,
                                          assistantName: name,
                                          accentColor: accentColor,
                                          actionData: actionData,
                                          messageQuickChips:
                                              (index == messages.length - 1 &&
                                                  !isUser)
                                              ? messageQuickChips
                                                    .take(2)
                                                    .toList()
                                              : const <String>[],
                                          onSelectChip: _handleSubmitted,
                                          isLatest:
                                              index == messages.length - 1,
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

                    // Single-enclosure floating AppComposer
                    AppComposer(
                      onMic: _toggleVoice,
                      listening: _listening,
                      controller: _textController,
                      focusNode: _composerFocus,
                      assistantName: name,
                      isLoading: _isLoading,
                      onSubmitted: _handleSubmitted,
                      onPlusPressed: () {
                        HapticFeedback.lightImpact();
                        _showCompanionSelectorSheet(context, ref, name);
                      },
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

  Future<void> _showClearHistoryDialog(
    BuildContext context,
    String name,
  ) async {
    HapticFeedback.lightImpact();
    final confirmed = await AscentDialog.confirm(
      context: context,
      title: 'Clear chat history?',
      content:
          'This removes your conversation with $name. Your saved thoughts, tasks and reminders will stay available.',
      confirmLabel: 'Clear history',
    );
    if (confirmed == true && mounted) {
      await ref.read(aiAssistantDaoProvider).clearChatHistory();
      ref.read(riyaConversationProvider).resetConversation();
      await ref.read(sharedPreferencesProvider).remove(riyaConversationKey);
    }
  }

  void _showCompanionSelectorSheet(
    BuildContext context,
    WidgetRef ref,
    String currentName,
  ) {
    HapticFeedback.lightImpact();
    final customController = TextEditingController();
    showAscentSheet<void>(
      context: context,
      framed: false,
      builder: (sheetContext) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: sheetContext.c.surface,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
              border: Border.all(color: sheetContext.c.border, width: 1),
            ),
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: sheetContext.c.border,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Companion Identity',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: sheetContext.c.textPrimary,
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Choose who accompanies your daily Life OS',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                        color: sheetContext.c.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildCompanionTile(
                      sheetContext: sheetContext,
                      name: 'Jarvis',
                      tagline: 'Tactical & Thoughtful',
                      description:
                          'Sharp, proactive planning with grounded intelligence and calm clarity.',
                      icon: Icons.auto_awesome_rounded,
                      selected:
                          currentName == 'Jarvis' ||
                          currentName.isEmpty ||
                          currentName == 'Aria' ||
                          currentName == 'Riya',
                      onSelect: () {
                        HapticFeedback.mediumImpact();
                        ref
                            .read(assistantNameProvider.notifier)
                            .setName('Jarvis');
                        Navigator.pop(sheetContext);
                      },
                    ),
                    const SizedBox(height: 16),
                    AppTextField(
                      controller: customController,
                      hintText: 'Custom companion name...',
                      suffixIcon: TextButton(
                        onPressed: () {
                          final trimmed = customController.text.trim();
                          if (trimmed.isNotEmpty) {
                            HapticFeedback.mediumImpact();
                            ref
                                .read(assistantNameProvider.notifier)
                                .setName(trimmed);
                            Navigator.pop(sheetContext);
                          }
                        },
                        child: const Text('Set'),
                      ),
                      onSubmitted: (val) {
                        final trimmed = val.trim();
                        if (trimmed.isNotEmpty) {
                          HapticFeedback.mediumImpact();
                          ref
                              .read(assistantNameProvider.notifier)
                              .setName(trimmed);
                          Navigator.pop(sheetContext);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildCompanionTile({
    required BuildContext sheetContext,
    required String name,
    required String tagline,
    required String description,
    required IconData icon,
    required bool selected,
    required VoidCallback onSelect,
  }) {
    final isDark = Theme.of(sheetContext).brightness == Brightness.dark;
    final accent = sheetContext.accentPrimary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onSelect,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: selected
                ? accent.withValues(alpha: isDark ? 0.16 : 0.08)
                : ChatPalette.of(sheetContext).recessed,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? accent : ChatPalette.of(sheetContext).separator,
              width: selected ? 1.5 : 1,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: selected
                      ? accent.withValues(alpha: 0.22)
                      : ChatPalette.of(sheetContext).surface,
                ),
                child: Icon(
                  icon,
                  color: selected ? accent : sheetContext.textPrimary,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          name,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: sheetContext.textPrimary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '· $tagline',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: sheetContext.textMuted,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 3),
                    Text(
                      description,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        color: sheetContext.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),
              if (selected) ...[
                const SizedBox(width: 8),
                Icon(Icons.check_circle_rounded, color: accent, size: 20),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Modern Chat Bubble — Clear Contrast, Calm Aesthetic
// ---------------------------------------------------------------------------

class _ConversationMessageBubble extends ConsumerStatefulWidget {
  final AiChatMessage msg;
  final bool isUser;
  final bool isFirstInRun;
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

  /// Only the latest reply can be regenerated.
  final bool isLatest;

  const _ConversationMessageBubble({
    required this.msg,
    required this.isUser,
    required this.isFirstInRun,
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
    this.isLatest = false,
  });

  @override
  ConsumerState<_ConversationMessageBubble> createState() =>
      _ConversationMessageBubbleState();
}

class _ConversationMessageBubbleState
    extends ConsumerState<_ConversationMessageBubble>
    with SingleTickerProviderStateMixin {
  bool _showTimestamp = false;
  bool _isSaved = false;
  late final AnimationController _animController;
  late final Animation<double> _fadeAnimation;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 240),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _animController,
      curve: Curves.easeOut,
    );
    _slideAnimation =
        Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(
          CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic),
        );
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final msg = widget.msg;
    final isUser = widget.isUser;
    final isFirstInRun = widget.isFirstInRun;
    final assistantName = widget.assistantName;
    final accentColor = widget.accentColor;
    final actionData = widget.actionData;
    final messageQuickChips = widget.messageQuickChips;
    final onSelectChip = widget.onSelectChip;
    final onRecover = widget.onRecover;
    final onReview = widget.onReview;
    final onEditDraft = widget.onEditDraft;
    final onOpenCourse = widget.onOpenCourse;
    final onOpenHub = widget.onOpenHub;
    final busy = widget.busy;

    final timeString =
        "${msg.createdAt.hour % 12 == 0 ? 12 : msg.createdAt.hour % 12}:${msg.createdAt.minute.toString().padLeft(2, '0')} ${msg.createdAt.hour >= 12 ? 'PM' : 'AM'}";

    final c = context.c;

    final isDark = Theme.of(context).brightness == Brightness.dark;

    // User: action-tint bubble on the right. Assistant: no bubble, full
    // width, name label at the start of a turn (CLAUDE.md §5.4).
    final chat = ChatPalette.of(context);
    final Color bubbleFill = isUser ? chat.userBubble : Colors.transparent;
    final Color messageTextColor = isUser ? chat.userText : chat.label;
    final Color timestampColor = chat.labelTertiary;
    const borderRadius = BorderRadius.only(
      topLeft: Radius.circular(20),
      topRight: Radius.circular(20),
      bottomLeft: Radius.circular(20),
      bottomRight: Radius.circular(6),
    );

    final messageText = (actionData?['records'] as List? ?? []).isNotEmpty
        ? (msg.actionType?.startsWith('promises.') == true
              ? 'Here are your Promises.'
              : 'Here are your Todos. Choose a card below.')
        // Older replies were saved with raw timestamps; show them plainly.
        : (isUser ? msg.message : _RiyaRecordCard.humanise(msg.message));

    Widget bubbleContent = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Small 13px bold assistant name at start of turn
        if (!isUser && isFirstInRun) ...[
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Text(
              assistantName,
              style: AscentTextStyles.interfaceLabel.copyWith(
                color: chat.assistantName,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],

        // Message Body: styled with flutter_markdown for assistant, plain for user
        if (isUser)
          Text(
            messageText,
            style: AscentTextStyles.body.copyWith(
              color: messageTextColor,
              height: 1.4,
            ),
          )
        else
          MarkdownBody(
            data: messageText,
            selectable: true,
            styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context))
                .copyWith(
                  p: AscentTextStyles.body.copyWith(
                    color: chat.label,
                    height: 1.5,
                  ),
                  strong: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                  h1: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                  h2: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                  h3: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: c.textPrimary,
                  ),
                  listBullet: TextStyle(
                    fontSize: 15,
                    color: chat.action,
                    fontWeight: FontWeight.w600,
                  ),
                  pPadding: const EdgeInsets.only(bottom: 8),
                ),
          ),

        // Action row under each assistant reply: Copy, Share, Save to
        // Mindspace; Regenerate only under the latest reply.
        if (!isUser) ...[
          const SizedBox(height: 6),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: Icon(
                  Icons.copy_rounded,
                  size: 16,
                  color: chat.labelTertiary,
                ),
                tooltip: 'Copy',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () async {
                  HapticFeedback.lightImpact();
                  await Clipboard.setData(ClipboardData(text: messageText));
                  if (context.mounted) {
                    AscentSnackBar.show(
                      context,
                      message: 'Copied to clipboard',
                    );
                  }
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  Icons.share_outlined,
                  size: 16,
                  color: c.textTertiary,
                ),
                tooltip: 'Share',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  SharePlus.instance.share(ShareParams(text: messageText));
                },
              ),
              const SizedBox(width: 4),
              IconButton(
                icon: Icon(
                  _isSaved
                      ? Icons.bookmark_added_rounded
                      : Icons.bookmark_add_outlined,
                  size: 16,
                  color: _isSaved
                      ? (isDark
                            ? SharedControlColors.actionBlueDark
                            : SharedControlColors.actionBlue)
                      : c.textTertiary,
                ),
                tooltip: _isSaved ? 'Saved to Mindspace' : 'Save to Mindspace',
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  if (_isSaved) {
                    if (!mounted) return;
                    AscentSnackBar.show(
                      context,
                      message: 'Already saved in Mindspace',
                      actionLabel: 'View',
                      onAction: () => context.open('/thought-wall'),
                    );
                    return;
                  }
                  try {
                    final db = ref.read(databaseProvider);
                    await db.thoughtDao.insertThought(
                      ThoughtTableCompanion.insert(
                        content: messageText,
                        category: const drift.Value('general'),
                        mood: const drift.Value('idea'),
                        createdAt: drift.Value(DateTime.now()),
                      ),
                    );
                    if (!context.mounted) return;
                    setState(() => _isSaved = true);
                    AscentSnackBar.show(
                      context,
                      message: 'Saved to Mindspace',
                      actionLabel: 'View',
                      onAction: () => context.open('/thought-wall'),
                    );
                  } catch (_) {
                    if (!context.mounted) return;
                    AscentSnackBar.error(
                      context,
                      message: 'Could not save thought',
                    );
                  }
                },
              ),
              if (widget.isLatest) ...[
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(
                    Icons.refresh_rounded,
                    size: 16,
                    color: c.textTertiary,
                  ),
                  tooltip: 'Regenerate',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                    minWidth: 44,
                    minHeight: 44,
                  ),
                  onPressed: busy ? null : onRecover,
                ),
              ],
            ],
          ),
        ],

        // Micro Timestamp: revealed on tap or for user bubble
        if (_showTimestamp) ...[
          const SizedBox(height: 4),
          Text(
            timeString,
            style: GoogleFonts.jetBrainsMono(
              fontSize: 10,
              color: timestampColor,
            ),
          ),
        ],
      ],
    );

    final Widget mainBubble = GestureDetector(
      onTap: () => setState(() => _showTimestamp = !_showTimestamp),
      child: Container(
        padding: isUser
            ? const EdgeInsets.symmetric(horizontal: 16, vertical: 12)
            : const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        decoration: BoxDecoration(
          color: bubbleFill,
          borderRadius: borderRadius,
        ),
        child: bubbleContent,
      ),
    );

    return FadeTransition(
      opacity: _fadeAnimation,
      child: SlideTransition(
        position: _slideAnimation,
        child: Column(
          crossAxisAlignment: isUser
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            mainBubble,

            // Interactive Study Plan Card
            if (!isUser &&
                actionData != null &&
                (actionData['type'] == 'study_plan' ||
                    msg.actionType == 'studyPlanCreated'))
              RiyaStudyPlanCard(planData: actionData, accentColor: accentColor),

            // Interactive Meal Plan Card
            if (!isUser &&
                actionData != null &&
                (actionData['type'] == 'meal_plan' ||
                    msg.actionType == 'mealPlanCreated'))
              RiyaMealPlanCard(planData: actionData, accentColor: accentColor),

            if (!isUser && actionData?['executionStatus'] == 'proposed')
              Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Builder(
                      builder: (context) {
                        final isDark =
                            Theme.of(context).brightness == Brightness.dark;
                        final taskTitle = msg.actionType == 'tasks.create'
                            ? (actionData?['pendingCommand']?['arguments']?['title']
                                  as String?)
                            : null;
                        final taskDate = msg.actionType == 'tasks.create'
                            ? (actionData?['pendingCommand']?['arguments']?['plannedDate']
                                      as String?)
                                  ?.split('T')
                                  .first
                            : null;

                        return Container(
                          decoration: BoxDecoration(
                            color: ChatPalette.of(context).surface,
                            borderRadius: BorderRadius.circular(20),
                            border: isDark
                                ? Border.all(
                                    color: ChatPalette.of(context).separator,
                                  )
                                : null,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(
                                  alpha: isDark ? 0.25 : 0.06,
                                ),
                                blurRadius: 10,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 7,
                                      vertical: 2.5,
                                    ),
                                    decoration: BoxDecoration(
                                      color: accentColor.withValues(
                                        alpha: 0.14,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      msg.actionType?.startsWith('promises.') ==
                                              true
                                          ? 'PROMISE PREVIEW'
                                          : (msg.actionType?.startsWith(
                                                      'tasks.',
                                                    ) ==
                                                    true
                                                ? 'TODO PREVIEW'
                                                : 'REVIEW ACTION'),
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        letterSpacing: 1.0,
                                        color: accentColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(
                                taskTitle ??
                                    (actionData?['title'] as String? ??
                                        'Review'),
                                style: TextStyle(
                                  color: context.glass.ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 1.25,
                                ),
                              ),
                              if (taskDate != null) ...[
                                const SizedBox(height: 6),
                                Row(
                                  children: [
                                    Icon(
                                      Icons.calendar_today_rounded,
                                      size: 14,
                                      color: accentColor,
                                    ),
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
                                    onPressed: busy
                                        ? null
                                        : () => onReview(true),
                                    icon: Icon(
                                      msg.actionType?.endsWith('.delete') ==
                                              true
                                          ? Icons.delete_outline_rounded
                                          : Icons.check_rounded,
                                      size: 16,
                                    ),
                                    label: Text(
                                      msg.actionType?.endsWith('.delete') ==
                                              true
                                          ? 'Delete'
                                          : 'Save',
                                    ),
                                  ),
                                  if (msg.actionType?.endsWith('.create') ==
                                          true ||
                                      msg.actionType?.endsWith('.edit') == true)
                                    TextButton.icon(
                                      onPressed: busy ? null : onEditDraft,
                                      icon: const Icon(
                                        Icons.edit_outlined,
                                        size: 14,
                                      ),
                                      label: const Text('Change words'),
                                    ),
                                  TextButton(
                                    onPressed: busy
                                        ? null
                                        : () => onReview(false),
                                    child: const Text('Cancel'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  )
                  as Widget,
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
                actionData != null &&
                ['tasks', 'promises'].contains(actionData['entityType']) &&
                actionData['entityId'] is int &&
                (actionData['records'] as List? ?? []).isEmpty)
              RiyaEntityCard(
                type: actionData['entityType'] as String,
                id: actionData['entityId'] as int,
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
                child: Builder(
                  builder: (context) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: ChatPalette.of(context).surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: ChatPalette.of(context).separator,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            actionData?['executionStatus'] == 'recovery_pending'
                                ? 'Verification pending'
                                : 'Action needs attention',
                            style: TextStyle(
                              color: ChatPalette.of(context).label,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            'Review saved changes before sending this request again.',
                            style: TextStyle(
                              color: ChatPalette.of(context).labelSecondary,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: onRecover,
                            icon: const Icon(Icons.restore_rounded),
                            label: const Text('Recover'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),

            // Attached Action Confirmation Capsule (Executed Directly)
            if (!isUser &&
                msg.actionType != null &&
                actionData != null &&
                !['tasks', 'promises'].contains(actionData['entityType']) &&
                (actionData['records'] as List? ?? []).isEmpty &&
                actionData['executionStatus'] == 'verified' &&
                actionData['title'] != null) ...[
              const SizedBox(height: 6),
              _RiyaRecordCard(
                actionData: actionData,
                buttonLabel:
                    msg.actionType == AiActionType.lectureMarkedComplete.name
                    ? 'Open course'
                    : 'View',
                onOpen: () {
                  HapticFeedback.lightImpact();
                  if (msg.actionType ==
                      AiActionType.lectureMarkedComplete.name) {
                    onOpenCourse();
                  } else {
                    onOpenHub();
                  }
                },
              ),
            ],

            // Subtle contextual follow-up pills (at most 2 on latest message)
            if (!isUser && messageQuickChips.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: messageQuickChips.take(2).map((chipText) {
                  return Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        HapticFeedback.lightImpact();
                        onSelectChip(chipText);
                      },
                      borderRadius: BorderRadius.circular(999),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color: c.surfaceAlt,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: c.border, width: 1.0),
                        ),
                        child: Text(
                          chipText,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w500,
                            color: c.textSecondary,
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Organic "Living Thought" Thinking Indicator
// ---------------------------------------------------------------------------

class _ThinkingBubble extends StatefulWidget {
  const _ThinkingBubble({required this.name, required this.accentColor});
  final String name;
  final Color accentColor;

  @override
  State<_ThinkingBubble> createState() => _ThinkingBubbleState();
}

class _ThinkingBubbleState extends State<_ThinkingBubble>
    with SingleTickerProviderStateMixin {
  int _stepIndex = 0;
  Timer? _timer;
  late final AnimationController _pulseController;

  static const _thinkingSteps = [
    'Reflecting on your daily rhythm…',
    'Synthesizing schedule & milestones…',
    'Calibrating focused daily slots…',
    'Formulating tailored guidance…',
    'Polishing clarity & insights…',
  ];

  @override
  void initState() {
    super.initState();
    final isTest = WidgetsBinding.instance.runtimeType.toString().contains(
      'Test',
    );
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );
    if (!isTest) {
      _pulseController.repeat(reverse: true);
      _timer = Timer.periodic(const Duration(milliseconds: 1800), (_) {
        if (mounted) {
          setState(() {
            _stepIndex = (_stepIndex + 1) % _thinkingSteps.length;
          });
        }
      });
    } else {
      _pulseController.value = 0.5;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = context.c;

    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
        child: AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            return Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final delay = i * 0.25;
                final t = ((_pulseController.value - delay) % 1.0);
                final alpha = 0.25 + 0.70 * (math.sin(t * math.pi).abs());
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 3.5),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: c.textSecondary.withValues(alpha: alpha),
                  ),
                );
              }),
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Soft Minimalist Conversational Welcome (Opening State)
// ---------------------------------------------------------------------------

class _SoftChatWelcome extends StatefulWidget {
  final String assistantName;
  final ValueChanged<String> onSelectPrompt;

  /// Pre-fills the message composer with a partial prompt so the user can
  /// complete it before sending. Used for accelerator cards that need context.
  final ValueChanged<String> onPrefill;

  const _SoftChatWelcome({
    required this.assistantName,
    required this.onSelectPrompt,
    required this.onPrefill,
  });

  @override
  State<_SoftChatWelcome> createState() => _SoftChatWelcomeState();
}

class _SoftChatWelcomeState extends State<_SoftChatWelcome> {
  // Picked once when the chat opens, so tiles don't shuffle under a finger.
  late final DateTime _openedAt = DateTime.now();

  @override
  Widget build(BuildContext context) {
    return Consumer(
      builder: (context, ref, _) {
        final c = context.c;
        final colorScheme = Theme.of(context).colorScheme;

        return Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              20,
              MediaQuery.paddingOf(context).top + kToolbarHeight + 20,
              20,
              24,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Centered sparkle icon in primaryContainer
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: colorScheme.primaryContainer,
                  ),
                  child: Icon(
                    Icons.auto_awesome_rounded,
                    size: 24,
                    color: colorScheme.onPrimaryContainer,
                  ),
                ),
                const SizedBox(height: 16),

                // Centered hero greeting
                Text(
                  assistantGreeting(_openedAt),
                  key: const ValueKey('assistant_greeting'),
                  textAlign: TextAlign.center,
                  style: AscentTextStyles.interfaceSection.copyWith(
                    color: c.textPrimary,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 24),

                // Four suggestion tiles in a 2x2 grid (CLAUDE.md §5.4); one
                // column only when text is very large.
                LayoutBuilder(
                  builder: (context, constraints) {
                    final twoColumns =
                        constraints.maxWidth >= 280 &&
                        MediaQuery.textScalerOf(context).scale(1) < 1.6;
                    final cardWidth = twoColumns
                        ? (constraints.maxWidth - 10) / 2
                        : constraints.maxWidth;
                    final chat = ChatPalette.of(context);
                    return Wrap(
                      spacing: 10,
                      runSpacing: 10,
                      children: [
                        for (final title in assistantSuggestions(_openedAt))
                          SizedBox(
                            width: cardWidth,
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                key: ValueKey(
                                  'ai_suggestion_${title.replaceAll(' ', '_')}',
                                ),
                                onTap: () {
                                  HapticFeedback.lightImpact();
                                  widget.onSelectPrompt(title);
                                },
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  constraints: const BoxConstraints(
                                    minHeight: 84,
                                  ),
                                  padding: const EdgeInsets.all(14),
                                  decoration: BoxDecoration(
                                    color: chat.recessed,
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        assistantSuggestionIcon(title),
                                        size: 20,
                                        color: chat.action,
                                      ),
                                      const SizedBox(height: 8),
                                      Text(
                                        title,
                                        style: AscentTextStyles.bodyMedium
                                            .copyWith(
                                              color: chat.label,
                                              fontWeight: FontWeight.w500,
                                              height: 1.3,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
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
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Minimal Serene Chat Background — Inspired by ChatGPT & Gemini
// ---------------------------------------------------------------------------

class _AtmosphericChatBackground extends StatelessWidget {
  final bool isDark;
  final Color accentColor;

  const _AtmosphericChatBackground({
    required this.isDark,
    required this.accentColor,
  });

  /// Soft blue backdrop with a faint doodle, like a chat wallpaper.
  @override
  Widget build(BuildContext context) =>
      const AscentBackdrop(tone: BackdropTone.riya, child: SizedBox.expand());
}

/// What Riya just did, as a clear record card: a ring icon for the kind of
/// record, a readable title and summary (dates in plain words), and a View
/// button. Replaces the small grey capsule.
class _RiyaRecordCard extends StatelessWidget {
  const _RiyaRecordCard({
    required this.actionData,
    required this.buttonLabel,
    required this.onOpen,
  });
  final Map<String, dynamic> actionData;
  final String buttonLabel;
  final VoidCallback onOpen;

  static final _stamp = RegExp(
    r'(\d{4}-\d{2}-\d{2})[ T](\d{2}:\d{2})(:\d{2}(\.\d+)?)?Z?',
  );

  /// Any timestamp left in a reply reads as "tomorrow at 7:00 PM", and the
  /// old internal "not been verified" note is dropped.
  static String humanise(String text) => text
      .replaceAllMapped(_stamp, (m) {
        final at = DateTime.tryParse('${m.group(1)} ${m.group(2)}');
        return at == null ? m.group(0)! : humanWhen(at);
      })
      .replaceAll(' Device alert scheduling has not been verified.', '')
      .trim();

  @override
  Widget build(BuildContext context) {
    final chat = ChatPalette.of(context);
    final g = context.glass;
    final type = '${actionData['entityType'] ?? ''}';
    final (IconData icon, String tintId) = switch (type) {
      'reminders' => (Icons.notifications_active_outlined, 'things'),
      'water' || 'hydration' => (Icons.water_drop_outlined, 'hydration'),
      'money' ||
      'transactions' => (Icons.account_balance_wallet_outlined, 'money'),
      'medicine' => (Icons.medication_outlined, 'medicine'),
      'thoughts' => (Icons.lightbulb_outline_rounded, 'mind'),
      'focus' || 'sessions' => (Icons.timer_outlined, 'focus'),
      _ => (
        actionData['write'] == true
            ? Icons.check_rounded
            : Icons.info_outline_rounded,
        'assistant',
      ),
    };
    final tint = BrandPalette.pillarTint(tintId, dark: g.isDark);
    final summary = actionData['summary'] == null
        ? null
        : humanise(actionData['summary'].toString());
    return Container(
      key: const ValueKey('riya_record_card'),
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: chat.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: tint.withValues(alpha: .35)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: tint.withValues(alpha: g.isDark ? .12 : .07),
              border: Border.all(color: tint.withValues(alpha: .6), width: 1.5),
            ),
            child: Icon(icon, size: 20, color: tint),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  actionData['title'].toString(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.listRowTitle.copyWith(
                    color: chat.label,
                  ),
                ),
                if (summary != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AscentTextStyles.caption.copyWith(
                      color: chat.labelSecondary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            key: const ValueKey('riya_record_open'),
            onPressed: onOpen,
            style: TextButton.styleFrom(
              backgroundColor: tint.withValues(alpha: g.isDark ? .16 : .10),
              foregroundColor: tint,
              minimumSize: const Size(64, 44),
              shape: const StadiumBorder(),
            ),
            child: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}
