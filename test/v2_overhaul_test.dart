import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/home/plan_my_day_classifier.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('V2 Delta — UpcomingInterviewDao Tests', () {
    test('Can insert, retrieve, and clear upcoming interview', () async {
      final interviewDate = DateTime.now().add(const Duration(days: 14));

      // Initially empty
      final initial = await db.upcomingInterviewDao.getNextInterview();
      expect(initial, isNull);

      // Insert upcoming interview
      final interviewId = await db.upcomingInterviewDao.insertInterview(
        UpcomingInterviewTableCompanion.insert(
          companyName: 'Google',
          interviewDate: interviewDate,
          notes: const drift.Value('System Design Round'),
        ),
      );
      expect(interviewId, isNonZero);

      final next = await db.upcomingInterviewDao.getNextInterview();
      expect(next, isNotNull);
      expect(next!.companyName, 'Google');
      expect(next.notes, 'System Design Round');
      expect(next.interviewDate.day, interviewDate.day);

      // Clear all upcoming interviews
      await db.upcomingInterviewDao.clearAll();
      final cleared = await db.upcomingInterviewDao.getNextInterview();
      expect(cleared, isNull);
    });

    test('watchNextInterview emits reactive updates', () async {
      final stream = db.upcomingInterviewDao.watchNextInterview();
      expectLater(
        stream.map((i) => i?.companyName),
        emitsInOrder([
          isNull,
          'Anthropic',
          isNull,
        ]),
      );

      await Future.delayed(const Duration(milliseconds: 10));
      await db.upcomingInterviewDao.insertInterview(
        UpcomingInterviewTableCompanion.insert(
          companyName: 'Anthropic',
          interviewDate: DateTime.now().add(const Duration(days: 5)),
        ),
      );

      await Future.delayed(const Duration(milliseconds: 10));
      await db.upcomingInterviewDao.clearAll();
    });
  });

  group('V2 Delta — TimeSessionDao Write-Ahead & Heartbeat Tests', () {
    test('Supports durationSeconds, activityRefType, and heartbeat updates', () async {
      final now = DateTime.now();

      final sessionId = await db.timeSessionDao.startSession(
        label: 'LeetCode Dynamic Programming',
        categoryId: 1,
        activityType: 'DSA',
        activityRefType: 'dsa',
        startedAt: now,
      );

      expect(sessionId, isNonZero);

      var session = await (db.select(db.timeSessionTable)..where((t) => t.id.equals(sessionId))).getSingle();
      expect(session.status, 'running');
      expect(session.activityRefType, 'dsa');
      expect(session.durationSeconds, 0);

      // Simulate 10 seconds of heartbeat flush
      await db.timeSessionDao.heartbeat(sessionId, 10);

      session = await (db.select(db.timeSessionTable)..where((t) => t.id.equals(sessionId))).getSingle();
      expect(session.durationSeconds, 10);
      expect(session.lastHeartbeatAt, isNotNull);

      // Pause session
      await db.timeSessionDao.pauseSession(sessionId);
      session = await (db.select(db.timeSessionTable)..where((t) => t.id.equals(sessionId))).getSingle();
      expect(session.status, 'paused');

      // Complete session
      await db.timeSessionDao.completeSession(sessionId);
      session = await (db.select(db.timeSessionTable)..where((t) => t.id.equals(sessionId))).getSingle();
      expect(session.status, 'completed');
      expect(session.endedAt, isNotNull);
    });

    test('getTodayPausedSessionForTask finds paused session for task', () async {
      final now = DateTime.now();
      const taskId = 42;

      final sessionId = await intoSession(db, taskId: taskId, status: 'paused', duration: 300, now: now);

      final found = await db.timeSessionDao.getTodayPausedSessionForTask(taskId);
      expect(found, isNotNull);
      expect(found!.id, sessionId);
      expect(found.label, 'Graph BFS');
    });
  });

  group('V2 Delta — PlanMyDayClassifier Tests', () {
    test('Correctly categorizes DSA tasks and parses durations', () {
      final item = PlanMyDayClassifier.parse('Solve 3 LeetCode DP problems 45m');
      expect(item.category, 'DSA');
      expect(item.estimatedMinutes, 45);

      final item2 = PlanMyDayClassifier.parse('Review binary search and graphs');
      expect(item2.category, 'DSA');

      final item3 = PlanMyDayClassifier.parse('Neetcode 150 practice 2h');
      expect(item3.category, 'DSA');
      expect(item3.estimatedMinutes, 120);
    });

    test('Correctly categorizes Pipeline / Interview prep tasks', () {
      final item1 = PlanMyDayClassifier.parse('Follow up with Google recruiter');
      expect(item1.category, 'Pipeline');

      final item2 = PlanMyDayClassifier.parse('Apply to Stripe and Figma');
      expect(item2.category, 'Pipeline');

      final item3 = PlanMyDayClassifier.parse('Mock interview prep with John 1h');
      expect(item3.category, 'Pipeline');
      expect(item3.estimatedMinutes, 60);
    });

    test('Correctly categorizes Break tasks', () {
      final item1 = PlanMyDayClassifier.parse('Take a quick walk outside 20m');
      expect(item1.category, 'Break');
      expect(item1.estimatedMinutes, 20);

      final item2 = PlanMyDayClassifier.parse('Lunch break and coffee');
      expect(item2.category, 'Break');
    });

    test('Correctly categorizes Study tasks', () {
      final item1 = PlanMyDayClassifier.parse('Read Designing Data-Intensive Applications 1.5h');
      expect(item1.category, 'Study');
      expect(item1.estimatedMinutes, 90);

      final item2 = PlanMyDayClassifier.parse('System design video course');
      expect(item2.category, 'Study');
    });

    test('Falls back to General when no specific pattern matches', () {
      final item = PlanMyDayClassifier.parse('Clean desk and organize workspace');
      expect(item.category, 'General');
    });
  });
}

Future<int> intoSession(
  AppDatabase db, {
  required int taskId,
  required String status,
  required int duration,
  required DateTime now,
}) {
  return db.into(db.timeSessionTable).insert(
    TimeSessionTableCompanion.insert(
      categoryId: 1,
      activityType: drift.Value('DSA'),
      label: 'Graph BFS',
      startedAt: now,
      status: drift.Value(status),
      linkedTaskId: drift.Value(taskId),
      durationSeconds: drift.Value(duration),
    ),
  );
}
