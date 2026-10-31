import 'dart:async';

import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../app/theme/thought_theme.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/note_draft_binding.dart';
import '../../../shared/widgets/ascent_scaffold.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/message_composer.dart';
import '../../promises/providers/promise_providers.dart';
import '../thought_action_ui.dart';
import '../thought_category_action.dart';
import '../thought_wall_appearance_sheet.dart';
import '../thought_wall_preferences.dart';
import '../thought_wall_screen.dart' show shareMultipleThoughts;
import 'board_actions.dart';
import 'board_cards.dart';
import 'board_logic.dart';
import 'board_preferences.dart';
import 'board_routes.dart';
import 'spaces_shelf.dart';
import 'thought_detail_sheet.dart';

/// The Thought Wall: a calm board of thoughts. Cards carry no buttons. Spaces
/// (Movies, Books …) sit in one row on top; everything you can do with a
/// thought is behind a tap.
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
  final _scroll = ScrollController();
  NoteDraftBinding? _draft;
  Timer? _dayTimer;
  UnlockedPromiseIdsNotifier? _unlockedNotifier;

  final Set<int> _selected = <int>{};
  bool _selecting = false;
  bool _saving = false;
  bool _showDone = false;
  int? _openedId;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _unlockedNotifier = ref.read(unlockedPromiseIdsProvider.notifier);
  }

  @override
  void didUpdateWidget(covariant ThoughtBoardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialThoughtId != widget.initialThoughtId) _openFromHome();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _scheduleDayChange();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _unlockedNotifier?.lockAll();
    }
  }

  void _scheduleDayChange() {
    _dayTimer?.cancel();
    final now = DateTime.now();
    final next = DateTime(now.year, now.month, now.day + 1);
    _dayTimer = Timer(next.difference(now), () {
      if (!mounted) return;
      setState(() {});
      _scheduleDayChange();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayTimer?.cancel();
    _draft?.dispose();
    _input.dispose();
    _focus.dispose();
    _scroll.dispose();
    _unlockedNotifier?.lockAll();
    super.dispose();
  }

  /// A thought opened from Home: on the wall it becomes the top card; inside a
  /// space, that space opens.
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
    if (thought.isArchived) {
      context.push(thoughtSpaceLocation(archiveSpaceKey, highlight: id));
      return;
    }
    if (thought.category != wallCategoryKey) {
      context.push(thoughtSpaceLocation(thought.category, highlight: id));
      return;
    }
    setState(() {
      _openedId = id;
      _selected.clear();
      _selecting = false;
    });
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
      await ref.read(thoughtDaoProvider).insertThought(
        ThoughtTableCompanion.insert(
          content: tag?.text ?? raw,
          mood: const drift.Value('thought'),
          category: drift.Value(tag?.key ?? wallCategoryKey),
        ),
      );
      if (_input.text.trim() == raw) _input.clear();
      if (!mounted) return;
      setState(() => _openedId = null);
      if (tag != null) {
        AscentSnackBar.show(
          context,
          message: 'Added to ${categories[tag.key]}',
          icon: Icons.folder_outlined,
          actionLabel: 'Open',
          onAction: () async {
            if (mounted) context.push(thoughtSpaceLocation(tag.key));
          },
        );
      } else if (_scroll.hasClients) {
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
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const CreateThoughtCategoryDialog(),
    );
    if (name == null || !mounted) return;
    try {
      final key = await ref
          .read(thoughtDaoProvider)
          .createCategoryAndMove(name, const []);
      if (mounted) context.push(thoughtSpaceLocation(key));
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

  List<Thought> _selectedThoughts(List<Thought> all) =>
      all.where((t) => _selected.contains(t.id)).toList();

  Future<void> _more(List<Thought> picked) async {
    final g = context.glass;
    final db = ref.read(databaseProvider);
    final action = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(AppSpace.s20),
        child: Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            ChoicePill(
              key: const ValueKey('select_todo'),
              icon: Icons.add_task_rounded,
              label: 'Todo',
              onTap: () => Navigator.pop(sheetContext, 'todo'),
            ),
            ChoicePill(
              key: const ValueKey('select_reminder'),
              icon: Icons.notifications_active_outlined,
              label: 'Reminder',
              onTap: () => Navigator.pop(sheetContext, 'reminder'),
            ),
            if (picked.length > 1)
              ChoicePill(
                key: const ValueKey('select_merge'),
                icon: Icons.merge_rounded,
                label: 'Merge',
                onTap: () => Navigator.pop(sheetContext, 'merge'),
              ),
            ChoicePill(
              key: const ValueKey('select_share'),
              icon: Icons.share_outlined,
              label: 'Share',
              color: g.ink,
              onTap: () => Navigator.pop(sheetContext, 'share'),
            ),
          ],
        ),
      ),
    );
    if (action == null || !mounted) return;
    if (action == 'share') {
      await shareMultipleThoughts(picked);
      return;
    }
    final saved = await applyThoughtAction(context, db, picked, action);
    if (saved && mounted) _stopSelecting();
  }

  Widget _selectionBar(List<Thought> all) {
    final g = context.glass;
    final picked = _selectedThoughts(all);
    final enabled = picked.isNotEmpty;
    Future<void> run(Future<void> Function() job) async {
      if (!enabled) return;
      await job();
      if (mounted) _stopSelecting();
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
              key: const ValueKey('select_move'),
              icon: Icons.folder_outlined,
              label: 'Move',
              onTap: !enabled
                  ? null
                  : () async {
                      final pick = await showSpacePicker(context);
                      if (pick == null || !mounted) return;
                      final moved = await moveThoughtsToSpace(
                        context,
                        ref,
                        picked,
                        pick,
                      );
                      if (moved && mounted) _stopSelecting();
                    },
            ),
            ChoicePill(
              key: const ValueKey('select_done'),
              icon: Icons.check_circle_outline_rounded,
              label: 'Done',
              onTap: !enabled
                  ? null
                  : () => run(() async {
                      final dao = ref.read(thoughtDaoProvider);
                      for (final t in picked.where((t) => !t.isCompleted)) {
                        await dao.toggleCompleted(t.id);
                      }
                    }),
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
              key: const ValueKey('select_delete'),
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              color: g.errorInk,
              onTap: !enabled
                  ? null
                  : () => run(() async {
                      await deleteThoughtsWithUndo(context, ref, picked);
                    }),
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

  Widget _composer(AscentGlass g) => Container(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.s10,
      AppSpace.s8,
      AppSpace.s10,
      AppSpace.s10,
    ),
    decoration: BoxDecoration(
      color: g.bg,
      border: Border(top: BorderSide(color: g.edge)),
    ),
    child: SafeArea(
      top: false,
      child: MessageComposer(
        controller: _input,
        focusNode: _focus,
        hint: 'Write a thought…  (#movies to file it)',
        busy: _saving,
        onSend: (_) => _send(),
      ),
    ),
  );

  // Board -------------------------------------------------------------------

  Widget _sectionHeader(AscentGlass g, String label, int count) => Padding(
    padding: const EdgeInsets.fromLTRB(
      AppSpace.s4,
      AppSpace.s16,
      AppSpace.s4,
      AppSpace.s8,
    ),
    child: Row(
      children: [
        Text(
          label.toUpperCase(),
          style: AscentTextStyles.labelSmall.copyWith(
            color: g.inkMuted,
            letterSpacing: 1.1,
          ),
        ),
        const SizedBox(width: AppSpace.s8),
        Text(
          '$count',
          style: AscentTextStyles.labelSmall.copyWith(color: g.inkMuted),
        ),
      ],
    ),
  );

  Widget _grid(
    List<Thought> thoughts, {
    required Widget Function(Thought, int) card,
    required ThoughtBoardLayout layout,
    required double width,
  }) {
    if (layout == ThoughtBoardLayout.stream) {
      return Column(
        children: [
          for (var i = 0; i < thoughts.length; i++) ...[
            card(thoughts[i], i),
            const SizedBox(height: AppSpace.s10),
          ],
        ],
      );
    }
    final columnWidth = (width - AppSpace.s10) / 2;
    final indexed = [for (var i = 0; i < thoughts.length; i++) (thoughts[i], i)];
    final columns = balanceColumns<(Thought, int)>(
      indexed,
      2,
      (item) => estimateCardHeight(item.$1, columnWidth: columnWidth),
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var c = 0; c < columns.length; c++) ...[
          if (c > 0) const SizedBox(width: AppSpace.s10),
          Expanded(
            child: Column(
              children: [
                for (final item in columns[c]) ...[
                  card(item.$1, item.$2),
                  const SizedBox(height: AppSpace.s10),
                ],
              ],
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThoughtTheme.from(Theme.of(context)),
    child: Builder(builder: _buildBoard),
  );

  Widget _buildBoard(BuildContext context) {
    final g = context.glass;
    final appearance = ref.watch(thoughtWallAppearanceProvider);
    final layout = ref.watch(thoughtBoardLayoutProvider);
    final categories =
        ref.watch(thoughtCategoriesStreamProvider).value ??
        ThoughtDao.builtInCategories;
    final activeAsync = ref.watch(allThoughtsStreamProvider);
    final active = activeAsync.value ?? <Thought>[];
    final archived =
        ref.watch(archivedThoughtsStreamProvider).value ?? <Thought>[];
    final privateIds = ref.watch(privatePromiseIdsProvider);
    final unlocked = ref.watch(unlockedPromiseIdsProvider);
    final now = DateTime.now();

    final wall = active.where((t) => t.category == wallCategoryKey).toList();
    _selected.retainAll(wall.map((t) => t.id));
    if (_selected.isEmpty) _selecting = false;

    final lockedIds = {
      for (final t in wall)
        if (isPrivateLocked(t, privateIds, unlocked)) t.id,
    };
    final content = buildBoardContent(
      wall,
      now: now,
      heroId: _openedId,
      excludedFromHero: lockedIds,
    );
    final spaces = buildSpaceSummaries(categories, active, archived);
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;

    Widget cardFor(Thought t, int index) => BoardCard(
      key: ValueKey('board_card_${t.id}'),
      thought: t,
      index: index,
      now: now,
      appearance: appearance,
      isSelected: _selected.contains(t.id),
      isSelectionMode: _selecting,
      isLocked: lockedIds.contains(t.id),
      onTap: () {
        if (_selecting) return _toggle(t.id);
        if (lockedIds.contains(t.id)) {
          unlockPrivateThought(ref, t);
        } else {
          ThoughtDetailSheet.show(context, t);
        }
      },
      onLongPress: () => _selecting ? _toggle(t.id) : _startSelecting(t.id),
      onDoubleTap: () => toggleThoughtDone(context, ref, t),
    );

    final hero = content.hero;
    return PopScope(
      canPop: !_selecting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _selecting) _stopSelecting();
      },
      child: AscentScaffold(
        title: _selecting ? '${_selected.length} selected' : 'Thought Wall',
        subtitle: _selecting ? 'Tap cards to add or remove' : 'Notes to myself',
        glow2: g.glow2,
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
                TextButton(
                  key: const ValueKey('select_all'),
                  onPressed: () => setState(() {
                    final ids = wall.map((t) => t.id).toSet();
                    if (_selected.length == ids.length) {
                      _selected.clear();
                      _selecting = false;
                    } else {
                      _selected.addAll(ids);
                    }
                  }),
                  child: Text(
                    _selected.length == wall.length ? 'None' : 'All',
                  ),
                ),
              ]
            : [
                IconButton(
                  key: const ValueKey('board_layout_toggle'),
                  tooltip: layout == ThoughtBoardLayout.board
                      ? 'One column'
                      : 'Two columns',
                  icon: Icon(
                    layout == ThoughtBoardLayout.board
                        ? Icons.view_agenda_outlined
                        : Icons.dashboard_outlined,
                  ),
                  onPressed: () => ref
                      .read(thoughtBoardLayoutProvider.notifier)
                      .set(
                        layout == ThoughtBoardLayout.board
                            ? ThoughtBoardLayout.stream
                            : ThoughtBoardLayout.board,
                      )
                      .catchError((_) {
                        if (mounted) {
                          AscentSnackBar.error(
                            context,
                            message: 'Could not save the layout.',
                          );
                        }
                      }),
                ),
                IconButton(
                  tooltip: 'Your promises',
                  icon: const Icon(Icons.handshake_rounded),
                  onPressed: () => context.push('/promises'),
                ),
                IconButton(
                  tooltip: 'Wall appearance',
                  icon: const Icon(Icons.tune_rounded),
                  onPressed: () => showModalBottomSheet<void>(
                    context: context,
                    useSafeArea: true,
                    isScrollControlled: true,
                    builder: (_) => const ThoughtWallAppearanceSheet(),
                  ),
                ),
              ],
        body: Column(
          children: [
            Expanded(
              child: activeAsync.isLoading && !activeAsync.hasValue
                  ? const Center(child: CircularProgressIndicator())
                  : LayoutBuilder(
                      builder: (context, constraints) {
                        final inner =
                            constraints.maxWidth - AppSpace.s16 * 2;
                        return CustomScrollView(
                          controller: _scroll,
                          slivers: [
                            if (!_selecting && !keyboardOpen)
                              SliverToBoxAdapter(
                                child: SpacesShelf(
                                  spaces: spaces,
                                  archivedCount: archived.length,
                                  onOpen: (s) =>
                                      context.push(thoughtSpaceLocation(s.key)),
                                  onNew: _newSpace,
                                  onOpenArchive: () => context.push(
                                    thoughtSpaceLocation(archiveSpaceKey),
                                  ),
                                ),
                              ),
                            if (content.isEmpty)
                              SliverFillRemaining(
                                hasScrollBody: false,
                                child: EmptyState(
                                  icon: Icons.bubble_chart_rounded,
                                  title: 'Your wall is empty',
                                  subtitle:
                                      'Write below. Add #movies (or any space) '
                                      'to file a thought straight into it.',
                                  actionLabel: 'Write a thought',
                                  onAction: _focus.requestFocus,
                                ),
                              )
                            else
                              SliverPadding(
                                padding: const EdgeInsets.fromLTRB(
                                  AppSpace.s16,
                                  AppSpace.s4,
                                  AppSpace.s16,
                                  AppSpace.s24,
                                ),
                                sliver: SliverList.list(
                                  children: [
                                    if (hero != null) ...[
                                      BoardHeroCard(
                                        key: ValueKey('board_hero_${hero.id}'),
                                        thought: hero,
                                        now: now,
                                        label: _openedId == hero.id
                                            ? 'Opened'
                                            : 'Latest',
                                        isSelected: _selected.contains(hero.id),
                                        isSelectionMode: _selecting,
                                        onTap: () => _selecting
                                            ? _toggle(hero.id)
                                            : ThoughtDetailSheet.show(
                                                context,
                                                hero,
                                              ),
                                        onLongPress: () => _selecting
                                            ? _toggle(hero.id)
                                            : _startSelecting(hero.id),
                                        onDoubleTap: () =>
                                            toggleThoughtDone(context, ref, hero),
                                      ),
                                      const SizedBox(height: AppSpace.s4),
                                    ],
                                    for (final section in content.sections) ...[
                                      _sectionHeader(
                                        g,
                                        section.label,
                                        section.thoughts.length,
                                      ),
                                      _grid(
                                        section.thoughts,
                                        card: cardFor,
                                        layout: layout,
                                        width: inner,
                                      ),
                                    ],
                                    if (content.done.isNotEmpty) ...[
                                      Padding(
                                        padding: const EdgeInsets.only(
                                          top: AppSpace.s8,
                                        ),
                                        child: Align(
                                          alignment: Alignment.centerLeft,
                                          child: TextButton.icon(
                                            key: const ValueKey(
                                              'board_done_toggle',
                                            ),
                                            onPressed: () => setState(
                                              () => _showDone = !_showDone,
                                            ),
                                            icon: Icon(
                                              _showDone
                                                  ? Icons.expand_less_rounded
                                                  : Icons.expand_more_rounded,
                                            ),
                                            label: Text(
                                              'Done · ${content.done.length}',
                                            ),
                                          ),
                                        ),
                                      ),
                                      if (_showDone)
                                        _grid(
                                          content.done,
                                          card: cardFor,
                                          layout: layout,
                                          width: inner,
                                        ),
                                    ],
                                  ],
                                ),
                              ),
                          ],
                        );
                      },
                    ),
            ),
            if (_selecting) _selectionBar(wall) else _composer(g),
          ],
        ),
      ),
    );
  }
}
