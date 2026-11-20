import 'package:ascent/features/thought_wall/board/thought_lines.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('plain, dash, arrow and checkbox lines are bullets', () {
    final lines = parseThoughtLines('Title\n- one\n[x] two\n-> three');
    expect(lines.first.isItem, isFalse);
    expect(lines.where((l) => l.isItem).length, 3);
    expect(lines.where((l) => l.isDone).length, 1);
  });

  test('item indexes are consecutive over items only', () {
    final items = listItems('- a\nnote\n- b\n- c');
    expect(items.map((l) => l.itemIndex), [0, 1, 2]);
  });

  test('single bullet is not list-like', () {
    expect(listItems('- only one'), isEmpty);
    expect(progressLabel('- only one'), isNull);
  });

  test('progress and all-done', () {
    expect(progressLabel('- [x] a\n- [ ] b'), '1/2');
    expect(allItemsDone('- [x] a\n- [x] b'), isTrue);
    expect(allItemsDone('- [x] a\n- [ ] b'), isFalse);
    expect(allItemsDone('just text'), isFalse);
  });

  test('style resolves stored first, then default', () {
    expect(resolveBulletStyle('bullet', BulletStyle.todo), BulletStyle.bullet);
    expect(resolveBulletStyle(null, BulletStyle.todo), BulletStyle.todo);
    expect(resolveBulletStyle('junk', BulletStyle.bullet), BulletStyle.bullet);
  });
}
