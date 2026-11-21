import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../shared/widgets/next_step_chips.dart';
import '../../../core/services/quick_add_parser.dart';
import 'package:intl/intl.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/local_day_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/note_draft_binding.dart';
import '../../../core/services/voice_input.dart';
import '../../../shared/widgets/skeleton_shimmer.dart';
import '../../../shared/widgets/undo_snackbar.dart';
import '../../../shared/widgets/app_chip.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/ascent_action_menu.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_sheet.dart';
import '../../../shared/widgets/ascent_scaffold.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/message_composer.dart';
import '../drop_thought_sheet.dart';
import '../thought_action_ui.dart';
import '../thought_category_action.dart';
import '../thought_wall_appearance_sheet.dart';
import '../thought_wall_preferences.dart';
import '../thought_quick_add.dart';
import '../thought_share.dart' show shareMultipleThoughts;
import '../utils/thought_checklist_helper.dart';
import 'board_actions.dart';
import 'board_background.dart';
import 'board_cards.dart' show spaceAccentFor;
import 'board_logic.dart';
import 'board_routes.dart';
import 'palace_card.dart';
import 'palace_providers.dart';
import 'thought_lifecycle.dart';
import 'thought_lines.dart';

/// One drawn row of a tab: a header, a card, or a control. Built lazily, so a
/// tab with thousands of thoughts only builds what is on screen.
class _Entry {
  const _Entry(this.key, this.builder);
  final String key;
  final WidgetBuilder builder;
}

/// The Mindspace: Today, Done, Archive and History in one row of tabs.
///
/// Every thought is one record; each tab is a view of its dates. Reading a
/// thought never opens a popup: the card grows in place.
class ThoughtBoardScreen extends ConsumerStatefulWidget {
  const ThoughtBoardScreen({super.key, this.initialThoughtId});

  final int? initialThoughtId;

  @override
  ConsumerState<ThoughtBoardScreen> createState() => _ThoughtBoardScreenState();
}

class _ThoughtBoardScreenState extends ConsumerState<ThoughtBoardScreen>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _focus = FocusNode();
  final _search = TextEditingController();
  final _scroll = ScrollController();
  NoteDraftBinding? _draft;
  Timer? _dayTimer;

  final Set<int> _selected = <int>{};
  bool _selecting = false;
  bool _saving = false;
  bool _applying = false;
  bool _searching = false;
  bool _earlierOpen = false;
  bool _listening = false;

  /// The clipboard has text the user could save as a thought. Only whether
  /// text exists is checked; the text is read when the user taps (so iOS
  /// never shows a paste prompt on its own).
  bool _canPaste = false;

  /// The thought being dragged toward a space, if any.
  Thought? _dragging;
  VoiceInput? _voice;
  PalaceTab _tab = PalaceTab.today;
  int _doneLimit = palacePageSize;
  int _archiveLimit = palacePageSize;
  DateTime? _historyDay;
  int? _highlightId;

  /// Thoughts drawn by the current tab; selection is trimmed to these.
  List<Thought> _visible = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDayChange();
    try {
      _draft = NoteDraftBinding(
        _input,
        ref.read(sharedPreferencesProvider),
        'wall',
      );
    } catch (_) {}
    _openFromHome();
    _focus.addListener(_checkClipboard);
    _input.addListener(_onInputChanged);
    _checkClipboard();
  }

  bool _inputEmpty = true;
  void _onInputChanged() {
    final empty = _input.text.trim().isEmpty;
    if (!empty && _nextSteps.isNotEmpty) _clearNextSteps();
    if (empty != _inputEmpty && mounted) setState(() => _inputEmpty = empty);
  }

  // Next steps ---------------------------------------------------------------

  /// Suggestions for the thought just saved, shown above the composer.
  List<NextStep> _nextSteps = const [];
  Timer? _nextStepsTimer;

  void _clearNextSteps() {
    _nextStepsTimer?.cancel();
    if (mounted && _nextSteps.isNotEmpty) {
      setState(() => _nextSteps = const []);
    }
  }

  /// A thought that mentions a day or time can become a reminder; one with
  /// two or more checklist lines can become to-dos. Nothing else is offered.
  void _suggestNextSteps(int id, String text) {
    final steps = <NextStep>[];
    final parsed = parseQuickAdd(text.split('\n').first, DateTime.now());
    if (parsed.day != null || parsed.hasTime) {
      final when = [
        if (parsed.day != null) _relativeDay(parsed.day!),
        if (parsed.hasTime)
          TimeOfDay(
            hour: parsed.hour!,
            minute: parsed.minute ?? 0,
          ).format(context),
      ].join(' ');
      steps.add(
        NextStep(
          id: 'remind',
          label: 'Remind me $when',
          icon: Icons.notifications_active_outlined,
          onTap: () => _runNextStep(id, (t) async {
            await convertThoughtWithQuickAdd(context, ref, t, remind: true);
          }),
        ),
      );
    }
    final ticks = parseThoughtLines(
      text,
    ).where((l) => l.isItem && l.isCheckbox).length;
    if (ticks >= 2) {
      steps.add(
        NextStep(
          id: 'todos',
          label: 'Make these $ticks to-dos',
          icon: Icons.add_task_rounded,
          onTap: () => _runNextStep(id, (t) async {
            await applyThoughtAction(context, ref.read(databaseProvider), [
              t,
            ], 'todo');
          }),
        ),
      );
    }
    _nextStepsTimer?.cancel();
    setState(() => _nextSteps = steps);
    if (steps.isNotEmpty) {
      _nextStepsTimer = Timer(const Duration(seconds: 12), _clearNextSteps);
    }
  }

  Future<void> _runNextStep(
    int id,
    Future<void> Function(Thought) action,
  ) async {
    _clearNextSteps();
    final thought = await ref.read(thoughtDaoProvider).getThoughtById(id);
    if (thought == null || !mounted) return;
    await action(thought);
  }

  static String _relativeDay(DateTime day) {
    final now = DateTime.now();
    final diff = DateTime.utc(
      day.year,
      day.month,
      day.day,
    ).difference(DateTime.utc(now.year, now.month, now.day)).inDays;
    if (diff == 0) return 'today';
    if (diff == 1) return 'tomorrow';
    return DateFormat('EEE d MMM').format(day);
  }

  Future<void> _checkClipboard() async {
    bool has;
    try {
      has = await Clipboard.hasStrings();
    } catch (_) {
      has = false;
    }
    if (mounted && has != _canPaste) setState(() => _canPaste = has);
  }

  /// Saves the clipboard text as a thought in one tap, with Undo.
  Future<void> _pasteAsThought() async {
    HapticFeedback.lightImpact();
    final text = (await Clipboard.getData(Clipboard.kTextPlain))?.text?.trim();
    if (!mounted) return;
    if (text == null || text.isEmpty) {
      setState(() => _canPaste = false);
      AscentSnackBar.show(
        context,
        message: 'Nothing to paste',
        icon: Icons.content_paste_off_rounded,
      );
      return;
    }
    final dao = ref.read(thoughtDaoProvider);
    try {
      final id = await dao.insertThought(
        ThoughtTableCompanion.insert(
          content: text.length > 5000 ? text.substring(0, 5000) : text,
          mood: const drift.Value('thought'),
          category: drift.Value(
            ref.read(palaceFilterProvider).space ?? wallCategoryKey,
          ),
        ),
      );
      if (!mounted) return;
      showUndoSnackbar(
        context,
        message: 'Saved from clipboard',
        onUndo: () => dao.deleteThought(id),
      );
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(context, message: 'Could not save. Try again.');
      }
    }
  }

  @override
  void didUpdateWidget(covariant ThoughtBoardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialThoughtId != widget.initialThoughtId) _openFromHome();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkClipboard();
      ref.read(localClockProvider.notifier).refresh();
      setState(() {});
      _scheduleDayChange();
    }
  }

  /// At midnight the views are recomputed: archived-today tags leave Today and
  /// open thoughts move to the Earlier row. No data changes.
  void _scheduleDayChange() {
    _dayTimer?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _dayTimer = Timer(next.difference(now), () {
      if (!mounted) return;
      ref.read(localClockProvider.notifier).refresh();
      setState(() {});
      _scheduleDayChange();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayTimer?.cancel();
    _nextStepsTimer?.cancel();
    if (_listening) {
      _listening = false; // the stop callback must not rebuild a dead state
      _voice?.stop();
    }
    _draft?.dispose();
    _input.dispose();
    _focus.dispose();
    _search.dispose();
    _scroll.dispose();
    super.dispose();
  }

  /// A thought opened from Home goes to the tab it lives in and opens
  /// expanded there.
  Future<void> _openFromHome() async {
    final id = widget.initialThoughtId;
    if (id == null) return;
    final thought = await ref.read(thoughtDaoProvider).getThoughtById(id);
    if (!mounted || widget.initialThoughtId != id) return;
    if (thought == null) {
      AscentSnackBar.error(
        context,
        message: 'This thought is no longer available.',
      );
      return;
    }
    ref.read(palaceFilterProvider.notifier).clear();
    _search.clear();
    final place = placeOf(thought, DateTime.now());
    setState(() {
      _highlightId = id;
      _selected.clear();
      _selecting = false;
      _searching = false;
      _tab = switch (place) {
        ThoughtPlace.today ||
        ThoughtPlace.archivedToday ||
        ThoughtPlace.earlier => PalaceTab.today,
        ThoughtPlace.done => PalaceTab.done,
        ThoughtPlace.archive => PalaceTab.archive,
      };
      _earlierOpen = place == ThoughtPlace.earlier;
    });
  }

  void _setTab(PalaceTab tab) {
    if (tab == _tab) return;
    setState(() {
      _tab = tab;
      _selected.clear();
      _selecting = false;
      _highlightId = null;
    });
    if (_scroll.hasClients) _scroll.jumpTo(0);
  }

  Future<void> _send() async {
    final raw = _input.text.trim();
    if (raw.isEmpty || _saving) return;
    HapticFeedback.mediumImpact();
    final categories =
        ref.read(thoughtCategoriesStreamProvider).value ??
        ThoughtDao.builtInCategories;
    final tag = parseSpaceTag(raw, categories);
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(thoughtDaoProvider)
          .insertThought(
            ThoughtTableCompanion.insert(
              content: tag?.text ?? raw,
              mood: const drift.Value('thought'),
              category: drift.Value(tag?.key ?? wallCategoryKey),
            ),
          );
      if (_input.text.trim() == raw) _input.clear();
      if (!mounted) return;
      // A space filter that would hide the new thought is dropped.
      final filter = ref.read(palaceFilterProvider);
      final landed = tag?.key ?? wallCategoryKey;
      if (filter.space != null && filter.space != landed) {
        ref.read(palaceFilterProvider.notifier).setSpace(null);
      }
      setState(() => _highlightId = null);
      _suggestNextSteps(id, tag?.text ?? raw);
      if (tag != null) {
        AscentSnackBar.show(
          context,
          message: 'Added to ${categories[tag.key]}',
          icon: Icons.folder_outlined,
        );
      }
      if (_scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(context, message: 'Could not save. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _newSpace() async {
    final name = await showCreateSpaceDialog(context);
    if (name == null || !mounted) return;
    try {
      final key = await ref
          .read(thoughtDaoProvider)
          .createCategoryAndMove(name, const []);
      if (mounted) ref.read(palaceFilterProvider.notifier).setSpace(key);
    } catch (e) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: e is ArgumentError
              ? '${e.message}'
              : 'Could not create the space.',
        );
      }
    }
  }

  // Selection ---------------------------------------------------------------

  void _toggle(int id) {
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.add(id)) _selected.remove(id);
      if (_selected.isEmpty) _selecting = false;
    });
  }

  void _startSelecting(int id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _selecting = true;
      _selected.add(id);
    });
  }

  void _stopSelecting() => setState(() {
    _selecting = false;
    _selected.clear();
  });

  List<Thought> _selectedThoughts() =>
      _visible.where((t) => _selected.contains(t.id)).toList();

  // Actions -----------------------------------------------------------------

  bool _anyLocked(List<Thought> picked) => false;

  Future<void> _toggleItem(Thought t, int itemIndex) async {
    final dao = ref.read(thoughtDaoProvider);
    try {
      final text = ThoughtChecklistHelper.toggleItemDone(t.content, itemIndex);
      await dao.setContent(t.id, text);
      // Unticking a bullet reopens a done thought. Ticking the last one only
      // offers "Mark thought done" on the card; it never ticks by itself.
      if (t.isCompleted && !allItemsDone(displayContent(text))) {
        await dao.setCompleted(t.id, false);
      }
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(context, message: 'Could not update. Try again.');
      }
    }
  }

  Future<void> _bring(List<Thought> thoughts) async {
    HapticFeedback.selectionClick();
    final dao = ref.read(thoughtDaoProvider);
    try {
      final moved = await dao.carryToToday(thoughts.map((t) => t.id));
      if (!mounted) return;
      AscentSnackBar.show(
        context,
        message: moved == 1
            ? '1 thought brought to Today'
            : '$moved thoughts brought to Today',
        icon: Icons.today_rounded,
      );
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(context, message: 'Could not update. Try again.');
      }
    }
  }

  /// Dictation appends to whatever is already typed. The user reviews the
  /// text and sends it; nothing is saved by voice alone.
  Future<void> _toggleVoice() async {
    final VoiceInput voice = _voice ?? ref.read(voiceInputProvider);
    _voice = voice;
    if (_listening) {
      await voice.stop();
      return;
    }
    final typed = _input.text.trimRight();
    final base = typed.isEmpty ? '' : '$typed ';
    setState(() => _listening = true);
    final ok = await voice.start(
      onText: (words) {
        if (!mounted) return;
        _input.text = '$base$words';
        _input.selection = TextSelection.collapsed(offset: _input.text.length);
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

  /// Writing prompts for an empty Today. A prompt alone isn't a useful
  /// thought, so tapping one starts the sentence in the composer.
  static const _starterPrompts = [
    'One thing I’m grateful for',
    'An idea I don’t want to lose',
    'What’s on my mind right now',
  ];

  void _startWith(String prompt) {
    HapticFeedback.selectionClick();
    _input.text = '$prompt: ';
    _input.selection = TextSelection.collapsed(offset: _input.text.length);
    _focus.requestFocus();
  }

  /// Undo-first (CLAUDE.md §1.8): bring everything over, offer Undo.
  Future<void> _bringAll() async {
    HapticFeedback.lightImpact();
    final dao = ref.read(thoughtDaoProvider);
    try {
      final previous = await dao.carryAllEarlierToToday();
      if (!mounted) return;
      setState(() => _earlierOpen = false);
      final moved = previous.length;
      showUndoSnackbar(
        context,
        message: moved == 1
            ? '1 thought brought to Today'
            : '$moved thoughts brought to Today',
        onUndo: () => dao.restoreCarriedOn(previous),
      );
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(context, message: 'Could not update. Try again.');
      }
    }
  }

  Future<void> _bulkDone(List<Thought> picked) async {
    final dao = ref.read(thoughtDaoProvider);
    var applied = 0;
    await ref.read(databaseProvider).transaction(() async {
      for (final t in picked) {
        final current = await dao.getThoughtById(t.id);
        if (current != null && !current.isCompleted) {
          await dao.setCompleted(t.id, true);
          applied++;
        }
      }
    });
    if (!mounted) return;
    AscentSnackBar.show(
      context,
      message: BulkResult(applied, picked.length - applied).summary('done'),
      icon: Icons.check_circle_outline_rounded,
    );
  }

  /// The "More" menu. [single] adds the actions that only make sense for one
  /// thought (pin, copy, bullet style).
  Future<void> _more(List<Thought> picked, {bool single = false}) async {
    final db = ref.read(databaseProvider);
    if (_anyLocked(picked)) {
      AscentSnackBar.error(
        context,
        message:
            'Unlock private commitments before sharing or converting them.',
      );
      return;
    }
    final t = picked.first;
    final action = await showAscentActionMenu<String>(
      context: context,
      title: 'More actions',
      actions: [
        if (single)
          AscentAction(
            'pin',
            t.isPinned ? 'Unpin' : 'Pin to top',
            Icons.push_pin_outlined,
          ),
        const AscentAction('move', 'Move to space', Icons.folder_outlined),
        const AscentAction('todo', 'Convert to to-do', Icons.add_task_rounded),
        const AscentAction(
          'reminder',
          'Set reminder',
          Icons.notifications_active_outlined,
        ),
        if (picked.length > 1)
          const AscentAction('merge', 'Merge thoughts', Icons.merge_rounded),
        const AscentAction('share', 'Share', Icons.share_outlined),
        if (single) ...[
          const AscentAction('copy', 'Copy text', Icons.copy_outlined),
          const AscentAction(
            'bullets_todo',
            'Show every line as a checklist',
            Icons.radio_button_unchecked_rounded,
          ),
          const AscentAction(
            'bullets_plain',
            'Show as a plain list',
            Icons.format_list_bulleted_rounded,
          ),
          if (t.bulletStyle != null)
            const AscentAction(
              'bullets_default',
              'Show lines as written',
              Icons.restart_alt_rounded,
            ),
        ],
        const AscentAction(
          'delete',
          'Delete',
          Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
    if (action == null || !mounted) return;
    if (_anyLocked(picked)) return;
    final dao = ref.read(thoughtDaoProvider);
    switch (action) {
      case 'pin':
        await dao.togglePin(t.id);
      case 'copy':
        await Clipboard.setData(ClipboardData(text: displayContent(t.content)));
        if (mounted) {
          AscentSnackBar.show(
            context,
            message: 'Copied',
            icon: Icons.copy_outlined,
          );
        }
      case 'bullets_todo':
        await dao.setBulletStyle(t.id, BulletStyle.todo.storage);
      case 'bullets_plain':
        await dao.setBulletStyle(t.id, BulletStyle.bullet.storage);
      case 'bullets_default':
        await dao.setBulletStyle(t.id, null);
      case 'move':
        final pick = await showSpacePicker(context);
        if (pick == null || !mounted) return;
        final moved = await moveThoughtsToSpace(context, ref, picked, pick);
        if (moved && mounted && _selecting) _stopSelecting();
      case 'delete':
        final removed = await deleteThoughtsWithUndo(context, ref, picked);
        if (removed > 0 && mounted && _selecting) _stopSelecting();
      case 'share':
        await shareMultipleThoughts(picked);
      case 'todo' || 'reminder' when picked.length == 1:
        final saved = await convertThoughtWithQuickAdd(
          context,
          ref,
          t,
          remind: action == 'reminder',
        );
        if (saved && mounted && _selecting) _stopSelecting();
      default:
        final saved = await applyThoughtAction(context, db, picked, action);
        if (saved && mounted && _selecting) _stopSelecting();
    }
  }

  /// The space's own page: bulk paste, poster view, rename and delete.
  void _openSpace(String key) {
    HapticFeedback.selectionClick();
    context.push(thoughtSpaceLocation(key));
  }

  Future<void> _settings() async {
    final space = ref.read(palaceFilterProvider).space;
    final categories =
        ref.read(thoughtCategoriesStreamProvider).value ??
        ThoughtDao.builtInCategories;
    final choice = await showAscentActionMenu<String>(
      context: context,
      title: 'Mindspace',
      actions: [
        const AscentAction(
          'space',
          'New space',
          Icons.create_new_folder_outlined,
        ),
        const AscentAction(
          'appearance',
          'Card style',
          Icons.auto_awesome_outlined,
        ),
        if (space != null)
          AscentAction(
            'open_space',
            'Open ${categories[space] ?? 'space'} page',
            Icons.folder_open_outlined,
          ),
      ],
    );
    if (choice == null || !mounted) return;
    switch (choice) {
      case 'space':
        await _newSpace();
      case 'open_space':
        _openSpace(space!);
      default:
        await showAscentSheet<void>(
          context: context,
          framed: false,
          builder: (_) => const ThoughtWallAppearanceSheet(),
        );
    }
  }

  // Selection bar -----------------------------------------------------------

  Widget _selectionBar() {
    final g = context.glass;
    final picked = _selectedThoughts();
    final enabled = picked.isNotEmpty && !_applying;
    Future<void> run(Future<void> Function() job) async {
      if (!enabled || _applying) return;
      setState(() => _applying = true);
      try {
        await job();
        if (mounted) _stopSelecting();
      } catch (_) {
        if (mounted) {
          AscentSnackBar.error(
            context,
            message: 'Could not update the selection. Try again.',
          );
        }
      } finally {
        if (mounted) setState(() => _applying = false);
      }
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s12,
        AppSpace.s8,
        AppSpace.s12,
        AppSpace.s8,
      ),
      decoration: BoxDecoration(
        color: g.bg,
        border: Border(top: BorderSide(color: g.edge)),
      ),
      child: SafeArea(
        top: false,
        child: Wrap(
          alignment: WrapAlignment.center,
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            ChoicePill(
              key: const ValueKey('select_done'),
              icon: Icons.check_circle_outline_rounded,
              label: 'Done',
              onTap: !enabled ? null : () => run(() => _bulkDone(picked)),
            ),
            ChoicePill(
              key: const ValueKey('select_archive'),
              icon: Icons.archive_outlined,
              label: 'Archive',
              onTap: !enabled
                  ? null
                  : () => run(
                      () => archiveThoughtsWithUndo(context, ref, picked),
                    ),
            ),
            ChoicePill(
              key: const ValueKey('select_more'),
              icon: Icons.more_horiz_rounded,
              label: 'More',
              onTap: !enabled ? null : () => _more(picked),
            ),
          ],
        ),
      ),
    );
  }

  Widget _composer() {
    // The board body already ends at the tab bar, so a small gap is enough:
    // the field sits right above it instead of floating mid-screen.
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_nextSteps.isNotEmpty && _inputEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s8),
              child: NextStepChips(steps: _nextSteps),
            ),
          if (_canPaste && _inputEmpty && !_listening && _nextSteps.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpace.s8),
              child: AppChip(
                key: const ValueKey('palace_paste'),
                label: 'Paste as a thought',
                icon: Icons.content_paste_rounded,
                onTap: _pasteAsThought,
              ),
            ),
          MessageComposer(
            quiet: true,
            controller: _input,
            focusNode: _focus,
            hint: 'e.g. Idea for the weekend trip',
            busy: _saving,
            // Taller, Gemini-like field: two lines visible before typing.
            minHeight: 76,
            minLines: 2,
            onMic: _toggleVoice,
            listening: _listening,
            onSend: (_) {
              if (_listening) _voice?.stop();
              _send();
            },
          ),
        ],
      ),
    );
  }

  // Rows --------------------------------------------------------------------

  _Entry _header(String id, String label, int count) =>
      _Entry('h_$id', (context) {
        final g = context.glass;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpace.s4,
            AppSpace.s16,
            AppSpace.s4,
            AppSpace.s8,
          ),
          child: Row(
            children: [
              Flexible(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.listRowTitle.copyWith(
                    color: g.ink,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: AppSpace.s8),
              if (count > 0)
                Text(
                  '$count',
                  style: AscentTextStyles.labelSmall.copyWith(
                    color: g.inkMuted,
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
        );
      });

  _Entry _card(
    String id,
    Thought t,
    DateTime now,
    ThoughtWallAppearance appearance,
    Map<String, String> categories, {
    ThoughtPlace? place,
    bool earlier = false,
    String? note,
  }) {
    return _Entry('c_$id', (context) {
      final locked = false;
      final card = PalaceCard(
        key: ValueKey('palace_card_$id'),
        thought: t,
        now: now,
        appearance: appearance,
        place: place ?? placeOf(t, now),
        spaceName: t.category == wallCategoryKey
            ? null
            : categories[t.category],
        note: note,
        isSelected: _selected.contains(t.id),
        isSelectionMode: _selecting,
        isLocked: locked,
        highlight: _highlightId == t.id,
        onSelectToggle: () => _toggle(t.id),
        // Outside selection, a long press lifts the card (see below).
        onLongPress: _selecting ? () => _toggle(t.id) : null,
        onDoubleTap: () => toggleThoughtDone(context, ref, t),
        onUnlock: () => unlockPrivateThought(ref, t),
        onToggleItem: (i) => _toggleItem(t, i),
        onDone: () => toggleThoughtDone(context, ref, t),
        onEdit: () => DropThoughtSheet.show(context, existingThought: t),
        onArchive: () => archiveThoughtsWithUndo(context, ref, [t]),
        onMore: () => _more([t], single: true),
        onBring: earlier ? () => _bring([t]) : null,
      );
      return Padding(
        padding: const EdgeInsets.only(bottom: AppSpace.s10),
        child: LayoutBuilder(
          builder: (context, box) => LongPressDraggable<Thought>(
            data: t,
            maxSimultaneousDrags: _selecting ? 0 : 1,
            hapticFeedbackOnStart: true,
            onDragStarted: () => setState(() => _dragging = t),
            onDragCompleted: () => setState(() => _dragging = null),
            // Released without a space: the long press selects, as before.
            onDraggableCanceled: (_, _) {
              setState(() => _dragging = null);
              if (mounted && !_selecting) _startSelecting(t.id);
            },
            feedback: _DragFeedback(width: box.maxWidth, child: card),
            childWhenDragging: Opacity(opacity: .35, child: card),
            // Another card dropped here: merge the two, or file it with this
            // one's space.
            child: DragTarget<Thought>(
              key: ValueKey('palace_drop_on_${t.id}'),
              onWillAcceptWithDetails: (d) {
                final ok = d.data.id != t.id;
                if (ok) HapticFeedback.selectionClick();
                return ok;
              },
              onAcceptWithDetails: (d) => _groupWith(d.data, t),
              builder: (context, candidates, _) => AnimatedScale(
                scale: candidates.isNotEmpty ? 1.02 : 1,
                duration: const Duration(milliseconds: 160),
                curve: Curves.easeOutCubic,
                child: DecoratedBox(
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(20),
                    border: candidates.isEmpty
                        ? null
                        : Border.all(color: context.glass.clay),
                  ),
                  child: card,
                ),
              ),
            ),
          ),
        ),
      );
    });
  }

  /// A card dropped on another card: merge them into one thought, or put the
  /// dragged one in the target's space.
  Future<void> _groupWith(Thought dragged, Thought target) async {
    if (_anyLocked([dragged, target])) {
      AscentSnackBar.error(
        context,
        message: 'Unlock private commitments before grouping them.',
      );
      return;
    }
    final categories =
        ref.read(thoughtCategoriesStreamProvider).value ??
        ThoughtDao.builtInCategories;
    final sameSpace = dragged.category == target.category;
    final spaceName = target.category == wallCategoryKey
        ? 'the wall'
        : (categories[target.category] ?? 'this space');
    final choice = await showAscentActionMenu<String>(
      context: context,
      title: 'Put these together',
      actions: [
        const AscentAction(
          'merge',
          'Merge into one thought',
          Icons.merge_rounded,
        ),
        if (!sameSpace)
          AscentAction('space', 'Move to $spaceName', Icons.folder_outlined),
      ],
    );
    if (choice == null || !mounted) return;
    if (choice == 'space') {
      await _dropInto(dragged, (key: target.category, newName: null));
    } else {
      await applyThoughtAction(context, ref.read(databaseProvider), [
        target,
        dragged,
      ], 'merge');
    }
  }

  /// Files a dragged thought into a space, with Undo.
  Future<void> _dropInto(Thought t, SpacePick pick) async {
    HapticFeedback.lightImpact();
    await moveThoughtsToSpace(context, ref, [t], pick);
  }

  /// Shown in place of the composer while a card is dragged: every space is a
  /// drop target, plus "New space".
  Widget _dropDock(Map<String, String> categories, Thought dragged) {
    final g = context.glass;
    final bottomInset = MediaQuery.paddingOf(context).bottom;
    final spaces = [
      (wallCategoryKey, 'Wall', Icons.dashboard_outlined),
      for (final e in categories.entries)
        if (e.key != wallCategoryKey) (e.key, e.value, Icons.folder_outlined),
    ];
    Widget target({
      required Key key,
      required String label,
      required IconData icon,
      required bool enabled,
      required Future<void> Function(Thought) onDrop,
    }) => DragTarget<Thought>(
      key: key,
      onWillAcceptWithDetails: (_) {
        if (enabled) HapticFeedback.selectionClick();
        return enabled;
      },
      onAcceptWithDetails: (d) => onDrop(d.data),
      builder: (context, candidates, _) => AnimatedScale(
        scale: candidates.isNotEmpty ? 1.08 : 1,
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        child: Opacity(
          opacity: enabled ? 1 : .4,
          child: AppChip(
            label: label,
            icon: icon,
            isSelected: candidates.isNotEmpty,
          ),
        ),
      ),
    );

    return Container(
      key: const ValueKey('palace_drop_dock'),
      padding: EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s12,
        AppSpace.s16,
        AppSpace.s12 + bottomInset,
      ),
      decoration: BoxDecoration(
        color: g.elevated,
        border: Border(top: BorderSide(color: g.edge)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Drop into a space',
            style: AscentTextStyles.labelMedium.copyWith(color: g.inkMuted),
          ),
          const SizedBox(height: AppSpace.s8),
          Wrap(
            spacing: AppSpace.s8,
            runSpacing: AppSpace.s8,
            children: [
              for (final (key, label, icon) in spaces)
                target(
                  key: ValueKey('drop_space_$key'),
                  label: label,
                  icon: icon,
                  enabled: dragged.category != key,
                  onDrop: (t) => _dropInto(t, (key: key, newName: null)),
                ),
              target(
                key: const ValueKey('drop_space_new'),
                label: 'New space',
                icon: Icons.add_rounded,
                enabled: true,
                onDrop: (t) async {
                  final name = await showCreateSpaceDialog(context);
                  if (name == null || !mounted) return;
                  await _dropInto(t, (key: null, newName: name));
                },
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Highlighted thought first, so a thought opened from Home is on screen.
  List<Thought> _hoist(List<Thought> list) {
    final id = _highlightId;
    if (id == null) return list;
    final i = list.indexWhere((t) => t.id == id);
    if (i <= 0) return list;
    return [list[i], ...list.take(i), ...list.skip(i + 1)];
  }

  List<_Entry> _dayGroups(
    List<Thought> thoughts,
    DateTime now,
    DateTime Function(Thought) dateOf,
    ThoughtWallAppearance appearance,
    Map<String, String> categories,
  ) {
    final entries = <_Entry>[];
    final id = _highlightId;
    final hoisted = id == null
        ? null
        : thoughts.where((t) => t.id == id).firstOrNull;
    if (hoisted != null) {
      entries.add(_card('${hoisted.id}', hoisted, now, appearance, categories));
    }
    final rest = hoisted == null
        ? thoughts
        : thoughts.where((t) => t.id != hoisted.id).toList();
    for (final group in groupByDay(rest, now, dateOf)) {
      entries.add(
        _header(
          '${_tab.name}_${group.day.millisecondsSinceEpoch}',
          group.label,
          group.thoughts.length,
        ),
      );
      for (final t in group.thoughts) {
        entries.add(_card('${t.id}', t, now, appearance, categories));
      }
    }
    return entries;
  }

  /// Search results, grouped by where each thought lives.
  List<_Entry> _searchGroups(
    List<Thought> results,
    DateTime now,
    ThoughtWallAppearance appearance,
    Map<String, String> categories,
  ) {
    const groups = [
      ('today', 'Today'),
      ('earlier', 'Earlier'),
      ('done', 'Done'),
      ('archive', 'Archive'),
    ];
    String groupOf(ThoughtPlace place) => switch (place) {
      ThoughtPlace.today || ThoughtPlace.archivedToday => 'today',
      ThoughtPlace.earlier => 'earlier',
      ThoughtPlace.done => 'done',
      ThoughtPlace.archive => 'archive',
    };
    final entries = <_Entry>[];
    for (final (id, label) in groups) {
      final inGroup = [
        for (final t in results)
          if (groupOf(placeOf(t, now)) == id) t,
      ];
      if (inGroup.isEmpty) continue;
      entries.add(_header('search_$id', label, inGroup.length));
      for (final t in inGroup) {
        entries.add(
          _card(
            's_${t.id}',
            t,
            now,
            appearance,
            categories,
            earlier: id == 'earlier',
          ),
        );
      }
    }
    return entries;
  }

  _Entry _showMore(VoidCallback onTap) => _Entry('show_more', (context) {
    return Align(
      alignment: Alignment.center,
      child: AscentButton.ghost(
        key: const ValueKey('palace_show_more'),
        label: 'Show more',
        compact: true,
        onPressed: onTap,
      ),
    );
  });

  _Entry _earlierRow(
    int count,
    List<Thought> earlier,
    ThoughtWallAppearance appearance,
  ) => _Entry('earlier_row', (context) {
    final g = context.glass;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpace.s10),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: g.edge),
        ),
        child: Row(
          children: [
            Expanded(
              child: GestureDetector(
                key: const ValueKey('earlier_row_toggle'),
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _earlierOpen = !_earlierOpen),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 48),
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s16,
                    vertical: AppSpace.s8,
                  ),
                  alignment: Alignment.centerLeft,
                  child: Row(
                    children: [
                      Icon(
                        _earlierOpen
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_down_rounded,
                        size: 20,
                        color: g.inkSecondary,
                      ),
                      const SizedBox(width: AppSpace.s8),
                      Flexible(
                        child: Text(
                          '$count from earlier',
                          style: AscentTextStyles.bodyMedium.copyWith(
                            color: g.ink,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            AscentButton.ghost(
              key: const ValueKey('earlier_bring_all'),
              label: 'Bring all',
              compact: true,
              onPressed: _bringAll,
            ),
          ],
        ),
      ),
    );
  });

  // Tabs --------------------------------------------------------------------

  Widget _tabs() => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.s16,
      AppSpace.s4,
      AppSpace.s16,
      AppSpace.s8,
    ),
    child: AscentSegmentedControl<PalaceTab>(
      key: const ValueKey('palace_tabs'),
      selected: _tab,
      onChanged: _setTab,
      segments: const [
        AscentSegment(
          value: PalaceTab.today,
          label: 'Today',
          key: ValueKey('tab_today'),
        ),
        AscentSegment(
          value: PalaceTab.done,
          label: 'Done',
          key: ValueKey('tab_done'),
        ),
        AscentSegment(
          value: PalaceTab.archive,
          label: 'Archive',
          key: ValueKey('tab_archive'),
        ),
        AscentSegment(
          value: PalaceTab.history,
          label: 'History',
          key: ValueKey('tab_history'),
        ),
      ],
    ),
  );

  Widget _searchField() => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.s16,
      0,
      AppSpace.s16,
      AppSpace.s8,
    ),
    child: AppTextField(
      key: const ValueKey('palace_search'),
      controller: _search,
      autofocus: true,
      hintText: 'Search all thoughts',
      prefixIcon: const Icon(Icons.search_rounded),
      onChanged: ref.read(palaceFilterProvider.notifier).setQuery,
    ),
  );

  /// Space filter. Shown only when at least one space exists.
  Widget? _spaceChips(Map<String, String> categories, PalaceFilter filter) {
    // Built-in spaces (Suggestions, Bugs, Life Goals) only show once they
    // hold a thought; spaces the person made always show.
    final used = {
      for (final t in ref.watch(allThoughtsStreamProvider).value ?? const [])
        t.category,
    };
    final g = context.glass;
    final spaces = categories.entries
        .where(
          (e) =>
              e.key != wallCategoryKey &&
              (e.key.startsWith('custom_') ||
                  used.contains(e.key) ||
                  filter.space == e.key),
        )
        .toList();
    if (spaces.isEmpty) return null;
    return SizedBox(
      height: 44,
      child: ListView(
        key: const ValueKey('palace_space_chips'),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppSpace.s16),
        children: [
          AppChip(
            label: 'All',
            isSelected: filter.space == null,
            onTap: () => ref.read(palaceFilterProvider.notifier).setSpace(null),
          ),
          for (final e in spaces) ...[
            const SizedBox(width: 8),
            GestureDetector(
              onLongPress: () => _openSpace(e.key),
              child: Semantics(
                onLongPressHint: 'Open the ${e.value} page',
                child: AppChip(
                  key: ValueKey('space_chip_${e.key}'),
                  label: e.value,
                  icon: Icons.circle,
                  iconColor: spaceAccentFor(g, e.key),
                  isSelected: filter.space == e.key,
                  onTap: () =>
                      ref.read(palaceFilterProvider.notifier).setSpace(e.key),
                ),
              ),
            ),
          ],
          const SizedBox(width: 8),
          AppChip(
            key: const ValueKey('space_chip_new'),
            label: 'New space',
            icon: Icons.add_rounded,
            onTap: _newSpace,
          ),
        ],
      ),
    );
  }

  Widget _historyStrip(DateTime today, List<Thought> activity) {
    final g = context.glass;
    final counts = historyDayCounts(activity);
    final selected = dayOf(_historyDay ?? today);
    final days = [
      for (var i = 0; i < 14; i++) today.subtract(Duration(days: i)),
    ];
    final weekdays = const ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return SizedBox(
      height: 72,
      child: ListView(
        key: const ValueKey('history_strip'),
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpace.s16,
          vertical: AppSpace.s4,
        ),
        children: [
          GestureDetector(
            key: const ValueKey('history_pick_date'),
            behavior: HitTestBehavior.opaque,
            onTap: () async {
              final picked = await showDatePicker(
                context: context,
                initialDate: selected,
                firstDate: DateTime(2020),
                lastDate: today,
              );
              if (picked != null && mounted) {
                setState(() => _historyDay = dayOf(picked));
              }
            },
            child: SizedBox(
              width: 48,
              child: Icon(Icons.calendar_month_outlined, color: g.ink),
            ),
          ),
          for (final d in days)
            GestureDetector(
              key: ValueKey('history_day_${d.year}_${d.month}_${d.day}'),
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _historyDay = d),
              child: Container(
                width: 48,
                margin: const EdgeInsets.only(right: 6),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  color: d == selected
                      ? g.clay.withValues(alpha: .14)
                      : Colors.transparent,
                  border: Border.all(color: d == selected ? g.clay : g.edge),
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      weekdays[d.weekday - 1],
                      style: AscentTextStyles.labelSmall.copyWith(
                        color: g.inkMuted,
                      ),
                    ),
                    Text(
                      '${d.day}',
                      style: AscentTextStyles.bodyMedium.copyWith(
                        color: g.ink,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: (counts[d] ?? 0) > 0
                            ? g.clay
                            : Colors.transparent,
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

  // Build -------------------------------------------------------------------

  @override
  Widget build(BuildContext context) => _buildBoard(context);

  Widget _buildBoard(BuildContext context) {
    final g = context.glass;
    final appearance = ref.watch(thoughtWallAppearanceProvider);
    final categories =
        ref.watch(thoughtCategoriesStreamProvider).value ??
        ThoughtDao.builtInCategories;
    final filter = ref.watch(palaceFilterProvider);
    final today = ref.watch(localDayProvider);
    final now = DateTime.now();

    var loading = false;
    Object? error;
    var empty = const EmptyState(
      icon: Icons.bubble_chart_rounded,
      title: 'Nothing here yet',
      subtitle: 'Write a thought below.',
    );
    var entries = <_Entry>[];
    var visible = <Thought>[];
    Widget? beforeList;

    final searchingAll = _searching && filter.query.trim().isNotEmpty;
    if (searchingAll) {
      final async = ref.watch(palaceSearchProvider);
      loading = async.isLoading && !async.hasValue;
      error = async.hasError && !async.hasValue ? async.error : null;
      final results = async.value ?? const <Thought>[];
      visible = results;
      entries = _searchGroups(results, now, appearance, categories);
      empty = EmptyState(
        icon: Icons.search_off_rounded,
        title: 'No thoughts match “${filter.query.trim()}”',
        subtitle: filter.space == null
            ? 'Search looks through Today, Done and Archive.'
            : 'Try All spaces, or another word.',
        actionLabel: filter.space == null ? null : 'Search all spaces',
        onAction: filter.space == null
            ? null
            : () => ref.read(palaceFilterProvider.notifier).setSpace(null),
      );
    } else {
      switch (_tab) {
        case PalaceTab.today:
          final todayAsync = ref.watch(palaceTodayProvider);
          final earlierAsync = ref.watch(palaceEarlierProvider);
          loading =
              (todayAsync.isLoading && !todayAsync.hasValue) ||
              (earlierAsync.isLoading && !earlierAsync.hasValue);
          error = todayAsync.hasError && !todayAsync.hasValue
              ? todayAsync.error
              : (earlierAsync.hasError && !earlierAsync.hasValue
                    ? earlierAsync.error
                    : null);
          final all = [...?todayAsync.value, ...?earlierAsync.value];
          final content = buildTodayContent(all, now);
          void section(String id, String label, List<Thought> list) {
            if (list.isEmpty) return;
            entries.add(_header(id, label, list.length));
            for (final t in _hoist(list)) {
              entries.add(_card('${t.id}', t, now, appearance, categories));
            }
          }

          if (content.earlier.isNotEmpty && !_selecting) {
            entries.add(
              _earlierRow(content.earlier.length, content.earlier, appearance),
            );
            if (_earlierOpen) {
              for (final t in _hoist(content.earlier)) {
                entries.add(
                  _card(
                    '${t.id}',
                    t,
                    now,
                    appearance,
                    categories,
                    earlier: true,
                  ),
                );
              }
            }
          }
          section('pinned', 'Pinned', content.pinned);
          section('today', 'Today', content.open);
          section('done_today', 'Done today', content.doneToday);
          section('archived_today', 'Archived today', content.archivedToday);
          visible = [
            ...content.pinned,
            ...content.open,
            ...content.doneToday,
            ...content.archivedToday,
            if (_earlierOpen) ...content.earlier,
          ];
          if (filter.isActive && entries.isEmpty) {
            empty = const EmptyState(
              icon: Icons.search_off_rounded,
              title: 'No matches today',
              subtitle: 'Try another space or search.',
            );
          } else {
            empty = EmptyState(
              icon: Icons.bubble_chart_rounded,
              title: 'Nothing for today yet',
              subtitle:
                  'Write below. Add #movies (or any space) to file a thought straight into it.',
              actionLabel: 'Write a thought',
              onAction: _focus.requestFocus,
              starters: [
                for (final prompt in _starterPrompts)
                  EmptyStarter(
                    label: prompt,
                    icon: Icons.edit_outlined,
                    onTap: () => _startWith(prompt),
                  ),
              ],
            );
          }
        case PalaceTab.done:
          final async = ref.watch(palaceDoneProvider(_doneLimit));
          loading = async.isLoading && !async.hasValue;
          error = async.hasError && !async.hasValue ? async.error : null;
          final list = async.value ?? const <Thought>[];
          visible = list;
          entries = _dayGroups(list, now, doneDate, appearance, categories);
          if (list.length >= _doneLimit) {
            entries.add(
              _showMore(() => setState(() => _doneLimit += palacePageSize)),
            );
          }
          empty = EmptyState(
            icon: Icons.check_circle_outline_rounded,
            title: filter.isActive ? 'No matches' : 'Nothing done yet',
            subtitle: filter.isActive
                ? 'Try another space or search.'
                : 'Thoughts you tick off appear here, grouped by day.',
          );
        case PalaceTab.archive:
          final async = ref.watch(palaceArchiveProvider(_archiveLimit));
          loading = async.isLoading && !async.hasValue;
          error = async.hasError && !async.hasValue ? async.error : null;
          final list = async.value ?? const <Thought>[];
          visible = list;
          entries = _dayGroups(list, now, archiveDate, appearance, categories);
          if (list.length >= _archiveLimit) {
            entries.add(
              _showMore(() => setState(() => _archiveLimit += palacePageSize)),
            );
          }
          empty = EmptyState(
            icon: Icons.archive_outlined,
            title: filter.isActive ? 'No matches' : 'Archive is empty',
            subtitle: filter.isActive
                ? 'Try another space or search.'
                : 'Archived thoughts are kept here, grouped by day.',
          );
        case PalaceTab.history:
          final day = dayOf(_historyDay ?? today);
          final async = ref.watch(palaceHistoryDayProvider(day));
          final activity =
              ref.watch(palaceActivityProvider).value ?? const <Thought>[];
          loading = async.isLoading && !async.hasValue;
          error = async.hasError && !async.hasValue ? async.error : null;
          beforeList = _historyStrip(today, activity);
          final events = historyForDay(async.value ?? const <Thought>[], day);
          const order = [
            (HistoryKind.written, 'Written'),
            (HistoryKind.carriedIn, 'Carried in'),
            (HistoryKind.finished, 'Finished'),
            (HistoryKind.archived, 'Archived'),
          ];
          final seen = <int>{};
          for (final (kind, label) in order) {
            final ofKind = events.where((e) => e.kind == kind).toList();
            if (ofKind.isEmpty) continue;
            entries.add(_header('hist_${kind.name}', label, ofKind.length));
            for (final e in ofKind) {
              if (seen.add(e.thought.id)) visible.add(e.thought);
              entries.add(
                _card(
                  '${kind.name}_${e.thought.id}',
                  e.thought,
                  now,
                  appearance,
                  categories,
                  note: e.note,
                ),
              );
            }
          }
          empty = EmptyState(
            icon: Icons.history_rounded,
            title:
                'Nothing on ${dayHeading(day, now).toLowerCase() == 'today' ? 'today' : dayHeading(day, now)}',
            subtitle:
                'Thoughts written, finished, archived or carried in on this day show here.',
          );
      }
    }

    _visible = visible;
    _selected.retainAll(visible.map((t) => t.id));
    if (_selected.isEmpty) _selecting = false;

    final chips = _tab == PalaceTab.history && !searchingAll
        ? null
        : _spaceChips(categories, filter);
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 0;
    final showComposer =
        _tab == PalaceTab.today && !_selecting && !searchingAll;

    Widget list() {
      if (error != null) {
        return EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load your thoughts',
          subtitle: 'Your records have not been changed.',
          actionLabel: 'Retry',
          onAction: () {
            ref.invalidate(palaceTodayProvider);
            ref.invalidate(palaceEarlierProvider);
            ref.invalidate(palaceDoneProvider);
            ref.invalidate(palaceArchiveProvider);
            ref.invalidate(palaceHistoryDayProvider);
          },
        );
      }
      if (loading) {
        // Skeletons shaped like thought cards (CLAUDE.md §6.2).
        return ListView(
          key: const ValueKey('palace_loading'),
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
          children: [
            for (final h in const [96.0, 72.0, 120.0, 84.0]) ...[
              SkeletonShimmer.card(height: h),
              const SizedBox(height: 10),
            ],
          ],
        );
      }
      return CustomScrollView(
        key: ValueKey('palace_list_${_tab.name}'),
        controller: _scroll,
        physics: const BouncingScrollPhysics(),
        slivers: [
          if (beforeList != null && !searchingAll)
            SliverToBoxAdapter(child: beforeList),
          if (entries.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 140),
                child: empty,
              ),
            )
          else
            SliverPadding(
              padding: EdgeInsets.fromLTRB(
                AppSpace.s16,
                AppSpace.s4,
                AppSpace.s16,
                _selecting ? 90.0 : (showComposer ? 190.0 : 40.0),
              ),
              sliver: SliverList.builder(
                itemCount: entries.length,
                itemBuilder: (context, i) => KeyedSubtree(
                  key: ValueKey(entries[i].key),
                  child: entries[i].builder(context),
                ),
              ),
            ),
        ],
      );
    }

    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) _stopSelecting();
      },
      // One backdrop behind the title and the board, so the large
      // title never sits on a different colour band.
      child: BoardBackground(
        child: AscentScaffold(
          backgroundColor: Colors.transparent,
          title: _selecting ? '${_selected.length} selected' : 'Mindspace',
          largeTitle: true,
          showBackButton: false,
          subtitle: _selecting ? 'Tap cards to add or remove' : null,
          showFeatureHelp: false,
          leading: _selecting
              ? IconButton(
                  icon: Icon(Icons.close_rounded, color: g.ink),
                  tooltip: 'Exit selection',
                  onPressed: _stopSelecting,
                )
              : null,
          onBack: _selecting ? _stopSelecting : null,
          actions: _selecting
              ? [
                  AscentButton.ghost(
                    key: const ValueKey('select_all'),
                    label: _selected.length == _visible.length ? 'None' : 'All',
                    compact: true,
                    onPressed: () => setState(() {
                      final ids = _visible.map((t) => t.id).toSet();
                      if (_selected.length == ids.length) {
                        _selected.clear();
                        _selecting = false;
                      } else {
                        _selected.addAll(ids);
                      }
                    }),
                  ),
                ]
              : [
                  IconButton(
                    key: const ValueKey('palace_search_toggle'),
                    tooltip: _searching ? 'Close search' : 'Search',
                    icon: Icon(
                      _searching
                          ? Icons.search_off_rounded
                          : Icons.search_rounded,
                      color: g.ink,
                    ),
                    onPressed: () {
                      setState(() => _searching = !_searching);
                      if (!_searching) {
                        _search.clear();
                        ref.read(palaceFilterProvider.notifier).setQuery('');
                      }
                    },
                  ),
                  IconButton(
                    key: const ValueKey('board_settings'),
                    tooltip: 'Settings',
                    icon: Icon(Icons.tune_rounded, color: g.ink),
                    onPressed: _settings,
                  ),
                ],
          body: Stack(
            children: [
              Positioned.fill(
                child: Column(
                  children: [
                    if (!_selecting && !searchingAll) _tabs(),
                    if (_searching && !_selecting) _searchField(),
                    if (chips != null && !_selecting && !keyboardOpen) ...[
                      chips,
                      const SizedBox(height: AppSpace.s4),
                    ],
                    Expanded(child: list()),
                  ],
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                child: _dragging != null
                    ? _dropDock(categories, _dragging!)
                    : _selecting
                    ? _selectionBar()
                    : (showComposer ? _composer() : const SizedBox.shrink()),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The lifted card under the finger: same width, slightly larger, softly
/// shadowed so it reads as picked up.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.width, required this.child});
  final double width;
  final Widget child;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Transform.scale(
      scale: 1.03,
      child: Material(
        type: MaterialType.transparency,
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: context.glass.shadow,
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: child,
        ),
      ),
    ),
  );
}
