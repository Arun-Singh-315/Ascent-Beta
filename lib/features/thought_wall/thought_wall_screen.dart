import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import '../../core/services/note_draft_binding.dart';
import '../../core/providers/settings_provider.dart';
import '../../shared/widgets/thought_presentation.dart';
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
import '../../shared/widgets/ascent_scaffold.dart';
import '../../shared/widgets/empty_state.dart';
import '../../shared/widgets/undo_snackbar.dart';
import 'drop_thought_sheet.dart';
import 'thought_action_ui.dart';
import 'thought_quick_actions.dart';

/// Formats thought content cleanly for WhatsApp, messages, and external sharing.
String formatThoughtForShare(Thought thought) {
  final buffer = StringBuffer();
  if (thought.promptQuestion != null &&
      thought.promptQuestion!.trim().isNotEmpty) {
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
    if (t.promptQuestion != null && t.promptQuestion!.trim().isNotEmpty) {
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

/// Thought Wall / Mind Space Screen ("Me to Me")
/// An aesthetic spatial wall for unfiltered self-talk, sparks of inspiration,
/// daily wins, and letters to your future self.
class ThoughtWallScreen extends ConsumerStatefulWidget {
  const ThoughtWallScreen({super.key, this.initialThoughtId});
  final int? initialThoughtId;

  @override
  ConsumerState<ThoughtWallScreen> createState() => _ThoughtWallScreenState();
}

class _ThoughtWallScreenState extends ConsumerState<ThoughtWallScreen> {
  String _viewToggle = 'today'; // 'today', 'history'
  String _categoryFilter =
      'all'; // 'all', 'me_to_me', 'thought', 'idea', 'win', 'pinned'
  bool _isSelectionMode = false;
  bool _applyingSelection = false;
  int? _openedThoughtId;
  int? _lastSavedThoughtId;
  final Set<int> _selectedIds = <int>{};

  final Map<String, (String, IconData)> _filterMeta = const {
    'all': ('All Thoughts', Icons.bubble_chart_rounded),
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

  Future<void> _openHomeThought() async {
    final id = widget.initialThoughtId;
    if (id == null) return;
    final thought = await ref.read(thoughtDaoProvider).getThoughtById(id);
    if (!mounted || thought == null) return;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    setState(() {
      _openedThoughtId = id;
      _viewToggle = thought.isArchived || thought.createdAt.isBefore(today)
          ? 'history'
          : 'today';
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
      final savedId = await ref
          .read(thoughtDaoProvider)
          .insertThought(
            ThoughtTableCompanion.insert(
              content: text,
              mood: const drift.Value(mood),
              colorHex: drift.Value(colorHex),
            ),
          );
      if (_inputController.text.trim() == text) _inputController.clear();

      if (!mounted) return;
      setState(() => _lastSavedThoughtId = savedId);
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

    return AppCard(
      key: const ValueKey('thought_selection_actions'),
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(
        AppSpace.s16,
        AppSpace.s6,
        AppSpace.s16,
        AppSpace.s10,
      ),
      nightDecoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: g.line)),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 6,
        children: [
          for (final item in const [
            ('todo', 'Todo', Icons.checklist_rounded),
            ('reminder', 'Reminder', Icons.notifications_none_rounded),
            ('both', 'Both', Icons.add_task_rounded),
            ('merge', 'Merge', Icons.merge_rounded),
          ])
            AppPill.action(
              avatar: Icon(item.$3, size: 17),
              label: Text(item.$2),
              onPressed:
                  _applyingSelection ||
                      selected.isEmpty ||
                      item.$1 == 'merge' && selected.length < 2
                  ? null
                  : () => act(item.$1),
            ),
          AppPill.action(
            avatar: const Icon(Icons.share_outlined, size: 17),
            label: const Text('Share'),
            onPressed: _applyingSelection || selected.isEmpty
                ? null
                : () => shareMultipleThoughts(selected),
          ),
        ],
      ),
    );
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
        child: MessageComposer(
          controller: _inputController,
          focusNode: _focusNode,
          hint: 'Write a thought...',
          busy: _isSubmitting,
          onSend: (_) => _submitThought(),
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
    return Expanded(
      child: AppGestureTap(
        onTap: () {
          HapticFeedback.selectionClick();
          setState(() {
            _viewToggle = key;
            _openedThoughtId = null;
            _selectedIds.clear();
            _isSelectionMode = false;
          });
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(vertical: AppSpace.s8),
          alignment: Alignment.center,
          decoration: AppPill.decoration(
            context,
            selected: isSelected,
            night: BoxDecoration(
              color: isSelected ? g.clay : AppPalette.transparent,
              borderRadius: AppGeometry.roundedr10,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 13,
                color: isSelected ? AppPalette.white : g.inkMuted,
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppStateTypography.stateType12(
                    state0: isSelected,
                    color: isSelected ? AppPalette.white : g.inkMuted,
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
  Widget build(BuildContext context) {
    final activeAsync = ref.watch(allThoughtsStreamProvider);
    final archivedAsync = ref.watch(archivedThoughtsStreamProvider);

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
            ? 'Select notes for sharing, Todo or reminders'
            : 'Mind space · Notes to myself',
        glow2: g.glow2,
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
                    final now = DateTime.now();
                    final todayStart = DateTime(now.year, now.month, now.day);
                    final filtered = allThoughts.where((t) {
                      if (_categoryFilter == 'pinned' && !t.isPinned) {
                        return false;
                      }
                      if (_categoryFilter == 'archived') return t.isArchived;
                      if (_categoryFilter != 'all' &&
                          _categoryFilter != 'pinned' &&
                          t.mood != _categoryFilter) {
                        return false;
                      }
                      if (_viewToggle == 'today') {
                        return !t.isArchived &&
                            t.createdAt.isAfter(
                              todayStart.subtract(const Duration(seconds: 1)),
                            );
                      } else {
                        return t.isArchived || t.createdAt.isBefore(todayStart);
                      }
                    }).toList();

                    final isAllSelected =
                        filtered.isNotEmpty &&
                        _selectedIds.length >= filtered.length;

                    return IconButton(
                      icon: Icon(
                        isAllSelected
                            ? Icons.deselect_rounded
                            : Icons.select_all_rounded,
                        color: g.clay,
                      ),
                      tooltip: isAllSelected ? 'Deselect All' : 'Select All',
                      onPressed: () => _toggleSelectAll(filtered),
                    );
                  },
                  orElse: () => const SizedBox.shrink(),
                ),
                IconButton(
                  icon: Icon(Icons.share_rounded, color: g.clay),
                  tooltip: 'Share to WhatsApp',
                  onPressed: () {
                    final activeList = activeAsync.value ?? [];
                    final archivedList = archivedAsync.value ?? [];
                    final allThoughts = [...activeList, ...archivedList];
                    final selectedList = allThoughts
                        .where((t) => _selectedIds.contains(t.id))
                        .toList();
                    shareMultipleThoughts(selectedList);
                  },
                ),
                IconButton(
                  icon: Icon(Icons.close_rounded, color: g.inkMuted),
                  tooltip: 'Exit Selection',
                  onPressed: _exitSelectionMode,
                ),
              ]
            : [
                TextButton.icon(
                  icon: const Icon(Icons.handshake_rounded, size: 17),
                  label: const Text('Add Promise'),
                  onPressed: () =>
                      DropThoughtSheet.show(context, initialMood: 'promise'),
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
                color: context.bgSurface,
                borderRadius: AppGeometry.roundedr14,
                border: Border.all(
                  color: context.divider.withValues(alpha: 0.8),
                ),
              ),
              child: Row(
                children: [
                  _buildViewSegment('today', "Today", Icons.today_rounded, g),
                  _buildViewSegment(
                    'history',
                    "History & Archive",
                    Icons.history_rounded,
                    g,
                  ),
                ],
              ),
            ),
            if (_isSelectionMode)
              _buildSelectionActions(context, g, [
                ...(activeAsync.value ?? []),
                ...(archivedAsync.value ?? []),
              ]),
            const SizedBox(height: 6),

            // Sub-bar: Category Selector & Title that fits directly on screen (NO horizontal swipe)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s18,
                vertical: AppSpace.s2,
              ),
              child: Row(
                children: [
                  Text(
                    _viewToggle == 'today'
                        ? 'TODAY\'S REFLECTIONS'
                        : 'PAST & ARCHIVED',
                    style: AscentTextStyles.labelSmall
                        .copyWith(color: context.textMuted, letterSpacing: 1.0)
                        .merge(AppTypeRoles.typeRole2),
                  ),
                  const Spacer(),
                  PopupMenuButton<String>(
                    tooltip: 'Category filter',
                    initialValue: _categoryFilter,
                    onSelected: (val) {
                      HapticFeedback.lightImpact();
                      setState(() {
                        _categoryFilter = val;
                        _openedThoughtId = null;
                        _selectedIds.clear();
                        _isSelectionMode = false;
                      });
                    },
                    child: AppTag(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpace.s9,
                        vertical: AppSpace.s4,
                      ),
                      nightDecoration: BoxDecoration(
                        color: context.bgSurface,
                        borderRadius: AppGeometry.roundedr10,
                        border: Border.all(color: context.divider),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _filterMeta[_categoryFilter]?.$2 ??
                                Icons.filter_alt_outlined,
                            size: 13,
                            color: _categoryFilter != 'all'
                                ? g.clay
                                : context.textMuted,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            _categoryFilter == 'all'
                                ? 'All notes'
                                : (_filterMeta[_categoryFilter]?.$1 ??
                                      'Filter'),
                            style: AscentTextStyles.captionMedium
                                .copyWith(
                                  color: _categoryFilter != 'all'
                                      ? g.clay
                                      : context.textPrimary,
                                )
                                .merge(AppTypeRoles.typeRole8),
                          ),
                          const SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            size: 14,
                            color: context.textMuted,
                          ),
                        ],
                      ),
                    ),
                    itemBuilder: (ctx) => [
                      const PopupMenuItem(
                        value: 'all',
                        child: Text('All notes'),
                      ),
                      const PopupMenuItem(
                        value: 'promise',
                        child: Text('Promises'),
                      ),
                      const PopupMenuItem(
                        value: 'pinned',
                        child: Text('Pinned Only'),
                      ),
                      const PopupMenuItem(
                        value: 'archived',
                        child: Text('Archived Only'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Main Wall Content
            Expanded(
              child: activeAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (err, _) =>
                    Center(child: Text('Error loading wall: $err')),
                data: (activeList) {
                  final archivedList = archivedAsync.value ?? [];
                  final allThoughts = [...activeList, ...archivedList];
                  final now = DateTime.now();
                  final todayStart = DateTime(now.year, now.month, now.day);

                  final filtered = allThoughts.where((t) {
                    if (_categoryFilter == 'pinned' && !t.isPinned) {
                      return false;
                    }
                    if (_categoryFilter == 'archived') return t.isArchived;
                    if (_categoryFilter != 'all' &&
                        _categoryFilter != 'pinned' &&
                        t.mood != _categoryFilter) {
                      return false;
                    }

                    if (_viewToggle == 'today') {
                      return !t.isArchived &&
                          t.createdAt.isAfter(
                            todayStart.subtract(const Duration(seconds: 1)),
                          );
                    } else {
                      return t.isArchived || t.createdAt.isBefore(todayStart);
                    }
                  }).toList();

                  if (_openedThoughtId != null) {
                    final index = filtered.indexWhere(
                      (t) => t.id == _openedThoughtId,
                    );
                    if (index > 0) filtered.insert(0, filtered.removeAt(index));
                  }

                  if (filtered.isEmpty) {
                    return EmptyState(
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
                        thought: thought,
                        index: index,
                        showQuickActions: thought.id == _lastSavedThoughtId,
                        isSelected: _selectedIds.contains(thought.id),
                        isSelectionMode: _isSelectionMode,
                        onToggleSelect: () => _toggleSelection(thought.id),
                        onLongPress: () => _enterSelectionMode(thought.id),
                      );
                      final showHeading =
                          _categoryFilter != 'pinned' &&
                          !thought.isArchived &&
                          (index == 0 ||
                              filtered[index - 1].isPinned != thought.isPinned);
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
                              child: Text(
                                thought.isPinned ? 'Pinned' : 'Recent',
                                style: AscentTextStyles.labelMedium.copyWith(
                                  color: g.inkMuted,
                                ),
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
            // Selection actions are visible below the tabs; compose when not selecting.
            _isSelectionMode
                ? const SizedBox.shrink()
                : _buildWhatsAppComposer(context, g),
          ],
        ),
      ),
    );
  }
}

class ThoughtCardBubble extends ConsumerWidget {
  final Thought thought;
  final int index;
  final bool isSelected;
  final bool showQuickActions;
  final bool isSelectionMode;
  final VoidCallback? onToggleSelect;
  final VoidCallback? onLongPress;

  const ThoughtCardBubble({
    super.key,
    required this.thought,
    required this.index,
    this.isSelected = false,
    this.showQuickActions = false,
    this.isSelectionMode = false,
    this.onToggleSelect,
    this.onLongPress,
  });

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final moodColor = _moodColor(thought.mood);
    final timeStr = DateFormat('MMM d • h:mm a').format(thought.createdAt);
    final g = context.glass;

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
          bottom: AppSpace.s14,
          left: (index % AppSpace.s2 == AppSpace.s1)
              ? AppSpace.s38point0
              : AppSpace.s4point0,
          right: (index % AppSpace.s2 == AppSpace.s0)
              ? AppSpace.s38point0
              : AppSpace.s4point0,
        ),
        child: Dismissible(
          key: ValueKey('thought_${thought.id}'),
          direction: isSelectionMode
              ? DismissDirection.none
              : DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            final thoughtDao = ref.read(thoughtDaoProvider);
            if (direction == DismissDirection.startToEnd) {
              // Archive / Unarchive
              HapticFeedback.mediumImpact();
              if (thought.isArchived) {
                await thoughtDao.unarchiveThought(thought.id);
              } else {
                await thoughtDao.archiveThought(thought.id);
              }
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
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
                      textColor: context.accentPrimary,
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
              return true;
            } else {
              // Delete
              HapticFeedback.mediumImpact();
              final backup = thought;
              await thoughtDao.deleteThought(thought.id);
              if (context.mounted) {
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    persist: false,
                    content: const Text('Thought removed'),
                    duration: const Duration(seconds: 3),
                    behavior: SnackBarBehavior.floating,
                    action: SnackBarAction(
                      label: 'UNDO',
                      textColor: context.accentPrimary,
                      onPressed: () async {
                        await thoughtDao.restoreDeletedThought(backup);
                      },
                    ),
                  ),
                );
              }
              return true;
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
              color: AppPalette.redAccent.withValues(alpha: 0.2),
              borderRadius: AppGeometry.roundedr14,
              border: Border.all(
                color: AppPalette.redAccent.withValues(alpha: 0.4),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text(
                  'Delete',
                  style: AppTypeRoles.typeRole8.copyWith(
                    color: AppPalette.redAccent,
                  ),
                ),
                SizedBox(width: 8),
                Icon(
                  Icons.delete_outline_rounded,
                  color: AppPalette.redAccent,
                  size: 20,
                ),
              ],
            ),
          ),
          child: AppTapArea(
            onTap: isSelectionMode ? onToggleSelect : null,
            onLongPress: isSelectionMode ? onToggleSelect : onLongPress,
            borderRadius: AppGeometry.roundedr16,
            child: GestureDetector(
              onDoubleTap: isSelectionMode
                  ? null
                  : thought.mood == 'promise'
                  ? null
                  : () async {
                      HapticFeedback.mediumImpact();
                      await ref
                          .read(thoughtDaoProvider)
                          .toggleCompleted(thought.id);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).hideCurrentSnackBar();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            persist: false,
                            content: Text(
                              thought.isCompleted
                                  ? 'Thought marked active'
                                  : 'Thought marked done ✓',
                            ),
                            duration: const Duration(seconds: 2),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      }
                    },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.all(AppSpace.s16),
                decoration: AppCard.decoration(
                  context,
                  selected: isSelected,
                  night: BoxDecoration(
                    color: isSelected
                        ? g.clay.withValues(alpha: context.isDark ? .22 : .12)
                        : context.isDark
                        ? g.fill
                        : const Color(0x1AFFFFFF),
                    borderRadius: BorderRadius.only(
                      topLeft: AppGeometry.radiusr18,
                      topRight: AppGeometry.radiusr18,
                      bottomLeft: AppGeometry.bubbleTail(index.isEven),
                      bottomRight: AppGeometry.bubbleTail(index.isOdd),
                    ),
                    border: isSelected
                        ? Border.all(
                            color: g.clay,
                            width: AppBorderScale.w1point8,
                          )
                        : Border.all(
                            color: context.isDark
                                ? g.inkMuted.withValues(alpha: .4)
                                : const Color(
                                    0xFF73727B,
                                  ).withValues(alpha: .18),
                            width: AppBorderScale.w1point2,
                          ),
                    boxShadow: context.isDark
                        ? [
                            BoxShadow(
                              color: AppPalette.black.withValues(
                                alpha: context.isDark ? 0.30 : 0.06,
                              ),
                              blurRadius: 10,
                              offset: const Offset(0, 3),
                            ),
                          ]
                        : const [],
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Date left; Promise and secondary menu remain in the top header.
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        if (isSelectionMode) ...[
                          Icon(
                            isSelected
                                ? Icons.check_circle_rounded
                                : Icons.radio_button_unchecked_rounded,
                            size: 18,
                            color: isSelected ? g.clay : g.inkMuted,
                          ),
                          const SizedBox(width: 6),
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
                        if (thought.mood == 'promise')
                          AppTag(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.s7,
                              vertical: AppSpace.s3,
                            ),
                            nightDecoration: BoxDecoration(
                              color: g.clay.withValues(alpha: 0.14),
                              borderRadius: AppGeometry.roundedr7,
                            ),
                            child: Text(
                              'Promise',
                              style: AscentTextStyles.labelSmall
                                  .copyWith(color: g.clay)
                                  .merge(AppTypeRoles.typeRole18),
                            ),
                          ),
                        if (thought.isArchived) ...[
                          IconButton(
                            icon: Icon(
                              Icons.unarchive_outlined,
                              size: 16,
                              color: g.inkSecondary,
                            ),
                            tooltip: 'Unarchive thought',
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(
                              minWidth: 48,
                              minHeight: 48,
                            ),
                            onPressed: () async {
                              HapticFeedback.lightImpact();
                              await ref
                                  .read(thoughtDaoProvider)
                                  .unarchiveThought(thought.id);
                              if (context.mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).hideCurrentSnackBar();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    persist: false,
                                    content: Text('Thought restored to wall'),
                                    duration: Duration(seconds: 2),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
                              }
                            },
                          ),
                          const SizedBox(width: 2),
                        ],
                        if (!isSelectionMode && !thought.isArchived)
                          IconButton(
                            tooltip: thought.isPinned
                                ? 'Unpin thought'
                                : 'Pin thought',
                            icon: Icon(
                              thought.isPinned
                                  ? Icons.push_pin_rounded
                                  : Icons.push_pin_outlined,
                              size: 18,
                              color: thought.isPinned ? g.clay : g.inkMuted,
                            ),
                            onPressed: () async {
                              HapticFeedback.selectionClick();
                              try {
                                await ref
                                    .read(thoughtDaoProvider)
                                    .togglePin(thought.id);
                              } catch (_) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Could not change the pin. Try again.',
                                      ),
                                    ),
                                  );
                                }
                              }
                            },
                          ),
                        PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_horiz_rounded,
                            size: 18,
                            color: context.textMuted,
                          ),
                          color: context.bgSurface,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 48,
                            minHeight: 48,
                          ),
                          onSelected: (action) async {
                            if (action == 'share') {
                              await shareThought(thought);
                            } else if (action == 'toggle_done') {
                              HapticFeedback.lightImpact();
                              await ref
                                  .read(thoughtDaoProvider)
                                  .toggleCompleted(thought.id);
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
                              if (thought.isArchived) {
                                await dao.unarchiveThought(thought.id);
                              } else {
                                await dao.archiveThought(thought.id);
                              }
                              if (context.mounted) {
                                showUndoSnackbar(
                                  context,
                                  message: thought.isArchived
                                      ? 'Thought restored'
                                      : 'Thought archived',
                                  onUndo: () {
                                    if (thought.isArchived) {
                                      dao.archiveThought(thought.id);
                                    } else {
                                      dao.unarchiveThought(thought.id);
                                    }
                                  },
                                );
                              }
                            } else if (action == 'pin') {
                              HapticFeedback.lightImpact();
                              await ref
                                  .read(thoughtDaoProvider)
                                  .togglePin(thought.id);
                            } else if (action == 'copy') {
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
                              HapticFeedback.lightImpact();
                              DropThoughtSheet.show(
                                context,
                                existingThought: thought,
                              );
                            } else if (action == 'open_todo') {
                              context.push('/today');
                            } else if (action == 'track_challenge') {
                              context.push('/momentum', extra: thought);
                            } else if (action == 'delete') {
                              HapticFeedback.mediumImpact();
                              final dao = ref.read(thoughtDaoProvider);
                              await dao.deleteThought(thought.id);
                              if (context.mounted) {
                                showUndoSnackbar(
                                  context,
                                  message: 'Thought removed',
                                  onUndo: () => dao.insertThought(
                                    thought.toCompanion(true),
                                  ),
                                );
                              }
                            }
                          },
                          itemBuilder: (_) => [
                            const PopupMenuItem(
                              value: 'both',
                              child: Text('Todo + Reminder'),
                            ),
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
                            if (thought.mood != 'promise')
                              PopupMenuItem(
                                value: 'toggle_done',
                                child: Row(
                                  children: [
                                    Icon(
                                      thought.isCompleted
                                          ? Icons.check_circle_outline_rounded
                                          : Icons.check_circle_rounded,
                                      size: 16,
                                    ),
                                    SizedBox(width: 8),
                                    Text(
                                      thought.isCompleted
                                          ? 'Mark as undone'
                                          : 'Mark as done',
                                    ),
                                  ],
                                ),
                              )
                            else
                              const PopupMenuItem(
                                value: 'open_todo',
                                child: Row(
                                  children: [
                                    Icon(Icons.open_in_new_rounded, size: 16),
                                    SizedBox(width: 8),
                                    Text('View linked Todo'),
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

                    // Status badges row (if completed, pinned, or archived)
                    if (thought.isCompleted ||
                        thought.isPinned ||
                        thought.isArchived) ...[
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 5,
                        runSpacing: 4,
                        children: [
                          if (thought.isCompleted)
                            AppTag(
                              padding: const EdgeInsets.symmetric(
                                horizontal: AppSpace.s5,
                                vertical: AppSpace.s2,
                              ),
                              nightDecoration: BoxDecoration(
                                color: context.accentPrimary.withValues(
                                  alpha: 0.14,
                                ),
                                borderRadius: AppGeometry.roundedr6,
                              ),
                              child: Text(
                                '✓ Done',
                                style: AppTypeRoles.typeRole55.copyWith(
                                  color: context.accentPrimary,
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
                                color: context.accentPrimary.withValues(
                                  alpha: 0.12,
                                ),
                                borderRadius: AppGeometry.roundedr6,
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.push_pin_rounded,
                                    size: 9,
                                    color: context.accentPrimary,
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    'PINNED',
                                    style: AscentTextStyles.labelSmall
                                        .copyWith(color: context.accentPrimary)
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

                    Padding(
                      key: ValueKey('thought_header_divider_${thought.id}'),
                      padding: const EdgeInsets.symmetric(
                        vertical: AppSpace.s10,
                      ),
                      child: AppSeparator(
                        night: Row(
                          children: [
                            Expanded(
                              child: Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      AppPalette.transparent,
                                      g.line,
                                      g.clay.withValues(alpha: .35),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            Container(
                              width: 4,
                              height: 4,
                              margin: const EdgeInsets.symmetric(
                                horizontal: AppSpace.s6,
                              ),
                              decoration: BoxDecoration(
                                color: g.clay.withValues(alpha: .55),
                                shape: BoxShape.circle,
                              ),
                            ),
                            Expanded(
                              child: Container(
                                height: 1,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      g.clay.withValues(alpha: .35),
                                      g.line,
                                      AppPalette.transparent,
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    // Optional prompt question banner
                    if (thought.promptQuestion != null) ...[
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
                    Text(
                      quotedThought(thought.content),
                      style: AppTypography.plusJakartaSans14W60071(
                        color: thought.isCompleted
                            ? (context.isDark
                                  ? context.textMuted
                                  : const Color(0xFF73727B))
                            : (context.isDark
                                  ? context.textPrimary
                                  : const Color(0xFF242323)),
                        decoration: thought.isCompleted
                            ? TextDecoration.lineThrough
                            : null,
                      ),
                    ),
                    if (showQuickActions &&
                        !isSelectionMode &&
                        !thought.isArchived &&
                        !thought.isCompleted)
                      ThoughtQuickActions(
                        key: ValueKey('thought_quick_${thought.id}'),
                        thought: thought,
                        db: ref.read(databaseProvider),
                      ),
                    if (!isSelectionMode)
                      Align(
                        alignment: Alignment.centerRight,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (!isSelectionMode)
                              IconButton(
                                tooltip: 'Edit thought',
                                icon: Icon(
                                  Icons.edit_outlined,
                                  size: 17,
                                  color: g.inkMuted,
                                ),
                                onPressed: () => DropThoughtSheet.show(
                                  context,
                                  existingThought: thought,
                                ),
                              ),
                            if (!isSelectionMode)
                              IconButton(
                                tooltip: 'Copy text',
                                icon: Icon(
                                  Icons.copy_outlined,
                                  size: 17,
                                  color: g.inkMuted,
                                ),
                                onPressed: () => Clipboard.setData(
                                  ClipboardData(text: thought.content),
                                ),
                              ),
                            // Right actions (quick unarchive & popup menu)
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
