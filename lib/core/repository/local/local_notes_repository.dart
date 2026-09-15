import '../../database/app_database.dart';
import '../repository_interface.dart';

class LocalNotesRepository implements INotesRepository {
  final NotesDao _dao;

  const LocalNotesRepository(this._dao);

  @override
  Stream<List<Note>> watchAllNotes() => _dao.watchAllNotes();

  @override
  Stream<List<Note>> searchNotes(String query) => _dao.searchNotes(query);

  @override
  Future<int> insertNote(NoteTableCompanion companion) =>
      _dao.insertNote(companion);

  @override
  Future<void> deleteNote(int id) => _dao.deleteNote(id);

  @override
  Stream<List<Note>> watchStaleNotes(int daysThreshold) =>
      _dao.watchStaleNotes(daysThreshold);
}
