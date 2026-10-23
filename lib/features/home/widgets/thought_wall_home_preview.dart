import '../../../app/theme/thought_theme.dart';
import '../../plans/widgets/plan_collection_editor.dart';
import '../../../shared/widgets/note_list_button.dart';
import 'dart:async';
import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/color_tokens.dart';
import '../../../app/theme/frozen_palette.dart';
import '../../../app/theme/merlot_palette.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/note_draft_binding.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/thought_excerpt.dart';
import '../../thought_wall/thought_action_ui.dart';
import '../../thought_wall/thought_wall_preferences.dart';
import 'home_schedule_sheet.dart';
import 'dart:convert';

/// Level 3 · Supporting: Mind Space
/// Redesigned according to Ascent Home Redesign spec:
/// - Prominent capture field and a permanent doorway to Thought Wall.
/// - Glass thought bubble for latest reflection.
/// - 44dp hit targets.
class ThoughtWallHomePreview extends ConsumerStatefulWidget {
  const ThoughtWallHomePreview({
    super.key,
    this.showComposer = true,
    this.previewLimit = 4,
  });
  final bool showComposer;
  final int previewLimit;

  @override
  ConsumerState<ThoughtWallHomePreview> createState() =>
      _ThoughtWallHomePreviewState();
}

class _ThoughtWallHomePreviewState
    extends ConsumerState<ThoughtWallHomePreview> {
  final _controller = TextEditingController();
  bool _saving = false;
  bool _expanded = false;

  final _focusNode = FocusNode();
  NoteDraftBinding? _draft;
  int? _transientThoughtId;
  Timer? _transientTimer;

  void _activateTransient(int id) {
    _transientTimer?.cancel();
    setState(() => _transientThoughtId = id);
    final accessible =
        MediaQuery.maybeOf(context)?.accessibleNavigation ?? false;
    if (!accessible) {
      _transientTimer = Timer(const Duration(seconds: 7), () {
        if (mounted && _transientThoughtId == id) {
          setState(() => _transientThoughtId = null);
        }
      });
    }
  }

  void _dismissTransient() {
    _transientTimer?.cancel();
    if (mounted && _transientThoughtId != null) {
      setState(() => _transientThoughtId = null);
    }
  }

  @override
  void dispose() {
    _transientTimer?.cancel();
    _draft?.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    try {
      if (widget.showComposer) {
        _draft = NoteDraftBinding(
          _controller,
          ref.read(sharedPreferencesProvider),
          'home',
        );
      }
    } catch (_) {
      // An optional preference provider may be absent in isolated widget tests.
    }
    _focusNode.addListener(_refresh);
    _controller.addListener(_refresh);
  }

  final _fieldKey = GlobalKey();

  void _refresh() {
    NoteListButton.revealCaret(_fieldKey, _controller);
    if (mounted) setState(() {});
  }

  Future<void> _send() async {
    final content = _controller.text.trim();
    if (content.isEmpty || _saving) return;
    setState(() => _saving = true);
    try {
      final id = await ref
          .read(thoughtDaoProvider)
          .insertThought(
            ThoughtTableCompanion.insert(
              content: content,
              mood: const drift.Value('thought'),
            ),
          );
      if (mounted) {
        setState(() => _saving = false);
        if (_controller.text.trim() == content) _controller.clear();
        FocusScope.of(context).unfocus();
        // Do NOT show plan automatically.
        // Instead, show transient actions (Plan, Todo, Reminder) for a few seconds.
        _activateTransient(id);
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save. Your note is still here.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _plan(Thought thought) async {
    await showHomeSchedule(context, thought);
    if (mounted) setState(() {});
  }

  Future<void> _resume() async {
    final draft = _pendingDraft;
    if (draft == null) return;
    final sourceId = draft['sourceId'] as int?;
    final source = sourceId == null
        ? null
        : await ref.read(thoughtDaoProvider).getThoughtById(sourceId);
    if (!mounted) return;
    await showPlanCollectionEditor(
      context,
      source: source,
      draftKey: draft['key'] as String,
    );
    if (mounted) setState(() {});
  }

  Map<String, dynamic>? get _pendingDraft {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final drafts = <Map<String, dynamic>>[];
      for (final key in prefs.getKeys().where(
        (k) => k.startsWith('planning_draft_v1:'),
      )) {
        try {
          final data = Map<String, dynamic>.from(
            jsonDecode(prefs.getString(key)!) as Map,
          );
          data['key'] = key;
          drafts.add(data);
        } catch (_) {
          /* Ignore an unreadable draft; preserve the original note. */
        }
      }
      drafts.sort(
        (a, b) => (b['updatedAt'] as int? ?? 0).compareTo(
          a['updatedAt'] as int? ?? 0,
        ),
      );
      return drafts.firstOrNull;
    } catch (_) {
      return null;
    }
  }

  Future<void> _keepThought() async {
    try {
      final key = _pendingDraft?['key'] as String?;
      if (key != null) await ref.read(sharedPreferencesProvider).remove(key);
      if (mounted) {
        setState(() {});
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Kept as a thought. No reminder was added.'),
          ),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not close this draft. Please retry.'),
          ),
        );
      }
    }
  }

  List<Thought> _preview(List<Thought> thoughts) {
    if (_expanded) {
      return thoughts.take(widget.previewLimit.clamp(1, 4)).toList();
    }
    final pinned = thoughts.where((t) => t.isPinned).firstOrNull;
    if (pinned == null) {
      return thoughts.take(2).toList();
    }
    final others = thoughts.where((t) => t.id != pinned.id).take(1).toList();
    return [pinned, ...others];
  }

  Widget _draftActions(Map<String, dynamic> draft, {bool showTitle = true}) {
    final g = context.glass;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.edit_calendar_outlined, color: g.inkSecondary, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Plan draft',
                style: Theme.of(
                  context,
                ).textTheme.titleSmall?.copyWith(color: g.ink),
              ),
            ),
          ],
        ),
        if (showTitle) ...[
          const SizedBox(height: 8),
          Text(
            (draft['title'] as String?)?.trim().isNotEmpty == true
                ? draft['title'] as String
                : 'Your saved thought',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: g.ink),
          ),
        ],
        const SizedBox(height: 4),
        Text(
          showTitle
              ? 'Draft saved. Review and save to activate its schedule.'
              : 'No reminder set yet.',
          style: Theme.of(
            context,
          ).textTheme.bodySmall?.copyWith(color: g.inkMuted),
        ),
        Wrap(
          spacing: 4,
          children: [
            TextButton.icon(
              onPressed: _saving ? null : _resume,
              icon: const Icon(Icons.arrow_forward_rounded, size: 18),
              label: const Text('Review & schedule'),
            ),
            TextButton(
              onPressed: _saving ? null : _keepThought,
              child: const Text('Discard plan draft'),
            ),
          ],
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: ThoughtTheme.from(Theme.of(context)),
    child: Builder(builder: _buildThoughtSpace),
  );

  Widget _buildThoughtSpace(BuildContext context) {
    final g = context.glass;
    final appearance = ref.watch(thoughtWallAppearanceProvider);
    final recentThoughtsAsync = ref.watch(recentThoughtsStreamProvider);
    final pendingDraft = _pendingDraft;
    final draftInPreview =
        pendingDraft != null &&
        _preview(
          recentThoughtsAsync.value ?? [],
        ).any((t) => t.id == pendingDraft['thoughtId']);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showComposer) ...[
          if (_focusNode.hasFocus && _controller.text.isEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: InkWell(
                onTap: () => InlineListAddButton.showHelperDialog(context),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: g.clay.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: g.clay.withValues(alpha: 0.25)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        size: 14,
                        color: g.clay,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Tip: Tap + or type → for plans, • for to-do',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: g.clay,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(Icons.help_outline_rounded, size: 12, color: g.clay),
                    ],
                  ),
                ),
              ),
            ),
          AppCard(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            nightDecoration: BoxDecoration(
              color: context.isDark
                  ? g.fill
                  : (g.merlot
                      ? MerlotPalette.surface
                      : (g.frozen
                          ? const Color(0xFFFBFDFF)
                          : const Color(0xFFFFFDFB))),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: _focusNode.hasFocus
                    ? g.clay
                    : (context.isDark
                        ? g.edge
                        : (g.merlot
                            ? MerlotPalette.line
                            : (g.frozen
                                ? FrozenPalette.line
                                : const Color(0xFFD9C5BB)))),
                width: _focusNode.hasFocus ? 1.5 : 1.2,
              ),
            ),
            child: Row(
              children: [
                InlineListAddButton(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !_saving,
                ),
                const SizedBox(width: 4),
                Expanded(
                  child: TextField(
                    key: _fieldKey,
                    controller: _controller,
                    focusNode: _focusNode,
                    onTap: () {
                      try {
                        InlineListAddButton.maybeShowFirstTimeDiscovery(
                           context,
                          prefs: ref.read(sharedPreferencesProvider),
                        );
                      } catch (_) {}
                    },
                    cursorColor: g.clay,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTypography.plusJakartaSans14W60080(color: g.ink),
                    decoration: InputDecoration(
                      hintText: "Capture a thought…",
                      hintStyle: TextStyle(
                        color: g.inkMuted,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                      filled: false,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      disabledBorder: InputBorder.none,
                      errorBorder: InputBorder.none,
                      focusedErrorBorder: InputBorder.none,
                      border: InputBorder.none,
                    ),
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Send capture',
                  style: IconButton.styleFrom(
                    backgroundColor: g.clay,
                    disabledBackgroundColor: g.clay.withValues(alpha: 0.3),
                    foregroundColor: Theme.of(context).colorScheme.onPrimary,
                    disabledForegroundColor: Colors.white.withValues(
                      alpha: 0.4,
                    ),
                    minimumSize: const Size(44, 44),
                  ),
                  onPressed: _saving || _controller.text.trim().isEmpty
                      ? null
                      : _send,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(
                          Icons.arrow_upward_rounded,
                          color: Colors.white,
                        ),
                ),
              ],
            ),
          ),
        ],

        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: () => context.push('/thought-wall'),
            icon: const Icon(Icons.bubble_chart_outlined, size: 18),
            label: const Text('Open Thought Wall'),
          ),
        ),

        // ── THOUGHTS MESSAGE PREVIEW (ENCLOSED CARD) ──────────────────
        recentThoughtsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => TextButton(
            onPressed: () => ref.invalidate(recentThoughtsStreamProvider),
            child: const Text('Could not load thoughts. Retry'),
          ),
          data: (thoughts) {
            if (thoughts.isEmpty) {
              if (pendingDraft != null) {
                return Padding(
                  padding: const EdgeInsets.only(top: 8, bottom: 12),
                  child: AppCard(
                    padding: const EdgeInsets.all(14),
                    nightDecoration: BoxDecoration(
                      color: g.fill,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: g.edge),
                    ),
                    child: _draftActions(pendingDraft),
                  ),
                );
              }
              return const SizedBox.shrink();
            }

            final previewThoughts = _preview(thoughts);
            final isDark = context.isDark;

            final cardFill = isDark
                ? null
                : (g.merlot
                    ? MerlotPalette.surface
                    : (g.frozen
                        ? const Color(0xFFF8FAFD)
                        : const Color(0xFFFFFDFB)));

            final cardBorder = isDark
                ? null
                : Border.all(
                    color: g.merlot
                        ? MerlotPalette.line
                        : (g.frozen
                            ? FrozenPalette.line
                            : g.edge.withValues(alpha: 0.45)),
                    width: 1.0,
                  );

            final titleColor = g.inkMuted;
            final expandIconColor = g.clay;
            final actionAccentColor = g.clay;

            final appliedToneTint = switch (appearance.tone) {
              ThoughtCardTone.theme => g.clay,
              ThoughtCardTone.linen => const Color(0xFFA38B6B),
              ThoughtCardTone.sage => const Color(0xFF718B72),
              ThoughtCardTone.slate => const Color(0xFF718398),
            };
            final tint = appearance.applyToHome ? appliedToneTint : g.clay;
            final hardBorderColor = isDark
                ? g.edge.withValues(alpha: 0.65)
                : (g.merlot
                    ? MerlotPalette.action.withValues(alpha: 0.36)
                    : (g.frozen
                        ? FrozenPalette.line
                        : const Color(0xFFD4B2A7)));
            final bubbleFill = isDark
                ? tint.withValues(alpha: .12)
                : Colors.transparent;
            final bubbleBorder = Border.all(
              color: hardBorderColor,
              width: 1.2,
            );
            final thoughtTextColor = g.ink;
            final thoughtTextMutedColor = g.inkMuted;
            final bubbleAccentColor = g.clay;

            return Padding(
              padding: const EdgeInsets.only(top: 14),
              child: GlassSurface(
                key: const ValueKey('home_mind_space_card'),
                radius: 20,
                enableBlur: false,
                fillColor: cardFill,
                customBorder: cardBorder,
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            _expanded || previewThoughts.length > 1
                                ? 'Recent thoughts'
                                : 'Recent thought',
                            style: AscentTextStyles.homeCaption.copyWith(
                              color: titleColor,
                            ),
                          ),
                        ),
                        IconButton(
                          tooltip: _expanded
                              ? 'Collapse Mind Space'
                              : 'Expand Mind Space',
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            setState(() => _expanded = !_expanded);
                          },
                          icon: Icon(
                            _expanded
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: expandIconColor,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ...List.generate(previewThoughts.length, (index) {
                      final thought = previewThoughts[index];
                      final timeAgo = _formatTimeAgo(thought.createdAt);
                      final isDraftSource =
                          pendingDraft?['thoughtId'] == thought.id;

                      final isTransientActive =
                          _transientThoughtId == thought.id &&
                          !thought.isCompleted;

                      final isRight = (index % 2 == 1);

                      return Padding(
                        padding: EdgeInsets.only(
                          bottom: AppSpace.s10,
                          left: isRight ? 36.0 : 0.0,
                          right: isRight ? 0.0 : 36.0,
                        ),
                        child: AppTapArea(
                          onTap: () {
                            HapticFeedback.selectionClick();
                            context.push('/thought-wall?thought=${thought.id}');
                          },
                          child: Container(
                            key: ValueKey('home_thought_${thought.id}'),
                            decoration: BoxDecoration(
                              color: bubbleFill,
                              border: bubbleBorder,
                              borderRadius: BorderRadius.only(
                                topLeft: const Radius.circular(18),
                                topRight: const Radius.circular(18),
                                bottomLeft: Radius.circular(isRight ? 18 : 6),
                                bottomRight: Radius.circular(isRight ? 6 : 18),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppSpace.s16,
                              vertical: AppSpace.s12,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (thought.isPinned) ...[
                                  AppTag(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpace.s8,
                                      vertical: AppSpace.s2,
                                    ),
                                    nightDecoration: BoxDecoration(
                                      color: bubbleAccentColor.withValues(
                                        alpha: .12,
                                      ),
                                      borderRadius: AppGeometry.roundedr10,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.push_pin_rounded,
                                          size: 11,
                                          color: bubbleAccentColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'PINNED TO HOME',
                                          style: AscentTextStyles.homeCaption
                                              .copyWith(color: bubbleAccentColor)
                                              .merge(AppTypeRoles.typeRole65),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ] else if (thought.mood == 'promise') ...[
                                  AppTag(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpace.s8,
                                      vertical: AppSpace.s2,
                                    ),
                                    nightDecoration: BoxDecoration(
                                      color: bubbleAccentColor.withValues(
                                        alpha: .12,
                                      ),
                                      borderRadius: AppGeometry.roundedr10,
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.handshake_rounded,
                                          size: 11,
                                          color: bubbleAccentColor,
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'PROMISE',
                                          style: AscentTextStyles.homeCaption
                                              .copyWith(color: bubbleAccentColor)
                                              .merge(AppTypeRoles.typeRole65),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                ThoughtExcerpt(
                                  content: thought.content,
                                  arrowColor: thoughtTextColor,
                                  style: AppTypography.thoughtContent(
                                    color: thought.isCompleted
                                        ? thoughtTextMutedColor
                                        : thoughtTextColor,
                                    decoration: thought.isCompleted
                                        ? TextDecoration.lineThrough
                                        : null,
                                  ),
                                ),
                                if (isDraftSource) ...[
                                  const SizedBox(height: 8),
                                  Divider(color: g.line),
                                  const SizedBox(height: 6),
                                  _draftActions(pendingDraft!, showTitle: false),
                                ],
                                if (isTransientActive && !isDraftSource) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 6,
                                    runSpacing: 4,
                                    children: [
                                      AppPill.action(
                                        avatar: Icon(
                                          Icons.edit_calendar_outlined,
                                          size: 14,
                                          color: bubbleAccentColor,
                                        ),
                                        label: const Text('Plan'),
                                        backgroundColor: bubbleAccentColor
                                            .withValues(alpha: .10),
                                        labelStyle: TextStyle(
                                          color: bubbleAccentColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        onPressed: () {
                                          _dismissTransient();
                                          _plan(thought);
                                        },
                                      ),
                                      AppPill.action(
                                        avatar: Icon(
                                          Icons.checklist_rounded,
                                          size: 14,
                                          color: bubbleAccentColor,
                                        ),
                                        label: const Text('Todo'),
                                        backgroundColor: bubbleAccentColor
                                            .withValues(alpha: .10),
                                        labelStyle: TextStyle(
                                          color: bubbleAccentColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        onPressed: () {
                                          _dismissTransient();
                                          applyThoughtAction(
                                            context,
                                            ref.read(databaseProvider),
                                            [thought],
                                            'todo',
                                          );
                                        },
                                      ),
                                      AppPill.action(
                                        avatar: Icon(
                                          Icons.notifications_none_rounded,
                                          size: 14,
                                          color: bubbleAccentColor,
                                        ),
                                        label: const Text('Reminder'),
                                        backgroundColor: bubbleAccentColor
                                            .withValues(alpha: .10),
                                        labelStyle: TextStyle(
                                          color: bubbleAccentColor,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        onPressed: () {
                                          _dismissTransient();
                                          applyThoughtAction(
                                            context,
                                            ref.read(databaseProvider),
                                            [thought],
                                            'reminder',
                                          );
                                        },
                                      ),
                                    ],
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        if (thought.isCompleted) ...[
                                          Icon(
                                            Icons.check_circle_rounded,
                                            size: 12,
                                            color: bubbleAccentColor,
                                          ),
                                          const SizedBox(width: 4),
                                        ],
                                        Text(
                                          timeAgo,
                                          style: AscentTextStyles.homeCaption
                                              .copyWith(
                                                color: thoughtTextMutedColor,
                                                letterSpacing: 0.5,
                                              )
                                              .merge(AppTypeRoles.typeRole66),
                                        ),
                                      ],
                                    ),
                                    IconButton(
                                      tooltip: isTransientActive
                                          ? 'Collapse actions'
                                          : 'Expand actions',
                                      iconSize: 18,
                                      padding: EdgeInsets.zero,
                                      visualDensity: VisualDensity.compact,
                                      constraints: const BoxConstraints(
                                        minWidth: 26,
                                        minHeight: 26,
                                      ),
                                      onPressed: () {
                                        HapticFeedback.selectionClick();
                                        if (isTransientActive) {
                                          _dismissTransient();
                                        } else {
                                          _activateTransient(thought.id);
                                        }
                                      },
                                      icon: Icon(
                                        isTransientActive
                                            ? Icons.keyboard_arrow_up_rounded
                                            : Icons.keyboard_arrow_down_rounded,
                                        color: bubbleAccentColor,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    }),
                    if (pendingDraft != null && !draftInPreview)
                      Padding(
                        padding: const EdgeInsets.only(top: 8, bottom: 8),
                        child: AppCard(
                          padding: const EdgeInsets.all(14),
                          nightDecoration: BoxDecoration(
                            color: g.fill,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: g.edge),
                          ),
                          child: _draftActions(pendingDraft),
                        ),
                      ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton.icon(
                        style: TextButton.styleFrom(
                          foregroundColor: actionAccentColor,
                        ),
                        onPressed: () {
                          HapticFeedback.selectionClick();
                          context.push('/thought-wall');
                        },
                        icon: const Icon(Icons.chevron_right_rounded, size: 18),
                        label: const Text('View all'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'JUST NOW';
    if (diff.inMinutes < 60) return '${diff.inMinutes}M AGO';
    if (diff.inHours < 24) return '${diff.inHours}H AGO';
    return '${diff.inDays}D AGO';
  }
}
