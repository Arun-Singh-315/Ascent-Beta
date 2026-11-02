import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/note_draft_binding.dart';
import '../../../shared/widgets/ascent_scaffold.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../promises/providers/promise_providers.dart';
import 'board_actions.dart';
import 'board_cards.dart';
import 'board_background.dart';
import 'board_logic.dart';
import 'space_style.dart';
import 'thought_detail_sheet.dart';

enum SpaceViewMode { list, grid }

/// One space ("Movies", "Books", …): every entry in one place, with a field
/// that stays open so several entries can be added in a row.
class ThoughtSpaceScreen extends ConsumerStatefulWidget {
  const ThoughtSpaceScreen({
    super.key,
    required this.spaceKey,
    this.initialThoughtId,
  });

  final String spaceKey;
  final int? initialThoughtId;

  @override
  ConsumerState<ThoughtSpaceScreen> createState() => _ThoughtSpaceScreenState();
}

class _ThoughtSpaceScreenState extends ConsumerState<ThoughtSpaceScreen>
    with WidgetsBindingObserver {
  final _input = TextEditingController();
  final _focus = FocusNode();
  late String _tab = widget.initialThoughtId == null ? 'open' : 'all';
  SpaceViewMode _mode = SpaceViewMode.list;
  bool _saving = false;
  NoteDraftBinding? _draft;
  UnlockedPromiseIdsNotifier? _unlocked;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (!_isArchive) {
      _draft = NoteDraftBinding(
        _input,
        ref.read(sharedPreferencesProvider),
        'space_${widget.spaceKey}',
      );
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _unlocked = ref.read(unlockedPromiseIdsProvider.notifier);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _unlocked?.lockAll();
    }
  }

  bool get _isArchive => widget.spaceKey == archiveSpaceKey;

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _draft?.dispose();
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add(String raw) async {
    if (!mounted) return;
    final entries = splitEntries(raw, max: 101);
    if (entries.isEmpty || _saving) return;
    if (entries.length > 100) {
      AscentSnackBar.error(
        context,
        message: 'Add up to 100 entries at a time. Your text is kept.',
      );
      return;
    }
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      await ref
          .read(thoughtDaoProvider)
          .insertEntries(entries, widget.spaceKey);
      if (!mounted) return;
      if (_input.text.trim() == raw.trim()) _input.clear();
      if (_tab == 'done') setState(() => _tab = 'open');
      _focus.requestFocus();
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(context, message: 'Could not save. Try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pasteList(SpaceStyle style) async {
    final text = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (_) =>
          _SpaceTextDialog(title: 'Add several ${style.noun}s', bulk: true),
    );
    if (text != null) await _add(text);
  }

  Future<void> _rename(String current) async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _SpaceTextDialog(title: 'Rename space', initial: current),
    );
    if (!mounted) return;
    if (name == null || name.trim() == current) return;
    try {
      await ref.read(thoughtDaoProvider).renameCategory(widget.spaceKey, name);
    } catch (e) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: e is ArgumentError
              ? '${e.message}'
              : 'Could not rename. Try again.',
        );
      }
    }
  }

  Future<void> _deleteSpace(String name) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('Delete "$name"?'),
        content: const Text('Your entries are kept and move back to the wall.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Delete space'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ref.read(thoughtDaoProvider).deleteCategory(widget.spaceKey);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(context, message: 'Could not delete the space.');
      }
    }
  }

  void _menu(String name, bool custom) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      builder: (sheetContext) => Padding(
        padding: const EdgeInsets.all(AppSpace.s20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SpaceMenuAction(
              key: const ValueKey('space_view_toggle'),
              icon: _mode == SpaceViewMode.list
                  ? Icons.grid_view_rounded
                  : Icons.view_agenda_outlined,
              label: _mode == SpaceViewMode.list ? 'Poster view' : 'List view',
              onTap: () {
                Navigator.pop(sheetContext);
                setState(
                  () => _mode = _mode == SpaceViewMode.list
                      ? SpaceViewMode.grid
                      : SpaceViewMode.list,
                );
              },
            ),
            if (custom) ...[
              _SpaceMenuAction(
                key: const ValueKey('space_rename'),
                icon: Icons.edit_outlined,
                label: 'Rename',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _rename(name);
                },
              ),
              _SpaceMenuAction(
                key: const ValueKey('space_delete'),
                icon: Icons.delete_outline_rounded,
                label: 'Delete space',
                color: context.glass.errorInk,
                onTap: () {
                  Navigator.pop(sheetContext);
                  _deleteSpace(name);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final categories =
        ref.watch(thoughtCategoriesStreamProvider).value ??
        ThoughtDao.builtInCategories;
    final source = _isArchive
        ? ref.watch(archivedThoughtsStreamProvider)
        : ref.watch(allThoughtsStreamProvider);
    if (source.isLoading && !source.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (source.hasError && !source.hasValue) {
      return AscentScaffold(
        title: 'Space',
        showFeatureHelp: false,
        body: EmptyState(
          icon: Icons.cloud_off_outlined,
          title: 'Could not load these entries',
          subtitle: 'Your records have not been changed.',
          actionLabel: 'Retry',
          onAction: () => _isArchive
              ? ref.invalidate(archivedThoughtsStreamProvider)
              : ref.invalidate(allThoughtsStreamProvider),
        ),
      );
    }
    final active = ref.watch(allThoughtsStreamProvider).value ?? <Thought>[];
    final archived =
        ref.watch(archivedThoughtsStreamProvider).value ?? <Thought>[];
    final privateIds = ref.watch(privatePromiseIdsProvider);
    final unlocked = ref.watch(unlockedPromiseIdsProvider);

    final categoryState = ref.watch(thoughtCategoriesStreamProvider);
    if (categoryState.isLoading && !categoryState.hasValue) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final exists = _isArchive || categories.containsKey(widget.spaceKey);
    final name = _isArchive
        ? 'Archive'
        : (categories[widget.spaceKey] ?? 'Space');
    final style = _isArchive
        ? const SpaceStyle(
            icon: Icons.archive_outlined,
            noun: 'entry',
            doneLabel: 'Done',
            openLabel: 'Open',
          )
        : spaceStyleFor(name);
    final accent = _isArchive ? g.inkMuted : spaceAccentFor(g, widget.spaceKey);

    final all = _isArchive
        ? [...archived]
        : active.where((t) => t.category == widget.spaceKey).toList();
    final doneCount = all.where((t) => t.isCompleted).length;
    final shown = (_isArchive || _tab == 'all')
        ? all
        : all.where((t) => t.isCompleted == (_tab == 'done')).toList();
    shown.sort((a, b) {
      if (a.id == widget.initialThoughtId) return -1;
      if (b.id == widget.initialThoughtId) return 1;
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final byDate = b.createdAt.compareTo(a.createdAt);
      return byDate != 0 ? byDate : b.id.compareTo(a.id);
    });

    if (!exists) {
      return AscentScaffold(
        title: 'Space',
        showFeatureHelp: false,
        body: const EmptyState(
          icon: Icons.folder_off_outlined,
          title: 'This space is gone',
          subtitle: 'Its entries are safe on the wall.',
        ),
      );
    }

    Widget entryFor(Thought t, int index) {
      final locked = isPrivateLocked(t, privateIds, unlocked);
      return _SpaceEntry(
        key: ValueKey('space_entry_${t.id}'),
        thought: t,
        index: index,
        style: style,
        accent: accent,
        locked: locked,
        grid:
            _mode == SpaceViewMode.grid &&
            MediaQuery.sizeOf(context).width >= 360 &&
            MediaQuery.textScalerOf(context).scale(1) < 1.45,
        showCheck: !_isArchive,
        onToggle: () => toggleThoughtDone(context, ref, t),
        onOpen: () => ThoughtDetailSheet.show(context, t),
      );
    }

    final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return AscentScaffold(
      title: name,
      subtitle: all.isEmpty
          ? 'Your own collection'
          : '${all.length} ${all.length == 1 ? 'entry' : 'entries'} · $doneCount ${style.doneLabel.toLowerCase()}',
      glow2: g.glow2,
      showFeatureHelp: false,
      actions: [
        if (!_isArchive)
          IconButton(
            key: const ValueKey('space_menu'),
            tooltip: 'Space options',
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () => _menu(name, widget.spaceKey.startsWith('custom_')),
          ),
      ],
      body: BoardBackground(
        child: Column(
          children: [
            if (!_isArchive) ...[
              if (all.isNotEmpty && !keyboardOpen)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpace.s16,
                    vertical: AppSpace.s8,
                  ),
                  child: Column(
                    children: [
                      AscentSegmentedControl<String>(
                        segments: [
                          AscentSegment(
                            value: 'open',
                            label: style.openLabel,
                            key: const ValueKey('space_tab_open'),
                          ),
                          AscentSegment(
                            value: 'done',
                            label: style.doneLabel,
                            key: const ValueKey('space_tab_done'),
                          ),
                          const AscentSegment(
                            value: 'all',
                            label: 'All',
                            key: ValueKey('space_tab_all'),
                          ),
                        ],
                        selected: _tab,
                        onChanged: (v) => setState(() => _tab = v),
                      ),
                    ],
                  ),
                ),
            ],
            Expanded(
              child: shown.isEmpty
                  ? SingleChildScrollView(
                      child: EmptyState(
                        icon: style.icon,
                        title: all.isEmpty
                            ? (_isArchive
                                  ? 'Archive is empty'
                                  : 'Start your $name list')
                            : (_tab == 'done'
                                  ? 'Nothing ${style.doneLabel.toLowerCase()} yet'
                                  : 'All caught up'),
                        subtitle: all.isEmpty
                            ? (_isArchive
                                  ? 'Archived thoughts are kept here.'
                                  : 'Add your first entry below. Keep going at your own pace.')
                            : 'Switch tabs to see the rest.',
                      ),
                    )
                  : _mode == SpaceViewMode.grid &&
                        MediaQuery.sizeOf(context).width >= 360 &&
                        MediaQuery.textScalerOf(context).scale(1) < 1.45
                  ? _grid(shown, entryFor, bottomInset)
                  : ListView.separated(
                      padding: EdgeInsets.fromLTRB(
                        AppSpace.s16,
                        AppSpace.s8,
                        AppSpace.s16,
                        AppSpace.s24 + bottomInset,
                      ),
                      itemCount: shown.length,
                      separatorBuilder: (_, _) =>
                          const SizedBox(height: AppSpace.s8),
                      itemBuilder: (_, i) => entryFor(shown[i], i),
                    ),
            ),
            if (!_isArchive)
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 12),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(8, 4, 6, 4),
                    decoration: BoxDecoration(
                      color: g.fill,
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(
                        color: g.ink.withValues(alpha: .1),
                        width: .7,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: .04),
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        IconButton(
                          key: const ValueKey('space_paste_button'),
                          tooltip: 'Add several at once',
                          onPressed: () => _pasteList(style),
                          icon: Icon(Icons.add_rounded, color: g.inkSecondary),
                        ),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('space_add_field'),
                            controller: _input,
                            focusNode: _focus,
                            textInputAction: TextInputAction.done,
                            textCapitalization: TextCapitalization.sentences,
                            onSubmitted: _add,
                            decoration: InputDecoration(
                              hintText: style.addHint,
                              filled: false,
                              border: InputBorder.none,
                              enabledBorder: InputBorder.none,
                              focusedBorder: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        IconButton.filled(
                          key: const ValueKey('space_add_button'),
                          tooltip: 'Add',
                          style: IconButton.styleFrom(
                            backgroundColor: g.ink,
                            foregroundColor: g.bg,
                          ),
                          onPressed: _saving ? null : () => _add(_input.text),
                          icon: _saving
                              ? SizedBox(
                                  width: 18,
                                  height: 18,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: g.bg,
                                  ),
                                )
                              : const Icon(
                                  Icons.arrow_upward_rounded,
                                  size: 22,
                                ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _grid(
    List<Thought> shown,
    Widget Function(Thought, int) entryFor,
    double bottomInset,
  ) {
    final columns = balanceColumns<(Thought, int)>(
      [for (var i = 0; i < shown.length; i++) (shown[i], i)],
      2,
      (item) => item.$1.content.length > 40 ? 150 : 130,
    );
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s8,
        AppSpace.s16,
        AppSpace.s24 + bottomInset,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var c = 0; c < columns.length; c++) ...[
            if (c > 0) const SizedBox(width: AppSpace.s10),
            Expanded(
              child: Column(
                children: [
                  for (final item in columns[c]) ...[
                    entryFor(item.$1, item.$2),
                    const SizedBox(height: AppSpace.s10),
                  ],
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// One entry of a space. A list row has a big tap-circle on the left that
/// marks it done; a poster tile is a coloured card with the same tap-circle.
class _SpaceEntry extends StatelessWidget {
  const _SpaceEntry({
    super.key,
    required this.thought,
    required this.index,
    required this.style,
    required this.accent,
    required this.locked,
    required this.grid,
    required this.showCheck,
    required this.onToggle,
    required this.onOpen,
  });

  final Thought thought;
  final int index;
  final SpaceStyle style;
  final Color accent;
  final bool locked;
  final bool grid;
  final bool showCheck;
  final VoidCallback onToggle;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final parts = locked
        ? (title: 'Private commitment', body: null)
        : entryParts(thought.content);
    final done = thought.isCompleted;
    final titleStyle =
        (grid ? AscentTextStyles.sectionHeading : AscentTextStyles.bodyMedium)
            .copyWith(
              color: g.ink,
              decoration: done ? TextDecoration.lineThrough : null,
              decorationColor: g.inkMuted,
            );

    final check = showCheck
        ? Semantics(
            button: true,
            checked: done,
            label: done
                ? 'Mark as ${style.openLabel.toLowerCase()}'
                : 'Mark as ${style.doneLabel.toLowerCase()}',
            child: GestureDetector(
              key: ValueKey('space_check_${thought.id}'),
              behavior: HitTestBehavior.opaque,
              onTap: onToggle,
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? accent : Colors.transparent,
                      border: Border.all(
                        color: done
                            ? accent
                            : g.inkMuted.withValues(alpha: .45),
                        width: 1.4,
                      ),
                    ),
                    child: done
                        ? Icon(Icons.check_rounded, size: 18, color: g.bg)
                        : null,
                  ),
                ),
              ),
            ),
          )
        : null;

    final text = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          parts.title,
          maxLines: grid ? 4 : 2,
          overflow: TextOverflow.ellipsis,
          style: titleStyle,
        ),
        if (parts.body != null) ...[
          const SizedBox(height: AppSpace.s4),
          Text(
            parts.body!,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: AscentTextStyles.bodySmall.copyWith(color: g.inkSecondary),
          ),
        ],
      ],
    );

    final shape = BoxDecoration(
      color: Color.alphaBlend(g.ink.withValues(alpha: .045), g.bg),
      borderRadius: grid ? AppGeometry.roundedr18 : AppGeometry.roundedr14,
      border: Border.all(color: g.ink.withValues(alpha: .07), width: .7),
    );

    return Opacity(
      opacity: done ? .7 : 1,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onOpen,
        onLongPress: onOpen,
        child: Container(
          decoration: shape,
          padding: grid
              ? const EdgeInsets.all(AppSpace.s12)
              : const EdgeInsets.fromLTRB(
                  AppSpace.s4,
                  AppSpace.s4,
                  AppSpace.s12,
                  AppSpace.s4,
                ),
          child: grid
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(style.icon, size: 20, color: accent),
                        const Spacer(),
                        if (thought.isPinned)
                          Icon(Icons.push_pin_rounded, size: 14, color: accent),
                        ?check,
                      ],
                    ),
                    text,
                    const SizedBox(height: AppSpace.s4),
                  ],
                )
              : Row(
                  children: [
                    if (check != null)
                      check
                    else
                      const SizedBox(width: AppSpace.s12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpace.s8,
                        ),
                        child: text,
                      ),
                    ),
                    if (thought.isPinned)
                      Icon(Icons.push_pin_rounded, size: 14, color: accent),
                  ],
                ),
        ),
      ),
    );
  }
}

/// Dialog owns its controller until the closing transition has unmounted it.
class _SpaceTextDialog extends StatefulWidget {
  const _SpaceTextDialog({
    required this.title,
    this.initial = '',
    this.bulk = false,
  });
  final String title, initial;
  final bool bulk;
  @override
  State<_SpaceTextDialog> createState() => _SpaceTextDialogState();
}

class _SpaceTextDialogState extends State<_SpaceTextDialog> {
  late final _text = TextEditingController(text: widget.initial);
  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final count = splitEntries(_text.text, max: 101).length;
    final valid = widget.bulk
        ? count > 0 && count <= 100
        : _text.text.trim().isNotEmpty;
    if (widget.bulk) {
      final g = context.glass;
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * .7,
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: AscentTextStyles.sectionHeading.copyWith(color: g.ink),
                ),
                const SizedBox(height: 8),
                Text(
                  'Paste a list. Each line becomes its own entry.',
                  style: TextStyle(color: g.inkSecondary),
                ),
                const SizedBox(height: 20),
                TextField(
                  key: const ValueKey('space_paste_field'),
                  controller: _text,
                  autofocus: true,
                  minLines: 3,
                  maxLines: 6,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    hintText: 'One per line',
                    filled: true,
                    fillColor: g.ink.withValues(alpha: .04),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: BorderSide(
                        color: g.ink.withValues(alpha: .2),
                      ),
                    ),
                    helperText: count > 100
                        ? 'Add up to 100 entries at a time.'
                        : null,
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: const ValueKey('space_paste_save'),
                      style: FilledButton.styleFrom(
                        backgroundColor: g.ink,
                        foregroundColor: g.bg,
                      ),
                      onPressed: valid
                          ? () => Navigator.pop(context, _text.text)
                          : null,
                      child: Text('Add ${count > 100 ? 100 : count}'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      );
    }
    return AlertDialog(
      title: Text(widget.title),
      scrollable: true,
      content: TextField(
        key: ValueKey(widget.bulk ? 'space_paste_field' : 'space_rename_field'),
        controller: _text,
        autofocus: true,
        minLines: widget.bulk ? 5 : 1,
        maxLines: widget.bulk ? 10 : 1,
        maxLength: widget.bulk ? null : 50,
        onChanged: (_) => setState(() {}),
        decoration: InputDecoration(
          hintText: widget.bulk ? 'One per line' : 'Space name',
          helperText: widget.bulk && count > 100
              ? 'Add up to 100 entries at a time.'
              : null,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          key: widget.bulk ? const ValueKey('space_paste_save') : null,
          onPressed: valid ? () => Navigator.pop(context, _text.text) : null,
          child: Text(
            widget.bulk ? 'Add ${count > 100 ? 100 : count}' : 'Save',
          ),
        ),
      ],
    );
  }
}

class _SpaceMenuAction extends StatelessWidget {
  const _SpaceMenuAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.color,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final Color? color;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: color ?? context.glass.inkSecondary),
    title: Text(label, style: TextStyle(color: color)),
    onTap: onTap,
  );
}
