import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:drift/drift.dart' as drift;
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/glass_surface.dart';

/// Level 3 · Supporting: Mind Space
/// Redesigned according to Ascent Home Redesign spec:
/// - Open layout with single underline input (no heavy nested boxes).
/// - Glass thought bubble for latest reflection.
/// - 44dp hit targets.
class ThoughtWallHomePreview extends ConsumerStatefulWidget {
  const ThoughtWallHomePreview({super.key});

  @override
  ConsumerState<ThoughtWallHomePreview> createState() =>
      _ThoughtWallHomePreviewState();
}

class _ThoughtWallHomePreviewState
    extends ConsumerState<ThoughtWallHomePreview> {
  final _controller = TextEditingController();
  bool _saving = false;
  final _focusNode = FocusNode();

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
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
      await ref
          .read(thoughtDaoProvider)
          .insertThought(
            ThoughtTableCompanion.insert(
              content: content,
              mood: const drift.Value('thought'),
            ),
          );
      if (mounted) {
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
        // ── SECTION HEADING ───────────────────────────────────────────
        Row(
          children: [
            Expanded(
              child: Text(
                'Mind space',
                style: AscentTextStyles.homeTitle.copyWith(color: g.ink),
              ),
            ),
            TextButton.icon(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push('/thought-wall');
              },
              style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
              icon: Icon(Icons.chevron_right_rounded, size: 18, color: g.clay),
              label: Text(
                'Open wall',
                style: AscentTextStyles.homeSecondary.copyWith(color: g.clay),
              ),
            ),
          ],
        ),

        const SizedBox(height: 10),

        Container(
          decoration: BoxDecoration(
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
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: g.ink,
                  ),
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

            final previewThoughts = thoughts.take(3).toList();

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: 12),
                ...List.generate(previewThoughts.length, (index) {
                  final thought = previewThoughts[index];
                  final isEven = index % 2 == 0;
                  final timeAgo = _formatTimeAgo(thought.createdAt);

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Align(
                      alignment: isEven
                          ? Alignment.centerLeft
                          : Alignment.centerRight,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 300),
                        child: GlassSurface(
                          radius: 18,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isEven ? 4 : 18),
                            bottomRight: Radius.circular(isEven ? 18 : 4),
                          ),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                          onTap: () {
                            HapticFeedback.lightImpact();
                            context.push('/thought-wall');
                          },
                          child: Column(
                            crossAxisAlignment: isEven
                                ? CrossAxisAlignment.start
                                : CrossAxisAlignment.end,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (thought.mood == 'promise') ...[
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 3,
                                  ),
                                  decoration: BoxDecoration(
                                    color: g.clay.withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(10),
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
                                            .copyWith(
                                              color: g.clay,
                                              fontSize: 9,
                                              fontWeight: FontWeight.w800,
                                            ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 7),
                              ],
                              Text(
                                thought.content,
                                style: GoogleFonts.plusJakartaSans(
                                  color: thought.isCompleted
                                      ? g.inkMuted
                                      : g.ink,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  decoration: thought.isCompleted
                                      ? TextDecoration.lineThrough
                                      : null,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
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
                                          fontSize: 10.5,
                                          letterSpacing: 0.5,
                                          fontWeight: FontWeight.w600,
                                        ),
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
