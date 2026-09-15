import '../../database/app_database.dart';
import '../../database/tables/enums.dart';
import '../repository_interface.dart';

class LocalApplicationRepository implements IApplicationRepository {
  final ApplicationDao _dao;

  const LocalApplicationRepository(this._dao);

  @override
  Stream<List<ApplicationRow>> watchAllApplications() =>
      _dao.watchAllApplications();

  @override
  Future<int> insertApplication(ApplicationTableCompanion companion) =>
      _dao.insertApplication(companion);

  @override
  Future<void> moveToStage(
    int id,
    ApplicationStage stage, {
    String? notes,
  }) =>
      _dao.moveToStage(id, stage, notes: notes);

  @override
  Stream<List<ApplicationStatusHistory>> watchStatusHistory(
    int applicationId,
  ) =>
      _dao.watchStatusHistory(applicationId);
}
