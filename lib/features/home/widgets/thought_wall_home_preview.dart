import 'package:ascent/app/theme/text_styles.dart';
import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:ascent/shared/widgets/app_surfaces.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../core/services/note_draft_binding.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../../../shared/widgets/thought_excerpt.dart';
import '../../thought_wall/thought_quick_actions.dart';

/// Level 3 · Supporting: Mind Space
/// Redesigned according to Ascent Home Redesign spec:
/// - Open layout with single underline input (no heavy nested boxes).
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
  int? _lastSavedThoughtId;
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

  void _refresh() {
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
        setState(() {
          _lastSavedThoughtId = id;
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

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final recentThoughtsAsync = ref.watch(recentThoughtsStreamProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (widget.showComposer)
          AppCard(
            nightDecoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: _focusNode.hasFocus ? g.clay : g.line,
                  width: _focusNode.hasFocus ? 2 : 1,
                ),
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    focusNode: _focusNode,
                    cursorColor: g.clay,
                    minLines: 1,
                    maxLines: 4,
                    textCapitalization: TextCapitalization.sentences,
                    style: AppTypography.plusJakartaSans14W60080(color: g.ink),
                    decoration: const InputDecoration(
                      hintText: "What's on your mind?",
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
                IconButton(
                  tooltip: 'Send thought',
                  onPressed: _saving || _controller.text.trim().isEmpty
                      ? null
                      : _send,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : Icon(Icons.send_rounded, color: g.clay),
                ),
              ],
            ),
          ),

        // ── THOUGHTS BUBBLE PREVIEW (ALTERNATING LEFT/RIGHT) ───────────
        recentThoughtsAsync.when(
          loading: () => const SizedBox.shrink(),
          error: (_, _) => const SizedBox.shrink(),
          data: (thoughts) {
            if (thoughts.isEmpty) {
              return const SizedBox.shrink();
            }

            final List<Thought> previewThoughts;
            if (_expanded) {
              previewThoughts = thoughts
                  .take(widget.previewLimit.clamp(1, 4))
                  .toList();
            } else {
              final pinned = thoughts.where((t) => t.isPinned).firstOrNull;
              final latest =
                  thoughts.where((t) => t.id != pinned?.id).firstOrNull;
              if (pinned != null) {
                previewThoughts = [
                  pinned,
                  ?latest,
                ];
              } else {
                previewThoughts = thoughts.take(2).toList();
              }
            }

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        _expanded || previewThoughts.length > 1
                            ? 'Recent thoughts'
                            : 'Recent thought',
                        style: AscentTextStyles.homeCaption.copyWith(
                          color: g.inkMuted,
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
                        color: g.clay,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                ...List.generate(previewThoughts.length, (index) {
                  final thought = previewThoughts[index];
                  final isEven = index % 2 == 0;
                  final timeAgo = _formatTimeAgo(thought.createdAt);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppSpace.s10),
                    child: Align(
                      alignment: isEven
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: GlassSurface(
                          key: ValueKey('home_thought_${thought.id}'),
                          enableBlur: false,
                          customBorder: Border.all(
                            color: g.inkMuted.withValues(
                              alpha:
                                  Theme.of(context).brightness ==
                                      Brightness.dark
                                  ? 0.4
                                  : 0.18,
                            ),
                            width: AppBorderScale.w1point2,
                          ),
                          radius: 18,
                          borderRadius: BorderRadius.only(
                            topLeft: AppGeometry.radiusr18,
                            topRight: AppGeometry.radiusr18,
                            bottomLeft: AppGeometry.bubbleTail(isEven),
                            bottomRight: AppGeometry.bubbleTail(!isEven),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpace.s16,
                            vertical: AppSpace.s12,
                          ),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push('/thought-wall?thought=${thought.id}');
                          },
                          child: Column(
                            crossAxisAlignment: isEven
                                ? CrossAxisAlignment.start
                                : CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (thought.isPinned) ...[
                                AppTag(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpace.s8,
                                    vertical: AppSpace.s3,
                                  ),
                                  nightDecoration: BoxDecoration(
                                    color: g.clay.withValues(alpha: 0.14),
                                    borderRadius: AppGeometry.roundedr10,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.push_pin_rounded,
                                        size: 11,
                                        color: g.clay,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'PINNED TO HOME',
                                        style: AscentTextStyles.homeCaption
                                            .copyWith(color: g.clay)
                                            .merge(AppTypeRoles.typeRole65),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 7),
                              ] else if (thought.mood == 'promise') ...[
                                AppTag(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: AppSpace.s8,
                                    vertical: AppSpace.s3,
                                  ),
                                  nightDecoration: BoxDecoration(
                                    color: g.clay.withValues(alpha: 0.14),
                                    borderRadius: AppGeometry.roundedr10,
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.handshake_rounded,
                                        size: 12,
                                        color: g.clay,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'PROMISE',
                                        style: AscentTextStyles.homeCaption
                                            .copyWith(color: g.clay)
                                            .merge(AppTypeRoles.typeRole65),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 7),
                              ],
                              ThoughtExcerpt(
                                content: thought.content,
                                onReadMore: () => context.push(
                                  '/thought-wall?thought=${thought.id}',
                                ),
                                style: AppTypography.plusJakartaSans14W600116(
                                  color: thought.isCompleted
                                      ? g.inkMuted
                                      : g.ink,
                                  decoration: thought.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                              ),
                              if (thought.id == _lastSavedThoughtId)
                                ThoughtQuickActions(
                                  key: ValueKey(
                                    'home_thought_quick_${thought.id}',
                                  ),
                                  thought: thought,
                                  db: ref.read(databaseProvider),
                                ),
                              const SizedBox(height: 5),
                              Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (thought.isCompleted) ...[
                                    Icon(
                                      Icons.check_circle_rounded,
                                      size: 12,
                                      color: g.clay,
                                    ),
                                    const SizedBox(width: 4),
                                  ],
                                  Text(
                                    timeAgo,
                                    style: AscentTextStyles.homeCaption
                                        .copyWith(
                                          color: g.inkMuted,
                                          letterSpacing: 0.5,
                                        )
                                        .merge(AppTypeRoles.typeRole66),
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
              ],
            );
          },
        ),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            style: Theme.of(context).brightness == Brightness.light
                ? TextButton.styleFrom(foregroundColor: const Color(0xFF53617C))
                : null,
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
  }

  String _formatTimeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 2) return 'JUST NOW';
    if (diff.inMinutes < 60) return '${diff.inMinutes}M AGO';
    if (diff.inHours < 24) return '${diff.inHours}H AGO';
    return '${diff.inDays}D AGO';
  }
}
