import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/promises/promise_check_in_sheet.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  group('Promise Conversational Check-in Sheet Tests', () {
    testWidgets('steps through promises one-by-one with Kept and Slipped actions', (tester) async {
      final now = DateTime.now();

      final id1 = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'No smoking today',
          mood: const drift.Value('promise'),
          createdAt: drift.Value(now),
          isCompleted: const drift.Value(false),
        ),
      );

      final id2 = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Read 20 pages',
          mood: const drift.Value('promise'),
          createdAt: drift.Value(now),
          isCompleted: const drift.Value(false),
        ),
      );

      final t1 = (await db.thoughtDao.getThoughtById(id1))!;
      final t2 = (await db.thoughtDao.getThoughtById(id2))!;

      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          allThoughtsStreamProvider.overrideWith(
            (ref) => Stream.value([t1, t2]),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  onPressed: () => PromiseCheckInSheet.show(context),
                  child: const Text('Open Check-in'),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap open check-in
      await tester.tap(find.text('Open Check-in'));
      await tester.pumpAndSettle();

      // First promise shown
      expect(find.text('Promise 1 of 2'), findsOneWidget);
      expect(find.text('No smoking today'), findsOneWidget);

      // Tap Kept
      await tester.tap(find.byKey(const ValueKey('check_in_kept_button')));
      await tester.pumpAndSettle();

      // Second promise shown
      expect(find.text('Promise 2 of 2'), findsOneWidget);
      expect(find.text('Read 20 pages'), findsOneWidget);

      // Tap Slipped/Broke
      await tester.tap(find.byKey(const ValueKey('check_in_slipped_button')));
      await tester.pumpAndSettle();

      // Reflection reason options appear
      expect(find.text('What got in the way?'), findsOneWidget);
      await tester.tap(find.text('Distracted'));
      await tester.pumpAndSettle();

      // Final summary sheet shown
      expect(find.text('Accountability Summary'), findsOneWidget);
      expect(find.text('1 Kept • 1 Slipped'), findsOneWidget);

      // Finish check-in
      await tester.tap(find.text('Done'));
      await tester.pumpAndSettle();

      // Verify DB updates: promise 1 is completed, promise 2 has reflection recorded
      final thought1 = await db.thoughtDao.getThoughtById(id1);
      final thought2 = await db.thoughtDao.getThoughtById(id2);

      expect(thought1!.isCompleted, isTrue);
      expect(thought2!.isCompleted, isFalse);
      expect(thought2.promptQuestion, contains('Slipped: Distracted'));
    });
  });
}
