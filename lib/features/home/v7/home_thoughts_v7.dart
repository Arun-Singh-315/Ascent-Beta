import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../app/app_navigation.dart';
import '../../../app/theme/ascent_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/features/feature_registry.dart';
import '../../../core/providers/database_provider.dart';
import '../../../shared/widgets/ascent_composer.dart';
import '../../../shared/widgets/ascent_icon.dart';
import '../../../shared/widgets/ascent_small_button.dart';
import '../../../shared/widgets/ascent_snack_bar.dart';
import '../../thought_wall/board/thought_lines.dart';
import '../model/thought_chat.dart';
import 'home_region.dart';

final thoughtLinkedTasksProvider = StreamProvider.autoDispose
    .family<List<Task>, String>((ref, ids) {
      return ref.watch(thoughtDaoProvider).watchTasksFromThoughts(_ids(ids));
    });

final thoughtLinkedRemindersProvider = StreamProvider.autoDispose
    .family<List<(int, Reminder)>, String>((ref, ids) {
      return ref.watch(thoughtDaoProvider).watchRemindersForThoughts(_ids(ids));
    });

List<int> _ids(String key) => [
  for (final s in key.split(','))
    if (s.isNotEmpty) int.parse(s),
];

/// The latest thoughts as a chat: yours on the right, Ascent's replies
/// (what really happened to each one) on the left.
final homeThoughtChatProvider = Provider.autoDispose<List<ChatEntry>>((ref) {
  final thoughts = ref.watch(recentThoughtsStreamProvider).value ?? const [];
  final key = [for (final t in thoughts) t.id].join(',');
  return buildThoughtChat(
    thoughts,
    tasks: ref.watch(thoughtLinkedTasksProvider(key)).value ?? const [],
    reminders: ref.watch(thoughtLinkedRemindersProvider(key)).value ?? const [],
    now: DateTime.now(),
  );
});

/// Home v7 Thoughts: a short conversation and a field to add one.
class HomeThoughtsSection extends ConsumerStatefulWidget {
  const HomeThoughtsSection({super.key});

  @override
  ConsumerState<HomeThoughtsSection> createState() =>
      _HomeThoughtsSectionState();
}

class _HomeThoughtsSectionState extends ConsumerState<HomeThoughtsSection> {
  final _text = TextEditingController();
  final _focus = FocusNode();
  bool _saving = false;

  @override
  void dispose() {
    _text.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _save(String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _saving) return;
    setState(() => _saving = true);
    final dao = ref.read(thoughtDaoProvider);
    try {
      final id = await dao.insertThought(
        ThoughtTableCompanion.insert(content: text),
      );
      if (!mounted) return;
      HapticFeedback.lightImpact();
      _text.clear();
      AscentSnackBar.show(
        context,
        message: 'Thought saved',
        actionLabel: 'Undo',
        onAction: () => dao.deleteThought(id),
      );
    } catch (_) {
      if (mounted) {
        AscentSnackBar.error(
          context,
          message: 'Could not save. Your text is still here.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!ref.watch(unlockedFeaturesProvider).contains(AscentFeature.mind)) {
      return const SizedBox.shrink();
    }
    final t = context.tokens;
    final chat = ref.watch(homeThoughtChatProvider);
    final today = ref.watch(todayThoughtsCountStreamProvider).value ?? 0;
    return HomeRegion(
      key: const ValueKey('home_mind_card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeRegionHeader(
            glyph: AscentGlyph.mind,
            title: 'Thoughts',
            tint: t.think,
            count: today == 0 ? null : '$today today',
            trailing: AscentSmallButton.ghost(
              label: 'All',
              semanticLabel: 'Open all thoughts',
              onPressed: () => context.open('/thought-wall'),
            ),
          ),
          const SizedBox(height: 4),
          if (chat.isEmpty)
            const _Reply(
              key: ValueKey('home_mind_empty'),
              lead: 'Write anything here.',
              rest:
                  ' It stays on your wall, and you can turn it into a to-do '
                  'or a reminder later.',
              tone: null,
            )
          else
            for (final e in chat) ...[
              if (e.dayLabel != null) _DayLabel(e.dayLabel!),
              _Mine(key: ValueKey('home_thought_${e.thought.id}'), entry: e),
              if (e.reply case final r?)
                _Reply(
                  lead: r.lead,
                  rest: r.rest,
                  tone: r.tone,
                  at: e.thought.createdAt,
                  onTap: () => context.open(switch (r.tone) {
                    ReplyTone.todo => '/things',
                    ReplyTone.reminder => '/reminders',
                    _ => '/thought-wall?thought=${e.thought.id}',
                  }),
                ),
            ],
          const SizedBox(height: 10),
          AscentComposer(
            key: const ValueKey('home_mind_composer'),
            controller: _text,
            focusNode: _focus,
            hint: 'What’s on your mind?',
            maxLines: 4,
            busy: _saving,
            fieldKey: const ValueKey('home_mind_field'),
            sendKey: const ValueKey('home_mind_send'),
            sendTooltip: 'Save thought',
            onSend: _save,
          ),
        ],
      ),
    );
  }
}

class _DayLabel extends StatelessWidget {
  const _DayLabel(this.text);
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 2),
    child: Text(
      text.toUpperCase(),
      textAlign: TextAlign.center,
      style: AscentTextStyles.eyebrow.copyWith(
        color: context.tokens.labelTertiary,
        fontSize: 10.5,
      ),
    ),
  );
}

String _time(DateTime at) => DateFormat('h:mm a').format(at);

/// Your thought: right-aligned, navy tint, one squared corner.
class _Mine extends StatelessWidget {
  const _Mine({super.key, required this.entry});
  final ChatEntry entry;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final th = entry.thought;
    return Align(
      alignment: Alignment.centerRight,
      child: FractionallySizedBox(
        widthFactor: 0.82,
        alignment: Alignment.centerRight,
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Semantics(
              button: true,
              label: 'Your thought: ${entry.text}',
              excludeSemantics: true,
              child: Material(
                color: t.actionTint,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(14),
                    topRight: Radius.circular(14),
                    bottomLeft: Radius.circular(14),
                    bottomRight: Radius.circular(4),
                  ),
                ),
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: () => context.open('/thought-wall?thought=${th.id}'),
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(11, 8, 11, 7),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _ThoughtText(entry.text),
                        const SizedBox(height: 3),
                        Text(
                          [
                            if (th.isPinned) 'Pinned',
                            _time(th.createdAt),
                          ].join(' · '),
                          style: AscentTextStyles.meta.copyWith(
                            color: t.labelTertiary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Ascent's reply: left-aligned, outlined, the fact in bold and colour.
class _Reply extends StatelessWidget {
  const _Reply({
    super.key,
    required this.lead,
    required this.rest,
    required this.tone,
    this.at,
    this.onTap,
  });

  final String lead, rest;
  final ReplyTone? tone;
  final DateTime? at;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final color = switch (tone) {
      ReplyTone.todo || ReplyTone.done => t.success,
      ReplyTone.reminder => t.warning,
      ReplyTone.kept => t.think,
      null => t.action,
    };
    return Align(
      alignment: Alignment.centerLeft,
      child: FractionallySizedBox(
        widthFactor: 0.82,
        alignment: Alignment.centerLeft,
        child: Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Material(
              color: Colors.transparent,
              shape: RoundedRectangleBorder(
                side: BorderSide(color: t.separator),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(14),
                  topRight: Radius.circular(14),
                  bottomLeft: Radius.circular(4),
                  bottomRight: Radius.circular(14),
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(11, 8, 11, 7),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: lead,
                              style: TextStyle(
                                color: color,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            TextSpan(text: rest),
                          ],
                        ),
                        style: AscentTextStyles.thought.copyWith(
                          color: t.labelSecondary,
                        ),
                      ),
                      if (at != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          _time(at!),
                          style: AscentTextStyles.meta.copyWith(
                            color: t.labelTertiary,
                            fontSize: 10.5,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// A thought's words: plain text, or up to three checklist lines with a
/// small tick, and "+N more".
class _ThoughtText extends StatelessWidget {
  const _ThoughtText(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    final t = context.tokens;
    final style = AscentTextStyles.thought.copyWith(color: t.label);
    final lines = parseThoughtLines(text);
    if (!lines.any((l) => l.isItem)) {
      return Text(
        text,
        maxLines: 4,
        overflow: TextOverflow.ellipsis,
        style: style,
      );
    }
    final shown = lines.take(3).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final l in shown)
          Padding(
            padding: const EdgeInsets.only(bottom: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (l.isItem) ...[
                  Padding(
                    padding: const EdgeInsets.only(top: 3),
                    child: Container(
                      width: 12,
                      height: 12,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: l.isDone ? t.success : Colors.transparent,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: l.isDone ? t.success : t.labelTertiary,
                          width: 1.4,
                        ),
                      ),
                      child: l.isDone
                          ? AscentIcon(
                              AscentGlyph.check,
                              size: 8,
                              color: t.onAction,
                            )
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],
                Flexible(
                  child: Text(
                    l.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: style.copyWith(
                      color: l.isDone ? t.labelTertiary : t.label,
                      decoration: l.isDone ? TextDecoration.lineThrough : null,
                      decorationColor: t.labelTertiary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        if (lines.length > shown.length)
          Text(
            '+${lines.length - shown.length} more',
            style: AscentTextStyles.meta.copyWith(color: t.labelTertiary),
          ),
      ],
    );
  }
}
