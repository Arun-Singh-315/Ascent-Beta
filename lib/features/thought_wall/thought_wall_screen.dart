import '../../shared/widgets/glass_chip.dart';
import 'thought_category_action.dart';
import '../../app/theme/thought_theme.dart';
import '../../shared/widgets/ascent_snack_bar.dart';
import 'thought_wall_preferences.dart';
import 'thought_wall_appearance_sheet.dart';
import 'dart:async';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import '../../core/services/note_draft_binding.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/widgets/message_composer.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/theme/color_tokens.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/database/app_database.dart';
import '../../core/providers/database_provider.dart';
import '../promises/providers/promise_providers.dart';
import '../vault/providers/vault_providers.dart';
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../home/widgets/home_schedule_sheet.dart';
import 'drop_thought_sheet.dart';
import 'thought_action_ui.dart';
import '../../shared/widgets/thought_excerpt.dart';

/// Formats thought content cleanly for WhatsApp, messages, and external sharing.
String formatThoughtForShare(Thought thought) {
  final buffer = StringBuffer();
  if (thought.promptQuestion != null &&
      thought.promptQuestion!.trim().isNotEmpty &&
      thought.promptQuestion!.trim().toLowerCase() !=
          thought.content.trim().toLowerCase()) {
    buffer.writeln('💭 Prompt: ${thought.promptQuestion!.trim()}\n');
  }
  buffer.writeln('"${thought.content.trim()}"');
  buffer.writeln('\n— Mind Space · Ascent');
  return buffer.toString();
}

/// Formats multiple selected thoughts cleanly for WhatsApp and messaging apps.
String formatMultipleThoughtsForShare(List<Thought> thoughts) {
  if (thoughts.isEmpty) return '';
  if (thoughts.length == 1) {
    return formatThoughtForShare(thoughts.first);
  }

  final buffer = StringBuffer();
  buffer.writeln('✦ MIND SPACE REFLECTIONS ✦');
  buffer.writeln('Ascent · Notes to Myself\n');

  for (int i = 0; i < thoughts.length; i++) {
    final t = thoughts[i];
    buffer.writeln('── [Note ${i + 1}/${thoughts.length}] ──');
    if (t.promptQuestion != null &&
        t.promptQuestion!.trim().isNotEmpty &&
        t.promptQuestion!.trim().toLowerCase() !=
            t.content.trim().toLowerCase()) {
      buffer.writeln('💭 Prompt: ${t.promptQuestion!.trim()}');
    }
    buffer.writeln('"${t.content.trim()}"');
    buffer.writeln();
  }
  buffer.writeln('— Shared from Mind Space · Ascent');
  return buffer.toString().trim();
}

/// Triggers system share sheet to share thought directly to WhatsApp or any installed app.
Future<void> shareThought(Thought thought) async {
  HapticFeedback.lightImpact();
  final text = formatThoughtForShare(thought);
  await SharePlus.instance.share(
    ShareParams(text: text, subject: 'Mind Space Reflection'),
  );
}

/// Triggers system share sheet to batch-share thoughts directly to WhatsApp or any installed app.
Future<void> shareMultipleThoughts(List<Thought> thoughts) async {
  if (thoughts.isEmpty) return;
  HapticFeedback.lightImpact();
  final text = formatMultipleThoughtsForShare(thoughts);
  await SharePlus.instance.share(
    ShareParams(
      text: text,
      subject: 'Mind Space Reflections (${thoughts.length} notes)',
    ),
  );
}

/// Open notes remain above completed notes, with stable pin/date ordering.
int compareWallThoughts(Thought a, Thought b) {
  if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
  if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
  final date = b.createdAt.compareTo(a.createdAt);
  return date != 0 ? date : b.id.compareTo(a.id);
}

/// Thought Wall / Mind Space Screen ("Me to Me")
/// An aesthetic spatial wall for unfiltered self-talk, sparks of inspiration,
/// daily wins, and letters to your future self.
class ThoughtWallScreen extends ConsumerStatefulWidget {
  const ThoughtWallScreen({super.key, this.initialThoughtId});
  final int? initialThoughtId;

  @override
  ConsumerState<ThoughtWallScreen> createState() => _ThoughtWallScreenState();
}

class _ThoughtWallScreenState extends ConsumerState<ThoughtWallScreen>
    with WidgetsBindingObserver {
  Timer? _dayTimer;
  Map<String, String> get _categories =>
      ref.read(thoughtCategoriesStreamProvider).value ??
      ThoughtDao.builtInCategories;

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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      setState(() {});
      _scheduleDayChange();
    }
  }

  String _viewToggle = 'today';
  String _completionFilter = 'all';
  String _archiveFilter = 'active';
  String _categoryFilter =
      'all'; // 'all', 'me_to_me', 'thought', 'idea', 'win', 'pinned'
  bool _isSelectionMode = false;
  bool _applyingSelection = false;
  int? _openedThoughtId;
  final Set<int> _selectedIds = <int>{};

  Map<String, (String, IconData)> get _filterMeta => {
    'all': ('All Thoughts', Icons.bubble_chart_rounded),
    for (final entry in _categories.entries)
      entry.key: (entry.value, Icons.folder_outlined),
    'general': ('General', Icons.notes_rounded),
    'suggestions': ('Suggestions', Icons.lightbulb_outline_rounded),
    'life_goals': ('Life Goals', Icons.flag_outlined),
    'promise': ('Promises', Icons.handshake_rounded),
    'pinned': ('Pinned', Icons.push_pin_rounded),
    'archived': ('Archived', Icons.archive_outlined),
  };

  final TextEditingController _inputController = TextEditingController();
  NoteDraftBinding? _draft;
  final FocusNode _focusNode = FocusNode();
  final ScrollController _scrollController = ScrollController();
  bool _hasInputText = false;
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleDayChange();
    try {
      _draft = NoteDraftBinding(
        _inputController,
        ref.read(sharedPreferencesProvider),
        'wall',
      );
    } catch (_) {}
    _hasInputText = _inputController.text.trim().isNotEmpty;
    _inputController.addListener(_onInputChanged);
    _openHomeThought();
  }

  @override
  void didUpdateWidget(covariant ThoughtWallScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialThoughtId != widget.initialThoughtId) {
      _openHomeThought();
    }
  }

  Future<void> _openHomeThought() async {
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
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _openedThoughtId = id;
      _categoryFilter = 'all';
      _selectedIds.clear();
      _isSelectionMode = false;
      _viewToggle = thought.createdAt.isBefore(today) ? 'history' : 'today';
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _scrollController.hasClients) _scrollController.jumpTo(0);
    });
  }

  void _onInputChanged() {
    final hasText = _inputController.text.trim().isNotEmpty;
    if (_hasInputText != hasText) {
      setState(() => _hasInputText = hasText);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _dayTimer?.cancel();
    _draft?.dispose();
    _inputController.removeListener(_onInputChanged);
    _inputController.dispose();
    _focusNode.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Color _getMoodColor(String mood) {
    switch (mood) {
      case 'me_to_me':
        return AppPalette.colorFF8B6A4F;
      case 'idea':
        return AppPalette.colorFFD97706;
      case 'win':
        return AppPalette.colorFF16A34A;
      case 'future':
        return AppPalette.colorFFEA580C;
      case 'promise':
        return AppPalette.colorFFB46824;
      case 'thought':
      default:
        return AppPalette.colorFF6E8565;
    }
  }

  Future<void> _submitThought() async {
    final text = _inputController.text.trim();
    if (text.isEmpty || _isSubmitting) return;

    HapticFeedback.mediumImpact();

    const mood = 'thought';
    final moodColor = _getMoodColor(mood);
    final colorHex = '#${moodColor.toARGB32().toRadixString(16)}';
    setState(() => _isSubmitting = true);
    try {
      await ref
          .read(thoughtDaoProvider)
          .insertThought(
            ThoughtTableCompanion.insert(
              content: text,
              mood: const drift.Value(mood),
              category: drift.Value(
                _categories.containsKey(_categoryFilter)
                    ? _categoryFilter
                    : 'general',
              ),
              colorHex: drift.Value(colorHex),
            ),
          );
      if (_inputController.text.trim() == text) _inputController.clear();

      if (!mounted) return;
      setState(() {
        _completionFilter = 'all';
        _archiveFilter = 'active';
        _viewToggle = 'today';
        _openedThoughtId = null;
        if (!_categories.containsKey(_categoryFilter)) _categoryFilter = 'all';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(persist: false, content: Text('Added to your Thought Wall.')),
      );

      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          0,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOutCubic,
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Widget _buildSelectionActions(
    BuildContext context,
    AscentGlass g,
    List<Thought> allThoughts,
  ) {
    final selected = allThoughts
        .where((t) => _selectedIds.contains(t.id))
        .toList();
    Future<void> act(String action) async {
      if (_applyingSelection || selected.isEmpty) return;
      HapticFeedback.selectionClick();
      setState(() => _applyingSelection = true);
      try {
        if (action == 'plan') {
          await showHomeSchedule(context, selected.first);
          if (mounted) _exitSelectionMode();
          return;
        }
        final saved = await applyThoughtAction(
          context,
          ref.read(databaseProvider),
          selected,
          action,
        );
        if (mounted && saved) _exitSelectionMode();
      } finally {
        if (mounted) setState(() => _applyingSelection = false);
      }
    }

    Future<void> updateSelected(String action) async {
      if (_applyingSelection || selected.isEmpty) return;
      setState(() => _applyingSelection = true);
      final db = ref.read(databaseProvider);
      try {
        await db.transaction(() async {
          for (final thought in selected) {
            if (action == 'done') {
              await db.thoughtDao.setCompleted(thought.id, true);
            } else if (action == 'archive') {
              await db.thoughtDao.archiveThought(thought.id);
            } else {
              await db.thoughtDao.unarchiveThought(thought.id);
            }
          }
        });
        if (mounted) _exitSelectionMode();
      } catch (_) {
        if (context.mounted) {
          AscentSnackBar.error(
            context,
            message: 'Could not update notes. Try again.',
          );
        }
      } finally {
        if (mounted) setState(() => _applyingSelection = false);
      }
    }

    Future<void> deleteSelected() async {
      if (_applyingSelection || selected.isEmpty) return;
      HapticFeedback.mediumImpact();
      final dao = ref.read(thoughtDaoProvider);
      final messenger = ScaffoldMessenger.of(context);
      final count = selected.length;
      setState(() => _applyingSelection = true);
      try {
        final snapshots = <dynamic>[];
        for (final thought in selected) {
          final s = await dao.deleteThoughtForUndo(thought.id);
          if (s != null) snapshots.add(s);
        }
        if (mounted) _exitSelectionMode();
        if (messenger.mounted && snapshots.isNotEmpty) {
          messenger.hideCurrentSnackBar();
          messenger.showSnackBar(
            SnackBar(
              persist: false,
              content: Text(
                count == 1 ? 'Thought removed' : '$count thoughts removed',
              ),
              duration: const Duration(seconds: 4),
              action: SnackBarAction(
                label: 'Undo',
                onPressed: () async {
                  for (final s in snapshots) {
                    try {
                      await dao.restoreThoughtDeletion(s);
                    } catch (_) {}
                  }
                },
              ),
            ),
          );
        }
      } catch (_) {
        if (context.mounted) {
          AscentSnackBar.error(
            context,
            message: 'Could not remove selected thoughts. Try again.',
          );
        }
      } finally {
        if (mounted) setState(() => _applyingSelection = false);
      }
    }

    final enabled = !_applyingSelection && selected.isNotEmpty;
    return SafeArea(
      top: false,
      child: Padding(
        key: const ValueKey('thought_selection_actions'),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Expanded(
              child: TextButton.icon(
                icon: const Icon(Icons.check_circle_outline),
                label: const Text('Done'),
                onPressed: enabled ? () => updateSelected('done') : null,
              ),
            ),
            Expanded(
              child: TextButton.icon(
                icon: const Icon(Icons.folder_outlined),
                label: const Text('Category'),
                onPressed: enabled ? () => _moveToCategory(selected) : null,
              ),
            ),
            Expanded(
              child: TextButton.icon(
                icon: Icon(Icons.delete_outline_rounded, color: g.coral),
                label: Text('Delete', style: TextStyle(color: g.coral)),
                onPressed: enabled ? deleteSelected : null,
              ),
            ),
            PopupMenuButton<String>(
              tooltip: 'More selected actions',
              enabled: enabled,
              icon: Icon(Icons.more_horiz_rounded, color: g.ink),
              onSelected: (action) async {
                if (action == 'delete') {
                  await deleteSelected();
                } else if (action == 'archive' || action == 'restore') {
                  await updateSelected(action);
                } else if (action == 'share') {
                  await shareMultipleThoughts(selected);
                } else {
                  await act(action);
                }
              },
              itemBuilder: (_) => [
                for (final item in const [
                  ('plan', 'Plan'),
                  ('todo', 'Create Todo'),
                  ('reminder', 'Set reminder'),
                  ('both', 'Todo & Reminder'),
                  ('merge', 'Merge notes'),
                  ('archive', 'Archive'),
                  ('restore', 'Unarchive'),
                  ('share', 'Share'),
                  ('delete', 'Delete'),
                ])
                  PopupMenuItem(
                    value: item.$1,
                    enabled:
                        (item.$1 != 'merge' || selected.length > 1) &&
                        (item.$1 != 'plan' || selected.length == 1),
                    child: Text(item.$2),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopSelectionQuickBar(
    BuildContext context,
    AscentGlass g,
    List<Thought> allThoughts,
  ) {
    final selected = allThoughts
        .where((t) => _selectedIds.contains(t.id))
        .toList();
    final enabled = !_applyingSelection && selected.isNotEmpty;

    Future<void> act(String action) async {
      if (_applyingSelection || selected.isEmpty) return;
      HapticFeedback.selectionClick();
      setState(() => _applyingSelection = true);
      try {
        if (action == 'plan') {
          await showHomeSchedule(context, selected.first);
          if (mounted) _exitSelectionMode();
          return;
        }
        final saved = await applyThoughtAction(
          context,
          ref.read(databaseProvider),
          selected,
          action,
        );
        if (mounted && saved) _exitSelectionMode();
      } finally {
        if (mounted) setState(() => _applyingSelection = false);
      }
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GlassChip(
              icon: Icons.transform_rounded,
              label: 'Convert',
              tooltip: 'Convert to Todo',
              onTap: enabled ? () => act('todo') : null,
            ),
            const SizedBox(width: 8),
            GlassChip(
              icon: Icons.folder_outlined,
              label: 'Category',
              tooltip: 'Move to category',
              onTap: enabled ? () => _moveToCategory(selected) : null,
            ),
            const SizedBox(width: 8),
            GlassChip(
              icon: Icons.archive_outlined,
              label: 'Archive',
              tooltip: 'Archive selected',
              onTap: enabled ? () => _batchArchive(selected) : null,
            ),
            const SizedBox(width: 8),
            GlassChip(
              icon: Icons.delete_outline_rounded,
              label: 'Delete',
              tooltip: 'Delete selected',
              onTap: enabled ? () => _batchDelete(selected) : null,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _batchArchive(List<Thought> selected) async {
    if (_applyingSelection || selected.isEmpty) return;
    setState(() => _applyingSelection = true);
    try {
      final dao = ref.read(thoughtDaoProvider);
      final anyActive = selected.any((t) => !t.isArchived);
      for (final t in selected) {
        if (anyActive) {
          await dao.archiveThought(t.id);
        } else {
          await dao.unarchiveThought(t.id);
        }
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              anyActive
                  ? '${selected.length} notes archived'
                  : '${selected.length} notes restored',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        _exitSelectionMode();
      }
    } finally {
      if (mounted) setState(() => _applyingSelection = false);
    }
  }

  Future<void> _batchDelete(List<Thought> selected) async {
    if (_applyingSelection || selected.isEmpty) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(
          'Delete ${selected.length} note${selected.length > 1 ? 's' : ''}?',
        ),
        content: const Text(
          'These thoughts and any linked reminders will be permanently removed.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _applyingSelection = true);
    try {
      final dao = ref.read(thoughtDaoProvider);
      for (final t in selected) {
        await dao.deleteThought(t.id);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '${selected.length} note${selected.length > 1 ? 's' : ''} deleted',
            ),
            duration: const Duration(seconds: 2),
          ),
        );
        _exitSelectionMode();
      }
    } finally {
      if (mounted) setState(() => _applyingSelection = false);
    }
  }

  Future<void> _moveToCategory(List<Thought> selected) async {
    if (_applyingSelection) return;
    setState(() => _applyingSelection = true);
    try {
      final saved = await moveThoughtsToCategory(context, ref, selected);
      if (mounted && saved) _exitSelectionMode();
    } finally {
      if (mounted) setState(() => _applyingSelection = false);
    }
  }

  void _selectFilter(String key) {
    setState(() {
      _categoryFilter = key;
      _archiveFilter = key == 'archived' ? 'archived' : 'active';
      _openedThoughtId = null;
      _selectedIds.clear();
      _isSelectionMode = false;
    });
  }

  bool _matches(Thought thought) {
    if (_viewToggle == 'today' && thought.isArchived) return false;
    if (_categoryFilter == 'pinned' && !thought.isPinned) return false;
    if (_categoryFilter == 'archived' && !thought.isArchived) return false;
    if (_categories.containsKey(_categoryFilter) &&
        thought.category != _categoryFilter) {
      return false;
    }
    if (!{'all', 'pinned', 'archived'}.contains(_categoryFilter) &&
        !_categories.containsKey(_categoryFilter) &&
        thought.mood != _categoryFilter) {
      return false;
    }
    if (_completionFilter == 'open' && thought.isCompleted) return false;
    if (_completionFilter == 'done' && !thought.isCompleted) return false;
    if (_archiveFilter == 'active' && thought.isArchived) return false;
    if (_archiveFilter == 'archived' && !thought.isArchived) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (_viewToggle == 'today') return !thought.createdAt.isBefore(today);
    if (_viewToggle == 'history') return thought.createdAt.isBefore(today);
    return true;
  }

  Future<void> _createCategory() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const CreateThoughtCategoryDialog(),
    );
    if (name == null || !mounted) return;
    try {
      final key = await ref
          .read(thoughtDaoProvider)
          .createCategoryAndMove(name, []);
      if (mounted) {
        setState(() {
          _categoryFilter = key;
          _viewToggle = 'all';
        });
      }
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: 'Could not create category. Try again.',
        );
      }
    }
  }

  Future<void> _chooseFilter() async {
    final result = await showModalBottomSheet<String>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (ctx) => Consumer(
        builder: (ctx, sheetRef, _) => StatefulBuilder(
          builder: (ctx, sheetSetState) {
            final shortcuts = sheetRef.watch(thoughtCategoryShortcutsProvider);
            return ConstrainedBox(
              constraints: BoxConstraints(
                maxHeight: MediaQuery.sizeOf(ctx).height * .8,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ListTile(
                    title: const Text('Filter thoughts'),
                    trailing: IconButton(
                      tooltip: 'Create category',
                      icon: const Icon(Icons.create_new_folder_outlined),
                      onPressed: () => Navigator.pop(ctx, '__create__'),
                    ),
                  ),
                  Flexible(
                    child: ListView(
                      shrinkWrap: true,
                      children: [
                        const ListTile(
                          subtitle: Text(
                            'Combine a category with date, completion and storage.',
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              for (final item in const [
                                ('all', 'Any status'),
                                ('open', 'Open'),
                                ('done', 'Done'),
                              ])
                                ChoiceChip(
                                  label: Text(item.$2),
                                  selected: _completionFilter == item.$1,
                                  onSelected: (_) {
                                    setState(() => _completionFilter = item.$1);
                                    sheetSetState(() {});
                                  },
                                ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Wrap(
                            spacing: 8,
                            children: [
                              for (final item in const [
                                ('all', 'Active & archived'),
                                ('active', 'Active'),
                                ('archived', 'Archived'),
                              ])
                                ChoiceChip(
                                  label: Text(item.$2),
                                  selected: _archiveFilter == item.$1,
                                  onSelected: (_) {
                                    setState(() {
                                      _archiveFilter = item.$1;
                                      if (item.$1 != 'active') {
                                        _viewToggle = 'all';
                                      }
                                    });
                                    sheetSetState(() {});
                                  },
                                ),
                            ],
                          ),
                        ),
                        const ListTile(
                          subtitle: Text(
                            'Star categories to show them as quick filters.',
                          ),
                        ),
                        for (final entry in _filterMeta.entries.where(
                          (e) => e.key != 'archived',
                        ))
                          ListTile(
                            selected: _categoryFilter == entry.key,
                            leading: Icon(entry.value.$2),
                            title: Text(
                              entry.key == 'all' ? 'All notes' : entry.value.$1,
                            ),
                            trailing: _categories.containsKey(entry.key)
                                ? IconButton(
                                    tooltip: shortcuts.contains(entry.key)
                                        ? 'Remove quick filter'
                                        : 'Add quick filter',
                                    icon: Icon(
                                      shortcuts.contains(entry.key)
                                          ? Icons.star_rounded
                                          : Icons.star_border_rounded,
                                    ),
                                    onPressed: () async {
                                      try {
                                        await sheetRef
                                            .read(
                                              thoughtCategoryShortcutsProvider
                                                  .notifier,
                                            )
                                            .toggle(entry.key);
                                      } catch (_) {
                                        if (ctx.mounted) {
                                          AscentSnackBar.error(
                                            ctx,
                                            message:
                                                'Could not save quick filters.',
                                          );
                                        }
                                      }
                                    },
                                  )
                                : null,
                            onTap: () => Navigator.pop(ctx, entry.key),
                          ),
                        ListTile(
                          leading: const Icon(Icons.create_new_folder_outlined),
                          title: const Text('Create category'),
                          onTap: () => Navigator.pop(ctx, '__create__'),
                        ),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        TextButton(
                          onPressed: () {
                            setState(() {
                              _completionFilter = 'all';
                              _archiveFilter = 'active';
                              _categoryFilter = 'all';
                            });
                            sheetSetState(() {});
                          },
                          child: const Text('Reset filters'),
                        ),
                        const Spacer(),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Apply filters'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (result == '__create__') {
      await _createCategory();
      return;
    }
    _selectFilter(result);
  }

  Widget _buildWhatsAppComposer(BuildContext context, AscentGlass g) {
    return Container(
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MessageComposer(
              controller: _inputController,
              focusNode: _focusNode,
              hint: 'Write a thought...',
              busy: _isSubmitting,
              onSend: (_) => _submitThought(),
            ),
          ],
        ),
      ),
    );
  }

  void _toggleSelection(int id) {
    if (_applyingSelection) return;
    HapticFeedback.selectionClick();
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) {
          _isSelectionMode = false;
        }
      } else {
        _selectedIds.add(id);
      }
    });
  }

  void _enterSelectionMode(int id) {
    HapticFeedback.mediumImpact();
    setState(() {
      _isSelectionMode = true;
      _selectedIds.add(id);
    });
  }

  void _exitSelectionMode() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSelectionMode = false;
      _selectedIds.clear();
    });
  }

  void _toggleSelectAll(List<Thought> thoughts) {
    HapticFeedback.lightImpact();
    setState(() {
      final allIds = thoughts.map((t) => t.id).toSet();
      if (_selectedIds.length == allIds.length) {
        _selectedIds.clear();
        _isSelectionMode = false;
      } else {
        _selectedIds.addAll(allIds);
        _isSelectionMode = true;
      }
    });
  }

  Widget _buildViewSegment(String key, String label, IconData icon, dynamic g) {
    final isSelected = _viewToggle == key;
    final activeColor = context.isDark
        ? Theme.of(context).colorScheme.surfaceContainerHighest
        : context.accentPrimary;
    final activeInk = context.isDark ? g.ink : Colors.white;
    return Expanded(
      child: AppGestureTap(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _viewToggle = key;
            if (key == 'all') _archiveFilter = 'all';
            _openedThoughtId = null;
            _selectedIds.clear();
            _isSelectionMode = false;
          });
        },
        child: AnimatedContainer(
          key: ValueKey('thought_view_$key'),
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: 9),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isSelected ? activeColor : AppPalette.transparent,
            borderRadius: BorderRadius.circular(12),
            boxShadow: isSelected && !context.isDark
                ? [
                    BoxShadow(
                      color: activeColor.withValues(alpha: 0.28),
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: isSelected ? activeInk : g.inkMuted),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AscentTextStyles.labelMedium.copyWith(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected ? activeInk : g.inkMuted,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThoughtTheme.from(Theme.of(context)),
    child: Builder(builder: _buildThoughtSpace),
  );

  Widget _buildThoughtSpace(BuildContext context) {
    ref.watch(thoughtCategoriesStreamProvider);
    final appearance = ref.watch(thoughtWallAppearanceProvider);
    final shortcuts = ref.watch(thoughtCategoryShortcutsProvider);
    final activeAsync = ref.watch(allThoughtsStreamProvider);
    final archivedAsync = ref.watch(archivedThoughtsStreamProvider);

    if (activeAsync.hasValue && archivedAsync.hasValue) {
      final ids = [
        ...activeAsync.value!,
        ...archivedAsync.value!,
      ].map((t) => t.id).toSet();
      _selectedIds.retainAll(ids);
      if (_selectedIds.isEmpty) _isSelectionMode = false;
    }
    final g = context.glass;

    return PopScope(
      canPop: !_isSelectionMode,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && _isSelectionMode) {
          _exitSelectionMode();
        }
      },
      child: AscentScaffold(
        title: _isSelectionMode
            ? '${_selectedIds.length} Selected'
            : 'Thought Wall',
        subtitle: _isSelectionMode
            ? 'Done, category or more actions'
            : 'Mind space · Notes to myself',
        glow2: g.glow2,
        showFeatureHelp: false,
        leading: _isSelectionMode
            ? IconButton(
                icon: Icon(Icons.close_rounded, color: g.ink),
                tooltip: 'Exit selection',
                onPressed: _exitSelectionMode,
              )
            : null,
        onBack: _isSelectionMode ? _exitSelectionMode : null,
        actions: _isSelectionMode
            ? [
                activeAsync.maybeWhen(
                  data: (activeList) {
                    final archivedList = archivedAsync.value ?? [];
                    final allThoughts = [...activeList, ...archivedList];
                    final filtered = allThoughts.where(_matches).toList()
                      ..sort(compareWallThoughts);

                    final isAllSelected =
                        filtered.isNotEmpty &&
                        filtered.every((t) => _selectedIds.contains(t.id));

                    return Tooltip(
                      message: isAllSelected ? 'Deselect All' : 'Select All',
                      child: TextButton.icon(
                        key: const ValueKey('thought_select_all_btn'),
                        style: TextButton.styleFrom(
                          foregroundColor: g.clay,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                        icon: Icon(
                          isAllSelected
                              ? Icons.check_box_outlined
                              : Icons.checklist_rounded,
                          size: 18,
                          color: g.clay,
                        ),
                        label: Text(
                          isAllSelected ? 'Deselect All' : 'Select All',
                          style: AscentTextStyles.labelMedium.copyWith(
                            color: g.clay,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        onPressed: () => _toggleSelectAll(filtered),
                      ),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
              ]
            : [
                if (MediaQuery.sizeOf(context).width < 400 ||
                    MediaQuery.textScalerOf(context).scale(14) > 17)
                  IconButton(
                    tooltip: 'Your promises',
                    icon: const Icon(Icons.handshake_rounded, size: 20),
                    onPressed: () => context.push('/promises'),
                  )
                else
                  TextButton.icon(
                    icon: const Icon(Icons.handshake_rounded, size: 17),
                    label: const Text('Promises'),
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
            // Segmented 2-Way Toggle: Today | History & Archive
            AppCard(
              margin: const EdgeInsets.symmetric(
                horizontal: AppSpace.s16,
                vertical: AppSpace.s4,
              ),
              padding: const EdgeInsets.all(AppSpace.s4),
              nightDecoration: BoxDecoration(
                color: context.isDark
                    ? Theme.of(context).colorScheme.surface
                    : (g.frozen
                          ? const Color(0xFFEDF4FA)
                          : (g.merlot
                                ? const Color(0xFFF3ECE0)
                                : const Color(0xFFF5EFE9))),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: g.edge.withValues(alpha: 0.6),
                  width: 1.0,
                ),
              ),
              child: Row(
                children: [
                  _buildViewSegment('all', 'All', Icons.notes_rounded, g),
                  _buildViewSegment('today', "Today", Icons.today_rounded, g),
                  _buildViewSegment(
                    'history',
                    "History",
                    Icons.history_rounded,
                    g,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 6),

            if (_isSelectionMode)
              _buildTopSelectionQuickBar(context, g, [
                ...(activeAsync.value ?? []),
                ...(archivedAsync.value ?? []),
              ])
            else ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 6, 18, 0),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _viewToggle == 'today'
                        ? "TODAY'S REFLECTIONS"
                        : _viewToggle == 'all'
                        ? 'ALL REFLECTIONS'
                        : 'OLDER REFLECTIONS',
                    style: AscentTextStyles.labelSmall.copyWith(
                      color: g.inkMuted,
                      letterSpacing: 1,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Row(
                  key: const ValueKey('thought_filter_bar'),
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (final key in <String>{
                              if (_categoryFilter != 'all' &&
                                  !shortcuts.contains(_categoryFilter))
                                _categoryFilter,
                              'all',
                              ...shortcuts.where(_categories.containsKey),
                            })
                              Padding(
                                padding: const EdgeInsets.only(right: 8),
                                child: AppPill.choice(
                                  label: Text(
                                    key == 'all'
                                        ? 'All notes'
                                        : _filterMeta[key]?.$1 ?? 'Category',
                                  ),
                                  selected: _categoryFilter == key,
                                  onSelected: (_) => _selectFilter(key),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    GlassChip(
                      label: 'Archive',
                      icon: Icons.archive_outlined,
                      selected: _archiveFilter == 'archived',
                      onTap: () => _selectFilter(
                        _archiveFilter == 'archived' ? 'all' : 'archived',
                      ),
                    ),
                    const SizedBox(width: 4),
                    IconButton(
                      tooltip: 'Category filter',
                      icon: Badge(
                        isLabelVisible:
                            _completionFilter != 'all' ||
                            _archiveFilter != 'active',
                        child: const Icon(Icons.filter_list_rounded),
                      ),
                      onPressed: _chooseFilter,
                    ),
                  ],
                ),
              ),
            ],

            // Main Wall Content
            Expanded(
              child: activeAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) =>
                    Center(child: Text('Error loading wall: $err')),
                data: (activeList) {
                  final archivedList = archivedAsync.value ?? [];
                  final allThoughts = [...activeList, ...archivedList];

                  final filtered = allThoughts.where(_matches).toList()
                    ..sort(compareWallThoughts);

                  if (_openedThoughtId != null) {
                    final index = filtered.indexWhere(
                      (t) => t.id == _openedThoughtId,
                    );
                    if (index > 0) filtered.insert(0, filtered.removeAt(index));
                  }

                  if (filtered.isEmpty) {
                    return SingleChildScrollView(
                      child: EmptyState(
                        title: _categoryFilter == 'archived'
                            ? 'No archived reflections'
                            : (_viewToggle == 'today'
                                  ? 'No thoughts logged today'
                                  : 'No past or archived reflections'),
                        subtitle: _categoryFilter == 'archived'
                            ? 'Reflections you archive from the wall will be safely stored here.'
                            : 'Drop an unfiltered reflection, spark of idea, or note to yourself.',
                        icon: _categoryFilter == 'archived'
                            ? Icons.archive_outlined
                            : Icons.bubble_chart_rounded,
                        actionLabel: 'Drop a Thought',
                        onAction: () => DropThoughtSheet.show(context),
                      ),
                    );
                  }

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.only(
                      left: AppSpace.s16,
                      right: AppSpace.s16,
                      top: AppSpace.s8,
                      bottom: AppSpace.s16,
                    ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final thought = filtered[index];
                      final bubble = ThoughtCardBubble(
                        key: ValueKey(thought.id),
                        compact: true,
                        appearance: appearance,
                        categoryLabel: _categories[thought.category],
                        onMoveToCategory: () => _moveToCategory([thought]),
                        thought: thought,
                        index: index,
                        isSelected: _selectedIds.contains(thought.id),
                        isSelectionMode: _isSelectionMode,
                        onToggleSelect: () => _toggleSelection(thought.id),
                        onLongPress: () => _enterSelectionMode(thought.id),
                      );
                      final showHeading = _isSelectionMode
                          ? index == 0
                          : _categoryFilter != 'pinned' &&
                                !thought.isArchived &&
                                (index == 0 ||
                                    filtered[index - 1].isPinned !=
                                        thought.isPinned ||
                                    filtered[index - 1].isCompleted !=
                                        thought.isCompleted);
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (showHeading)
                            Padding(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpace.s4,
                                AppSpace.s10,
                                AppSpace.s4,
                                AppSpace.s10,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      thought.isCompleted
                                          ? 'Completed'
                                          : thought.isPinned
                                          ? 'Pinned'
                                          : 'Recent',
                                      style: AscentTextStyles.labelMedium
                                          .copyWith(color: g.inkMuted),
                                    ),
                                  ),
                                  if (_isSelectionMode) ...[
                                    IconButton(
                                      tooltip: 'Share selected notes',
                                      icon: const Icon(Icons.share_outlined),
                                      onPressed: _applyingSelection
                                          ? null
                                          : () => shareMultipleThoughts(
                                              allThoughts
                                                  .where(
                                                    (t) => _selectedIds
                                                        .contains(t.id),
                                                  )
                                                  .toList(),
                                            ),
                                    ),
                                    IconButton(
                                      tooltip: 'Merge selected notes',
                                      icon: const Icon(Icons.merge_rounded),
                                      onPressed:
                                          _applyingSelection ||
                                              _selectedIds.length < 2
                                          ? null
                                          : () async {
                                              setState(
                                                () => _applyingSelection = true,
                                              );
                                              try {
                                                final saved =
                                                    await applyThoughtAction(
                                                      context,
                                                      ref.read(
                                                        databaseProvider,
                                                      ),
                                                      allThoughts
                                                          .where(
                                                            (t) => _selectedIds
                                                                .contains(t.id),
                                                          )
                                                          .toList(),
                                                      'merge',
                                                    );
                                                if (mounted && saved) {
                                                  _exitSelectionMode();
                                                }
                                              } finally {
                                                if (mounted) {
                                                  setState(
                                                    () => _applyingSelection =
                                                        false,
                                                  );
                                                }
                                              }
                                            },
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          bubble,
                        ],
                      );
                    },
                  );
                },
              ),
            ),
            if (_isSelectionMode)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * .32,
                ),
                child: SingleChildScrollView(
                  child: _buildSelectionActions(context, g, [
                    ...(activeAsync.value ?? []),
                    ...(archivedAsync.value ?? []),
                  ]),
                ),
              )
            else
              _buildWhatsAppComposer(context, g),
          ],
        ),
      ),
    );
  }
}

class ThoughtCardBubble extends ConsumerStatefulWidget {
  final bool compact;
  final ThoughtWallAppearance appearance;
  final String? categoryLabel;
  final Future<void> Function()? onMoveToCategory;
  final Thought thought;
  final int index;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onLongPress;

  const ThoughtCardBubble({
    super.key,
    required this.thought,
    required this.index,
    this.compact = false,
    this.appearance = const ThoughtWallAppearance(),
    this.categoryLabel,
    this.onMoveToCategory,
    this.isSelected = false,
    this.isSelectionMode = false,
    this.onToggleSelect,
    this.onLongPress,
  });

  @override
  ConsumerState<ThoughtCardBubble> createState() => _ThoughtCardBubbleState();
}

class _ThoughtCardBubbleState extends ConsumerState<ThoughtCardBubble> {
  Thought get thought => widget.thought;
  int get index => widget.index;
  bool get isSelected => widget.isSelected;
  bool get isSelectionMode => widget.isSelectionMode;
  VoidCallback? get onToggleSelect => widget.onToggleSelect;
  VoidCallback? get onLongPress => widget.onLongPress;

  Future<void> _toggleDone() async {
    try {
      await ref.read(thoughtDaoProvider).toggleCompleted(thought.id);
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: 'Could not update thought. Try again.',
        );
      }
    }
  }


  Future<bool> _deleteWithUndo(BuildContext context, WidgetRef ref) async {
    HapticFeedback.mediumImpact();
    final dao = ref.read(thoughtDaoProvider);
    final messenger = ScaffoldMessenger.of(context);
    void failure(String message) {
      messenger.hideCurrentSnackBar();
      messenger.showSnackBar(SnackBar(content: Text(message)));
    }

    try {
      final snapshot = await dao.deleteThoughtForUndo(thought.id);
      if (snapshot == null) {
        if (messenger.mounted) failure('This thought is no longer available.');
        return false;
      }
      Future<void> restore() async {
        try {
          if (!await dao.restoreThoughtDeletion(snapshot) &&
              messenger.mounted) {
            failure('Undo is no longer available. Newer changes were kept.');
          }
        } catch (_) {
          if (messenger.mounted) {
            messenger.hideCurrentSnackBar();
            messenger.showSnackBar(
              SnackBar(
                content: const Text('Could not restore the thought.'),
                action: SnackBarAction(label: 'Retry', onPressed: restore),
              ),
            );
          }
        }
      }

      if (messenger.mounted) {
        messenger.hideCurrentSnackBar();
        messenger.showSnackBar(
          SnackBar(
            persist: false,
            content: const Text('Thought removed'),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(label: 'Undo', onPressed: restore),
          ),
        );
      }
      return true;
    } catch (_) {
      if (messenger.mounted) {
        failure('Could not delete the thought. Please try again.');
      }
      return false;
    }
  }

  Color _moodColor(String mood) {
    switch (mood) {
      case 'me_to_me':
        return AppPalette.colorFF8B6A4F; // Refined Indigo
      case 'idea':
        return AppPalette.colorFFD97706; // Warm Amber
      case 'win':
        return AppPalette.colorFF16A34A; // Sage Green
      case 'future':
        return AppPalette.colorFFEA580C; // Terracotta
      case 'promise':
        return AppPalette.colorFFB46824;
      case 'thought':
      default:
        return AppPalette.colorFF6E8565; // Sky Deep
    }
  }

  BoxDecoration _wallDecoration(BuildContext context) {
    final g = context.glass;
    final isDark = context.isDark;
    final style = widget.appearance.style;
    final minimal = style == ThoughtCardStyle.minimal;
    final isBubble = style == ThoughtCardStyle.bubble;
    final radius = switch (style) {
      ThoughtCardStyle.soft => BorderRadius.circular(16),
      ThoughtCardStyle.bubble => BorderRadius.only(
        topLeft: const Radius.circular(16),
        topRight: const Radius.circular(16),
        bottomLeft: Radius.circular(index.isEven ? 4 : 16),
        bottomRight: Radius.circular(index.isOdd ? 4 : 16),
      ),
      ThoughtCardStyle.minimal => BorderRadius.zero,
    };

    final moodAccent = g.frozen
        ? (thought.mood == 'win' ? g.sage : g.slate)
        : _moodColor(thought.mood);

    final hardBorderColor = thought.isCompleted
        ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534))
              .withValues(alpha: .6)
        : isBubble
        ? Color.lerp(
            g.ink.withValues(alpha: isDark ? .35 : .40),
            moodAccent,
            isDark ? 0.45 : 0.40,
          )!
        : g.ink.withValues(alpha: isDark ? .34 : .38);

    final borderWidth = isBubble ? 1.8 : 1.0;

    final bubbleFill = thought.isCompleted
        ? (isDark ? const Color(0xFF86EFAC) : const Color(0xFF166534))
              .withValues(alpha: .08)
        : isSelected
        ? g.clay.withValues(alpha: isDark ? 0.09 : 0.06)
        : isBubble
        ? Color.lerp(
            g.fill,
            moodAccent.withValues(alpha: isDark ? 0.06 : 0.04),
            0.5,
          )
        : Colors.transparent;

    return BoxDecoration(
      color: bubbleFill,
      boxShadow: isSelected
          ? [
              BoxShadow(
                color: g.clay.withValues(alpha: isDark ? 0.36 : 0.22),
                blurRadius: 12,
                spreadRadius: 1,
                offset: const Offset(0, 2),
              ),
            ]
          : isBubble
          ? [
              BoxShadow(
                color: moodAccent.withValues(alpha: isDark ? 0.10 : 0.05),
                blurRadius: 8,
                spreadRadius: 0,
                offset: const Offset(0, 2),
              ),
            ]
          : const [],
      borderRadius: widget.compact
          ? radius
          : BorderRadius.only(
              topLeft: const Radius.circular(18),
              topRight: const Radius.circular(18),
              bottomLeft: Radius.circular(index.isEven ? 18 : 6),
              bottomRight: Radius.circular(index.isOdd ? 18 : 6),
            ),
      border: isSelected
          ? Border.all(color: g.clay, width: 2.0)
          : minimal && widget.compact
          ? Border(bottom: BorderSide(color: hardBorderColor, width: 1.0))
          : Border.all(color: hardBorderColor, width: borderWidth),
    );
  }

  @override
  Widget build(BuildContext context) {
    final moodColor = context.glass.frozen
        ? (thought.mood == 'win' ? context.glass.sage : context.glass.slate)
        : _moodColor(thought.mood);
    final timeStr = DateFormat('MMM d • h:mm a').format(thought.createdAt);
    final g = context.glass;
    final contentLower = thought.content.toLowerCase();
    final isHighPriority = thought.content.contains('[HIGH]') ||
        contentLower.contains('#high') ||
        contentLower.contains('#urgent');
    final privatePromiseIds = ref.watch(privatePromiseIdsProvider);
    final unlockedPromiseIds = ref.watch(unlockedPromiseIdsProvider);
    final isPrivatePromise = thought.mood == 'promise' &&
        privatePromiseIds.contains(thought.id);
    final isPromiseLocked = isPrivatePromise &&
        !unlockedPromiseIds.contains(thought.id);

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50).clamp(0, 400)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 16 * (1.0 - value)),
            child: child,
          ),
        );
      },
      child: Padding(
        padding: EdgeInsets.only(
          bottom: widget.compact
              ? (widget.appearance.density == ThoughtCardDensity.compact
                    ? 8
                    : 12)
              : AppSpace.s14,
          left: index.isOdd ? 32 : 0,
          right: index.isEven ? 32 : 0,
        ),
        child: Dismissible(
          key: ValueKey('thought_${thought.id}'),
          direction: isSelectionMode
              ? DismissDirection.none
              : DismissDirection.startToEnd,
          confirmDismiss: (direction) async {
            final thoughtDao = ref.read(thoughtDaoProvider);
            final messenger = ScaffoldMessenger.of(context);
            if (direction == DismissDirection.startToEnd) {
              // Archive / Unarchive
              HapticFeedback.mediumImpact();
              if (thought.isArchived) {
                await thoughtDao.unarchiveThought(thought.id);
              } else {
                await thoughtDao.archiveThought(thought.id);
              }
              if (messenger.mounted) {
                messenger.hideCurrentSnackBar();
                messenger.showSnackBar(
                  SnackBar(
                    persist: false,
                    content: Text(
                      thought.isArchived
                          ? 'Thought unarchived'
                          : 'Thought archived',
                    ),
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: 'UNDO',
                      onPressed: () async {
                        if (thought.isArchived) {
                          await thoughtDao.archiveThought(thought.id);
                        } else {
                          await thoughtDao.unarchiveThought(thought.id);
                        }
                      },
                    ),
                  ),
                );
              }
              return false;
            } else {
              return false;
            }
          },
          background: AppCard(
            alignment: Alignment.centerLeft,
            padding: const EdgeInsets.only(left: AppSpace.s20),
            nightDecoration: BoxDecoration(
              color: g.fill,
              borderRadius: AppGeometry.roundedr14,
              border: Border.all(color: g.line),
            ),
            child: Row(
              children: [
                Icon(
                  thought.isArchived
                      ? Icons.unarchive_outlined
                      : Icons.archive_outlined,
                  color: g.inkSecondary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  thought.isArchived ? 'Unarchive' : 'Archive',
                  style: AppTypeRoles.typeRole8.copyWith(color: g.inkSecondary),
                ),
              ],
            ),
          ),
          secondaryBackground: AppCard(
            alignment: Alignment.centerRight,
            padding: const EdgeInsets.only(right: AppSpace.s20),
            nightDecoration: BoxDecoration(
              color: g.coralSoft,
              borderRadius: AppGeometry.roundedr14,
              border: Border.all(color: g.coral.withValues(alpha: 0.3)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Delete',
                  style: AppTypeRoles.typeRole8.copyWith(color: g.coral),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.delete_outline_rounded,
                  color: g.coral,
                  size: 20,
                ),
              ],
            ),
          ),
          child: AppTapArea(
            onTap: isSelectionMode ? onToggleSelect : null,
            onLongPress: isSelectionMode ? onToggleSelect : onLongPress,
            borderRadius: AppGeometry.roundedr16,
            child: AnimatedContainer(
              key: ValueKey(
                  'thought_surface_${thought.id}_${widget.appearance.style.name}',
                ),
                duration: const Duration(milliseconds: 200),
                padding: EdgeInsets.all(
                  widget.compact
                      ? (widget.appearance.density == ThoughtCardDensity.compact
                            ? 12
                            : 18)
                      : AppSpace.s16,
                ),
                decoration: _wallDecoration(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (thought.mood == 'promise') ...[
                      Center(
                        child: Container(
                          key: ValueKey(
                            'promise_top_middle_wrapper_${thought.id}',
                          ),
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s10,
                            vertical: AppSpace.s4,
                          ),
                          decoration: BoxDecoration(
                            color: g.clay.withValues(alpha: 0.12),
                            borderRadius: AppGeometry.roundedr12,
                            border: Border.all(
                              color: g.clay.withValues(alpha: 0.28),
                              width: AppBorderScale.w1point0,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                isPrivatePromise
                                    ? (isPromiseLocked
                                        ? Icons.lock_rounded
                                        : Icons.lock_open_rounded)
                                    : Icons.handshake_rounded,
                                size: 12,
                                color: g.clay,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                isPrivatePromise
                                    ? (isPromiseLocked
                                        ? 'PRIVATE PROMISE'
                                        : 'UNLOCKED PROMISE')
                                    : 'PROMISE',
                                style: AscentTextStyles.homeCaption
                                    .copyWith(
                                      color: g.clay,
                                      fontWeight: FontWeight.w700,
                                      letterSpacing: 1.2,
                                    )
                                    .merge(AppTypeRoles.typeRole65),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                    // Date left; Promise and secondary menu remain in the top header.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (!isSelectionMode) ...[
                          Tooltip(
                            message: thought.isCompleted
                                ? 'Mark open'
                                : 'Mark done',
                            child: GestureDetector(
                              key: ValueKey('thought_left_done_${thought.id}'),
                              behavior: HitTestBehavior.opaque,
                              onTap: _toggleDone,
                              child: Padding(
                                padding: const EdgeInsets.only(right: 6),
                                child: Icon(
                                  thought.isCompleted
                                      ? Icons.check_circle_rounded
                                      : Icons.circle_outlined,
                                  size: 16,
                                  color: thought.isCompleted
                                      ? g.sage
                                      : g.inkMuted.withValues(alpha: 0.5),
                                ),
                              ),
                            ),
                          ),
                        ],
                        Expanded(
                          child: Text(
                            timeStr,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: AscentTextStyles.labelSmall
                                .copyWith(color: g.inkMuted)
                                .merge(AppTypeRoles.typeRole54),
                          ),
                        ),
                        if (!isSelectionMode) ...[
                          IconButton(
                            tooltip: 'Edit thought',
                            visualDensity: VisualDensity.compact,
                            icon: Icon(
                              Icons.edit_outlined,
                              size: 18,
                              color: g.ink,
                            ),
                            onPressed: () => DropThoughtSheet.show(
                              context,
                              existingThought: thought,
                            ),
                          ),
                        ],
                        if (!isSelectionMode)
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_horiz_rounded,
                              size: 18,
                              color: context.textMuted,
                            ),
                            color: context.isDark ? context.bgSurface : g.fill,
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onSelected: (action) async {
                              if (action == 'category') {
                                widget.onMoveToCategory?.call();
                              } else if (action == 'share') {
                                if (isPromiseLocked) {
                                  final security = ref.read(vaultSecurityServiceProvider);
                                  final unlocked = await security.authenticateBiometrics(
                                    reason: 'Unlock private commitment before sharing',
                                  );
                                  if (!unlocked) return;
                                  ref.read(unlockedPromiseIdsProvider.notifier).unlock(thought.id);
                                }
                                await shareThought(thought);
                              } else if (action == 'convert_task') {
                                await applyThoughtAction(
                                  context,
                                  ref.read(databaseProvider),
                                  [thought],
                                  'todo',
                                );
                              } else if (action == 'both') {
                                await applyThoughtAction(
                                  context,
                                  ref.read(databaseProvider),
                                  [thought],
                                  'both',
                                );
                              } else if (action == 'reminder') {
                                await applyThoughtAction(
                                  context,
                                  ref.read(databaseProvider),
                                  [thought],
                                  'reminder',
                                );
                              } else if (action == 'archive') {
                                HapticFeedback.lightImpact();
                                final dao = ref.read(thoughtDaoProvider);
                                final messenger = ScaffoldMessenger.of(context);
                                final id = thought.id;
                                final wasArchived = thought.isArchived;
                                if (wasArchived) {
                                  await dao.unarchiveThought(id);
                                } else {
                                  await dao.archiveThought(id);
                                }
                                if (messenger.mounted) {
                                  messenger.hideCurrentSnackBar();
                                  messenger.showSnackBar(
                                    SnackBar(
                                      persist: false,
                                      content: Text(
                                        wasArchived
                                            ? 'Thought restored'
                                            : 'Thought archived',
                                      ),
                                      action: SnackBarAction(
                                        label: 'Undo',
                                        onPressed: () {
                                          if (wasArchived) {
                                            dao.archiveThought(id);
                                          } else {
                                            dao.unarchiveThought(id);
                                          }
                                        },
                                      ),
                                    ),
                                  );
                                }
                              } else if (action == 'pin') {
                                HapticFeedback.lightImpact();
                                await ref
                                    .read(thoughtDaoProvider)
                                    .togglePin(thought.id);
                              } else if (action == 'copy') {
                                if (isPromiseLocked) {
                                  final security = ref.read(vaultSecurityServiceProvider);
                                  final unlocked = await security.authenticateBiometrics(
                                    reason: 'Unlock private commitment before copying',
                                  );
                                  if (!unlocked) return;
                                  ref.read(unlockedPromiseIdsProvider.notifier).unlock(thought.id);
                                }
                                HapticFeedback.lightImpact();
                                await Clipboard.setData(
                                  ClipboardData(text: thought.content),
                                );
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      persist: false,
                                      content: Text('Copied to clipboard!'),
                                    ),
                                  );
                                }
                              } else if (action == 'edit') {
                                if (isPromiseLocked) {
                                  final security = ref.read(vaultSecurityServiceProvider);
                                  final unlocked = await security.authenticateBiometrics(
                                    reason: 'Unlock private commitment before editing',
                                  );
                                  if (!unlocked) return;
                                  ref.read(unlockedPromiseIdsProvider.notifier).unlock(thought.id);
                                }
                                HapticFeedback.lightImpact();
                                if (!context.mounted) return;
                                DropThoughtSheet.show(
                                  context,
                                  existingThought: thought,
                                );
                              } else if (action == 'promises') {
                                context.push('/promises');
                              } else if (action == 'open_todo') {
                                context.push('/today');
                              } else if (action == 'track_challenge') {
                                context.push('/momentum', extra: thought);
                              } else if (action == 'delete') {
                                await _deleteWithUndo(context, ref);
                              } else if (action == 'priority') {
                                HapticFeedback.lightImpact();
                                final isHigh = thought.content.contains('[HIGH]');
                                final newContent = isHigh
                                    ? thought.content.replaceAll('[HIGH] ', '').replaceAll('[HIGH]', '').trim()
                                    : '[HIGH] ${thought.content}';
                                await (ref.read(databaseProvider).update(
                                  ref.read(databaseProvider).thoughtTable,
                                )..where((t) => t.id.equals(thought.id))).write(
                                  ThoughtTableCompanion(
                                    content: drift.Value(newContent),
                                  ),
                                );
                              }
                            },
                            itemBuilder: (_) => [
                              if (widget.onMoveToCategory != null)
                                const PopupMenuItem(
                                  value: 'category',
                                  child: Row(
                                    children: [
                                      Icon(Icons.folder_outlined, size: 16),
                                      SizedBox(width: 8),
                                      Text('Move to category'),
                                    ],
                                  ),
                                ),
                              const PopupMenuItem(
                                value: 'edit',
                                child: Text('Edit thought'),
                              ),
                              PopupMenuItem(
                                value: 'priority',
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.flag_outlined,
                                      size: 16,
                                      color: thought.content.contains('[HIGH]')
                                          ? g.coral
                                          : g.inkSecondary,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      thought.content.contains('[HIGH]')
                                          ? 'Remove priority'
                                          : 'Mark high priority',
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'copy',
                                child: Text('Copy text'),
                              ),
                              if (thought.mood != 'promise')
                                const PopupMenuItem(
                                  value: 'reminder',
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.notifications_active_outlined,
                                        size: 16,
                                      ),
                                      SizedBox(width: 8),
                                      Text('Set reminder'),
                                    ],
                                  ),
                                ),
                              if (thought.mood == 'promise')
                                const PopupMenuItem(
                                  value: 'promises',
                                  child: Row(
                                    children: [
                                      Icon(Icons.open_in_new_rounded, size: 16),
                                      SizedBox(width: 8),
                                      Text('View promises'),
                                    ],
                                  ),
                                ),
                              if (thought.mood == 'promise')
                                const PopupMenuItem(
                                  value: 'track_challenge',
                                  child: Row(
                                    children: [
                                      Icon(Icons.flag_outlined, size: 16),
                                      SizedBox(width: 8),
                                      Text('Track with Challenge'),
                                    ],
                                  ),
                                ),
                              if (thought.mood != 'promise')
                                const PopupMenuItem(
                                  value: 'convert_task',
                                  child: Row(
                                    children: [
                                      Icon(Icons.add_task_rounded, size: 16),
                                      SizedBox(width: 8),
                                      Text('Convert to Today Task'),
                                    ],
                                  ),
                                ),
                              PopupMenuItem(
                                value: 'archive',
                                child: Row(
                                  children: [
                                    Icon(
                                      thought.isArchived
                                          ? Icons.unarchive_outlined
                                          : Icons.archive_outlined,
                                      size: 16,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      thought.isArchived
                                          ? 'Unarchive'
                                          : 'Archive thought',
                                    ),
                                  ],
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'share',
                                child: Row(
                                  children: [
                                    Icon(Icons.share_rounded, size: 16),
                                    SizedBox(width: 8),
                                    Text('Share (WhatsApp & apps)'),
                                  ],
                                ),
                              ),
                              PopupMenuItem(
                                value: 'pin',
                                child: Text(
                                  thought.isPinned ? 'Unpin' : 'Pin to top',
                                ),
                              ),
                              const PopupMenuItem(
                                value: 'delete',
                                child: Text(
                                  'Delete thought',
                                  style: TextStyle(color: AppPalette.redAccent),
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),

                    if (thought.isCompleted ||
                        thought.isPinned ||
                        thought.isArchived ||
                        isHighPriority) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          if (isHighPriority)
                            AppTag(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.s5,
                                vertical: AppSpace.s2,
                              ),
                              nightDecoration: BoxDecoration(
                                color: g.coral.withValues(alpha: 0.14),
                                borderRadius: AppGeometry.roundedr6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.flag_rounded,
                                    size: 9,
                                    color: g.coral,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'HIGH',
                                    style: AscentTextStyles.labelSmall
                                        .copyWith(color: g.coral)
                                        .merge(AppTypeRoles.typeRole56),
                                  ),
                                ],
                              ),
                            ),
                          if (thought.isCompleted)
                            AppTag(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.s5,
                                vertical: AppSpace.s2,
                              ),
                              nightDecoration: BoxDecoration(
                                color: g.sage.withValues(alpha: 0.14),
                                borderRadius: AppGeometry.roundedr6,
                              ),
                              child: Text(
                                '✓ Done',
                                style: AppTypeRoles.typeRole55.copyWith(
                                  color: g.sage,
                                ),
                              ),
                            ),
                          if (thought.isPinned)
                            AppTag(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.s5,
                                vertical: AppSpace.s2,
                              ),
                              nightDecoration: BoxDecoration(
                                color: g.amber.withValues(alpha: 0.14),
                                borderRadius: AppGeometry.roundedr6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.push_pin_rounded,
                                    size: 9,
                                    color: g.amber,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'PINNED',
                                    style: AscentTextStyles.labelSmall
                                        .copyWith(color: g.amber)
                                        .merge(AppTypeRoles.typeRole56),
                                  ),
                                ],
                              ),
                            ),
                          if (thought.isArchived)
                            AppTag(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.s5,
                                vertical: AppSpace.s2,
                              ),
                              nightDecoration: BoxDecoration(
                                color: g.inkMuted.withValues(alpha: 0.10),
                                borderRadius: AppGeometry.roundedr6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.archive_outlined,
                                    size: 9,
                                    color: g.inkSecondary,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'ARCHIVED',
                                    style: AscentTextStyles.labelSmall
                                        .copyWith(color: g.inkSecondary)
                                        .merge(AppTypeRoles.typeRole56),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ],

                    if (widget.categoryLabel != null) ...[
                      Text(
                        '#${widget.categoryLabel}',
                        style: AscentTextStyles.labelSmall.copyWith(
                          color: g.inkSecondary,
                        ),
                      ),
                      const SizedBox(height: 4),
                    ],
                    if (isPromiseLocked) ...[
                      const SizedBox(height: 10),
                      InkWell(
                        onTap: () async {
                          final security = ref.read(vaultSecurityServiceProvider);
                          final unlocked = await security.authenticateBiometrics(
                            reason: 'Unlock private commitment',
                          );
                          if (unlocked) {
                            ref
                                .read(unlockedPromiseIdsProvider.notifier)
                                .unlock(thought.id);
                          }
                        },
                        borderRadius: AppGeometry.roundedr12,
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: g.fill.withValues(alpha: 0.6),
                            borderRadius: AppGeometry.roundedr12,
                            border: Border.all(color: g.line),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 16,
                                color: g.inkMuted,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Private commitment · Tap to unlock',
                                  style: TextStyle(
                                    color: g.inkMuted,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Optional prompt question banner: only show if distinct from content
                      if (thought.promptQuestion != null &&
                          thought.promptQuestion!.trim().isNotEmpty &&
                          thought.promptQuestion!.trim().toLowerCase() !=
                              thought.content.trim().toLowerCase()) ...[
                        const SizedBox(height: 10),
                        AppTag(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s10,
                            vertical: AppSpace.s6,
                          ),
                          nightDecoration: BoxDecoration(
                            color: moodColor.withValues(alpha: 0.08),
                            borderRadius: AppGeometry.roundedr8,
                            border: Border(
                              left: BorderSide(
                                color: moodColor.withValues(alpha: 0.5),
                                width: AppBorderScale.w2point5,
                              ),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.help_outline_rounded,
                                size: 13,
                                color: moodColor,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  thought.promptQuestion!,
                                  style: AscentTextStyles.bodySmall
                                      .copyWith(
                                        color: context.textMuted,
                                        fontStyle: FontStyle.italic,
                                        height: 1.3,
                                      )
                                      .merge(AppTypeRoles.typeRole27),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 10),

                      // Content
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onDoubleTap: isSelectionMode ? null : _toggleDone,
                        child: ThoughtExcerpt(
                          content: thought.content.startsWith('[HIGH] ')
                              ? thought.content.substring(7)
                              : thought.content,
                          maxLines: 5,
                          style: AppTypography.thoughtContent(
                            color: context.glass.ink,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
  }
}
