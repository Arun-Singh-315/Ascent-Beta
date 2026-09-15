import '../../database/app_database.dart';
import '../repository_interface.dart';

class LocalTaskRepository implements ITaskRepository {
  final TaskDao _dao;

  const LocalTaskRepository(this._dao);

  @override
  Stream<List<Task>> watchOverdueTasks() => _dao.watchOverdueTasks();

  @override
  Stream<List<Task>> watchTasksForDate(DateTime date) =>
      _dao.watchTasksByDate(date);

  @override
  Stream<List<Task>> watchUpcomingTasks(int days) =>
      _dao.watchUpcomingTasks(days);

  @override
  Future<int> insertTask(TaskTableCompanion companion) =>
      _dao.insertTask(companion);

  @override
  Future<bool> updateTask(TaskTableCompanion companion) =>
      _dao.updateTask(companion);

  @override
  Future<void> markComplete(int id) => _dao.markComplete(id);

  @override
  Future<int> deleteTask(int id) => _dao.deleteTask(id);
}
