import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/thought_wall/board/board_logic.dart';
import 'package:ascent/features/thought_wall/board/space_style.dart';
import 'package:flutter_test/flutter_test.dart';

Thought t(
  int id,
  String content, {
  DateTime? at,
  bool done = false,
  bool pinned = false,
  String category = 'general',
}) => Thought(
  id: id,
  content: content,
  mood: 'thought',
  category: category,
  colorHex: '#000000',
  isPinned: pinned,
  isArchived: false,
  isCompleted: done,
  createdAt: at ?? DateTime(2026, 10, 31, 9),
);

void main() {
  final now = DateTime(2026, 10, 31, 10);

  test('card kind follows the text', () {
    expect(boardCardKind('Call mom'), BoardCardKind.spark);
    expect(boardCardKind('- milk\n- eggs\n- rice'), BoardCardKind.list);
    expect(boardCardKind('a' * 300), BoardCardKind.long);
    expect(
      boardCardKind('A normal sentence that is clearly longer than a spark.'),
      BoardCardKind.note,
    );
  });

  test('newest open thought becomes the hero, rest grouped by day', () {
    final content = buildBoardContent([
      t(1, 'old', at: DateTime(2026, 10, 1)),
      t(2, 'today new', at: DateTime(2026, 10, 31, 9, 30)),
      t(3, 'today older', at: DateTime(2026, 10, 31, 8)),
      t(4, 'pinned', pinned: true, at: DateTime(2026, 10, 2)),
      t(5, 'finished', done: true),
    ], now: now);
    expect(content.hero!.id, 2);
    expect(content.sections.first.label, 'Pinned');
    expect(content.sections.map((s) => s.label), contains('Today'));
    expect(content.done.single.id, 5);
  });

  test('hero can be forced and locked thoughts are skipped', () {
    final all = [t(1, 'a'), t(2, 'b', at: DateTime(2026, 10, 30))];
    expect(buildBoardContent(all, now: now, heroId: 2).hero!.id, 2);
    expect(
      buildBoardContent(all, now: now, excludedFromHero: {1}).hero!.id,
      2,
    );
  });

  test('balanceColumns fills the shorter column', () {
    final cols = balanceColumns<int>([5, 1, 1, 1], 2, (v) => v.toDouble());
    expect(cols[0], [5]);
    expect(cols[1], [1, 1, 1]);
  });

  test('splitEntries drops markers and blanks', () {
    expect(splitEntries('- Inception\n\n2. Dune\n[ ] Heat'), [
      'Inception',
      'Dune',
      'Heat',
    ]);
  });

  test('space summaries hide empty built-ins but keep own spaces', () {
    final summaries = buildSpaceSummaries(
      {
        'general': 'General',
        'bugs': 'Bugs',
        'custom_1': 'Movies',
      },
      [
        t(1, 'Inception', category: 'custom_1'),
        t(2, 'Dune', category: 'custom_1', done: true),
      ],
      const [],
    );
    expect(summaries.single.name, 'Movies');
    expect(summaries.single.total, 2);
    expect(summaries.single.done, 1);
  });

  test('#space tag routes a thought', () {
    final cats = {'general': 'General', 'custom_1': 'Movies', 'custom_2': 'Life Goals'};
    expect(parseSpaceTag('#movies Inception', cats)!.key, 'custom_1');
    expect(parseSpaceTag('#movies Inception', cats)!.text, 'Inception');
    expect(parseSpaceTag('#life goals Run a marathon', cats)!.key, 'custom_2');
    expect(parseSpaceTag('#moviesx hi', cats), isNull);
    expect(parseSpaceTag('#movies', cats), isNull);
    expect(parseSpaceTag('no tag', cats), isNull);
  });

  test('space style picks wording from the name', () {
    expect(spaceStyleFor('My Movies').doneLabel, 'Watched');
    expect(spaceStyleFor('Books').openLabel, 'To read');
    expect(spaceStyleFor('Random').noun, 'entry');
  });
}
