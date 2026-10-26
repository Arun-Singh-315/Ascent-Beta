import 'home_outline_surface.dart';
import '../../thought_wall/drop_thought_sheet.dart';
import '../../../app/theme/thought_theme.dart';
import '../../plans/widgets/plan_collection_editor.dart';
import '../../../shared/widgets/note_list_button.dart';
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
import '../../promises/providers/promise_providers.dart';
import '../../vault/providers/vault_providers.dart';
import '../../thought_wall/thought_wall_preferences.dart';
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
    this.previewLimit = 2,
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
  final Set<int> _seenThoughtIds = <int>{};
  bool _listSeen = false;

  final _focusNode = FocusNode();
  NoteDraftBinding? _draft;

  @override
  void dispose() {
    _draft?.dispose();
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      if (widget.showComposer) {
        _draft = NoteDraftBinding(
          _controller,
          prefs,
          'home',
        );
      }
    } catch (_) {
      // An optional preference provider may be absent in isolated widget tests.
    }
    _focusNode.addListener(_refresh);
    _controller.addListener(_refresh);
  }

  Future<void> _setBubbleStyle({bool? filled, double? borderWidth}) async {
    final current = ref.read(thoughtWallAppearanceProvider);
    await ref.read(thoughtWallAppearanceProvider.notifier).save(
      current.copyWith(
        bubbleFilled: filled,
        bubbleBorderWidth: borderWidth,
      ),
    );
  }

  void _showBubbleStyleSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    final g = context.glass;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Consumer(
          builder: (sheetContext, sheetRef, _) {
            final appearance = sheetRef.watch(thoughtWallAppearanceProvider);
            final bubbleFilled = appearance.bubbleFilled;
            final bubbleBorderWidth = appearance.bubbleBorderWidth;
            return Container(
              decoration: BoxDecoration(
                color: context.isDark ? context.bgSurface : g.fill,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
                border: Border(top: BorderSide(color: g.line)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: g.inkMuted.withValues(alpha: 0.25),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Icon(Icons.tune_rounded, size: 20, color: g.clay),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Mind Palace Card Style',
                            style: AscentTextStyles.homeTitle.copyWith(
                              color: g.ink,
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 20),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'CARD BACKGROUND',
                      style: AscentTextStyles.labelSmall.copyWith(
                        color: g.inkMuted,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _setBubbleStyle(filled: true);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: bubbleFilled
                                    ? g.clay.withValues(alpha: 0.14)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: bubbleFilled
                                      ? g.clay
                                      : g.line.withValues(alpha: 0.5),
                                  width: bubbleFilled ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    bubbleFilled
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    size: 16,
                                    color: bubbleFilled
                                        ? g.clay
                                        : g.inkSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Coloured Fill',
                                    style: AscentTextStyles.bodySmall.copyWith(
                                      color: bubbleFilled ? g.clay : g.ink,
                                      fontWeight: bubbleFilled
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _setBubbleStyle(filled: false);
                            },
                            borderRadius: BorderRadius.circular(12),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: !bubbleFilled
                                    ? g.clay.withValues(alpha: 0.14)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: !bubbleFilled
                                      ? g.clay
                                      : g.line.withValues(alpha: 0.5),
                                  width: !bubbleFilled ? 1.8 : 1.0,
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(
                                    !bubbleFilled
                                        ? Icons.check_circle_rounded
                                        : Icons.circle_outlined,
                                    size: 16,
                                    color: !bubbleFilled
                                        ? g.clay
                                        : g.inkSecondary,
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Border Only',
                                    style: AscentTextStyles.bodySmall.copyWith(
                                      color: !bubbleFilled ? g.clay : g.ink,
                                      fontWeight: !bubbleFilled
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text(
                      'BORDER THICKNESS',
                      style: AscentTextStyles.labelSmall.copyWith(
                        color: g.inkMuted,
                        letterSpacing: 1.0,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        for (final width in [1.0, 1.8, 2.6]) ...[
                          Expanded(
                            child: InkWell(
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _setBubbleStyle(borderWidth: width);
                              },
                              borderRadius: BorderRadius.circular(12),
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                decoration: BoxDecoration(
                                  color: (bubbleBorderWidth - width).abs() <
                                          0.1
                                      ? g.clay.withValues(alpha: 0.14)
                                      : Colors.transparent,
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: (bubbleBorderWidth - width).abs() <
                                            0.1
                                        ? g.clay
                                        : g.line.withValues(alpha: 0.5),
                                    width: (bubbleBorderWidth - width).abs() <
                                            0.1
                                        ? 1.8
                                        : 1.0,
                                  ),
                                ),
                                child: Center(
                                  child: Text(
                                    width == 1.0
                                        ? 'Thin (1px)'
                                        : (width == 1.8
                                            ? 'Standard'
                                            : 'Bold (2.6px)'),
                                    style: AscentTextStyles.bodySmall.copyWith(
                                      color: (bubbleBorderWidth - width).abs() <
                                              0.1
                                          ? g.clay
                                          : g.ink,
                                      fontWeight:
                                          (bubbleBorderWidth - width).abs() <
                                                  0.1
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          if (width != 2.6) const SizedBox(width: 8),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
      await ref
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
    thoughts = [...thoughts]
      ..sort((a, b) {
        if (a.isCompleted != b.isCompleted) return a.isCompleted ? 1 : -1;
        if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
        return b.createdAt.compareTo(a.createdAt);
      });
    final pinned = thoughts
        .where((t) => t.isPinned && !t.isCompleted)
        .firstOrNull;
    if (pinned == null) {
      return thoughts.take(widget.previewLimit.clamp(1, 4)).toList();
    }
    final others = thoughts
        .where((t) => t.id != pinned.id)
        .take(widget.previewLimit.clamp(1, 4) - 1)
        .toList();
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
    final bubbleFilled = appearance.bubbleFilled;
    final bubbleBorderWidth = appearance.bubbleBorderWidth;
    final recentThoughtsAsync = ref.watch(recentThoughtsStreamProvider);
    final categories =
        ref.watch(thoughtCategoriesStreamProvider).value ??
        ThoughtDao.builtInCategories;
    final pendingDraft = _pendingDraft;
    final draftInPreview =
        pendingDraft != null &&
        _preview(
          recentThoughtsAsync.value ?? [],
        ).any((t) => t.id == pendingDraft['thoughtId']);


    // The composer and the recent thoughts live in ONE card: the composer
    // stays on top exactly as before and saved thoughts appear right below it.
    final shellChildren = <Widget>[
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
                    : g.ink.withValues(alpha: context.isDark ? .48 : .42),
                width: _focusNode.hasFocus ? 2.6 : 2.0,
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

        // ── THOUGHTS PREVIEW (grows smoothly below the composer) ──────
        AnimatedSize(
          duration: const Duration(milliseconds: 480),
          curve: Curves.easeOutCubic,
          alignment: Alignment.topCenter,
          child: recentThoughtsAsync.when(
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

Color getThoughtMoodColor(String mood) {
  switch (mood) {
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

            final titleColor = g.inkMuted;
            final actionAccentColor = g.clay;
            final thoughtTextColor = g.ink;
            final thoughtTextMutedColor = g.inkMuted;
            final bubbleAccentColor = g.clay;

            final thoughtsColumn = Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!widget.showComposer) ...[
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              previewThoughts.length > 1
                                  ? 'Recent thoughts'
                                  : 'Recent thought',
                              style: AscentTextStyles.homeCaption.copyWith(
                                color: titleColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                    ] else
                      const SizedBox(height: 14),
                    ...List.generate(previewThoughts.length, (index) {
                      final thought = previewThoughts[index];
                      final timeAgo = _formatTimeAgo(thought.createdAt);
                      final isDraftSource =
                          pendingDraft?['thoughtId'] == thought.id;

                      final isRight = (index % 2 == 1);
                      final isNew =
                          _listSeen && !_seenThoughtIds.contains(thought.id);

                      final moodAccent = g.frozen
                          ? (thought.mood == 'win' ? g.sage : g.slate)
                          : getThoughtMoodColor(thought.mood);

                      final privatePromiseIds =
                          ref.watch(privatePromiseIdsProvider);
                      final unlockedPromiseIds =
                          ref.watch(unlockedPromiseIdsProvider);
                      final isPrivatePromise = thought.mood == 'promise' &&
                          privatePromiseIds.contains(thought.id);
                      final isPromiseLocked = isPrivatePromise &&
                          !unlockedPromiseIds.contains(thought.id);

                      final itemHardBorderColor = thought.isCompleted
                          ? (isDark
                                  ? const Color(0xFF86EFAC)
                                  : const Color(0xFF166534))
                              .withValues(alpha: .6)
                          : Color.lerp(
                              g.ink.withValues(alpha: isDark ? .35 : .40),
                              moodAccent,
                              isDark ? 0.45 : 0.40,
                            )!;
                      final itemBubbleBorder = Border.all(
                        color: itemHardBorderColor,
                        width: bubbleBorderWidth,
                      );
                      final itemBubbleFill = !bubbleFilled
                          ? Colors.transparent
                          : thought.isCompleted
                              ? (isDark
                                      ? const Color(0xFF86EFAC)
                                      : const Color(0xFF166534))
                                  .withValues(alpha: .08)
                              : Color.lerp(
                                  g.fill,
                                  moodAccent.withValues(
                                    alpha: isDark ? 0.06 : 0.04,
                                  ),
                                  0.5,
                                );

                      return _ThoughtEntrance(
                        key: ValueKey('home_thought_entrance_${thought.id}'),
                        animate: isNew,
                        child: Padding(
                        padding: EdgeInsets.only(
                          bottom: AppSpace.s10,
                          left: isRight ? 36.0 : 0.0,
                          right: isRight ? 0.0 : 36.0,
                        ),
                        child: AppTapArea(
                          onTap: () async {
                            HapticFeedback.selectionClick();
                            if (isPromiseLocked) {
                              final security =
                                  ref.read(vaultSecurityServiceProvider);
                              final unlocked =
                                  await security.authenticateBiometrics(
                                reason: 'Unlock private commitment',
                              );
                              if (unlocked) {
                                ref
                                    .read(unlockedPromiseIdsProvider.notifier)
                                    .unlock(thought.id);
                              }
                              return;
                            }
                            context.push('/thought-wall?thought=${thought.id}');
                          },
                          child: Container(
                            key: ValueKey('home_thought_${thought.id}'),
                            decoration: BoxDecoration(
                              color: itemBubbleFill,
                              border: itemBubbleBorder,
                              boxShadow: [
                                BoxShadow(
                                  color: moodAccent.withValues(
                                    alpha: isDark ? 0.10 : 0.05,
                                  ),
                                  blurRadius: 8,
                                  spreadRadius: 0,
                                  offset: const Offset(0, 2),
                                ),
                              ],
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
                                              .copyWith(
                                                color: bubbleAccentColor,
                                              )
                                              .merge(AppTypeRoles.typeRole65),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ] else if (thought.mood == 'promise') ...[
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
                                        color: bubbleAccentColor.withValues(
                                          alpha: .12,
                                        ),
                                        borderRadius: AppGeometry.roundedr12,
                                        border: Border.all(
                                          color: bubbleAccentColor.withValues(
                                            alpha: 0.28,
                                          ),
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
                                            color: bubbleAccentColor,
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
                                                  color: bubbleAccentColor,
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
                                Text(
                                  '#${categories[thought.category] ?? thought.category}',
                                  style: AscentTextStyles.labelSmall.copyWith(
                                    color: thoughtTextMutedColor,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                if (isPromiseLocked) ...[
                                  const SizedBox(height: 6),
                                  InkWell(
                                    onTap: () async {
                                      final security = ref.read(
                                        vaultSecurityServiceProvider,
                                      );
                                      final unlocked = await security
                                          .authenticateBiometrics(
                                            reason:
                                                'Unlock private commitment',
                                          );
                                      if (unlocked) {
                                        ref
                                            .read(
                                              unlockedPromiseIdsProvider
                                                  .notifier,
                                            )
                                            .unlock(thought.id);
                                      }
                                    },
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        color: g.fill.withValues(alpha: 0.6),
                                        borderRadius:
                                            BorderRadius.circular(12),
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
                                              style: AscentTextStyles.bodySmall
                                                  .copyWith(
                                                    color: g.inkMuted,
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ] else ...[
                                  if (thought.promptQuestion != null &&
                                      thought.promptQuestion!.trim().isNotEmpty &&
                                      thought.promptQuestion!
                                              .trim()
                                              .toLowerCase() !=
                                          thought.content
                                              .trim()
                                              .toLowerCase()) ...[
                                    Text(
                                      thought.promptQuestion!,
                                      style: AscentTextStyles.bodySmall
                                          .copyWith(
                                            color: thoughtTextMutedColor,
                                            fontStyle: FontStyle.italic,
                                          ),
                                    ),
                                    const SizedBox(height: 6),
                                  ],
                                  Text.rich(
                                    ThoughtExcerpt.buildRichArrowSpan(
                                      context: context,
                                      text: thought.content,
                                      arrowColor: thoughtTextColor,
                                      baseStyle: AppTypography.thoughtContent(
                                        color: thoughtTextColor,
                                      ),
                                    ),
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                                if (isDraftSource) ...[
                                  const SizedBox(height: 8),
                                  Divider(color: g.line),
                                  const SizedBox(height: 6),
                                  _draftActions(
                                    pendingDraft!,
                                    showTitle: false,
                                  ),
                                ],
                                const SizedBox(height: 6),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Row(
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
                                          Flexible(
                                            child: Text(
                                              timeAgo,
                                              style: AscentTextStyles
                                                  .homeCaption
                                                  .copyWith(
                                                    color:
                                                        thoughtTextMutedColor,
                                                    letterSpacing: 0.5,
                                                  )
                                                  .merge(
                                                    AppTypeRoles.typeRole66,
                                                  ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (thought.isCompleted)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 3,
                                        ),
                                        decoration: BoxDecoration(
                                          color: g.sage.withValues(alpha: 0.14),
                                          borderRadius:
                                              BorderRadius.circular(8),
                                          border: Border.all(
                                            color:
                                                g.sage.withValues(alpha: 0.3),
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.check_circle_rounded,
                                              size: 11,
                                              color: g.sage,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Done',
                                              style: TextStyle(
                                                color: g.sage,
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    IconButton(
                                      tooltip: 'Edit thought',
                                      visualDensity: VisualDensity.compact,
                                      icon: Icon(
                                        Icons.edit_outlined,
                                        size: 17,
                                        color: g.ink,
                                      ),
                                      onPressed: () async {
                                        if (isPromiseLocked) {
                                          final security = ref.read(
                                            vaultSecurityServiceProvider,
                                          );
                                          final unlocked = await security
                                              .authenticateBiometrics(
                                                reason:
                                                    'Unlock private commitment before editing',
                                              );
                                          if (!unlocked) return;
                                          ref
                                              .read(
                                                unlockedPromiseIdsProvider
                                                    .notifier,
                                              )
                                              .unlock(thought.id);
                                        }
                                        if (!context.mounted) return;
                                        DropThoughtSheet.show(
                                          context,
                                          existingThought: thought,
                                        );
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
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
                );

            // With the composer, the thoughts live inside the shared card
            // built below; without it, keep the original standalone card.
            if (widget.showComposer) return thoughtsColumn;
            return Padding(
              padding: const EdgeInsets.only(top: 14),
              child: GlassSurface(
                key: const ValueKey('home_mind_space_card'),
                radius: 20,
                enableBlur: false,
                fillColor: cardFill,
                customBorder: cardBorder,
                padding: const EdgeInsets.all(14),
                child: thoughtsColumn,
              ),
            );
          },
          ),
        ),
    ];

    _markThoughtsSeen(recentThoughtsAsync.value);

    if (!widget.showComposer) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: shellChildren,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Mind palace" heading + doorway to the Thought Wall sit above the card.
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Mind palace',
                  style: AscentTextStyles.homeTitle.copyWith(
                    color: g.ink,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                key: const ValueKey('home_mind_palace_style_btn'),
                tooltip: 'Card style',
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.tune_rounded, size: 20, color: g.inkSecondary),
                onPressed: () => _showBubbleStyleSheet(context),
              ),
              TextButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.push('/thought-wall');
                },
                icon: const Icon(Icons.bubble_chart_outlined, size: 18),
                label: const Text('Open'),
              ),
            ],
          ),
        ),
        // One continuous frame encloses the composer and saved thoughts,
        // including the empty state.
        HomeOutlineSurface(
          surfaceKey: const ValueKey('home_mind_space_card'),
          radius: 24,
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: shellChildren,
          ),
        ),
      ],
    );
  }

  /// Remembers which thoughts were already on screen so only a thought saved
  /// after the first load gets the entrance animation.
  void _markThoughtsSeen(List<Thought>? thoughts) {
    if (thoughts == null) return;
    final ids = thoughts.map((t) => t.id).toList();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _seenThoughtIds.addAll(ids);
      _listSeen = true;
    });
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'JUST NOW';
    if (diff.inMinutes < 60) return '${diff.inMinutes}M AGO';
    if (diff.inHours < 24) return '${diff.inHours}H AGO';
    return '${diff.inDays}D AGO';
  }
}

/// Drops a freshly saved thought in from the composer: it slides down, settles
/// with a soft overshoot and fades in. Thoughts already on screen (first load,
/// reorders) are shown instantly. Honors the system "reduce motion" setting.
class _ThoughtEntrance extends StatefulWidget {
  const _ThoughtEntrance({
    super.key,
    required this.animate,
    required this.child,
  });

  final bool animate;
  final Widget child;

  @override
  State<_ThoughtEntrance> createState() => _ThoughtEntranceState();
}

class _ThoughtEntranceState extends State<_ThoughtEntrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: widget.animate ? 0 : 1,
  );
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    if (!widget.animate) return;
    if (MediaQuery.maybeDisableAnimationsOf(context) ?? false) {
      _controller.value = 1;
    } else {
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    child: widget.child,
    builder: (context, child) {
      final fade = Curves.easeOutCubic.transform(_controller.value);
      final settle = Curves.easeOutBack.transform(_controller.value);
      return Opacity(
        opacity: fade.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, -28 * (1 - settle)),
          child: Transform.scale(
            scale: 0.94 + 0.06 * settle,
            alignment: Alignment.topCenter,
            child: child,
          ),
        ),
      );
    },
  );
}
