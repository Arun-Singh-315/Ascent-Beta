import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/momentum/momentum_screen.dart';

void main() {
  group('Momentum Executive Redesign UI Tests', () {
    testWidgets('MomentumDayCapsuleStrip renders plain 1..7 numbers and expands 31 days on More click', (tester) async {
      int selected = 1;
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const [AscentGlass.dark],
          ),
          home: Scaffold(
            body: MomentumDayCapsuleStrip(
              selectedDayNumber: selected,
              currentDayNumber: 1,
              completedDayNumbers: const {1},
              onSelectDay: (d) => selected = d,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify plain numbers 1..7 rendered (NO 'D' prefix)
      expect(find.text('1'), findsOneWidget);
      expect(find.text('2'), findsOneWidget);
      expect(find.text('7'), findsOneWidget);
      expect(find.text('D1'), findsNothing);
      expect(find.text('D2'), findsNothing);

      // Verify 'More' button is present
      expect(find.text('More'), findsOneWidget);

      // Tap 'More' to open 31-day inline matrix without scrolling
      await tester.tap(find.text('More'));
      await tester.pumpAndSettle();

      // Full 31 days matrix should now be visible on screen
      expect(find.text('ALL 31 DAYS'), findsOneWidget);
      expect(find.text('31'), findsOneWidget);
      expect(find.text('Close'), findsOneWidget);

      // Tap day 15 in the 31 matrix
      await tester.tap(find.text('15'));
      await tester.pumpAndSettle();
      expect(selected, 15);
    });

    testWidgets('MomentumExecutiveTodayActionCard unifies progress with straight linear bar and next action in one card', (tester) async {
      final commitment = MomentumCommitment(
        id: 1,
        challengeId: 1,
        dayNumber: 1,
        scheduledDate: DateTime(2026, 10, 9),
        scheduledTimeMinutes: 1050, // 17:30
        commitmentType: 'gym',
        title: 'Gym: Lower Body B (Hamstring & Glute Focus)',
        description: 'Leg Press, Hamstring Curls, Walking Lunges',
        isCompleted: false,
        wasAdapted: false,
        metadataJson: '{}',
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const [AscentGlass.dark],
          ),
          home: Scaffold(
            body: MomentumExecutiveTodayActionCard(
              doneCount: 3,
              totalCount: 5,
              progressFraction: 0.6,
              selectedDayNumber: 1,
              currentDayNumber: 1,
              nextCommitment: commitment,
              onActionTap: () {},
              onAdaptSession: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Progress section
      expect(find.text('60%'), findsOneWidget);
      expect(find.text('3 of 5 completed'), findsOneWidget);
      expect(find.text('Strong Steady Pace'), findsOneWidget);

      // Straight progress bar present (LinearProgressIndicator, not CircularProgressIndicator)
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);

      // Next Action unified in the same card
      expect(find.text('Gym: Lower Body B (Hamstring & Glute Focus)'), findsOneWidget);
      expect(find.text('Start Gym'), findsOneWidget);
      expect(find.text('Short on time? (20m express)'), findsOneWidget);
      expect(find.text('Move to evening'), findsOneWidget);
    });

    testWidgets('MomentumExecutiveTodayActionCard works seamlessly in Day/Light mode', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.light().copyWith(
            extensions: const [AscentGlass.light],
          ),
          home: const Scaffold(
            body: MomentumExecutiveTodayActionCard(
              doneCount: 5,
              totalCount: 5,
              progressFraction: 1.0,
              selectedDayNumber: 1,
              currentDayNumber: 1,
              nextCommitment: null,
              hasCommitments: true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('100%'), findsOneWidget);
      expect(find.text('5 of 5 completed'), findsOneWidget);
      expect(find.text('Daily Target Locked In'), findsOneWidget);
      expect(find.text('Day 1 Crushed! ⚡'), findsOneWidget);
      expect(find.byType(LinearProgressIndicator), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
    });
  });
}
