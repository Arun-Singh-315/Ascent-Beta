import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/ascent_scaffold.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../promises/providers/promise_providers.dart';
import 'board_actions.dart';
import 'board_cards.dart';
import 'board_logic.dart';
import 'space_style.dart';
import 'spaces_shelf.dart';
import 'thought_detail_sheet.dart';

enum SpaceViewMode { list, grid }

/// One space ("Movies", "Books", …): every entry in one place, with a field
/// that stays open so several entries can be added in a row.
class ThoughtSpaceScreen extends ConsumerStatefulWidget {
  const ThoughtSpaceScreen({super.key, required this.spaceKey});

  final String spaceKey;

  @override
  ConsumerState<ThoughtSpaceScreen> createState() => _ThoughtSpaceScreenState();
}

class _ThoughtSpaceScreenState extends ConsumerState<ThoughtSpaceScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  String _tab = 'open';
  SpaceViewMode _mode = SpaceViewMode.list;
  bool _saving = false;

  bool get _isArchive => widget.spaceKey == archiveSpaceKey;

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _add(String raw) async {
    final entries = splitEntries(raw);
    if (entries.isEmpty || _saving) return;
    setState(() => _saving = true);
    HapticFeedback.mediumImpact();
    try {
      await ref
          .read(thoughtDaoProvider)
          .insertEntries(entries, widget.spaceKey);
      if (!mounted) return;
      _input.clear();
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
    final controller = TextEditingController();
    final text = await showDialog<String>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocal) {
          final count = splitEntries(controller.text).length;
          return AlertDialog(
            title: Text('Add several ${style.noun}s'),
            scrollable: true,
            content: TextField(
              key: const ValueKey('space_paste_field'),
              controller: controller,
              autofocus: true,
              minLines: 5,
              maxLines: 10,
              onChanged: (_) => setLocal(() {}),
              decoration: const InputDecoration(
                hintText: 'One per line',
                border: OutlineInputBorder(),
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                key: const ValueKey('space_paste_save'),
                onPressed: count == 0
                    ? null
                    : () => Navigator.pop(dialogContext, controller.text),
                child: Text(count == 0 ? 'Add' : 'Add $count'),
              ),
            ],
          );
        },
      ),
    );
    controller.dispose();
    if (text != null) await _add(text);
  }

  Future<void> _rename(String current) async {
    final controller = TextEditingController(text: current);
    final name = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Rename space'),
        scrollable: true,
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLength: 50,
          textCapitalization: TextCapitalization.sentences,
          onSubmitted: (v) => Navigator.pop(dialogContext, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, controller.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (name == null || name.trim() == current) return;
    try {
      await ref
          .read(thoughtDaoProvider)
          .renameCategory(widget.spaceKey, name);
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
        content: const Text(
          'Your entries are kept and move back to the wall.',
        ),
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
        child: Wrap(
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            ChoicePill(
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
              ChoicePill(
                key: const ValueKey('space_rename'),
                icon: Icons.edit_outlined,
                label: 'Rename',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _rename(name);
                },
              ),
              ChoicePill(
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
    final active = ref.watch(allThoughtsStreamProvider).value ?? <Thought>[];
    final archived =
        ref.watch(archivedThoughtsStreamProvider).value ?? <Thought>[];
    final privateIds = ref.watch(privatePromiseIdsProvider);
    final unlocked = ref.watch(unlockedPromiseIdsProvider);

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
        grid: _mode == SpaceViewMode.grid,
        showCheck: !_isArchive,
        onToggle: () => toggleThoughtDone(context, ref, t),
        onOpen: () => ThoughtDetailSheet.show(context, t),
      );
    }

    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;
    return AscentScaffold(
      title: name,
      subtitle: all.isEmpty
          ? 'Nothing here yet'
          : '$doneCount of ${all.length} ${style.doneLabel.toLowerCase()}',
      glow2: g.glow2,
      showFeatureHelp: false,
      actions: [
        if (!_isArchive)
          IconButton(
            key: const ValueKey('space_menu'),
            tooltip: 'Space options',
            icon: const Icon(Icons.more_horiz_rounded),
            onPressed: () =>
                _menu(name, widget.spaceKey.startsWith('custom_')),
          ),
      ],
      body: Column(
        children: [
          if (!_isArchive) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpace.s16,
                AppSpace.s8,
                AppSpace.s16,
                AppSpace.s4,
              ),
              child: Row(
                children: [
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
                        prefixIcon: Icon(style.icon, color: accent),
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpace.s8),
                  IconButton.filled(
                    key: const ValueKey('space_add_button'),
                    tooltip: 'Add',
                    onPressed: _saving ? null : () => _add(_input.text),
                    icon: const Icon(Icons.add_rounded),
                  ),
                  IconButton(
                    key: const ValueKey('space_paste_button'),
                    tooltip: 'Add several at once',
                    onPressed: () => _pasteList(style),
                    icon: const Icon(Icons.playlist_add_rounded),
                  ),
                ],
              ),
            ),
            if (all.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpace.s16,
                  vertical: AppSpace.s8,
                ),
                child: Column(
                  children: [
                    ProgressBar(
                      value: doneCount / all.length,
                      color: accent,
                    ),
                    const SizedBox(height: AppSpace.s10),
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
                                : 'Type above and press done. Keep typing to add more.')
                          : 'Switch tabs to see the rest.',
                    ),
                  )
                : _mode == SpaceViewMode.grid
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
        ],
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
                    width: 26,
                    height: 26,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: done ? accent : Colors.transparent,
                      border: Border.all(color: accent, width: 2),
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
      color: Color.alphaBlend(
        accent.withValues(alpha: grid ? .16 : .07),
        g.fill,
      ),
      borderRadius: grid ? AppGeometry.roundedr18 : AppGeometry.roundedr14,
      border: Border.all(color: accent.withValues(alpha: .4)),
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
                        if (check != null) check,
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
