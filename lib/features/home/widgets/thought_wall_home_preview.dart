import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/capped_chip_wrap.dart';
import '../../../shared/widgets/section_card.dart';
import '../../../shared/widgets/app_input_bar.dart';
import '../../../shared/widgets/app_chip.dart';
import 'home_record_actions.dart';
import 'home_capture_entrance.dart';
import 'home_outline_surface.dart';
import 'home_section_heading.dart';
import '../../../app/theme/home_design.dart';
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
import '../../thought_wall/board/board_actions.dart';
import '../../../core/services/festival_service.dart';
import 'dart:convert';

/// Level 3 · Supporting: Mindspace
/// Redesigned according to Ascent Home Redesign spec:
/// - Prominent capture field and a permanent doorway to Mindspace.
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
      useRootNavigator: true,
      useSafeArea: true,
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
        setState(() {
          _saving = false;
        });
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
  Widget build(BuildContext context) => widget.compact
      ? _compactHome(context)
      : Theme(
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
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: _focusNode.hasFocus ? g.clay : g.line,
            width: _focusNode.hasFocus ? 1.5 : .75,
          ),
          boxShadow: [
            BoxShadow(
              color: (_focusNode.hasFocus ? g.clay : Colors.black).withValues(
                alpha: context.isDark ? 0.18 : 0.04,
              ),
              blurRadius: 10,
              offset: const Offset(0, 3),
            ),
          ],
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
                  hintText: 'Capture a thought…',
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
              final todayFestival = ref.watch(todayFestivalProvider);
              return Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (todayFestival != null) ...[
                      Container(
                        key: const ValueKey('festival_default_thought_card'),
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: todayFestival.accentColor.withValues(
                            alpha: 0.1,
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: todayFestival.accentColor.withValues(
                              alpha: 0.3,
                            ),
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  todayFestival.emoji,
                                  style: const TextStyle(fontSize: 16),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    '${todayFestival.name} Reflection',
                                    style: AscentTextStyles.labelMedium
                                        .copyWith(
                                          color: context.isDark
                                              ? const Color(0xFFFDE68A)
                                              : const Color(0xFF92400E),
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Text(
                              todayFestival.thought,
                              style: AscentTextStyles.bodySmall.copyWith(
                                color: g.ink.withValues(alpha: 0.85),
                                fontStyle: FontStyle.italic,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (!widget.compact)
                      Wrap(
                        spacing: 8,
                        runSpacing: 6,
                        children: [
                          if (todayFestival != null)
                            _buildSparkChip(
                              icon: Icons.auto_awesome_rounded,
                              label:
                                  '${todayFestival.emoji} ${todayFestival.name}',
                              onTap: () {
                                HapticFeedback.selectionClick();
                                _controller.text =
                                    '${todayFestival.emoji} ${todayFestival.name}: ';
                                _controller
                                    .selection = TextSelection.fromPosition(
                                  TextPosition(offset: _controller.text.length),
                                );
                                _focusNode.requestFocus();
                              },
                              g: g,
                            ),
                          _buildSparkChip(
                            icon: Icons.lightbulb_outline_rounded,
                            label: 'Spark an idea',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _controller.text = '💡 ';
                              _controller
                                  .selection = TextSelection.fromPosition(
                                TextPosition(offset: _controller.text.length),
                              );
                              _focusNode.requestFocus();
                            },
                            g: g,
                          ),
                          _buildSparkChip(
                            icon: Icons.emoji_events_outlined,
                            label: 'Log a win',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _controller.text = '🎯 Win: ';
                              _controller
                                  .selection = TextSelection.fromPosition(
                                TextPosition(offset: _controller.text.length),
                              );
                              _focusNode.requestFocus();
                            },
                            g: g,
                          ),
                          _buildSparkChip(
                            icon: Icons.edit_note_rounded,
                            label: 'Reflect',
                            onTap: () {
                              HapticFeedback.selectionClick();
                              _controller.text = 'Reflecting on: ';
                              _controller
                                  .selection = TextSelection.fromPosition(
                                TextPosition(offset: _controller.text.length),
                              );
                              _focusNode.requestFocus();
                            },
                            g: g,
                          ),
                        ],
                      ),
                  ],
                ),
              );
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
                      ? context.doneInk.withValues(alpha: .6)
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
                      ? context.doneInk.withValues(alpha: .08)
                      : Color.lerp(
                          g.fill.withValues(alpha: isDark ? 0.25 : 0.40),
                          moodAccent.withValues(alpha: isDark ? 0.05 : 0.03),
                          0.4,
                        );

                  return HomeCaptureEntrance(
                    key: ValueKey('home_thought_entrance_${thought.id}'),
                    animate: isNew,
                    child: Padding(
                      padding: EdgeInsets.only(
                        left: isRight ? 36 : 0,
                        right: isRight ? 0 : 36,
                        bottom: AppSpace.s10,
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
                                ThoughtExcerpt(
                                  content: thought.content,
                                  maxLines: 5,
                                  arrowColor: thoughtTextColor,
                                  style: AppTypography.thoughtContent(
                                    color: thoughtTextColor,
                                  ),
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

    final todayFestival = ref.watch(todayFestivalProvider);
    final hasThoughts =
        (recentThoughtsAsync.value?.isNotEmpty ?? false) ||
        pendingDraft != null ||
        todayFestival != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // "Mind palace" heading + doorway to the Mindspace sit above the card.
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
                  const SizedBox(width: 4),
                  HomeSectionArrowButton(
                    tooltip: 'Open Mindspace',
                    color: const Color(0xFF7C5CB7),
                    onTap: () => context.push('/thought-wall'),
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
    final c = context.c;
    final latest = ref.watch(latestHomeThoughtProvider).value;
    final privateIds = ref.watch(privatePromiseIdsProvider);
    final unlocked = ref.watch(unlockedPromiseIdsProvider);
    final locked =
        latest != null &&
        latest.mood == 'promise' &&
        !unlocked.contains(latest.id) &&
        (privateIds.contains(latest.id) ||
            !ref.watch(allPromisesStreamProvider).hasValue);

    return SectionCard(
      key: const ValueKey('home_mind_space_card'),
      icon: Icons.psychology_alt_outlined,
      title: 'Mindspace',
      trailing: TextButton(
        onPressed: () => context.push('/thought-wall'),
        child: const Text('View all'),
      ),
      onOpen: () => context.push('/thought-wall'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 1. AppInputBar(hint: "What's on your mind?", leadingIcon: Icons.add)
          AppInputBar(
            controller: _controller,
            focusNode: _focusNode,
            hint: "What's on your mind?",
            submitTooltip: 'Send capture',
            leadingIcon: Icons.add,
            onLeadingTap: () {
              HapticFeedback.lightImpact();
              _focusNode.requestFocus();
            },
            onSubmit: _send,
          ),
          const SizedBox(height: 12),

          // 2. Wrap of AppChips capped at 2 rows with "+N more" expansion
          CappedChipWrap(
            maxRows: 2,
            spacing: 8,
            runSpacing: 8,
            children: [
              AppChip(
                icon: Icons.lightbulb_outline_rounded,
                label: 'Spark an idea',
                onTap: () {
                  HapticFeedback.selectionClick();
                  _controller.text = '💡 ';
                  _controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: _controller.text.length),
                  );
                  _focusNode.requestFocus();
                },
              ),
              AppChip(
                icon: Icons.emoji_events_outlined,
                label: 'Log a win',
                onTap: () {
                  HapticFeedback.selectionClick();
                  _controller.text = '🎯 Win: ';
                  _controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: _controller.text.length),
                  );
                  _focusNode.requestFocus();
                },
              ),
              AppChip(
                icon: Icons.edit_note_rounded,
                label: 'Reflect',
                onTap: () {
                  HapticFeedback.selectionClick();
                  _controller.text = 'Reflecting on: ';
                  _controller.selection = TextSelection.fromPosition(
                    TextPosition(offset: _controller.text.length),
                  );
                  _focusNode.requestFocus();
                },
              ),
            ],
          ),
          const SizedBox(height: 14),

          // 3. Latest entry as premium bubble OR Empty state
          if (latest != null) ...[
            HomeCaptureEntrance(
              key: ValueKey('home_thought_entrance_${latest.id}'),
              animate: false,
              child: Dismissible(
                key: ValueKey('home_latest_thought_dismissible_${latest.id}'),
                direction: DismissDirection.endToStart,
                confirmDismiss: (_) async {
                  HapticFeedback.mediumImpact();
                  ThoughtExpandedRegistry.collapse(latest.id);
                  if (context.mounted) {
                    await deleteThoughtsWithUndo(context, ref, [latest]);
                  }
                  return true;
                },
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  decoration: BoxDecoration(
                    color: c.alertTint,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(
                    Icons.delete_outline_rounded,
                    color: c.alert,
                    size: 22,
                  ),
                ),
                child: _HomeThoughtBubble(
                  key: const ValueKey('home_latest_thought_bubble'),
                  thought: latest,
                  locked: locked,
                  timeAgo: _formatTimeAgo(latest.createdAt),
                  maxLines: widget.previewLimit == 1 ? 2 : 4,
                  onTap: () => context.push('/thought-wall?thought=${latest.id}'),
                  onAction: () => showHomeThoughtActions(
                    context,
                    ref,
                    latest,
                    locked: locked,
                  ),
                ),
              ),
            ),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
              decoration: BoxDecoration(
                color: c.surfaceAlt,
                borderRadius: BorderRadius.circular(Rd.card),
                border: Border.all(color: c.border),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: c.accent.withValues(alpha: 0.10),
                      border: Border.all(
                        color: c.accent.withValues(alpha: 0.25),
                        width: 1,
                      ),
                    ),
                    child: Icon(
                      Icons.lightbulb_outline_rounded,
                      size: 22,
                      color: c.accent,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Your mindspace is clear',
                    style: TextStyle(
                      color: c.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Capture a thought, win, or spark an idea above.',
                    style: TextStyle(
                      color: c.textSecondary,
                      fontSize: 12.5,
                      height: 1.35,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 12),
                  Wrap(
                    alignment: WrapAlignment.center,
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      AppChip(
                        icon: Icons.lightbulb_outline_rounded,
                        label: 'Spark idea',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _controller.text = '💡 ';
                          _controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: _controller.text.length),
                          );
                          _focusNode.requestFocus();
                        },
                      ),
                      AppChip(
                        icon: Icons.auto_awesome_rounded,
                        label: 'Daily win',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _controller.text = '✨ Today’s win: ';
                          _controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: _controller.text.length),
                          );
                          _focusNode.requestFocus();
                        },
                      ),
                      AppChip(
                        icon: Icons.psychology_outlined,
                        label: 'Self-reflection',
                        onTap: () {
                          HapticFeedback.selectionClick();
                          _controller.text = '🧠 Realization: ';
                          _controller.selection = TextSelection.fromPosition(
                            TextPosition(offset: _controller.text.length),
                          );
                          _focusNode.requestFocus();
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSparkChip({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    required AscentGlass g,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: HomeDesign.of(context).mindTint.withValues(alpha: .28),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: HomeDesign.of(context).mindInk.withValues(alpha: .35),
              width: 1.0,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 16, color: HomeDesign.of(context).mindInk),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: HomeDesign.of(context).mindInk,
                ),
              ),
            ],
          ),
        ),
      ),
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

class _HomeThoughtBubble extends StatelessWidget {
  const _HomeThoughtBubble({
    super.key,
    required this.thought,
    required this.locked,
    required this.timeAgo,
    required this.onTap,
    required this.onAction,
    this.maxLines = 4,
  });

  final Thought thought;
  final bool locked;
  final String timeAgo;
  final VoidCallback onTap;
  final VoidCallback onAction;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final c = context.c;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final display = locked
        ? 'Private thought'
        : ThoughtExcerpt.displayContent(thought.content);

    final heroBg = dark
        ? c.surfaceAlt.withValues(alpha: 0.95)
        : c.surface;
    final heroBorderColor = dark
        ? c.border.withValues(alpha: 0.95)
        : c.border.withValues(alpha: 0.85);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.bubble),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: heroBg,
            borderRadius: BorderRadius.circular(AppRadius.bubble),
            border: AppBorder.all(heroBorderColor),
            boxShadow: AppElevation.soft(dark ? Colors.black : c.border, dark: dark),
          ),
          padding: const EdgeInsets.fromLTRB(16, 14, 14, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header row: category pill + timestamp + more menu
              Row(
                children: [
                  if (locked) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: c.accentTint,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 12, color: c.accent),
                          const SizedBox(width: 4),
                          Text(
                            'PRIVATE COMMITMENT',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.8,
                              color: c.accent,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ] else ...[
                    Flexible(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: c.accentTint,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              thought.mood == 'win'
                                  ? Icons.emoji_events_outlined
                                  : (thought.mood == 'spark'
                                        ? Icons.lightbulb_outline_rounded
                                        : Icons.bubble_chart_outlined),
                              size: 12,
                              color: c.accent,
                            ),
                            const SizedBox(width: 4),
                            Flexible(
                              child: Text(
                                '#${thought.category}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: c.accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  Text(
                    timeAgo,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11.5,
                      color: c.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: 'Thought actions',
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 28,
                      minHeight: 28,
                    ),
                    icon: Icon(
                      Icons.more_horiz_rounded,
                      size: 18,
                      color: c.textSecondary,
                    ),
                    onPressed: onAction,
                  ),
                ],
              ),
              const SizedBox(height: 8),

              // Thought content via shared ThoughtExcerpt component
              ThoughtExcerpt(
                content: display,
                style: TextStyle(
                  fontSize: 14.5,
                  height: 1.45,
                  fontStyle: locked ? FontStyle.italic : FontStyle.normal,
                  color: locked ? c.textSecondary : c.textPrimary,
                  fontWeight: FontWeight.w500,
                ),
                maxLines: maxLines,
                thoughtId: thought.id,
                textKey: const ValueKey('home_latest_thought_text'),
                toggleKey: const ValueKey('home_thought_expand_toggle'),
                arrowColor: c.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
