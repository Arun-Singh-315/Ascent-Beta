import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/services/promise_service.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  late DateTime now;
  late PromiseService service;
  late Map<int, String> alerts;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    now = DateTime(2026, 10, 24, 11);
    alerts = {};
    service = PromiseService(
      db,
      clock: () => now,
      scheduleNotification: (id, copy, at) async {
        alerts[id] = copy;
      },
      cancelNotification: (id) async {
        alerts.remove(id);
      },
    );
  });

  tearDown(() => db.close());

  group('Promise Privacy Notification Tests', () {
    test('public promises display clear titles in scheduled check-in notifications', () async {
      await db.userProfileDao.upsertProfile(
        UserProfileTableCompanion.insert(name: 'Arun Singh'),
      );
      await service.create(content: 'Read 20 pages');
      expect(alerts, isNotEmpty);
      final alertText = alerts.values.first;
      expect(alertText, contains('1. Read 20 pages'));
      expect(alertText, isNot(contains('confidential')));
    });

    test('private promise masks content on system notifications to protect personal secrets', () async {
      await db.userProfileDao.upsertProfile(
        UserProfileTableCompanion.insert(name: 'Arun Singh'),
      );

      // Insert 1 public promise and 1 private/confidential promise
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Public run in park',
          mood: const drift.Value('promise'),
          category: const drift.Value('general'),
          createdAt: drift.Value(now),
          isCompleted: const drift.Value(false),
        ),
      );

      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Deep personal promise confidential',
          mood: const drift.Value('promise'),
          category: const drift.Value('private'),
          createdAt: drift.Value(now),
          isCompleted: const drift.Value(false),
        ),
      );

      await service.syncCheckIns();
      expect(alerts, isNotEmpty);
      final alertText = alerts.values.first;

      // Public promise is visible
      expect(alertText, contains('Public run in park'));

      // Private promise content is completely masked!
      expect(alertText, isNot(contains('Deep personal promise confidential')));
      expect(alertText, contains('🔒 Confidential commitment'));
    });

    test('all private promises show clean discreet safe notification copy', () async {
      await db.userProfileDao.upsertProfile(
        UserProfileTableCompanion.insert(name: 'Arun Singh'),
      );

      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Secret personal commitment 1',
          mood: const drift.Value('promise'),
          category: const drift.Value('private'),
          createdAt: drift.Value(now),
          isCompleted: const drift.Value(false),
        ),
      );

      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Secret personal commitment 2',
          mood: const drift.Value('promise'),
          category: const drift.Value('private'),
          createdAt: drift.Value(now),
          isCompleted: const drift.Value(false),
        ),
      );

      await service.syncCheckIns();
      expect(alerts, isNotEmpty);
      final alertText = alerts.values.first;

      expect(alertText, isNot(contains('Secret personal commitment')));
      expect(alertText, contains('🔒 2 confidential commitments waiting for your check-in'));
    });
  });
}
