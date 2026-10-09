import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/momentum/momentum_screen.dart';

void main() {
  group('Momentum Night Mode Contrast and UI Polish Tests', () {
    testWidgets('Completed timeline item has clear strikethrough and does not use opaque white alpha in dark mode', (tester) async {
      final commitment = MomentumCommitment(
        id: 1,
        challengeId: 1,
        dayNumber: 1,
        scheduledDate: DateTime(2026, 10, 9),
        scheduledTimeMinutes: 435, // 07:15
        commitmentType: 'wake',
        title: 'Wake-Up Target (07:15)',
        description: 'Phase 1 Circadian Entrainment',
        isCompleted: true,
        wasAdapted: false,
        metadataJson: '{}',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const [AscentGlass.dark],
          ),
          home: Scaffold(
            body: TimelineItemCard(
              commitment: commitment,
              isFirst: true,
              isLast: false,
              isCurrent: false,
              onToggle: () {},
              onAction: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Find the title text widget
      final textFinder = find.text('Wake-Up Target (07:15)');
      expect(textFinder, findsOneWidget);

      final textWidget = tester.widget<Text>(textFinder);
      expect(textWidget.style?.decoration, TextDecoration.lineThrough);

      // Verify container decoration background color is dark glass, NOT 45% white
      final containers = tester.widgetList<Container>(find.byType(Container));
      for (final container in containers) {
        if (container.decoration is BoxDecoration) {
          final box = container.decoration as BoxDecoration;
          if (box.color != null && box.color != Colors.transparent) {
            // Alpha of 45% white is approx 114 (0.45 * 255)
            // It must NOT be anywhere near 0.45 white on a dark background
            if (box.color!.r > 0.9 && box.color!.g > 0.9 && box.color!.b > 0.9) {
              expect(box.color!.a < 0.20, isTrue,
                reason: 'Completed card must not use high-opacity white background in dark mode: ${box.color}');
            }
          }
        }
      }
    });

    testWidgets('MomentumProgressHeroCard renders spacious percentage and separate completion pill', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const [AscentGlass.dark],
          ),
          home: const Scaffold(
            body: MomentumProgressHeroCard(
              doneCount: 3,
              totalCount: 5,
              progressFraction: 0.6,
              selectedDayNumber: 1,
              currentDayNumber: 1,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Bold 60% rendered clearly
      expect(find.text('60%'), findsOneWidget);
      // Dedicated completion pill rendered
      expect(find.text('3 of 5 completed'), findsOneWidget);
      // Day badge rendered
      expect(find.text('TODAY'), findsOneWidget);
      // Status phrase rendered
      expect(find.text('Strong Steady Pace'), findsOneWidget);
    });
  });
}
