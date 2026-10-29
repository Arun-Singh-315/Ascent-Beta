import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../database/app_database.dart';
import '../services/promise_service.dart';
import '../medicine/medicine_service.dart';
import '../services/plan_service.dart';
import '../services/home_capture_service.dart';
import '../services/plan_child_protection.dart';

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

final promiseServiceProvider = Provider<PromiseService>(
  (ref) => PromiseService(ref.watch(databaseProvider)),
);

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

final aiAssistantDaoProvider = Provider<AiAssistantDao>(
  (ref) => AiAssistantDao(ref.watch(databaseProvider)),
);

final waterDaoProvider = Provider<WaterDao>(
  (ref) => WaterDao(ref.watch(databaseProvider)),
);

final thoughtDaoProvider = Provider<ThoughtDao>(
  (ref) => ThoughtDao(ref.watch(databaseProvider)),
);

final courseDaoProvider = Provider<CourseDao>(
  (ref) => CourseDao(ref.watch(databaseProvider)),
);

final momentumDaoProvider = Provider<MomentumDao>(
  (ref) => MomentumDao(ref.watch(databaseProvider)),
);

final challengeDaoProvider = Provider<ChallengeDao>(
  (ref) => ChallengeDao(ref.watch(databaseProvider)),
);

final medicineDaoProvider = Provider<MedicineDao>(
  (ref) => MedicineDao(ref.watch(databaseProvider)),
);

final planDaoProvider = Provider<PlanDao>(
  (ref) => PlanDao(ref.watch(databaseProvider)),
);

final planServiceProvider = Provider<PlanService>(
  (ref) => PlanService(ref.watch(databaseProvider)),
);

final medicineServiceProvider = Provider<MedicineService>(
  (ref) => MedicineService(ref.watch(databaseProvider)),
);

final homeCaptureServiceProvider = Provider<HomeCaptureService>(
  (ref) => HomeCaptureService(ref.watch(databaseProvider)),
);

class DueCheckInItem {
  final int taskId;
  final String title;
  final int reminderId;
  final String? occurrenceId;
  final DateTime scheduledAt;
  final bool isRoutine;

  const DueCheckInItem({
    required this.taskId,
    required this.title,
    required this.reminderId,
    this.occurrenceId,
    required this.scheduledAt,
    required this.isRoutine,
  });
}

final dueCheckInForTaskProvider =
    StreamProvider.family<DueCheckInItem?, int>((ref, taskId) async* {
  final db = ref.watch(databaseProvider);
  final planDao = ref.watch(planDaoProvider);

  final remindersStream = db.reminderDao.watchAllReminders();
  await for (final reminders in remindersStream) {
    // 1. Check routine occurrences
    final occ = await planDao.getOccurrenceByTaskId(taskId);
    if (occ != null && occ.outcome == 'scheduled') {
      final links = await planDao.getAlertLinksForOccurrence(occ.id);
      final checkLinks = links.where((l) => l.role == 'check_in').toList();
      DueCheckInItem? found;
      for (final link in checkLinks) {
        final rem = reminders
            .where((r) => r.id == link.reminderId && r.isActive)
            .firstOrNull;
        if (rem != null && !rem.scheduledAt.isAfter(DateTime.now())) {
          found = DueCheckInItem(
            taskId: taskId,
            title: rem.title,
            reminderId: rem.id,
            occurrenceId: occ.id,
            scheduledAt: rem.scheduledAt,
            isRoutine: true,
          );
          break;
        }
      }
      if (found != null) {
        yield found;
        continue;
      }
    }

    // 2. Check one-time HomePlans
    final plans = await HomeCaptureService(db).watchPlans().first;
    final homePlan =
        plans.where((p) => p.task?.id == taskId && p.needsAnswer).firstOrNull;
    if (homePlan != null && homePlan.checkIn != null) {
      yield DueCheckInItem(
        taskId: taskId,
        title: homePlan.task?.title ?? homePlan.reminder.title,
        reminderId: homePlan.checkIn!.id,
        occurrenceId: null,
        scheduledAt: homePlan.checkIn!.scheduledAt,
        isRoutine: false,
      );
      continue;
    }

    yield null;
  }
});

final reminderProtectionProvider =
    FutureProvider.family<PlanChildRestriction?, int>((ref, reminderId) async {
  return ref.watch(reminderDaoProvider).getReminderProtection(reminderId);
});

final taskProtectionProvider =
    FutureProvider.family<PlanChildRestriction?, int>((ref, taskId) async {
  return ref.watch(taskDaoProvider).getTaskProtection(taskId);
});



// ── Medicine Reactive Stream Providers ─────────────────────────────────────────

final activeMedicinesStreamProvider = StreamProvider<List<Medicine>>((ref) {
  final dao = ref.watch(medicineDaoProvider);
  return dao.watchActiveMedicines();
});

final allMedicinesStreamProvider = StreamProvider<List<Medicine>>((ref) {
  final dao = ref.watch(medicineDaoProvider);
  return dao.watchAllMedicines();
});

final todayMedicineLogsStreamProvider = StreamProvider<List<MedicineLog>>((
  ref,
) {
  final dao = ref.watch(medicineDaoProvider);
  return dao.watchTodayMedicineLogs();
});

// ── Momentum Reactive Stream Providers ─────────────────────────────────────────

final activeMomentumChallengeStreamProvider =
    StreamProvider<MomentumChallenge?>((ref) {
      final dao = ref.watch(momentumDaoProvider);
      return dao.watchActiveChallenge();
    });

final todayMomentumCommitmentsStreamProvider =
    StreamProvider<List<MomentumCommitment>>((ref) {
      final dao = ref.watch(momentumDaoProvider);
      final now = DateTime.now();
      return dao.watchCommitmentsForDate(now);
    });

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

final recentTransactionsStreamProvider =
    StreamProvider<List<FinanceTransaction>>((ref) {
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

final past7DaysHydrationStreamProvider =
    StreamProvider<List<DailyHydrationRecord>>((ref) {
      final dao = ref.watch(waterDaoProvider);
      return dao.watchPast7DaysHistory();
    });

// ── Thought Wall & Mind Space Stream Providers ────────────────────────────────

final thoughtCategoriesStreamProvider = StreamProvider<Map<String, String>>((ref) {
  return ref.watch(thoughtDaoProvider).watchCategories();
});

final allThoughtsStreamProvider = StreamProvider<List<Thought>>((ref) {
  final dao = ref.watch(thoughtDaoProvider);
  return dao.watchAllThoughts();
});

final archivedThoughtsStreamProvider = StreamProvider<List<Thought>>((ref) {
  final dao = ref.watch(thoughtDaoProvider);
  return dao.watchArchivedThoughts();
});

final todayThoughtsCountStreamProvider = StreamProvider<int>((ref) {
  final dao = ref.watch(thoughtDaoProvider);
  return dao.watchTodayThoughtsCount();
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

final allUpcomingInterviewsProvider = StreamProvider<List<UpcomingInterview>>((
  ref,
) {
  final dao = ref.watch(upcomingInterviewDaoProvider);
  return dao.watchUpcomingInterviews();
});

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
  final pending = todayTasks
      .where((t) => t.actualCompletedDate == null)
      .toList();
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
  final activeApps = allApps
      .where((a) => a.currentStage != 'rejected' && a.currentStage != 'offer')
      .length;

  // Compute real hours this week from time sessions
  final now = DateTime.now();
  final weekStart = DateTime(
    now.year,
    now.month,
    now.day,
  ).subtract(Duration(days: now.weekday - 1));
  final sessions = await sessionDao.getSessionsBetween(
    weekStart,
    now.add(const Duration(days: 1)),
  );
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

enum TodayActivityStatus { notStarted, inProgress, paused, done }

enum ActivityKind { todo, duration, flexible }

class TodayActivityItem {
  final String id;
  final String title;
  final String sourceType; // 'task' | 'dsa' | 'prep' | 'custom' | 'session'
  final TodayActivityStatus status;
  final int elapsedSecondsToday;
  final int? linkedTaskId;
  final int? linkedSessionId;
  final String? learningCourseId;
  final int? learningLectureId;
  final String categoryTag;
  final String? priority;
  final ActivityKind kind;
  final int? targetMinutes;
  final DateTime? plannedDate;
  final bool isOverdue;
  final bool hasReminder;
  final String? notes;
  final DateTime? completedAt;
  final int? medicineId;
  final String? timeSlot;
  final DateTime? scheduledTime;

  const TodayActivityItem({
    required this.id,
    required this.title,
    required this.sourceType,
    required this.status,
    required this.elapsedSecondsToday,
    this.linkedTaskId,
    this.linkedSessionId,
    this.learningCourseId,
    this.learningLectureId,
    required this.categoryTag,
    this.priority,
    this.kind = ActivityKind.todo,
    this.targetMinutes,
    this.plannedDate,
    this.isOverdue = false,
    this.hasReminder = false,
    this.notes,
    this.completedAt,
    this.medicineId,
    this.timeSlot,
    this.scheduledTime,
  });

  bool get isScheduledInFuture {
    if (status == TodayActivityStatus.done) return false;
    if (scheduledTime == null) return false;
    return DateTime.now().isBefore(scheduledTime!);
  }

  TodayActivityItem copyWith({
    String? id,
    String? title,
    String? sourceType,
    TodayActivityStatus? status,
    int? elapsedSecondsToday,
    int? linkedTaskId,
    int? linkedSessionId,
    String? learningCourseId,
    int? learningLectureId,
    String? categoryTag,
    String? priority,
    ActivityKind? kind,
    int? targetMinutes,
    DateTime? plannedDate,
    bool? isOverdue,
    bool? hasReminder,
    String? notes,
    DateTime? completedAt,
    int? medicineId,
    String? timeSlot,
    DateTime? scheduledTime,
  }) {
    return TodayActivityItem(
      id: id ?? this.id,
      title: title ?? this.title,
      sourceType: sourceType ?? this.sourceType,
      status: status ?? this.status,
      elapsedSecondsToday: elapsedSecondsToday ?? this.elapsedSecondsToday,
      linkedTaskId: linkedTaskId ?? this.linkedTaskId,
      linkedSessionId: linkedSessionId ?? this.linkedSessionId,
      learningCourseId: learningCourseId ?? this.learningCourseId,
      learningLectureId: learningLectureId ?? this.learningLectureId,
      categoryTag: categoryTag ?? this.categoryTag,
      priority: priority ?? this.priority,
      kind: kind ?? this.kind,
      targetMinutes: targetMinutes ?? this.targetMinutes,
      plannedDate: plannedDate ?? this.plannedDate,
      isOverdue: isOverdue ?? this.isOverdue,
      hasReminder: hasReminder ?? this.hasReminder,
      notes: notes ?? this.notes,
      completedAt: completedAt ?? this.completedAt,
      medicineId: medicineId ?? this.medicineId,
      timeSlot: timeSlot ?? this.timeSlot,
      scheduledTime: scheduledTime ?? this.scheduledTime,
    );
  }
}
