import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/thought_wall/board/board_cards.dart';
import 'package:ascent/features/thought_wall/thought_wall_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final now = DateTime(2026, 11, 18, 12, 0);

  Thought makeThought({
    required int id,
    required String content,
    String mood = 'thought',
    bool isCompleted = false,
  }) =>
      Thought(
        id: id,
        content: content,
        category: 'wall',
        mood: mood,
        colorHex: '#000000',
        createdAt: now,
        isPinned: false,
        isArchived: false,
        isCompleted: isCompleted,
      );

  Widget wrapWidget(Widget child, {bool dark = false}) => MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: dark ? AscentTheme.dark() : AscentTheme.light(),
        home: Scaffold(
          body: Center(
            child: SizedBox(
              width: 360,
              child: child,
            ),
          ),
        ),
      );

  group('BoardCard Hug Width', () {
    testWidgets('Short text hugs width tightly (significantly less than maxWidth)', (tester) async {
      final thought = makeThought(id: 1, content: 'wat about me');

      await tester.pumpWidget(
        wrapWidget(
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: BoardCard(
                thought: thought,
                index: 0,
                now: now,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final cardFinder = find.byType(BoardCard);
      expect(cardFinder, findsOneWidget);
      final size = tester.getSize(cardFinder);

      // Card must hug the short text and never blow up to full maxWidth (340px)
      expect(size.width, lessThan(260.0));
      expect(size.width, greaterThanOrEqualTo(190.0));
    });

    testWidgets('Long text expands to full maxWidth', (tester) async {
      final thought = makeThought(
        id: 2,
        content: 'This is a long reflection explaining multiple thoughts, plans, and daily observations across multiple lines to verify that it expands naturally.',
      );

      await tester.pumpWidget(
        wrapWidget(
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: BoardCard(
                thought: thought,
                index: 0,
                now: now,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(BoardCard));
      expect(size.width, equals(340.0));
    });

    testWidgets('Checklists keep full maxWidth', (tester) async {
      final thought = makeThought(
        id: 3,
        content: '[ ] Milk\n[ ] Eggs',
      );

      await tester.pumpWidget(
        wrapWidget(
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: BoardCard(
                thought: thought,
                index: 0,
                now: now,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(BoardCard));
      expect(size.width, equals(340.0));
    });

    testWidgets('Selection mode keeps full maxWidth for ease of tapping', (tester) async {
      final thought = makeThought(id: 4, content: 'short');

      await tester.pumpWidget(
        wrapWidget(
          Align(
            alignment: Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 340),
              child: BoardCard(
                thought: thought,
                index: 0,
                now: now,
                isSelectionMode: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final size = tester.getSize(find.byType(BoardCard));
      expect(size.width, equals(340.0));
    });
  });

  group('BoardCard & BoardHeroCard Night Styling', () {
    testWidgets('BoardCard renders transparent fill and mood-tinted hairline in dark mode when bubbleFilled is false', (tester) async {
      final thought = makeThought(id: 5, content: 'so its alll about love', mood: 'win');

      await tester.pumpWidget(
        wrapWidget(
          BoardCard(
            thought: thought,
            index: 0,
            now: now,
            appearance: const ThoughtWallAppearance(bubbleFilled: false),
          ),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<AnimatedContainer>(
        find.descendant(
          of: find.byType(BoardCard),
          matching: find.byType(AnimatedContainer),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration;

      // Transparent night canvas fill
      expect(decoration.color, equals(Colors.transparent));

      // Border is not the old hardcoded near-invisible navy #262933
      final border = decoration.border as Border;
      expect(border.top.color, isNot(equals(const Color(0xFF262933))));
    });

    testWidgets('BoardHeroCard renders transparent fill and mood border in dark mode when bubbleFilled is false', (tester) async {
      final thought = makeThought(id: 6, content: 'hello love', mood: 'win');

      await tester.pumpWidget(
        wrapWidget(
          BoardHeroCard(
            thought: thought,
            now: now,
            appearance: const ThoughtWallAppearance(bubbleFilled: false),
          ),
          dark: true,
        ),
      );
      await tester.pumpAndSettle();

      final container = tester.widget<Container>(
        find.descendant(
          of: find.byType(BoardHeroCard),
          matching: find.byType(Container),
        ).first,
      );
      final decoration = container.decoration as BoxDecoration;

      expect(decoration.color, equals(Colors.transparent));
      final border = decoration.border as Border;
      expect(border.top.color, isNot(equals(const Color(0xFF262933))));
    });
  });
}
