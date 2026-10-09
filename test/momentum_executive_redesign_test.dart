import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/momentum/momentum_screen.dart';

void main() {
  group('Momentum Executive Redesign UI Tests', () {
    testWidgets('MomentumDayCapsuleStrip renders day capsules with active selection and completion indicators', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData.dark().copyWith(
            extensions: const [AscentGlass.dark],
          ),
          home: Scaffold(
            body: MomentumDayCapsuleStrip(
              selectedDayNumber: 1,
              currentDayNumber: 1,
              completedDayNumbers: const {1},
              onSelectDay: (_) {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Day capsules rendered
      expect(find.text('D1'), findsOneWidget);
      expect(find.text('D2'), findsOneWidget);
    });

    testWidgets('MomentumExecutiveNextActionCard renders category icon, title, and action button', (tester) async {
      final commitment = MomentumCommitment(
        id: 1,
        challengeId: 1,
        dayNumber: 1,
        scheduledDate: DateTime(2026, 10, 9),
        scheduledTimeMinutes: 420, // 07:00
        commitmentType: 'gym',
        title: 'Strength & Core Workout',
        description: 'Upper body hypertrophy + functional core',
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
            body: MomentumExecutiveNextActionCard(
              commitment: commitment,
              onActionTap: () {},
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('Strength & Core Workout'), findsOneWidget);
      expect(find.text('Upper body hypertrophy + functional core'), findsOneWidget);
      expect(find.text('Start Gym'), findsOneWidget);
      expect(find.byIcon(Icons.fitness_center_rounded), findsOneWidget);
    });
  });
}
