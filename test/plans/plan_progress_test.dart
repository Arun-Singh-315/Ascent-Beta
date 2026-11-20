import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/services/plan_collection_service.dart';
import 'package:ascent/features/plans/plan_progress.dart';
import 'package:ascent/features/plans/plan_templates.dart';
import 'package:ascent/features/plans/widgets/plan_progress_card.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('progress', () {
    final now = DateTime(2026, 11, 21, 12); // Saturday noon
    PlanSession s(int daysAgo, {bool done = false, int h = 7}) => PlanSession(
      at: DateTime(2026, 11, 21 - daysAgo, h),
      done: done,
      skipped: false,
      taskId: 100 + daysAgo,
    );

    test('all done is on track with a streak', () {
      final p = PlanProgress.from([
        for (var d = 0; d < 5; d++) s(d, done: true),
      ], now);
      expect(p.onTrack, isTrue);
      expect(p.streak, 5);
      expect(p.week.last.$2, PlanDayState.done);
    });

    test('missed sessions are counted and can be caught up', () {
      final p = PlanProgress.from([
        s(3, done: true),
        s(2),
        s(1),
        s(0, h: 20), // later today: not missed yet
      ], now);
      expect(p.behind, 2);
      expect(p.missedTaskIds, [102, 101]);
      expect(p.week[4].$2, PlanDayState.missed);
      expect(p.week.last.$2, PlanDayState.upcoming);
    });

    test('one missed day is forgiven in a streak', () {
      final p = PlanProgress.from([
        s(4, done: true),
        s(3, done: true),
        s(2),
        s(1, done: true),
      ], now);
      expect(p.streak, 3);
    });

    test('day number and range come from the sessions', () {
      final p = PlanProgress.from([s(2, done: true), s(-5)], now);
      expect(p.dayNumber, 3);
      expect(p.totalDays, 8);
    });
  });

  group('plan from a sentence', () {
    final now = DateTime(2026, 11, 21, 10);

    test('Study DSA 1 hour daily till 15 Jan', () {
      final t = planFromSentence('Study DSA 1 hour daily till 15 Jan', now);
      final step = t.steps.single;
      expect(step.title, 'Study DSA');
      expect(step.minutes, 60);
      expect(step.repeat, PlanRepeat.daily);
      expect(t.weeks, 8);
    });

    test('weekday gym at 7 for 6 weeks', () {
      final t = planFromSentence(
        'Gym every weekday at 7am 45 min for 6 weeks',
        now,
      );
      final step = t.steps.single;
      expect(step.title, 'Gym');
      expect(step.repeat, PlanRepeat.weekdays);
      expect(step.time, const TimeOfDay(hour: 7, minute: 0));
      expect(step.minutes, 45);
      expect(t.weeks, 6);
    });

    test('evening words pick an evening time', () {
      final t = planFromSentence('Read 20 minutes every evening', now);
      expect(t.steps.single.time.hour, 20);
      expect(t.steps.single.title, 'Read');
    });
  });

  testWidgets(
    'Catch up skips missed sessions and adds them to today, with Undo',
    (tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final started = DateTime.now().subtract(const Duration(days: 3));
      late String id;
      await tester.runAsync(() async {
        id = await PlanCollectionService(db, clock: () => started).save(
          title: 'Walks',
          items: draftsFor(
            const [
              PlanStep(title: 'Walk', time: TimeOfDay(hour: 6, minute: 0)),
            ],
            start: started,
            weeks: 2,
            now: started,
          ),
          requestId: 'catch_up_test',
        );
      });
      await tester.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(body: PlanProgressCard(collectionId: id)),
          ),
        ),
      );
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('behind'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('plan_catch_up')));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.textContaining('added to today'), findsOneWidget);
      var tasks = await tester.runAsync(() => db.select(db.taskTable).get());
      final catchUps = tasks!.where((t) => t.title == 'Walk (catch up)');
      expect(catchUps.length, greaterThanOrEqualTo(2));
      expect(find.textContaining('behind'), findsNothing);

      await tester.tap(find.text('Undo'));
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
      tasks = await tester.runAsync(() => db.select(db.taskTable).get());
      expect(tasks!.where((t) => t.title == 'Walk (catch up)'), isEmpty);
      expect(find.textContaining('behind'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 9));
    },
  );
}
