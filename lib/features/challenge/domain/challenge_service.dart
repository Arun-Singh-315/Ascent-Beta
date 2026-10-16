import 'package:drift/drift.dart' as drift;

import '../../../core/database/app_database.dart';
import 'challenge_pace_engine.dart';

class ChallengeService {
  ChallengeService(this._db);

  final AppDatabase _db;

  Future<int> create({
    required String type,
    required String title,
    required String sourceType,
    required String sourceId,
    required double targetTotal,
    required double dailyMinimum,
    required int durationDays,
    int? linkedPromiseThoughtId,
    DateTime? now,
  }) async {
    if (!{'activity', 'learning'}.contains(type)) {
      throw ArgumentError.value(type, 'type');
    }
    final cleanTitle = title.trim();
    if (cleanTitle.isEmpty || cleanTitle.length > 200) {
      throw ArgumentError.value(title, 'title', 'Use 1 to 200 characters.');
    }
    if (sourceId.trim().isEmpty || targetTotal <= 0 || dailyMinimum <= 0) {
      throw ArgumentError('Select a valid source and positive target.');
    }
    if (durationDays < 1 || durationDays > 365) {
      throw RangeError.range(durationDays, 1, 365, 'durationDays');
    }

    final start = now ?? DateTime.now();
    final startDay = DateTime(start.year, start.month, start.day);
    final endDay = startDay.add(Duration(days: durationDays - 1));
    late final int id;
    await _db.transaction(() async {
      id = await _db.challengeDao.insertChallenge(
        ChallengeTableCompanion.insert(
          type: type,
          title: cleanTitle,
          unit: const drift.Value('minutes'),
          targetTotal: targetTotal,
          dailyMinimum: dailyMinimum,
          startDay: formatChallengeDay(startDay),
          endDay: formatChallengeDay(endDay),
          lockedAt: drift.Value(start),
        ),
      );
      await _db.challengeDao.insertLink(
        ChallengeLinkTableCompanion.insert(
          challengeId: id,
          sourceType: sourceType,
          sourceId: sourceId,
          linkedAt: drift.Value(start),
        ),
      );
      if (linkedPromiseThoughtId != null) {
        final thought = await _db.thoughtDao.getThoughtById(
          linkedPromiseThoughtId,
        );
        if (thought == null || thought.mood != 'promise') {
          throw StateError('The linked Promise could not be found.');
        }
        await _db.challengeDao.insertLink(
          ChallengeLinkTableCompanion.insert(
            challengeId: id,
            sourceType: 'promise_context',
            sourceId: linkedPromiseThoughtId.toString(),
            linkedAt: drift.Value(start),
          ),
        );
      }
    });
    return id;
  }

  Future<void> archive(int id) => _db.challengeDao.setStatus(id, 'archived');

  Future<void> delete(int id) => _db.challengeDao.deleteChallenge(id);
}
