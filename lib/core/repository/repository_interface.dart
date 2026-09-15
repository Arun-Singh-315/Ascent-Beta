import '../database/app_database.dart';
import '../database/tables/enums.dart';

// ---------------------------------------------------------------------------
// IUserProfileRepository
// ---------------------------------------------------------------------------

abstract interface class IUserProfileRepository {
  /// Returns the singleton profile row, or null before onboarding.
  Future<UserProfile?> getProfile();

  /// Reactive stream of the profile row.
  Stream<UserProfile?> watchProfile();

  /// Insert or update the profile (conflict resolution on primary key).
  Future<int> upsertProfile(UserProfileTableCompanion companion);
}

// ---------------------------------------------------------------------------
// ITaskRepository
// ---------------------------------------------------------------------------

abstract interface class ITaskRepository {
  /// Stream of tasks that are past their plannedDate and not yet completed.
  Stream<List<Task>> watchOverdueTasks();

  /// Stream of tasks planned for the given calendar [date].
  Stream<List<Task>> watchTasksForDate(DateTime date);

  /// Stream of incomplete tasks due within the next [days] calendar days.
  Stream<List<Task>> watchUpcomingTasks(int days);

  /// Inserts a new task and returns its generated id.
  Future<int> insertTask(TaskTableCompanion companion);

  /// Updates the task.  Returns true if a row was modified.
  Future<bool> updateTask(TaskTableCompanion companion);

  /// Marks the task as complete (sets actualCompletedDate = now).
  Future<void> markComplete(int id);

  /// Deletes the task and returns the number of deleted rows.
  Future<int> deleteTask(int id);
}

// ---------------------------------------------------------------------------
// IApplicationRepository
// ---------------------------------------------------------------------------

abstract interface class IApplicationRepository {
  /// Stream of all applications, most recently updated first.
  Stream<List<ApplicationRow>> watchAllApplications();

  /// Inserts a new application (also records initial status history).
  Future<int> insertApplication(ApplicationTableCompanion companion);

  /// Moves the application to [stage] and records the transition.
  Future<void> moveToStage(
    int id,
    ApplicationStage stage, {
    String? notes,
  });

  /// Stream of status history for [applicationId], newest first.
  Stream<List<ApplicationStatusHistory>> watchStatusHistory(
    int applicationId,
  );
}

// ---------------------------------------------------------------------------
// IConsistencyRepository
// ---------------------------------------------------------------------------

abstract interface class IConsistencyRepository {
  /// Inserts or updates the consistency log entry for [date].
  Future<void> logDay(
    DateTime date,
    bool present, {
    String? note,
    double? hoursStudied,
  });

  /// Stream emitting the current consecutive streak (in days).
  Stream<int> watchCurrentStreak();

  /// Returns the all-time longest streak.
  Future<int> getLongestStreak();

  /// Returns today's log entry, or null.
  Future<ConsistencyLog?> getTodayLog();
}

// ---------------------------------------------------------------------------
// IDsaRepository
// ---------------------------------------------------------------------------

abstract interface class IDsaRepository {
  /// Stream of all DSA log entries, most recently solved first.
  Stream<List<DsaLog>> watchAllLogs();

  /// Inserts a new DSA log entry and returns its id.
  Future<int> insertLog(DsaLogTableCompanion companion);

  /// Number of problems solved in the current week.
  Future<int> getSolvedCountThisWeek();
}

// ---------------------------------------------------------------------------
// INotesRepository
// ---------------------------------------------------------------------------

abstract interface class INotesRepository {
  /// Stream of all notes, most recently updated first.
  Stream<List<Note>> watchAllNotes();

  /// Stream of notes whose title or content contains [query].
  Stream<List<Note>> searchNotes(String query);

  /// Inserts a new note and returns its id.
  Future<int> insertNote(NoteTableCompanion companion);

  /// Deletes the note and its tag rows.
  Future<void> deleteNote(int id);

  /// Stream of notes that have not been interacted with in [daysThreshold] days.
  Stream<List<Note>> watchStaleNotes(int daysThreshold);
}
