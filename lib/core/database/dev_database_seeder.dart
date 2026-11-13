import 'package:drift/drift.dart';
import 'package:intl/intl.dart';

import 'app_database.dart';
import '../history/history_ledger.dart';

/// Seeds the Ascent database with 20 consecutive days of realistic, dense test data.
/// Covers:
/// - 5 active scheduled medicines with full 20-day compliance logs and dose history
/// - 20 days of hydration intake (2-3 L/day) with multiple daily logs and today's active progress
/// - 20 days of walking sessions (distance, duration, calories, pace)
/// - 20 days of time tracking study sessions (yielding a 20-day streak)
/// - 20 days of completed and pending tasks (timed tasks, standard to-dos, standing daily tasks)
/// - Mind Palace thoughts across multiple categories with pins and moods
/// - Active 30-day Momentum challenge on Day 20 with completed & pending commitments
/// - Active and upcoming reminders
/// - Full 20-day chronology in HistoryLedger
class DevDatabaseSeeder {
  static Future<void> seed20DaysData(AppDatabase db) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dateFormat = DateFormat('yyyy-MM-dd');

    // 1. Ensure User Profile exists
    final existingProfile = await (db.select(db.userProfileTable)..limit(1)).getSingleOrNull();
    if (existingProfile == null) {
      await db.into(db.userProfileTable).insert(
        UserProfileTableCompanion.insert(
          name: 'Arun Singh',
          targetRole: const Value('Senior Software Engineer'),
          targetCompanies: const Value('["Google", "Apple", "DeepMind"]'),
          weeklyHoursAvailable: const Value(25),
          preferredStudyWindow: const Value('morning'),
          onboardingComplete: const Value(true),
          dateOfBirth: Value(DateTime(1998, 6, 5)),
        ),
      );
    } else {
      await (db.update(db.userProfileTable)..where((p) => p.id.equals(existingProfile.id))).write(
        UserProfileTableCompanion(
          name: const Value('Arun Singh'),
          targetRole: const Value('Senior Software Engineer'),
          onboardingComplete: const Value(true),
          dateOfBirth: Value(existingProfile.dateOfBirth ?? DateTime(1998, 6, 5)),
        ),
      );
    }

    // 2. Ensure Session Categories exist
    final categories = await db.select(db.sessionCategoryTable).get();
    int studyCatId = 1;
    if (categories.isEmpty) {
      studyCatId = await db.into(db.sessionCategoryTable).insert(
        SessionCategoryTableCompanion.insert(
          name: 'Study',
          colorHex: '#5FA070',
          isBuiltIn: const Value(true),
        ),
      );
      await db.into(db.sessionCategoryTable).insert(
        SessionCategoryTableCompanion.insert(
          name: 'Entertainment',
          colorHex: '#F2954F',
          isBuiltIn: const Value(true),
        ),
      );
    } else {
      studyCatId = categories.firstWhere((c) => c.name.toLowerCase() == 'study', orElse: () => categories.first).id;
    }

    // 3. Hydration Goal
    await (db.delete(db.waterGoalTable)).go();
    await db.into(db.waterGoalTable).insert(
      WaterGoalTableCompanion.insert(
        targetMl: const Value(2500),
      ),
    );

    // 4. Activity Goal
    await (db.delete(db.dailyActivityGoalTable)).go();
    await db.into(db.dailyActivityGoalTable).insert(
      DailyActivityGoalTableCompanion.insert(
        targetDistanceMeters: const Value(5000.0),
        targetWalkMinutes: const Value(45),
      ),
    );

    // 5. Clean prior test data for fresh deterministic 20-day populate
    await (db.delete(db.medicineLogTable)).go();
    await (db.delete(db.medicineTable)).go();
    await (db.delete(db.waterLogTable)).go();
    await (db.delete(db.walkSessionTable)).go();
    await (db.delete(db.timeSessionTable)).go();
    await (db.delete(db.momentumCommitmentTable)).go();
    await (db.delete(db.momentumChallengeTable)).go();

    // 6. Insert 5 Active Medicines
    final startDate = today.subtract(const Duration(days: 19));
    final med1Id = await db.into(db.medicineTable).insert(
      MedicineTableCompanion.insert(
        name: 'Vitamin D3 60,000 IU',
        dosage: '1 Capsule',
        scheduledTimes: '["09:00"]',
        durationDays: const Value(60),
        startDate: startDate,
        instructions: const Value('Take with milk after breakfast'),
        type: const Value('capsule'),
        isActive: const Value(true),
      ),
    );

    final med2Id = await db.into(db.medicineTable).insert(
      MedicineTableCompanion.insert(
        name: 'Omega-3 Triple Strength',
        dosage: '1 Softgel',
        scheduledTimes: '["08:30"]',
        durationDays: const Value(90),
        startDate: startDate,
        instructions: const Value('With morning meal'),
        type: const Value('capsule'),
        isActive: const Value(true),
      ),
    );

    final med3Id = await db.into(db.medicineTable).insert(
      MedicineTableCompanion.insert(
        name: 'Zinc & Magnesium Complex',
        dosage: '1 Tablet',
        scheduledTimes: '["21:30"]',
        durationDays: const Value(30),
        startDate: startDate,
        instructions: const Value('Before bed with water'),
        type: const Value('tablet'),
        isActive: const Value(true),
      ),
    );

    final med4Id = await db.into(db.medicineTable).insert(
      MedicineTableCompanion.insert(
        name: 'Pantoprazole 40mg',
        dosage: '1 Tablet',
        scheduledTimes: '["07:30"]',
        durationDays: const Value(28),
        startDate: startDate,
        instructions: const Value('Empty stomach 30m before breakfast'),
        type: const Value('tablet'),
        isActive: const Value(true),
      ),
    );

    final med5Id = await db.into(db.medicineTable).insert(
      MedicineTableCompanion.insert(
        name: 'Multivitamin Daily Boost',
        dosage: '1 Tablet',
        scheduledTimes: '["13:30"]',
        durationDays: const Value(30),
        startDate: startDate,
        instructions: const Value('After lunch with water'),
        type: const Value('tablet'),
        isActive: const Value(true),
      ),
    );

    final meds = [
      (id: med1Id, name: 'Vitamin D3 60,000 IU', time: '09:00'),
      (id: med2Id, name: 'Omega-3 Triple Strength', time: '08:30'),
      (id: med3Id, name: 'Zinc & Magnesium Complex', time: '21:30'),
      (id: med4Id, name: 'Pantoprazole 40mg', time: '07:30'),
      (id: med5Id, name: 'Multivitamin Daily Boost', time: '13:30'),
    ];

    // 7. Insert 20 Days of Medicine Logs, Water Logs, Walks, Study Sessions & Tasks
    for (var dayOffset = 19; dayOffset >= 0; dayOffset--) {
      final dayDate = today.subtract(Duration(days: dayOffset));
      final dateStr = dateFormat.format(dayDate);
      final isToday = dayOffset == 0;

      // --- Medicine Logs for this day ---
      for (final med in meds) {
        final parts = med.time.split(':');
        final scheduledHour = int.parse(parts[0]);
        final scheduledMinute = int.parse(parts[1]);
        final scheduledDateTime = DateTime(
          dayDate.year,
          dayDate.month,
          dayDate.day,
          scheduledHour,
          scheduledMinute,
        );

        bool taken;
        DateTime? takenAt;

        if (!isToday) {
          // In the past 19 days, high adherence (95% taken)
          taken = !(dayOffset % 7 == 3 && med.id == med3Id); // occasional missed dose for realism
          takenAt = taken ? scheduledDateTime.add(const Duration(minutes: 12)) : null;
        } else {
          // Today: Morning doses taken, afternoon/evening pending
          if (scheduledHour < 12) {
            taken = true;
            takenAt = scheduledDateTime.add(const Duration(minutes: 8));
          } else {
            taken = false;
            takenAt = null;
          }
        }

        await db.into(db.medicineLogTable).insert(
          MedicineLogTableCompanion.insert(
            medicineId: med.id,
            dateStr: dateStr,
            timeSlot: med.time,
            isTaken: Value(taken),
            takenAt: Value(takenAt),
            createdAt: Value(scheduledDateTime),
          ),
        );
      }

      // --- Hydration / Water Logs for this day ---
      if (!isToday) {
        // Full day intake: ~2500ml spread across the day
        final logTimes = [
          (h: 8, m: 15, ml: 250),
          (h: 10, m: 45, ml: 500),
          (h: 13, m: 0, ml: 250),
          (h: 15, m: 30, ml: 500),
          (h: 18, m: 15, ml: 250),
          (h: 20, m: 45, ml: 500),
          (h: 22, m: 0, ml: 250),
        ];
        for (final entry in logTimes) {
          final timestamp = DateTime(dayDate.year, dayDate.month, dayDate.day, entry.h, entry.m);
          await db.into(db.waterLogTable).insert(
            WaterLogTableCompanion.insert(
              amountMl: entry.ml,
              timestamp: Value(timestamp),
              date: dayDate,
            ),
          );
        }
      } else {
        // Today: Morning & midday intake (1500ml so far out of 2500ml)
        final todayLogs = [
          (h: 8, m: 30, ml: 500),
          (h: 10, m: 45, ml: 500),
          (h: 12, m: 30, ml: 500),
        ];
        for (final entry in todayLogs) {
          final timestamp = DateTime(dayDate.year, dayDate.month, dayDate.day, entry.h, entry.m);
          await db.into(db.waterLogTable).insert(
            WaterLogTableCompanion.insert(
              amountMl: entry.ml,
              timestamp: Value(timestamp),
              date: dayDate,
            ),
          );
        }
      }

      // --- Walk Sessions ---
      final walkKm = 3.5 + ((dayOffset * 3) % 4) * 0.8; // between 3.5km and 5.9km
      final walkSeconds = (walkKm * 600).round(); // ~10 min/km pace
      final walkCalories = (walkKm * 55).round();
      final walkStart = DateTime(dayDate.year, dayDate.month, dayDate.day, 18, 0);
      await db.into(db.walkSessionTable).insert(
        WalkSessionTableCompanion.insert(
          startTime: walkStart,
          endTime: Value(walkStart.add(Duration(seconds: walkSeconds))),
          durationSeconds: Value(walkSeconds),
          distanceMeters: Value(walkKm * 1000),
          calories: Value(walkCalories),
          avgPaceSecondsPerKm: const Value(600.0),
          isCompleted: const Value(true),
          notes: Value(isToday ? 'Refreshed evening stroll' : 'Evening recovery walk'),
          createdAt: Value(walkStart),
        ),
      );

      // --- Study / Focus Sessions (Guarantees 20-Day Study Streak) ---
      final studyMinutes = 60 + ((dayOffset * 7) % 5) * 15; // 60 to 120 minutes per day
      final studySeconds = studyMinutes * 60;
      final studyStart = DateTime(dayDate.year, dayDate.month, dayDate.day, 9, 30);
      final topics = [
        'DSA: Graph Algorithms BFS & DFS',
        'System Design: Distributed Cache & Redis',
        'Flutter: Custom Painters & RenderObjects',
        'Operating Systems: Virtual Memory & Paging',
        'Computer Networks: TCP Congestion Control',
        'Database Internals: B+ Trees & Write Ahead Logs',
        'System Design: Event-Driven Microservices',
      ];
      final studyLabel = topics[dayOffset % topics.length];

      await db.into(db.timeSessionTable).insert(
        TimeSessionTableCompanion.insert(
          label: studyLabel,
          activityType: const Value('study'),
          categoryId: studyCatId,
          startedAt: studyStart,
          endedAt: Value(studyStart.add(Duration(seconds: studySeconds))),
          durationSeconds: Value(studySeconds),
          status: const Value('completed'),
          createdAt: Value(studyStart),
        ),
      );

      // --- Completed Tasks for Past Days ---
      if (!isToday) {
        await db.into(db.taskTable).insert(
          TaskTableCompanion.insert(
            title: 'Study Session: $studyLabel',
            plannedDate: Value(dayDate),
            actualCompletedDate: Value(studyStart.add(Duration(seconds: studySeconds))),
            priority: const Value('high'),
          ),
        );
        await db.into(db.taskTable).insert(
          TaskTableCompanion.insert(
            title: 'Complete 3 LeetCode problems on ${studyLabel.split(':')[0]}',
            plannedDate: Value(dayDate),
            actualCompletedDate: Value(DateTime(dayDate.year, dayDate.month, dayDate.day, 16, 30)),
            priority: const Value('medium'),
          ),
        );
      }
    }

    // 8. Insert Today's Interactive Tasks
    await db.into(db.taskTable).insert(
      TaskTableCompanion.insert(
        title: 'Deep Work: System Design Distributed Cache (45m)',
        plannedDate: Value(today),
        priority: const Value('high'),
        notes: const Value('Design LRU cache eviction, write-through vs write-back'),
      ),
    );
    await db.into(db.taskTable).insert(
      TaskTableCompanion.insert(
        title: 'Triage PR reviews & verify Home Redesign on device',
        plannedDate: Value(today),
        actualCompletedDate: Value(now.subtract(const Duration(minutes: 45))),
        priority: const Value('high'),
      ),
    );
    await db.into(db.taskTable).insert(
      TaskTableCompanion.insert(
        title: 'Complete LeetCode Daily Challenge',
        plannedDate: Value(today),
        priority: const Value('medium'),
      ),
    );
    await db.into(db.taskTable).insert(
      TaskTableCompanion.insert(
        title: 'Morning stretch & deep breathing routine',
        plannedDate: Value(today),
        actualCompletedDate: Value(DateTime(today.year, today.month, today.day, 7, 15)),
        isDailyStanding: const Value(true),
        priority: const Value('low'),
      ),
    );
    await db.into(db.taskTable).insert(
      TaskTableCompanion.insert(
        title: 'Evening meditation & mental reset',
        plannedDate: Value(today),
        isDailyStanding: const Value(true),
        priority: const Value('low'),
      ),
    );

    // 9. Insert Active Momentum Challenge (Day 20 of 30)
    final challengeId = await db.into(db.momentumChallengeTable).insert(
      MomentumChallengeTableCompanion.insert(
        startDate: startDate,
        targetEndDate: today.add(const Duration(days: 10)),
        durationDays: const Value(30),
        status: const Value('active'),
        workoutDurationMinutes: const Value(45),
        targetWakeTimeMinutes: const Value(390), // 06:30 AM
        gymSplit: const Value('upper_lower'),
      ),
    );

    for (var dayNum = 1; dayNum <= 20; dayNum++) {
      final comDate = startDate.add(Duration(days: dayNum - 1));
      final isDay20 = dayNum == 20;

      await db.into(db.momentumCommitmentTable).insert(
        MomentumCommitmentTableCompanion.insert(
          challengeId: challengeId,
          dayNumber: dayNum,
          scheduledDate: comDate,
          commitmentType: 'wake',
          title: 'Wake at 06:30 AM',
          isCompleted: Value(!isDay20 || now.hour >= 7),
          completedAt: Value(!isDay20 || now.hour >= 7 ? DateTime(comDate.year, comDate.month, comDate.day, 6, 28) : null),
        ),
      );
      await db.into(db.momentumCommitmentTable).insert(
        MomentumCommitmentTableCompanion.insert(
          challengeId: challengeId,
          dayNumber: dayNum,
          scheduledDate: comDate,
          commitmentType: 'hydration',
          title: 'Hit 2.5L Water Intake',
          isCompleted: Value(!isDay20),
          completedAt: Value(!isDay20 ? DateTime(comDate.year, comDate.month, comDate.day, 21, 0) : null),
        ),
      );
      await db.into(db.momentumCommitmentTable).insert(
        MomentumCommitmentTableCompanion.insert(
          challengeId: challengeId,
          dayNumber: dayNum,
          scheduledDate: comDate,
          commitmentType: 'walk',
          title: '5,000 Steps Outdoor Walk',
          isCompleted: Value(!isDay20),
          completedAt: Value(!isDay20 ? DateTime(comDate.year, comDate.month, comDate.day, 19, 0) : null),
        ),
      );
    }

    // 10. Insert Thoughts / Mind Palace
    final sampleThoughts = [
      (content: 'Simplicity is a prerequisite for reliability. Complex systems always break in complex ways.', category: 'architecture', mood: 'idea', pinned: true),
      (content: 'Consistently hitting 2.5L water and daily walking dramatically clears cognitive fog.', category: 'health', mood: 'win', pinned: false),
      (content: 'Deep work produces extraordinary outcomes because depth is rare in an interrupted world.', category: 'engineering', mood: 'thought', pinned: false),
      (content: 'Focus on mastering fundamentals: Data Structures, Memory, I/O, and Concurrency.', category: 'engineering', mood: 'me_to_me', pinned: true),
      (content: 'A calm mind makes better engineering tradeoffs than an anxious one under false urgency.', category: 'philosophy', mood: 'thought', pinned: false),
      (content: 'Day 20 of momentum challenge completed with sustained energy and no burn-out.', category: 'health', mood: 'win', pinned: false),
    ];

    for (var i = 0; i < sampleThoughts.length; i++) {
      final t = sampleThoughts[i];
      final thoughtDate = now.subtract(Duration(days: i * 3, hours: i * 2));
      await db.into(db.thoughtTable).insert(
        ThoughtTableCompanion.insert(
          content: t.content,
          category: Value(t.category),
          mood: Value(t.mood),
          isPinned: Value(t.pinned),
          createdAt: Value(thoughtDate),
        ),
      );
    }

    // 11. Insert Active Reminders
    await (db.delete(db.reminderTable)).go();
    await db.into(db.reminderTable).insert(
      ReminderTableCompanion.insert(
        title: 'Take evening Zinc & Magnesium tablet',
        scheduledAt: DateTime(today.year, today.month, today.day, 21, 30),
        isActive: const Value(true),
      ),
    );
    await db.into(db.reminderTable).insert(
      ReminderTableCompanion.insert(
        title: 'Review System Design Distributed Caching module',
        scheduledAt: today.add(const Duration(days: 1, hours: 10)),
        isActive: const Value(true),
      ),
    );
    await db.into(db.reminderTable).insert(
      ReminderTableCompanion.insert(
        title: 'Order prescription refills (Vitamin D3 & Omega-3)',
        scheduledAt: today.add(const Duration(days: 3, hours: 14)),
        isActive: const Value(true),
      ),
    );

    // 12. Run History Ledger Backfill to guarantee 100% sync of historical events
    await HistoryLedger.install(db);
    await HistoryLedger.backfill(db);
  }
}
