import 'package:flutter/cupertino.dart' show CupertinoActivityIndicator;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/mindspace_palette.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/note_draft_binding.dart';
import '../../../shared/widgets/app_text_field.dart';
import '../../../shared/widgets/ascent_action_menu.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/ascent_dialog.dart';
import '../../../shared/widgets/ascent_scaffold.dart';
import '../../../shared/widgets/skeleton_shimmer.dart';
import '../../../shared/widgets/ascent_segmented_control.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../../shared/widgets/empty_state.dart';
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

class _ThoughtSpaceScreenState extends ConsumerState<ThoughtSpaceScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  late String _tab = widget.initialThoughtId == null ? 'open' : 'all';
  final _mode = SpaceViewMode.list;
  bool _saving = false;
  NoteDraftBinding? _draft;
  @override
  void initState() {
    super.initState();
    if (!_isArchive) {
      _draft = NoteDraftBinding(
        _input,
        ref.read(sharedPreferencesProvider),
        'space_${widget.spaceKey}',
      );
    }
  }

  bool get _isArchive => widget.spaceKey == archiveSpaceKey;

  @override
  void dispose() {
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
    final text = await showAscentFrostedDialog<String>(
      context: context,
      builder: (_) =>
          _SpaceTextDialog(title: 'Add several ${style.noun}s', bulk: true),
    );
    if (text != null) await _add(text);
  }

  Future<void> _rename(String current) async {
    final name = await showAscentFrostedDialog<String>(
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
    // Can't be undone in one step, so this one asks first (CLAUDE.md §1.8).
    final ok = await AscentDialog.confirm(
      context: context,
      title: 'Delete “$name”?',
      content: 'Your entries are kept and move back to the wall.',
      confirmLabel: 'Delete space',
      isDestructive: true,
    );
    if (ok != true || !mounted) return;
    try {
      await ref.read(thoughtDaoProvider).deleteCategory(widget.spaceKey);
      if (mounted) context.pop();
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(context, message: 'Could not delete the space.');
      }
    }
  }

  Future<void> _menu(String name, bool custom) async {
    if (!custom) return;
    final choice = await showAscentActionMenu<String>(
      context: context,
      title: name,
      actions: const [
        AscentAction('rename', 'Rename', Icons.edit_outlined),
        AscentAction(
          'delete',
          'Delete space',
          Icons.delete_outline_rounded,
          destructive: true,
        ),
      ],
    );
    if (!mounted) return;
    switch (choice) {
      case 'rename':
        await _rename(name);
      case 'delete':
        await _deleteSpace(name);
    }
  }

  /// Skeletons shaped like entries (CLAUDE.md §6.2), never a bare spinner.
  Widget _loadingScaffold() => AscentScaffold(
    title: 'Space',
    showFeatureHelp: false,
    body: ListView(
      key: const ValueKey('space_loading'),
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s12,
        AppSpace.s16,
        0,
      ),
      children: [
        for (final h in const [64.0, 64.0, 64.0, 64.0]) ...[
          SkeletonShimmer.card(height: h),
          const SizedBox(height: AppSpace.s10),
        ],
      ],
    ),
  );

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
      return _loadingScaffold();
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

    final categoryState = ref.watch(thoughtCategoriesStreamProvider);
    if (categoryState.isLoading && !categoryState.hasValue) {
      return _loadingScaffold();
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
      const locked = false;
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
                          color: MindspacePalette.cardShadowLight(),
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
                              ? CupertinoActivityIndicator(
                                  radius: 9,
                                  color: g.bg,
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

/// Rename a space, or paste several entries at once (one per line). The
/// dialog owns its controller until the closing transition has unmounted it.
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
    final g = context.glass;
    final count = splitEntries(_text.text, max: 101).length;
    final valid = widget.bulk
        ? count > 0 && count <= 100
        : _text.text.trim().isNotEmpty && _text.text.trim().length <= 50;
    return AscentDialog(
      title: widget.title,
      contentWidget: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            key: ValueKey(
              widget.bulk ? 'space_paste_field' : 'space_rename_field',
            ),
            controller: _text,
            autofocus: true,
            minLines: widget.bulk ? 5 : 1,
            maxLines: widget.bulk ? 10 : 1,
            hintText: widget.bulk ? 'One per line' : 'e.g. Movies',
            textCapitalization: widget.bulk
                ? TextCapitalization.sentences
                : TextCapitalization.words,
            onChanged: (_) => setState(() {}),
          ),
          if (widget.bulk && count > 100) ...[
            const SizedBox(height: AppSpace.s8),
            Text(
              'Add up to 100 entries at a time.',
              style: AscentTextStyles.caption.copyWith(color: g.errorInk),
            ),
          ],
        ],
      ),
      actions: [
        Wrap(
          alignment: WrapAlignment.end,
          spacing: AppSpace.s8,
          runSpacing: AppSpace.s8,
          children: [
            AscentButton.secondary(
              label: 'Cancel',
              onPressed: () => Navigator.pop(context),
            ),
            AscentButton.tonal(
              key: widget.bulk ? const ValueKey('space_paste_save') : null,
              label: widget.bulk ? 'Add ${count > 100 ? 100 : count}' : 'Save',
              compact: true,
              onPressed: valid
                  ? () => Navigator.pop(context, _text.text)
                  : null,
            ),
          ],
        ),
      ],
    );
  }
}
