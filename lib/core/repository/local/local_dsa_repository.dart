import '../../database/app_database.dart';
import '../repository_interface.dart';

class LocalDsaRepository implements IDsaRepository {
  final DsaDao _dao;

  const LocalDsaRepository(this._dao);

  @override
  Stream<List<DsaLog>> watchAllLogs() => _dao.watchAllLogs();

  @override
  Future<int> insertLog(DsaLogTableCompanion companion) =>
      _dao.insertLog(companion);

  @override
  Future<int> getSolvedCountThisWeek() => _dao.getSolvedCountThisWeek();
}
