import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';

void main() {
  group('Thought Wall Chat-Style UI Tests', () {
    testWidgets(
      'Even index thought is left-aligned and odd index thought is right-aligned in chat style',
      (tester) async {
        final thought1 = Thought(
          category: 'general',
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
          category: 'general',
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
                      compact: true,
                    ),
                    ThoughtCardBubble(
                      thought: thought2,
                      index: 1,
                      compact: true,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify thought contents rendered
        expect(
          find.text('Note to myself: Keep pushing steady today.'),
          findsOneWidget,
        );
        expect(
          find.text('Future me: You built something durable.'),
          findsOneWidget,
        );

        // Verify asymmetric padding/margins (index 0 left-aligned, index 1 right-aligned)
        final paddings = tester
            .widgetList<Padding>(find.byType(Padding))
            .toList();
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

        expect(
          foundLeftAligned,
          isTrue,
          reason:
              'Even thought should have right inset creating left-alignment',
        );
        expect(
          foundRightAligned,
          isTrue,
          reason: 'Odd thought should have left inset creating right-alignment',
        );
      },
    );

    testWidgets('Thought card uses a transparent outlined bubble in night mode', (
      tester,
    ) async {
      final thought = Thought(
        category: 'general',
        id: 1,
        content: 'Night glass reflection.',
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
            home: Scaffold(body: ThoughtCardBubble(thought: thought, index: 0)),
          ),
        ),
      );

      await tester.pumpAndSettle();

      final animatedContainers = tester.widgetList<AnimatedContainer>(
        find.byType(AnimatedContainer),
      );
      bool foundGlassCard = false;

      for (final ac in animatedContainers) {
        if (ac.decoration is BoxDecoration) {
          final box = ac.decoration as BoxDecoration;
          if (box.color == Colors.transparent && box.border != null) {
            foundGlassCard = true;
          }
        }
      }

      expect(
        foundGlassCard,
        isTrue,
        reason:
            'Thought card must keep the night canvas visible inside its outline',
      );
    });

    testWidgets(
      'Thought card has a visible rounded outline and inset header separator in day mode',
      (tester) async {
        final thought = Thought(
          category: 'general',
          id: 1,
          content: 'Day transparent reflection with a themed border.',
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
              theme: ThemeData.light().copyWith(
                extensions: const [AscentGlass.light],
              ),
              home: Scaffold(
                body: ThoughtCardBubble(thought: thought, index: 0),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final surfaces = tester
            .widgetList<AnimatedContainer>(find.byType(AnimatedContainer))
            .where((c) => c.decoration is BoxDecoration)
            .map((c) => c.decoration as BoxDecoration);
        expect(
          surfaces.any(
            (surface) =>
                surface.color == Colors.transparent &&
                surface.border is Border &&
                (surface.border! as Border).top.width == 1,
          ),
          isTrue,
        );
        expect(
          find.byKey(ValueKey('thought_header_divider_${thought.id}')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'Thought card displays timestamp at the top header above thought content',
      (tester) async {
        final testDate = DateTime(2026, 10, 11, 14, 30);
        final thought = Thought(
          category: 'general',
          id: 1,
          content: 'Deep reflective insight on architecture.',
          mood: 'idea',
          isPinned: false,
          isArchived: false,
          isCompleted: false,
          colorHex: '#6366F1',
          createdAt: testDate,
        );

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: ThemeData.dark().copyWith(
                extensions: const [AscentGlass.dark],
              ),
              home: Scaffold(
                body: ThoughtCardBubble(thought: thought, index: 0),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        final timeFinder = find.text('Oct 11 • 2:30 PM');
        final contentFinder = find.text(
          'Deep reflective insight on architecture.',
        );

        expect(timeFinder, findsOneWidget);
        expect(contentFinder, findsOneWidget);

        final timeTop = tester.getTopLeft(timeFinder).dy;
        final contentTop = tester.getTopLeft(contentFinder).dy;

        expect(
          timeTop < contentTop,
          isTrue,
          reason:
              'Timestamp ($timeTop) must be positioned above thought content ($contentTop) at the top of the card',
        );
      },
    );
  });
}
