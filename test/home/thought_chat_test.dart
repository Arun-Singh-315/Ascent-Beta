import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/home/model/thought_chat.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  final now = DateTime(2026, 11, 28, 10);

  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  Future<Thought> thought(
    String text, {
    DateTime? at,
    String category = 'general',
    bool pinned = false,
  }) async {
    final id = await db.thoughtDao.insertThought(
      ThoughtTableCompanion.insert(
        content: text,
        category: drift.Value(category),
        isPinned: drift.Value(pinned),
        createdAt: drift.Value(at ?? now),
      ),
    );
    return (await db.thoughtDao.getThoughtById(id))!;
  }

  Future<List<ChatEntry>> chat() async {
    final all = await db.select(db.thoughtTable).get();
    final ids = [for (final t in all) t.id];
    return buildThoughtChat(
      all,
      tasks: await db.thoughtDao.watchTasksFromThoughts(ids).first,
      reminders: await db.thoughtDao.watchRemindersForThoughts(ids).first,
      now: now,
    );
  }

  test('a to-do made from a thought becomes the reply', () async {
    final t = await thought('Buy oats and spinach');
    await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Buy oats and spinach',
        linkedThoughtId: drift.Value(t.id),
        plannedDate: drift.Value(DateTime(2026, 11, 28, 18, 30)),
      ),
    );
    final reply = (await chat()).single.reply!;
    expect(reply.tone, ReplyTone.todo);
    expect(reply.text, 'Turned into a to-do for today at 6:30 PM.');
  });

  test('a linked reminder becomes the reply', () async {
    final t = await thought('Call the bank');
    final rid = await db.reminderDao.insertReminder(
      ReminderTableCompanion.insert(
        title: 'Call the bank',
        scheduledAt: DateTime(2026, 11, 29, 9),
      ),
    );
    await db
        .into(db.thoughtReminderLinkTable)
        .insert(
          ThoughtReminderLinkTableCompanion.insert(
            thoughtId: t.id,
            reminderId: rid,
          ),
        );
    final reply = (await chat()).single.reply!;
    expect(reply.tone, ReplyTone.reminder);
    expect(reply.text, 'Reminder set for tomorrow at 9:00 AM.');
  });

  test('space, pin and checklist replies; plain thoughts stay quiet', () async {
    await thought('A slow Sunday', category: 'ideas', pinned: true);
    await thought(
      '- [x] milk\n- [ ] eggs',
      at: now.add(const Duration(minutes: 1)),
    );
    await thought('Just a note', at: now.add(const Duration(minutes: 2)));
    final c = await chat();
    expect(c[0].reply!.text, 'Kept in Ideas and pinned.');
    expect(c[1].reply?.lead, contains('ticked'));
    expect(c[2].reply, isNull);
  });

  test('oldest first, at most four, a day label at each new day', () async {
    for (var i = 0; i < 6; i++) {
      await thought('T$i', at: now.subtract(Duration(hours: 30 - i * 5)));
    }
    final c = await chat();
    expect(c.map((e) => e.text), ['T2', 'T3', 'T4', 'T5']);
    expect(c.first.dayLabel, isNotNull);
    expect(c.where((e) => e.dayLabel != null).length, 2);
    expect(c.last.dayLabel ?? c[2].dayLabel ?? c[1].dayLabel, isNotNull);
  });

  test('day labels read naturally', () {
    expect(chatDayLabel(now, now), 'Today');
    expect(
      chatDayLabel(now.subtract(const Duration(days: 1)), now),
      'Yesterday',
    );
    expect(chatDayLabel(DateTime(2026, 11, 2), now), '2 Nov');
  });
}
