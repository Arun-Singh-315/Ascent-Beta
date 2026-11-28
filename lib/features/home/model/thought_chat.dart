import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../../core/database/app_database.dart';
import '../../thought_wall/board/board_logic.dart' show displayContent;
import '../../thought_wall/board/thought_lines.dart';

/// What an Ascent reply is about; the section colours its bold lead by it.
enum ReplyTone { todo, reminder, kept, done }

/// Ascent's quiet reply under a thought: what actually happened to it.
/// Built only from real links (a to-do or reminder made from it, its space,
/// pin and checklist), never invented.
@immutable
class ThoughtReply {
  const ThoughtReply({
    required this.lead,
    required this.rest,
    required this.tone,
  });
  final String lead, rest;
  final ReplyTone tone;

  String get text => '$lead$rest';
}

/// One thought in the chat, with an optional day label above it and an
/// optional reply below it.
@immutable
class ChatEntry {
  const ChatEntry({
    required this.thought,
    required this.text,
    this.dayLabel,
    this.reply,
  });
  final Thought thought;
  final String text;
  final String? dayLabel;
  final ThoughtReply? reply;
}

String _when(DateTime day, DateTime now, {bool withTime = true}) {
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(day.year, day.month, day.day);
  final diff = d.difference(today).inDays;
  final label = switch (diff) {
    0 => 'today',
    1 => 'tomorrow',
    -1 => 'yesterday',
    _ when diff > 1 && diff < 7 => DateFormat('EEEE').format(day),
    _ => DateFormat('EEE d MMM').format(day),
  };
  final timed = withTime && (day.hour != 0 || day.minute != 0);
  return timed ? '$label at ${DateFormat('h:mm a').format(day)}' : label;
}

/// "Today", "Yesterday", a weekday this week, else "12 Nov".
String chatDayLabel(DateTime at, DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  final d = DateTime(at.year, at.month, at.day);
  final days = today.difference(d).inDays;
  if (days <= 0) return 'Today';
  if (days == 1) return 'Yesterday';
  if (days < 7) return DateFormat('EEEE').format(at);
  return DateFormat('d MMM').format(at);
}

String _space(String category) => category
    .split(RegExp(r'[\s_-]+'))
    .where((w) => w.isNotEmpty)
    .map((w) => '${w[0].toUpperCase()}${w.substring(1)}')
    .join(' ');

/// The reply for [t], most telling first: a to-do, a reminder, checklist
/// progress, then its space and pin. Null when nothing happened to it.
ThoughtReply? replyFor(
  Thought t, {
  required List<Task> tasks,
  required List<Reminder> reminders,
  required DateTime now,
}) {
  if (tasks.isNotEmpty) {
    final task = tasks.first;
    if (task.actualCompletedDate != null) {
      return const ThoughtReply(
        lead: 'Done',
        rest: ': the to-do made from this is finished.',
        tone: ReplyTone.done,
      );
    }
    final day = task.plannedDate;
    return ThoughtReply(
      lead: 'Turned into a to-do',
      rest: day == null ? ' in Anytime.' : ' for ${_when(day, now)}.',
      tone: ReplyTone.todo,
    );
  }
  if (reminders.isNotEmpty) {
    final r = reminders.reduce(
      (a, b) => a.scheduledAt.isBefore(b.scheduledAt) ? a : b,
    );
    return ThoughtReply(
      lead: 'Reminder set',
      rest: ' for ${_when(r.scheduledAt, now)}.',
      tone: ReplyTone.reminder,
    );
  }
  final content = t.content;
  final items = listItems(content);
  if (items.isNotEmpty) {
    final done = items.where((l) => l.isDone).length;
    if (done == items.length) {
      return const ThoughtReply(
        lead: 'All ticked off',
        rest: '.',
        tone: ReplyTone.done,
      );
    }
    return ThoughtReply(
      lead: '$done of ${items.length} ticked',
      rest: ' so far.',
      tone: ReplyTone.kept,
    );
  }
  final spaced = t.category.isNotEmpty && t.category != 'general';
  if (spaced) {
    return ThoughtReply(
      lead: 'Kept in ${_space(t.category)}',
      rest: t.isPinned ? ' and pinned.' : '.',
      tone: ReplyTone.kept,
    );
  }
  if (t.isPinned) {
    return const ThoughtReply(
      lead: 'Pinned',
      rest: ' to the top of your wall.',
      tone: ReplyTone.kept,
    );
  }
  return null;
}

/// The last [max] thoughts as a chat, oldest first, with a day label at
/// each new day. Archived thoughts are left out. Pure.
List<ChatEntry> buildThoughtChat(
  List<Thought> thoughts, {
  required List<Task> tasks,
  required List<(int, Reminder)> reminders,
  required DateTime now,
  int max = 4,
}) {
  final shown =
      (thoughts.where((t) => !t.isArchived).toList()
            ..sort((a, b) => b.createdAt.compareTo(a.createdAt)))
          .take(max)
          .toList()
          .reversed;
  final out = <ChatEntry>[];
  String? lastDay;
  for (final t in shown) {
    final day = chatDayLabel(t.createdAt, now);
    out.add(
      ChatEntry(
        thought: t,
        text: displayContent(t.content).trim(),
        dayLabel: day == lastDay ? null : day,
        reply: replyFor(
          t,
          tasks: [
            for (final k in tasks)
              if (k.linkedThoughtId == t.id) k,
          ],
          reminders: [
            for (final (id, r) in reminders)
              if (id == t.id) r,
          ],
          now: now,
        ),
      ),
    );
    lastDay = day;
  }
  return out;
}
