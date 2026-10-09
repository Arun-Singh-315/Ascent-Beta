import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;

import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/core/providers/database_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Timer Notification Architecture & Action Integrity Tests', () {
    test('Ongoing notification action constants contain strictly pause and resume', () {
      expect(NotificationService.actionPause, 'action_pause');
      expect(NotificationService.actionResume, 'action_resume');
      expect(NotificationService.isolatePortName, 'ascent_notification_actions_port');
    });

    test('Dedicated notification IDs separate Lecture, Focus, Walk, and Chai Break', () {
      expect(NotificationService.ongoingLectureNotificationId, 888800);
      expect(NotificationService.ongoingFocusNotificationId, 888803);
      expect(NotificationService.ongoingWalkNotificationId, 888801);
      expect(NotificationService.ongoingChaiBreakNotificationId, 888802);

      // Verify no ID collision across timers
      final ids = {
        NotificationService.ongoingLectureNotificationId,
        NotificationService.ongoingFocusNotificationId,
        NotificationService.ongoingWalkNotificationId,
        NotificationService.ongoingChaiBreakNotificationId,
      };
      expect(ids.length, 4);
    });
  });

  group('Module Independence: Todo Focus vs Learning Hub Tests', () {
    late AppDatabase db;
    late TimeSessionDao timeSessionDao;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      timeSessionDao = TimeSessionDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('watchActiveFocusSession ignores lecture sessions and isolates focus sessions', () async {
      // 1. Start a Lecture Session
      await timeSessionDao.startSession(
        label: 'Lecture: Flutter Deep Dive',
        categoryId: 1,
        activityRefType: 'lecture',
        activityType: 'study',
      );

      // 2. watchActiveSession sees it because it records all database sessions
      final generalActive = await timeSessionDao.getActiveSession();
      expect(generalActive, isNotNull);
      expect(generalActive!.activityRefType, 'lecture');

      // 3. BUT watchActiveFocusSession MUST NOT see the lecture session!
      final focusActive = await timeSessionDao.getActiveFocusSession();
      expect(focusActive, isNull);

      final focusStreamItem = await timeSessionDao.watchActiveFocusSession().first;
      expect(focusStreamItem, isNull);

      // 4. getActiveLectureSession specifically finds the lecture session
      final lectureActive = await timeSessionDao.getActiveLectureSession();
      expect(lectureActive, isNotNull);
      expect(lectureActive!.label, 'Lecture: Flutter Deep Dive');

      // 5. Now start a Todo Focus Task Session
      await timeSessionDao.startSession(
        label: 'Build Portfolio Resume',
        categoryId: 1,
        activityRefType: 'task',
        activityType: 'study',
      );

      // 6. Focus query sees the Task session independently
      final newFocusActive = await timeSessionDao.getActiveFocusSession();
      expect(newFocusActive, isNotNull);
      expect(newFocusActive!.label, 'Build Portfolio Resume');
      expect(newFocusActive.activityRefType, 'task');

      // 7. Lecture session is still queryable independently
      final lectureStillActive = await timeSessionDao.getActiveLectureSession();
      expect(lectureStillActive, isNotNull);
      expect(lectureStillActive!.label, 'Lecture: Flutter Deep Dive');
    });
  });

  group('Thought Wall WhatsApp Instant Composer Tests', () {
    late AppDatabase db;
    late ThoughtDao thoughtDao;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      thoughtDao = ThoughtDao(db);
    });

    tearDown(() async {
      await db.close();
    });

    test('Instant composer inserts thoughts with correct mood and color hex', () async {
      // 1. Insert a "Me to Me" self-talk message
      final id1 = await thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'You got this, stay focused on one problem at a time.',
          mood: const drift.Value('me_to_me'),
          colorHex: const drift.Value('#6366F1'),
          isPinned: const drift.Value(false),
          createdAt: drift.Value(DateTime.now().subtract(const Duration(seconds: 5))),
        ),
      );
      expect(id1, greaterThan(0));

      // 2. Insert a "Sparks / Idea" message (newer)
      final id2 = await thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Add an offline audio ambient sound generator for morning walk.',
          mood: const drift.Value('idea'),
          colorHex: const drift.Value('#D97706'),
          isPinned: const drift.Value(false),
          createdAt: drift.Value(DateTime.now()),
        ),
      );
      expect(id2, greaterThan(0));

      // 3. Verify thoughts appear in active thoughts stream in reverse chronological order
      final thoughts = await thoughtDao.watchActiveThoughts().first;
      expect(thoughts.length, 2);
      expect(thoughts.first.content, 'Add an offline audio ambient sound generator for morning walk.');
      expect(thoughts.first.mood, 'idea');
      expect(thoughts.last.content, 'You got this, stay focused on one problem at a time.');
      expect(thoughts.last.mood, 'me_to_me');
    });
  });
}
