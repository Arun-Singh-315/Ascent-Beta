import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';

void main() {
  group('Thought Wall Chat-Style UI Tests', () {
    testWidgets('Even index thought is left-aligned and odd index thought is right-aligned in chat style', (tester) async {
      final thought1 = Thought(
        id: 1,
        content: 'Note to myself: Keep pushing steady today.',
        mood: 'me_to_me',
        isPinned: false,
        isArchived: false,
        isCompleted: false,
        colorHex: '#6366F1',
        createdAt: DateTime.now(),
      );

      final thought2 = Thought(
        id: 2,
        content: 'Future me: You built something durable.',
        mood: 'future',
        isPinned: false,
        isArchived: false,
        isCompleted: false,
        colorHex: '#6366F1',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: const [AscentGlass.dark],
            ),
            home: Scaffold(
              body: Column(
                children: [
                  ThoughtCardBubble(
                    thought: thought1,
                    index: 0,
                  ),
                  ThoughtCardBubble(
                    thought: thought2,
                    index: 1,
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify thought contents rendered
      expect(find.text('Note to myself: Keep pushing steady today.'), findsOneWidget);
      expect(find.text('Future me: You built something durable.'), findsOneWidget);

      // Verify asymmetric padding/margins (index 0 left-aligned, index 1 right-aligned)
      final paddings = tester.widgetList<Padding>(find.byType(Padding)).toList();
      bool foundLeftAligned = false;
      bool foundRightAligned = false;

      for (final p in paddings) {
        if (p.padding is EdgeInsets) {
          final edge = p.padding as EdgeInsets;
          if (edge.right >= 32 && edge.left <= 8) {
            foundLeftAligned = true;
          }
          if (edge.left >= 32 && edge.right <= 8) {
            foundRightAligned = true;
          }
        }
      }

      expect(foundLeftAligned, isTrue, reason: 'Even thought should have right inset creating left-alignment');
      expect(foundRightAligned, isTrue, reason: 'Odd thought should have left inset creating right-alignment');
    });

    testWidgets('Thought card has black/dark border and transparent container styling', (tester) async {
      final thought = Thought(
        id: 1,
        content: 'Transparent reflection with black border.',
        mood: 'thought',
        isPinned: false,
        isArchived: false,
        isCompleted: false,
        colorHex: '#6366F1',
        createdAt: DateTime.now(),
      );

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            theme: ThemeData.dark().copyWith(
              extensions: const [AscentGlass.dark],
            ),
            home: Scaffold(
              body: ThoughtCardBubble(
                thought: thought,
                index: 0,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final animatedContainers = tester.widgetList<AnimatedContainer>(find.byType(AnimatedContainer));
      bool foundBlackBorder = false;

      for (final ac in animatedContainers) {
        if (ac.decoration is BoxDecoration) {
          final box = ac.decoration as BoxDecoration;
          if (box.border != null && box.border is Border) {
            final border = box.border as Border;
            // Border should be dark/black
            if (border.top.color.r < 0.15 && border.top.color.g < 0.15 && border.top.color.b < 0.15) {
              foundBlackBorder = true;
            }
          }
        }
      }

      expect(foundBlackBorder, isTrue, reason: 'Thought card container must have crisp dark/black border');
    });
  });
}
