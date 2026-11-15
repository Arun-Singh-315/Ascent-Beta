import 'package:ascent/shared/widgets/thought_excerpt.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'arrow formatting preserves line breaks without literal capture groups',
    () {
      expect(
        ThoughtExcerpt.formatArrowContent(
          '--> positive\n--> no junk food\n-- water',
        ),
        '→ positive\n→ no junk food\n• water',
      );
    },
  );

  testWidgets('show more expands in place and show less collapses', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 240,
            child: ThoughtExcerpt(
              content: 'First line\nSecond line\nThird line',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Show more'), findsOneWidget);
    Text richText() => tester.widget<Text>(find.byType(Text).first);
    expect(richText().maxLines, 2);
    await tester.tap(find.text('Show more'));
    await tester.pumpAndSettle();
    expect(find.text('Show less'), findsOneWidget);
    expect(richText().maxLines, isNull);
    await tester.tap(find.text('Show less'));
    await tester.pumpAndSettle();
    expect(richText().maxLines, 2);
  });

  testWidgets('two short lines do not show a spurious show more', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 300,
            child: ThoughtExcerpt(
              content: '--> positive\n--> no junk food\n\n',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      ),
    );
    expect(find.text('Show more'), findsNothing);
  });
}
