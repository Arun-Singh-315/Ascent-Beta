import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/services/plan_collection_service.dart';
import 'package:ascent/core/services/plan_generator.dart';
import 'package:ascent/features/plans/widgets/plan_generator_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  final now = DateTime(2026, 11, 21, 10);

  group('study plans', () {
    test('DSA gets real topics, revision days and a mock test', () {
      final p = generateStudyPlan(
        subject: 'DSA',
        days: 14,
        minutes: 60,
        time: const TimeOfDay(hour: 7, minute: 0),
        now: now,
      );
      expect(p.title, 'DSA in 14 days');
      expect(p.items, hasLength(14));
      expect(p.items.first.title, 'Arrays and two pointers');
      expect(
        p.items.first.at,
        DateTime(2026, 11, 22, 7),
        reason: '7:00 passed',
      );
      expect(p.items[3].title, startsWith('Revise: '));
      expect(p.items.last.title, 'Mock test and review');
      expect(p.items.every((i) => i.minutes == 60), isTrue);
    });

    test('an unknown subject still gets a sensible arc', () {
      final p = generateStudyPlan(
        subject: 'Guitar',
        days: 7,
        minutes: 30,
        time: const TimeOfDay(hour: 20, minute: 0),
        now: now,
      );
      expect(p.items.first.title, 'Get an overview of Guitar');
      expect(p.items.first.at, DateTime(2026, 11, 21, 20), reason: 'today');
    });
  });

  group('meal plans', () {
    test('three meals a day, no repeats in a week, past meals skipped', () {
      final p = generateMealPlan(goal: MealGoal.protein, days: 7, now: now);
      // Today's breakfast (8:30) has passed: 20 meals, not 21.
      expect(p.items, hasLength(20));
      final lunches = p.items
          .where((i) => i.title.startsWith('Lunch'))
          .map((i) => i.title)
          .toSet();
      expect(lunches, hasLength(7));
    });

    test('every generated plan saves', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final service = PlanCollectionService(db, clock: () => now);
      for (final goal in MealGoal.values) {
        final p = generateMealPlan(goal: goal, days: 14, now: now);
        final id = await service.save(
          title: p.title,
          items: [for (final i in p.items) i.toDraft()],
          requestId: 'meal_${goal.name}',
        );
        expect(await service.watchItems(id).first, hasLength(p.items.length));
      }
    });
  });

  testWidgets('study sheet: type a subject, see the plan, create it', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: Scaffold(
            // Saving uses the real clock, so the sheet must too.
            body: const PlanGeneratorSheet(
              kind: PlanKind.study,
              clock: DateTime.now,
            ),
          ),
        ),
      ),
    );
    await tester.enterText(
      find.descendant(
        of: find.byKey(const ValueKey('plan_generator_subject')),
        matching: find.byType(EditableText),
      ),
      'Python',
    );
    await tester.pump();
    expect(find.text('Syntax, variables and types'), findsOneWidget);
    expect(find.byKey(const ValueKey('plan_generator_more')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan_generator_create')));
    for (var i = 0; i < 6; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    final plans = await tester.runAsync(
      () => db.select(db.planCollectionTable).get(),
    );
    expect(plans!.single.title, 'Python in 14 days');
  });
}
