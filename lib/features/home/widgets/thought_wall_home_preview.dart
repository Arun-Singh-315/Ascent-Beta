import '../../../app/theme/shared_control_tokens.dart';
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
import '../../../shared/widgets/locked_commitment_tile.dart';
import '../../../shared/widgets/thought_excerpt.dart';
import '../../promises/providers/promise_providers.dart';
import '../../vault/providers/vault_providers.dart';
import '../../thought_wall/thought_wall_preferences.dart';
import '../../thought_wall/thought_wall_appearance_sheet.dart';
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
    this.compact = false,
  });
  final bool showComposer;
  final int previewLimit;
  final bool compact;

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
        _draft = NoteDraftBinding(_controller, prefs, 'home');
      }
    } catch (_) {
      // An optional preference provider may be absent in isolated widget tests.
    }
    _focusNode.addListener(_refresh);
    _controller.addListener(_refresh);
  }

  void _showBubbleStyleSheet(BuildContext context) {
    HapticFeedback.lightImpact();
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const ThoughtWallAppearanceSheet(),
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
    if (widget.compact) return _compactHome(context);
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

    Widget buildComposerContainer({required bool standalone}) {
      return Container(
        key: standalone ? const ValueKey('home_mind_space_card') : null,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: context.isDark
              ? g.fill.withValues(alpha: 0.35)
              : (g.merlot
                    ? MerlotPalette.surface
                    : (g.frozen
                          ? const Color(0xFFFBFDFF)
                          : const Color(0xFFFFFDFB))),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _focusNode.hasFocus ? g.clay : g.line,
            width: _focusNode.hasFocus ? 1.5 : .75,
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
                disabledForegroundColor: Colors.white.withValues(alpha: 0.4),
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
                  : const Icon(Icons.arrow_upward_rounded, color: Colors.white),
            ),
          ],
        ),
      );
    }

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
        buildComposerContainer(standalone: false),
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

                  final privatePromiseIds = ref.watch(
                    privatePromiseIdsProvider,
                  );
                  final unlockedPromiseIds = ref.watch(
                    unlockedPromiseIdsProvider,
                  );
                  final isPrivatePromise =
                      thought.mood == 'promise' &&
                      privatePromiseIds.contains(thought.id);
                  final isPromiseLocked =
                      isPrivatePromise &&
                      !unlockedPromiseIds.contains(thought.id);

                  final cardStyle = appearance.style;
                  final homeCardRadius = switch (cardStyle) {
                    ThoughtCardStyle.soft => BorderRadius.circular(16),
                    ThoughtCardStyle.bubble => BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isRight ? 18 : 6),
                      bottomRight: Radius.circular(isRight ? 6 : 18),
                    ),
                    ThoughtCardStyle.minimal => BorderRadius.circular(6),
                  };

                  final hasBubbleFraming =
                      cardStyle != ThoughtCardStyle.minimal;
                  final itemHardBorderColor = thought.isCompleted
                      ? (isDark
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFF166534))
                            .withValues(alpha: .6)
                      : hasBubbleFraming
                      ? Color.lerp(
                          g.ink.withValues(alpha: isDark ? .20 : .24),
                          moodAccent,
                          isDark ? 0.35 : 0.30,
                        )!
                      : g.ink.withValues(alpha: isDark ? .18 : .22);
                  final itemBubbleBorder = Border.all(
                    color: itemHardBorderColor,
                    width: hasBubbleFraming
                        ? bubbleBorderWidth.clamp(0.8, 1.2)
                        : 1.0,
                  );
                  final itemBubbleFill = !bubbleFilled && hasBubbleFraming
                      ? Colors.transparent
                      : thought.isCompleted
                      ? (isDark
                                ? const Color(0xFF86EFAC)
                                : const Color(0xFF166534))
                            .withValues(alpha: .06)
                      : Color.lerp(
                          g.fill.withValues(alpha: isDark ? 0.25 : 0.40),
                          moodAccent.withValues(alpha: isDark ? 0.05 : 0.03),
                          0.4,
                        );

                  return _ThoughtEntrance(
                    key: ValueKey('home_thought_entrance_${thought.id}'),
                    animate: isNew,
                    child: Padding(
                      padding: EdgeInsets.only(
                        bottom: AppSpace.s10,
                        left: !widget.compact && isRight ? 36.0 : 0.0,
                        right: !widget.compact && !isRight ? 36.0 : 0.0,
                      ),
                      child: AppTapArea(
                        onTap: () async {
                          HapticFeedback.selectionClick();
                          if (isPromiseLocked) {
                            final security = ref.read(
                              vaultSecurityServiceProvider,
                            );
                            final unlocked = await security
                                .authenticateBiometrics(
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
                            borderRadius: homeCardRadius,
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
                                Center(
                                  child: Tooltip(
                                    message:
                                        isPrivatePromise && !isPromiseLocked
                                        ? 'Tap to lock commitment'
                                        : '',
                                    child: InkWell(
                                      key: ValueKey(
                                        'promise_top_middle_wrapper_${thought.id}',
                                      ),
                                      onTap:
                                          isPrivatePromise && !isPromiseLocked
                                          ? () {
                                              HapticFeedback.lightImpact();
                                              ref
                                                  .read(
                                                    unlockedPromiseIdsProvider
                                                        .notifier,
                                                  )
                                                  .lock(thought.id);
                                            }
                                          : null,
                                      borderRadius: AppGeometry.roundedr12,
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 8,
                                        ),
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
                                                        : Icons
                                                              .lock_open_rounded)
                                                  : Icons.handshake_rounded,
                                              size: 12,
                                              color: bubbleAccentColor,
                                            ),
                                            const SizedBox(width: 5),
                                            Text(
                                              isPrivatePromise
                                                  ? (isPromiseLocked
                                                        ? 'PRIVATE PROMISE'
                                                        : 'UNLOCKED • TAP TO LOCK')
                                                  : 'PROMISE',
                                              style: AscentTextStyles
                                                  .homeCaption
                                                  .copyWith(
                                                    color: bubbleAccentColor,
                                                    fontWeight: FontWeight.w700,
                                                    letterSpacing: 1.2,
                                                  )
                                                  .merge(
                                                    AppTypeRoles.typeRole65,
                                                  ),
                                            ),
                                          ],
                                        ),
                                      ),
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
                                const SizedBox(height: 8),
                                LockedCommitmentTile(
                                  label: 'Private commitment',
                                  onTap: () async {
                                    final security = ref.read(
                                      vaultSecurityServiceProvider,
                                    );
                                    final unlocked = await security
                                        .authenticateBiometrics(
                                          reason: 'Unlock private commitment',
                                        );
                                    if (unlocked) {
                                      ref
                                          .read(
                                            unlockedPromiseIdsProvider.notifier,
                                          )
                                          .unlock(thought.id);
                                    }
                                  },
                                ),
                              ] else ...[
                                if (thought.mood != 'promise' &&
                                    thought.promptQuestion != null &&
                                    thought.promptQuestion!.trim().isNotEmpty &&
                                    thought.promptQuestion!
                                            .trim()
                                            .toLowerCase() !=
                                        thought.content
                                            .trim()
                                            .toLowerCase()) ...[
                                  Text(
                                    thought.promptQuestion!,
                                    style: AscentTextStyles.bodySmall.copyWith(
                                      color: thoughtTextMutedColor,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                ],
                                Text.rich(
                                  ThoughtExcerpt.buildRichArrowSpan(
                                    context: context,
                                    text: widget.compact
                                        ? thought.content
                                              .replaceAll(RegExp(r'\s+'), ' ')
                                              .trim()
                                        : thought.content,
                                    arrowColor: thoughtTextColor,
                                    baseStyle: AppTypography.thoughtContent(
                                      color: thoughtTextColor,
                                    ),
                                  ),
                                  maxLines: widget.compact ? 2 : 3,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              if (isDraftSource) ...[
                                const SizedBox(height: 8),
                                Divider(color: g.line),
                                const SizedBox(height: 6),
                                _draftActions(pendingDraft!, showTitle: false),
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
                                            style: AscentTextStyles.homeCaption
                                                .copyWith(
                                                  color: thoughtTextMutedColor,
                                                  letterSpacing: 0.5,
                                                )
                                                .merge(AppTypeRoles.typeRole66),
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
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(
                                          color: g.sage.withValues(alpha: 0.3),
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
                if (!widget.compact)
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      style: TextButton.styleFrom(
                        foregroundColor: actionAccentColor,
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        context.push('/thought-wall');
                      },
                      child: const Text('View ›'),
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

    final hasThoughts =
        (recentThoughtsAsync.value?.isNotEmpty ?? false) ||
        pendingDraft != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Mind palace" heading + doorway to the Thought Wall sit above the card.
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 6),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final title = Text(
                'Mind palace',
                style: AscentTextStyles.homeTitle.copyWith(
                  color: g.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              );
              final actions = Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    key: const ValueKey('home_mind_palace_style_btn'),
                    tooltip: 'Card style',
                    icon: Icon(
                      Icons.tune_rounded,
                      size: 20,
                      color: g.inkSecondary,
                    ),
                    onPressed: () => _showBubbleStyleSheet(context),
                  ),
                  TextButton(
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      context.push('/thought-wall');
                    },
                    child: const Text('View ›'),
                  ),
                ],
              );
              if (constraints.maxWidth < 300 ||
                  MediaQuery.textScalerOf(context).scale(14) > 18) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    title,
                    Align(alignment: Alignment.centerRight, child: actions),
                  ],
                );
              }
              return Row(
                children: [
                  Expanded(child: title),
                  actions,
                ],
              );
            },
          ),
        ),
        if (!hasThoughts)
          buildComposerContainer(standalone: true)
        else
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

  Widget _compactHome(BuildContext context) {
    final g = context.glass;
    final latest = ref.watch(latestHomeThoughtProvider).value;
    final privateIds = ref.watch(privatePromiseIdsProvider);
    final unlocked = ref.watch(unlockedPromiseIdsProvider);
    final locked =
        latest != null &&
        latest.mood == 'promise' &&
        !unlocked.contains(latest.id) &&
        (privateIds.contains(latest.id) ||
            !ref.watch(allPromisesStreamProvider).hasValue);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Mind palace',
                style: TextStyle(
                  color: g.ink,
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -.4,
                ),
              ),
            ),
            TextButton(
              onPressed: () => context.push('/thought-wall'),
              child: const Text('View ›'),
            ),
          ],
        ),
        if (widget.showComposer)
          Container(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: g.line, width: .75),
            ),
            padding: const EdgeInsets.fromLTRB(6, 5, 6, 5),
            child: Row(
              children: [
                InlineListAddButton(
                  controller: _controller,
                  focusNode: _focusNode,
                  enabled: !_saving,
                ),
                Expanded(
                  child: TextField(
                    key: _fieldKey,
                    controller: _controller,
                    focusNode: _focusNode,
                    minLines: 1,
                    maxLines: 3,
                    textCapitalization: TextCapitalization.sentences,
                    style: TextStyle(color: g.ink, fontSize: 15, height: 1.4),
                    decoration: const InputDecoration(
                      hintText: 'Capture a thought…',
                      filled: false,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                IconButton.filled(
                  tooltip: 'Send capture',
                  onPressed: _saving || _controller.text.trim().isEmpty
                      ? null
                      : _send,
                  style: IconButton.styleFrom(
                    backgroundColor: SharedControlColors.actionBlue,
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: g.ink.withValues(alpha: .08),
                    disabledForegroundColor: g.inkMuted,
                  ),
                  icon: const Icon(Icons.arrow_upward_rounded, size: 20),
                ),
              ],
            ),
          ),
        if (latest != null)
          Padding(
            padding: const EdgeInsets.only(top: 9, right: 26),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Dismissible(
                key: ValueKey('home_thought_dismiss_${latest.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (direction) async {
                  HapticFeedback.mediumImpact();
                  final thoughtDao = ref.read(thoughtDaoProvider);
                  final messenger = ScaffoldMessenger.of(context);
                  final snapshot = await thoughtDao.deleteThoughtForUndo(
                    latest.id,
                  );
                  if (snapshot == null) return false;

                  Future<void> restore() async {
                    try {
                      if (!await thoughtDao.restoreThoughtDeletion(snapshot) &&
                          messenger.mounted) {
                        messenger.hideCurrentSnackBar();
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Undo is no longer available.'),
                          ),
                        );
                      }
                    } catch (_) {
                      if (messenger.mounted) {
                        messenger.hideCurrentSnackBar();
                        messenger.showSnackBar(
                          SnackBar(
                            content: const Text(
                              'Could not restore the thought.',
                            ),
                            action: SnackBarAction(
                              label: 'Retry',
                              onPressed: restore,
                            ),
                          ),
                        );
                      }
                    }
                  }

                  if (messenger.mounted) {
                    messenger.hideCurrentSnackBar();
                    messenger.showSnackBar(
                      SnackBar(
                        content: const Text('Thought deleted'),
                        duration: const Duration(seconds: 4),
                        behavior: SnackBarBehavior.floating,
                        action: SnackBarAction(
                          label: 'Undo',
                          onPressed: restore,
                        ),
                      ),
                    );
                  }
                  return true;
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 14),
                  decoration: BoxDecoration(
                    color: SharedControlColors.errorSoftBg(context.isDark),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Delete',
                        style: TextStyle(
                          color: SharedControlColors.errorInk(context.isDark),
                          fontWeight: FontWeight.w600,
                          fontSize: 12.5,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.delete_outline_rounded,
                        color: SharedControlColors.errorInk(context.isDark),
                        size: 18,
                      ),
                    ],
                  ),
                ),
                child: Material(
                  color: g.ink.withValues(alpha: .045),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(17),
                    topRight: Radius.circular(17),
                    bottomRight: Radius.circular(17),
                    bottomLeft: Radius.circular(5),
                  ),
                  child: InkWell(
                    key: const ValueKey('home_latest_thought_bubble'),
                    borderRadius: BorderRadius.circular(17),
                    onTap: () =>
                        context.push('/thought-wall?thought=${latest.id}'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 13,
                        vertical: 10,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (locked)
                            Padding(
                              padding: const EdgeInsets.only(right: 7),
                              child: Icon(
                                Icons.lock_outline_rounded,
                                size: 15,
                                color: g.inkMuted,
                              ),
                            ),
                          Flexible(
                            child: Text(
                              locked
                                  ? 'Private thought'
                                  : ThoughtExcerpt.displayContent(
                                      latest.content,
                                    ),
                              key: const ValueKey('home_latest_thought_text'),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: g.inkSecondary,
                                fontSize: 14,
                                height: 1.4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.chevron_right_rounded,
                            size: 17,
                            color: g.inkMuted,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
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
