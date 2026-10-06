import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../repository/local/local_application_repository.dart';
import '../repository/local/local_consistency_repository.dart';
import '../repository/local/local_dsa_repository.dart';
import '../repository/local/local_notes_repository.dart';
import '../repository/local/local_task_repository.dart';
import '../repository/local/local_user_profile_repository.dart';
import '../repository/repository_interface.dart';

// ---------------------------------------------------------------------------
// Database singleton
// ---------------------------------------------------------------------------

/// Provides the single [AppDatabase] instance for the app lifetime.
/// The database is closed when the provider is disposed (e.g., in tests).
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

// ---------------------------------------------------------------------------
// DAO providers
// ---------------------------------------------------------------------------

final userProfileDaoProvider = Provider<UserProfileDao>(
  (ref) => UserProfileDao(ref.watch(databaseProvider)),
);

final taskDaoProvider = Provider<TaskDao>(
  (ref) => TaskDao(ref.watch(databaseProvider)),
);

final applicationDaoProvider = Provider<ApplicationDao>(
  (ref) => ApplicationDao(ref.watch(databaseProvider)),
);

final consistencyDaoProvider = Provider<ConsistencyDao>(
  (ref) => ConsistencyDao(ref.watch(databaseProvider)),
);

final dsaDaoProvider = Provider<DsaDao>(
  (ref) => DsaDao(ref.watch(databaseProvider)),
);

final notesDaoProvider = Provider<NotesDao>(
  (ref) => NotesDao(ref.watch(databaseProvider)),
);

final seriesDaoProvider = Provider<SeriesDao>(
  (ref) => SeriesDao(ref.watch(databaseProvider)),
);

final studyPhaseDaoProvider = Provider<StudyPhaseDao>(
  (ref) => StudyPhaseDao(ref.watch(databaseProvider)),
);

final resumeDaoProvider = Provider<ResumeDao>(
  (ref) => ResumeDao(ref.watch(databaseProvider)),
);

final interviewPrepDaoProvider = Provider<InterviewPrepDao>(
  (ref) => InterviewPrepDao(ref.watch(databaseProvider)),
);

final insightDismissalDaoProvider = Provider<InsightDismissalDao>(
  (ref) => InsightDismissalDao(ref.watch(databaseProvider)),
);

final timeSessionDaoProvider = Provider<TimeSessionDao>(
  (ref) => TimeSessionDao(ref.watch(databaseProvider)),
);

final upcomingInterviewDaoProvider = Provider<UpcomingInterviewDao>(
  (ref) => UpcomingInterviewDao(ref.watch(databaseProvider)),
);

final reminderDaoProvider = Provider<ReminderDao>(
  (ref) => ReminderDao(ref.watch(databaseProvider)),
);

final financeDaoProvider = Provider<FinanceDao>(
  (ref) => FinanceDao(ref.watch(databaseProvider)),
);

final walkDaoProvider = Provider<WalkDao>(
  (ref) => WalkDao(ref.watch(databaseProvider)),
);

final habitDaoProvider = Provider<HabitDao>(
  (ref) => HabitDao(ref.watch(databaseProvider)),
);

final aiAssistantDaoProvider = Provider<AiAssistantDao>(
  (ref) => AiAssistantDao(ref.watch(databaseProvider)),
);

final waterDaoProvider = Provider<WaterDao>(
  (ref) => WaterDao(ref.watch(databaseProvider)),
);

final thoughtDaoProvider = Provider<ThoughtDao>(
  (ref) => ThoughtDao(ref.watch(databaseProvider)),
);

// ── Finance Reactive Stream Providers ─────────────────────────────────────────

final todaySpendingStreamProvider = StreamProvider<double>((ref) {
  final dao = ref.watch(financeDaoProvider);
  return dao.watchTodaySpending();
});

final currentMonthSpendingStreamProvider = StreamProvider<double>((ref) {
  final dao = ref.watch(financeDaoProvider);
  final now = DateTime.now();
  return dao.watchMonthSpending(now.year, now.month);
});

final currentMonthIncomeStreamProvider = StreamProvider<double>((ref) {
  final dao = ref.watch(financeDaoProvider);
  final now = DateTime.now();
  return dao.watchMonthIncome(now.year, now.month);
});

final overallBudgetStreamProvider = StreamProvider<FinanceBudget?>((ref) {
  final dao = ref.watch(financeDaoProvider);
  return dao.watchOverallBudget();
});

final recentTransactionsStreamProvider = StreamProvider<List<FinanceTransaction>>((ref) {
  final dao = ref.watch(financeDaoProvider);
  return dao.watchRecentTransactions(limit: 25);
});

final savingsGoalsStreamProvider = StreamProvider<List<SavingsGoal>>((ref) {
  final dao = ref.watch(financeDaoProvider);
  return dao.watchSavingsGoals();
});

// ── Walk & Activity Stream Providers ──────────────────────────────────────────

final todayWalkDistanceStreamProvider = StreamProvider<double>((ref) {
  final dao = ref.watch(walkDaoProvider);
  return dao.watchTodayDistance();
});

final weekWalkDistanceStreamProvider = StreamProvider<double>((ref) {
  final dao = ref.watch(walkDaoProvider);
  return dao.watchWeekDistance();
});

final completedWalksStreamProvider = StreamProvider<List<WalkSession>>((ref) {
  final dao = ref.watch(walkDaoProvider);
  return dao.watchCompletedWalks();
});

final activityGoalStreamProvider = StreamProvider<DailyActivityGoal>((ref) {
  final dao = ref.watch(walkDaoProvider);
  return dao.watchActivityGoal();
});

// ── Habits Stream Providers ───────────────────────────────────────────────────

final allHabitsStreamProvider = StreamProvider<List<Habit>>((ref) {
  final dao = ref.watch(habitDaoProvider);
  return dao.watchAllHabits();
});

final todayCompletedHabitIdsStreamProvider = StreamProvider<Set<int>>((ref) {
  final dao = ref.watch(habitDaoProvider);
  return dao.watchTodayCompletedHabitIds();
});

// ── Water Hydration Stream Providers ──────────────────────────────────────────

final todayWaterMlStreamProvider = StreamProvider<int>((ref) {
  final dao = ref.watch(waterDaoProvider);
  return dao.watchTodayWaterMl();
});

final todayWaterLogsStreamProvider = StreamProvider<List<WaterLog>>((ref) {
  final dao = ref.watch(waterDaoProvider);
  return dao.watchTodayWaterLogs();
});

final dailyWaterGoalStreamProvider = StreamProvider<int>((ref) {
  final dao = ref.watch(waterDaoProvider);
  return dao.watchDailyWaterGoal();
});

// ── Thought Wall & Mind Space Stream Providers ────────────────────────────────

final allThoughtsStreamProvider = StreamProvider<List<Thought>>((ref) {
  final dao = ref.watch(thoughtDaoProvider);
  return dao.watchAllThoughts();
});

final recentThoughtsStreamProvider = StreamProvider<List<Thought>>((ref) {
  final dao = ref.watch(thoughtDaoProvider);
  return dao.watchRecentThoughts(limit: 6);
});

// ── Reminders & Interviews ───────────────────────────────────────────────────

final nextUpcomingReminderProvider = StreamProvider<Reminder?>((ref) {
  final dao = ref.watch(reminderDaoProvider);
  return dao.watchNextReminder();
});

final allRemindersProvider = StreamProvider<List<Reminder>>((ref) {
  final dao = ref.watch(reminderDaoProvider);
  return dao.watchAllReminders();
});

final allUpcomingInterviewsProvider = StreamProvider<List<UpcomingInterview>>((ref) {
  final dao = ref.watch(upcomingInterviewDaoProvider);
  return dao.watchUpcomingInterviews();
});

final mostRecentNoteProvider = StreamProvider<Note?>((ref) {
  final dao = ref.watch(notesDaoProvider);
  return dao.watchAllNotes().map((list) => list.firstOrNull);
});

// ---------------------------------------------------------------------------
// Repository providers (backed by local DAOs)
// ---------------------------------------------------------------------------

final userProfileRepositoryProvider = Provider<IUserProfileRepository>(
  (ref) => LocalUserProfileRepository(ref.watch(userProfileDaoProvider)),
);

final taskRepositoryProvider = Provider<ITaskRepository>(
  (ref) => LocalTaskRepository(ref.watch(taskDaoProvider)),
);

final applicationRepositoryProvider = Provider<IApplicationRepository>(
  (ref) => LocalApplicationRepository(ref.watch(applicationDaoProvider)),
);

final consistencyRepositoryProvider = Provider<IConsistencyRepository>(
  (ref) => LocalConsistencyRepository(ref.watch(consistencyDaoProvider)),
);

final dsaRepositoryProvider = Provider<IDsaRepository>(
  (ref) => LocalDsaRepository(ref.watch(dsaDaoProvider)),
);

final notesRepositoryProvider = Provider<INotesRepository>(
  (ref) => LocalNotesRepository(ref.watch(notesDaoProvider)),
);

// ---------------------------------------------------------------------------
// Reactive stream providers for screens (Home, Drawer, More, etc.)
// ---------------------------------------------------------------------------

class HomeQuickStats {
  final int dsaSolvedThisWeek;
  final int activeApplications;
  final double hoursThisWeek;

  HomeQuickStats({
    required this.dsaSolvedThisWeek,
    required this.activeApplications,
    required this.hoursThisWeek,
  });
}

final userProfileStreamProvider = StreamProvider<UserProfile?>((ref) {
  final dao = ref.watch(userProfileDaoProvider);
  return dao.watchProfile();
});

final todayTasksStreamProvider = StreamProvider<List<Task>>((ref) {
  final dao = ref.watch(taskDaoProvider);
  return dao.watchTasksByDate(DateTime.now());
});

final todayFocusTaskProvider = FutureProvider<Task?>((ref) async {
  final dao = ref.watch(taskDaoProvider);
  final overdue = await dao.watchOverdueTasks().first;
  if (overdue.isNotEmpty) return overdue.first;

  final todayTasks = await dao.watchTasksByDate(DateTime.now()).first;
  final pending = todayTasks.where((t) => t.actualCompletedDate == null).toList();
  if (pending.isNotEmpty) return pending.first;

  return null;
});

final currentStreakStreamProvider = StreamProvider<int>((ref) {
  final dao = ref.watch(consistencyDaoProvider);
  return dao.watchCurrentStreak();
});

final todayLogStreamProvider = FutureProvider<ConsistencyLog?>((ref) async {
  final dao = ref.watch(consistencyDaoProvider);
  return dao.getTodayLog();
});

final homeQuickStatsProvider = FutureProvider<HomeQuickStats>((ref) async {
  final dsaDao = ref.watch(dsaDaoProvider);
  final appDao = ref.watch(applicationDaoProvider);
  final sessionDao = ref.watch(timeSessionDaoProvider);

  final dsaCount = await dsaDao.getSolvedCountThisWeek();
  final allApps = await appDao.watchAllApplications().first;
  final activeApps = allApps.where((a) => a.currentStage != 'rejected' && a.currentStage != 'offer').length;

  // Compute real hours this week from time sessions
  final now = DateTime.now();
  final weekStart = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
  final sessions = await sessionDao.getSessionsBetween(weekStart, now.add(const Duration(days: 1)));
  int totalSeconds = 0;
  for (final s in sessions) {
    if (s.activityType.toLowerCase() == 'entertainment') continue;
    totalSeconds += TimeSessionDao.computeActiveDurationSeconds(
      s.startedAt,
      s.endedAt ?? (s.status == 'running' ? DateTime.now() : s.startedAt),
      s.pausedIntervals,
    );
  }
  final hoursThisWeek = totalSeconds / 3600.0;

  return HomeQuickStats(
    dsaSolvedThisWeek: dsaCount,
    activeApplications: activeApps,
    hoursThisWeek: hoursThisWeek,
  );
});

final nextUpcomingInterviewProvider = StreamProvider<UpcomingInterview?>((ref) {
  final dao = ref.watch(upcomingInterviewDaoProvider);
  return dao.watchNextInterview();
});

// ---------------------------------------------------------------------------
// Unified Today Activities Model (§2.2, §5.3)
// ---------------------------------------------------------------------------

enum TodayActivityStatus {
  notStarted,
  inProgress,
  paused,
  done,
}

enum ActivityKind {
  todo,
  duration,
  flexible,
}

class TodayActivityItem {
  final String id;
  final String title;
  final String sourceType; // 'task' | 'dsa' | 'prep' | 'custom' | 'session'
  final TodayActivityStatus status;
  final int elapsedSecondsToday;
  final int? linkedTaskId;
  final int? linkedSessionId;
  final String categoryTag;
  final String? priority;
  final ActivityKind kind;
  final int? targetMinutes;
  final DateTime? plannedDate;
  final bool isOverdue;
  final String? notes;

  const TodayActivityItem({
    required this.id,
    required this.title,
    required this.sourceType,
    required this.status,
    required this.elapsedSecondsToday,
    this.linkedTaskId,
    this.linkedSessionId,
    required this.categoryTag,
    this.priority,
    this.kind = ActivityKind.todo,
    this.targetMinutes,
    this.plannedDate,
    this.isOverdue = false,
    this.notes,
  });

  TodayActivityItem copyWith({
    String? id,
    String? title,
    String? sourceType,
    TodayActivityStatus? status,
    int? elapsedSecondsToday,
    int? linkedTaskId,
    int? linkedSessionId,
    String? categoryTag,
    String? priority,
    ActivityKind? kind,
    int? targetMinutes,
    DateTime? plannedDate,
    bool? isOverdue,
    String? notes,
  }) {
    return TodayActivityItem(
      id: id ?? this.id,
      title: title ?? this.title,
      sourceType: sourceType ?? this.sourceType,
      status: status ?? this.status,
      elapsedSecondsToday: elapsedSecondsToday ?? this.elapsedSecondsToday,
      linkedTaskId: linkedTaskId ?? this.linkedTaskId,
      linkedSessionId: linkedSessionId ?? this.linkedSessionId,
      categoryTag: categoryTag ?? this.categoryTag,
      priority: priority ?? this.priority,
      kind: kind ?? this.kind,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      plannedDate: plannedDate ?? this.plannedDate,
      isOverdue: isOverdue ?? this.isOverdue,
      notes: notes ?? this.notes,
    );
  }
}


