import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/local_day_provider.dart';
import 'package:ascent/features/home/widgets/home_feed_entrance.dart';
import 'package:ascent/features/home/widgets/home_life_shelf.dart';
import 'package:ascent/features/home/widgets/home_resurfaced_thought.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('water pace', () {
    DateTime at(int h, [int m = 0]) => DateTime(2026, 11, 21, h, m);

    test('morning with nothing yet invites a first glass', () {
      expect(
        waterPaceLine(0, 2000, at(6)),
        'Start the day with a glass of water',
      );
    });
    test('on pace for the time of day', () {
      // 14:30 is half of 7:00–22:00, so 1,000 ml is on track.
      expect(waterPaceLine(1000, 2000, at(14, 30)), 'On track · 1000 ml to go');
    });
    test('behind for the time of day says how much and what helps', () {
      expect(
        waterPaceLine(250, 2000, at(14, 30)),
        'About 750 ml behind for now · a glass catches you up',
      );
    });
    test('goal reached', () {
      expect(waterPaceLine(2100, 2000, at(20)), 'Goal reached · 2000 ml today');
    });
    test('late at night it states the gap without nagging', () {
      expect(waterPaceLine(1500, 2000, at(23)), '500 ml short of today’s goal');
    });
  });

  group('resurfaced thought', () {
    late AppDatabase db;
    late ProviderContainer container;
    final today = DateTime(2026, 11, 21);

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          localDayProvider.overrideWithValue(today),
          privatePromiseIdsProvider.overrideWith((ref) => <int>{}),
        ],
      );
    });
    tearDown(() async {
      container.dispose();
      await db.close();
    });

    Future<int> add(String text, int daysAgo, {bool done = false}) =>
        db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: text,
            createdAt: Value(today.subtract(Duration(days: daysAgo))),
            isCompleted: Value(done),
          ),
        );

    Future<Thought?> pick() async {
      final sub = container.listen(resurfacedThoughtProvider.future, (_, _) {});
      addTearDown(sub.close);
      return sub.read();
    }

    test('picks an open thought from 3–60 days ago', () async {
      await add('Written today, too fresh', 0);
      await add('Ancient history from last year', 200);
      await add('Already finished this one', 10, done: true);
      final id = await add('Learn to make sourdough', 6);
      expect((await pick())?.id, id);
    });

    test('nothing to show when there is no older open thought', () async {
      await add('Only today', 0);
      expect(await pick(), isNull);
    });
  });

  testWidgets('feed entrance plays once and respects reduce motion', (
    tester,
  ) async {
    HomeFeedEntrance.reset();
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: HomeFeedEntrance(index: 2, child: Text('card')),
        ),
      ),
    );
    final opacity = tester.widget<Opacity>(
      find.ancestor(of: find.text('card'), matching: find.byType(Opacity)),
    );
    expect(opacity.opacity, 1, reason: 'reduce motion shows it at once');

    HomeFeedEntrance.reset();
    await tester.pumpWidget(
      const MaterialApp(home: HomeFeedEntrance(index: 1, child: Text('a'))),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: find.text('a'), matching: find.byType(Opacity)),
          )
          .opacity,
      1,
    );
    // Coming back to Home does not replay it.
    await tester.pumpWidget(
      const MaterialApp(home: HomeFeedEntrance(index: 1, child: Text('b'))),
    );
    expect(
      tester
          .widget<Opacity>(
            find.ancestor(of: find.text('b'), matching: find.byType(Opacity)),
          )
          .opacity,
      1,
    );
  });
}
