import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/message_composer.dart';
import '../models/promise_model.dart';
import '../providers/promise_providers.dart';
import '../services/promise_intent_parser.dart';
import 'promise_schedule_editor.dart';

/// Write first. Confirm a small plan. Save without a questionnaire.
class PromiseChatComposer extends ConsumerStatefulWidget {
  const PromiseChatComposer({super.key});
  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const PromiseChatComposer(),
  );
  @override
  ConsumerState<PromiseChatComposer> createState() =>
      _PromiseChatComposerState();
}

class _PromiseChatComposerState extends ConsumerState<PromiseChatComposer> {
  static const _draftKey = 'ascent_promise_creation_draft_v3';
  final _controller = TextEditingController();
  final _focus = FocusNode();
  PromiseProposal? _proposal;
  bool _saving = false;
  String? _error;
  Future<void> _draftWrites = Future.value();
  @override
  void initState() {
    super.initState();
    try {
      final raw = ref.read(sharedPreferencesProvider).getString(_draftKey);
      if (raw != null) {
        final draft = jsonDecode(raw) as Map<String, dynamic>;
        _controller.text = draft['text'] as String? ?? '';
        if (draft['proposal'] != null) {
          _proposal = _decode(draft['proposal'] as Map<String, dynamic>);
        }
      }
    } catch (_) {
      /* A corrupt draft must not block writing. */
    }
    _controller.addListener(_persist);
  }

  Map<String, dynamic> _encode(PromiseProposal p) => {
    'title': p.title,
    'intention': p.intention,
    'category': p.category,
    'type': p.trackingType.name,
    'target': p.targetValue,
    'unit': p.unit,
    'weekly': p.frequencyPerWeek,
    'private': p.isPrivate,
    'reminder': p.reminderTime,
    'days': p.reminderDays,
    'schedule': p.schedule?.toJson(),
  };
  PromiseProposal _decode(Map<String, dynamic> p) => PromiseProposal(
    title: p['title'] as String,
    intention: p['intention'] as String,
    category: p['category'] as String,
    trackingType: PromiseTrackingType.values.byName(p['type'] as String),
    targetValue: (p['target'] as num).toDouble(),
    unit: p['unit'] as String,
    frequencyPerWeek: p['weekly'] as int,
    isPrivate: p['private'] as bool,
    reminderTime: p['reminder'] as String?,
    reminderDays: (p['days'] as List).cast<int>(),
    schedule: p['schedule'] == null
        ? null
        : PromiseSchedule.fromJson(p['schedule'] as Map<String, dynamic>),
  );
  void _persist() {
    final raw = jsonEncode({
      'text': _controller.text,
      'proposal': _proposal == null ? null : _encode(_proposal!),
    });
    final preferences = ref.read(sharedPreferencesProvider);
    _draftWrites = _draftWrites.catchError((_) {}).then((_) async {
      await preferences.setString(_draftKey, raw);
    });
    unawaited(_draftWrites.catchError((_) {}));
  }

  @override
  void dispose() {
    _controller.removeListener(_persist);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _continue(String text) {
    if (_saving || text.trim().isEmpty) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _proposal = PromiseIntentParser.parse(text);
      _error = null;
    });
    _persist();
  }

  Future<void> _save() async {
    final p = _proposal;
    if (p == null || _saving) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final messenger = ScaffoldMessenger.of(context);
    try {
      final saved = await ref
          .read(promiseRepositoryProvider)
          .createPromise(
            title: p.title,
            intention: p.intention,
            category: p.category,
            trackingType: p.trackingType,
            targetValue: p.targetValue,
            unit: p.unit,
            frequencyPerWeek: p.frequencyPerWeek,
            targetDate: p.schedule?.endDate,
            schedule: p.schedule,
            isPrivate: p.isPrivate,
            reminderTime: p.reminderTime,
            reminderEnabled: p.reminderTime != null,
            reminderDays: p.schedule?.days ?? p.reminderDays,
          );
      final preferences = ref.read(sharedPreferencesProvider);
      await _draftWrites.catchError((_) {});
      await preferences.remove(_draftKey);
      if (!mounted) return;
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            saved.reminderIssue ?? 'Promise saved. One small step at a time.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = error is ArgumentError
              ? error.message.toString()
              : 'Could not save. Your words and plan are still here.';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final media = MediaQuery.of(context);
    final available = math.max(
      180.0,
      media.size.height - media.viewInsets.bottom - media.padding.top - 24,
    );
    return PopScope(
      canPop: !_saving,
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: GlassSurface(
          radius: 28,
          minimumOpacity: .86,
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: math.min(
              _proposal == null
                  ? (media.textScaler.scale(14) > 20 ? available : 360.0)
                  : 620.0,
              available,
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 8, 4),
                  child: Row(
                    children: [
                      Icon(Icons.handshake_outlined, color: g.clay, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _proposal == null
                              ? 'A promise to yourself'
                              : 'Make it yours',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: g.ink,
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Close',
                        onPressed: _saving
                            ? null
                            : () => Navigator.pop(context),
                        icon: const Icon(Icons.close_rounded),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                    child: AbsorbPointer(
                      absorbing: _saving,
                      child: _proposal == null
                          ? Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'What do you want to do for yourself?',
                                  style: TextStyle(
                                    color: g.ink,
                                    fontSize: 21,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 10),
                                Text(
                                  'Write it as it comes to mind. You can choose when on the next step.',
                                  style: TextStyle(
                                    color: g.inkMuted,
                                    fontSize: 14,
                                    height: 1.5,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                PopupMenuButton<String>(
                                  tooltip: 'Need an idea?',
                                  onSelected: (text) {
                                    _controller.text = text;
                                    _focus.requestFocus();
                                  },
                                  itemBuilder: (_) => const [
                                    PopupMenuItem(
                                      value: 'Read for 20 minutes every day',
                                      child: Text('Read a little each day'),
                                    ),
                                    PopupMenuItem(
                                      value: 'Call my parents every Sunday',
                                      child: Text('Make time for family'),
                                    ),
                                    PopupMenuItem(
                                      value: 'Exercise 3 times a week',
                                      child: Text('Move a few times a week'),
                                    ),
                                  ],
                                  child: const Chip(
                                    label: Text('Need an idea?'),
                                    avatar: Icon(
                                      Icons.lightbulb_outline,
                                      size: 17,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _proposal!.title,
                                  style: TextStyle(
                                    color: g.ink,
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                TextButton.icon(
                                  onPressed: () {
                                    setState(() => _proposal = null);
                                    _persist();
                                    _focus.requestFocus();
                                  },
                                  icon: const Icon(
                                    Icons.edit_outlined,
                                    size: 16,
                                  ),
                                  label: const Text('Edit my words'),
                                ),
                                PromiseScheduleEditor(
                                  proposal: _proposal!,
                                  onChanged: (p) {
                                    setState(() => _proposal = p);
                                    _persist();
                                  },
                                ),
                              ],
                            ),
                    ),
                  ),
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 4, 20, 8),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: _proposal == null
                        ? MessageComposer(
                            autofocus: true,
                            controller: _controller,
                            focusNode: _focus,
                            hint: 'I promise myself…',
                            onSend: _continue,
                            busy: _saving,
                          )
                        : SizedBox(
                            width: double.infinity,
                            child: FilledButton.icon(
                              key: const ValueKey('promise_save'),
                              onPressed: _saving ? null : _save,
                              icon: _saving
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    )
                                  : const Icon(Icons.check_rounded),
                              label: Text(_saving ? 'Saving…' : 'Save promise'),
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
