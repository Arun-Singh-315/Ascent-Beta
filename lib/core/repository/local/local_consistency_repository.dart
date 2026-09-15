import '../../database/app_database.dart';
import '../repository_interface.dart';

class LocalConsistencyRepository implements IConsistencyRepository {
  final ConsistencyDao _dao;

  const LocalConsistencyRepository(this._dao);

  @override
  Future<void> logDay(
    DateTime date,
    bool present, {
    String? note,
    double? hoursStudied,
  }) =>
      _dao.logDay(date, present, note: note, hoursStudied: hoursStudied);

  @override
  Stream<int> watchCurrentStreak() => _dao.watchCurrentStreak();

  @override
  Future<int> getLongestStreak() => _dao.getLongestStreak();

  @override
  Future<ConsistencyLog?> getTodayLog() => _dao.getTodayLog();
}
