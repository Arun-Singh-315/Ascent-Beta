import 'dart:convert';
import 'dart:io';
import 'package:drift/drift.dart' as drift;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app_database.dart';
import 'tables/enums.dart';

/// Seeds realistic, production-quality beta demonstration data into the local SQLite database.
/// This allows beta testing every screen and feature end-to-end without requiring tedious manual data entry.
class DemoDataSeeder {
  static Future<void> seedRealisticBetaData(
    AppDatabase db, {
    SharedPreferences? prefs,
  }) async {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    // ── 1. Clean all existing tables cleanly ─────────────────────────────────
    await db.customStatement('DELETE FROM ai_chat_messages;');
    await db.customStatement('DELETE FROM habit_completions;');
    await db.customStatement('DELETE FROM habits;');
    await db.customStatement('DELETE FROM daily_activity_goals;');
    await db.customStatement('DELETE FROM walk_sessions;');
    await db.customStatement('DELETE FROM savings_goals;');
    await db.customStatement('DELETE FROM finance_budgets;');
    await db.customStatement('DELETE FROM finance_transactions;');
    await db.customStatement('DELETE FROM insight_dismissals;');
    await db.customStatement('DELETE FROM note_tags;');
    await db.customStatement('DELETE FROM notes;');
    await db.customStatement('DELETE FROM interview_prep;');
    await db.customStatement('DELETE FROM resumes;');
    await db.customStatement('DELETE FROM application_status_history;');
    await db.customStatement('DELETE FROM applications;');
    await db.customStatement('DELETE FROM tasks;');
    await db.customStatement('DELETE FROM series;');
    await db.customStatement('DELETE FROM study_phases;');
    await db.customStatement('DELETE FROM dsa_logs;');
    await db.customStatement('DELETE FROM consistency_logs;');
    await db.customStatement('DELETE FROM user_profiles;');

    // ── 2. User Profile ──────────────────────────────────────────────────────
    final targetInterviewDate = now.add(const Duration(days: 24));
    final targetCompanies = ['Stripe', 'Google', 'Datadog', 'Figma', 'Linear'];

    await db.userProfileDao.upsertProfile(
      UserProfileTableCompanion(
        id: const drift.Value(1),
        name: const drift.Value('Alex Chen'),
        targetRole: const drift.Value('Senior Full-Stack & Systems Engineer'),
        targetCompanies: drift.Value(jsonEncode(targetCompanies)),
        interviewDate: drift.Value(targetInterviewDate),
        weeklyHoursAvailable: const drift.Value(15),
        preferredStudyWindow: const drift.Value('evening'),
        onboardingComplete: const drift.Value(true),
        createdAt: drift.Value(now.subtract(const Duration(days: 30))),
        updatedAt: drift.Value(now),
      ),
    );

    if (prefs != null) {
      await prefs.setBool('onboarding_complete', true);
      await prefs.setString('last_open_date', now.toIso8601String());
    }

    // ── 3. Study Phases ──────────────────────────────────────────────────────
    final phase1Id = await db.studyPhaseDao.insertPhase(
      StudyPhaseTableCompanion.insert(
        title: 'Phase 1: Foundations & Core Concurrency',
        description: const drift.Value('Go channels/mutexes, memory model, TCP/IP, and DB indexing.'),
        orderIndex: const drift.Value(1),
        colorHex: const drift.Value('#7FA88A'),
      ),
    );

    final phase2Id = await db.studyPhaseDao.insertPhase(
      StudyPhaseTableCompanion.insert(
        title: 'Phase 2: High-Yield DSA & Patterns',
        description: const drift.Value('NeetCode 150: Trees, Graphs, Dynamic Programming, and Heaps.'),
        orderIndex: const drift.Value(2),
        colorHex: const drift.Value('#7C9CC4'),
      ),
    );

    final phase3Id = await db.studyPhaseDao.insertPhase(
      StudyPhaseTableCompanion.insert(
        title: 'Phase 3: Large-Scale System Design',
        description: const drift.Value('Distributed rate limiters, payment ledgers, sharding, and consensus.'),
        orderIndex: const drift.Value(3),
        colorHex: const drift.Value('#E8A57C'),
      ),
    );

    final phase4Id = await db.studyPhaseDao.insertPhase(
      StudyPhaseTableCompanion.insert(
        title: 'Phase 4: Behavioral & Leadership Mock Loops',
        description: const drift.Value('STAR methodology stories, executive alignment, and negotiation.'),
        orderIndex: const drift.Value(4),
        colorHex: const drift.Value('#C48AB8'),
      ),
    );

    // ── 4. Study Series ──────────────────────────────────────────────────────
    final series1Id = await db.seriesDao.insertSeries(
      SeriesTableCompanion.insert(
        title: 'NeetCode 150 Core Patterns',
        totalItems: const drift.Value(75),
        pacingRule: const drift.Value('fixedInterval'),
        fixedIntervalDays: const drift.Value(2),
        linkedPhaseId: drift.Value(phase2Id),
      ),
    );

    final series2Id = await db.seriesDao.insertSeries(
      SeriesTableCompanion.insert(
        title: 'System Design Interview Vol 1 & 2',
        totalItems: const drift.Value(16),
        pacingRule: const drift.Value('endDate'),
        endDate: drift.Value(targetInterviewDate),
        linkedPhaseId: drift.Value(phase3Id),
      ),
    );

    // ── 5. Tasks (Overdue, Today, Upcoming, Completed) ───────────────────────
    // Overdue task
    await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Review Rate Limiting: Token Bucket vs Leaky Bucket',
        plannedDate: drift.Value(today.subtract(const Duration(days: 1))),
        priority: const drift.Value('high'),
        linkedPhaseId: drift.Value(phase3Id),
        seriesId: drift.Value(series2Id),
        notes: const drift.Value('Compare distributed Redis implementation vs in-memory sliding window.'),
      ),
    );

    // Today tasks
    await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Implement LRU Cache with O(1) Get & Put in Go/Python',
        plannedDate: drift.Value(today),
        priority: const drift.Value('high'),
        linkedPhaseId: drift.Value(phase2Id),
        seriesId: drift.Value(series1Id),
        notes: const drift.Value('Practice lock-free concurrency if using Go sync.RWMutex.'),
      ),
    );

    await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Follow up with Stripe recruiter on onsite schedule & loop format',
        plannedDate: drift.Value(today),
        priority: const drift.Value('medium'),
        linkedPhaseId: drift.Value(phase4Id),
        notes: const drift.Value('Confirm whether laptop environment allows external IDE setup.'),
      ),
    );

    await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Review Datadog distributed tracing & APM architecture',
        plannedDate: drift.Value(today),
        priority: const drift.Value('medium'),
        linkedPhaseId: drift.Value(phase3Id),
        notes: const drift.Value('OpenTelemetry collector internals and span sampling mechanisms.'),
      ),
    );

    // Upcoming tasks
    await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Mock System Design: Design a Distributed Message Queue (Kafka clone)',
        plannedDate: drift.Value(today.add(const Duration(days: 1))),
        priority: const drift.Value('high'),
        linkedPhaseId: drift.Value(phase3Id),
        seriesId: drift.Value(series2Id),
      ),
    );

    await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Solve 3 Hard Graph Problems: Topological Sort & SCCs',
        plannedDate: drift.Value(today.add(const Duration(days: 2))),
        priority: const drift.Value('medium'),
        linkedPhaseId: drift.Value(phase2Id),
        seriesId: drift.Value(series1Id),
      ),
    );

    await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Refine STAR Stories for Leadership Principles: Disagree & Commit',
        plannedDate: drift.Value(today.add(const Duration(days: 3))),
        priority: const drift.Value('low'),
        linkedPhaseId: drift.Value(phase4Id),
      ),
    );

    await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Complete End-to-End Mock Behavioral Interview with Peer',
        plannedDate: drift.Value(today.add(const Duration(days: 5))),
        priority: const drift.Value('high'),
        linkedPhaseId: drift.Value(phase4Id),
      ),
    );

    // Past completed tasks
    await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Brush up Go channels, mutexes and goroutine memory model',
        plannedDate: drift.Value(today.subtract(const Duration(days: 3))),
        actualCompletedDate: drift.Value(today.subtract(const Duration(days: 3))),
        priority: const drift.Value('medium'),
        linkedPhaseId: drift.Value(phase1Id),
      ),
    );

    await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Solve 5 Medium Sliding Window problems on LeetCode',
        plannedDate: drift.Value(today.subtract(const Duration(days: 2))),
        actualCompletedDate: drift.Value(today.subtract(const Duration(days: 2))),
        priority: const drift.Value('high'),
        linkedPhaseId: drift.Value(phase2Id),
        seriesId: drift.Value(series1Id),
      ),
    );

    // ── 6. Applications in Pipeline ──────────────────────────────────────────
    // 1. Stripe (Offer)
    final stripeId = await db.applicationDao.insertApplication(
      ApplicationTableCompanion.insert(
        company: 'Stripe',
        role: 'Staff Infrastructure Engineer',
        currentStage: const drift.Value('offer'),
        salary: const drift.Value('\$240k base + equity (\$380k TC)'),
        jobUrl: const drift.Value('https://stripe.com/jobs/staff-infra'),
        nextActionDate: drift.Value(now.add(const Duration(days: 2))),
        notes: const drift.Value('Met with Director Sarah. Strong alignment on high-availability payments & ledger consistency.'),
      ),
    );
    await db.applicationDao.recordStatusChange(stripeId, ApplicationStage.wishlist, notes: 'Saved wishlist role');
    await db.applicationDao.recordStatusChange(stripeId, ApplicationStage.applied, notes: 'Applied via team referral');
    await db.applicationDao.recordStatusChange(stripeId, ApplicationStage.oaScreen, notes: 'Online technical screen completed');
    await db.applicationDao.recordStatusChange(stripeId, ApplicationStage.interview, notes: 'Virtual onsite loop: 4 rounds completed');
    await db.applicationDao.recordStatusChange(stripeId, ApplicationStage.offer, notes: 'Written offer received! Deadline in 5 days.');

    // 2. Datadog (Interview)
    final datadogId = await db.applicationDao.insertApplication(
      ApplicationTableCompanion.insert(
        company: 'Datadog',
        role: 'Senior Backend Engineer (APM & Tracing)',
        currentStage: const drift.Value('interview'),
        salary: const drift.Value('\$210,000 - \$230,000'),
        jobUrl: const drift.Value('https://careers.datadoghq.com/detail/12345'),
        nextActionDate: drift.Value(now.add(const Duration(days: 4))),
        notes: const drift.Value('Passed phone technical screen. Next up: 4-hour virtual onsite covering system architecture.'),
      ),
    );
    await db.applicationDao.recordStatusChange(datadogId, ApplicationStage.applied, notes: 'Applied on website');
    await db.applicationDao.recordStatusChange(datadogId, ApplicationStage.oaScreen, notes: 'Initial hiring manager phone screen');
    await db.applicationDao.recordStatusChange(datadogId, ApplicationStage.interview, notes: 'Invited to Virtual Onsite loop');

    // 3. Google (OA / Screen)
    final googleId = await db.applicationDao.insertApplication(
      ApplicationTableCompanion.insert(
        company: 'Google',
        role: 'Senior Software Engineer (L5)',
        currentStage: const drift.Value('oaScreen'),
        salary: const drift.Value('\$220,000 - \$260,000 base'),
        jobUrl: const drift.Value('https://google.com/about/careers/applications'),
        nextActionDate: drift.Value(now.add(const Duration(days: 7))),
        notes: const drift.Value('Recruiter call went great. Technical phone screen scheduled with Mountain View SWE.'),
      ),
    );
    await db.applicationDao.recordStatusChange(googleId, ApplicationStage.applied, notes: 'Recruiter reached out on LinkedIn');
    await db.applicationDao.recordStatusChange(googleId, ApplicationStage.oaScreen, notes: 'Phone screen confirmed');

    // 4. Figma (Applied)
    final figmaId = await db.applicationDao.insertApplication(
      ApplicationTableCompanion.insert(
        company: 'Figma',
        role: 'Senior Web Platform Engineer',
        currentStage: const drift.Value('applied'),
        salary: const drift.Value('\$200,000 - \$225,000'),
        jobUrl: const drift.Value('https://figma.com/careers'),
        nextActionDate: drift.Value(now.add(const Duration(days: 5))),
        notes: const drift.Value('Submitted tailored portfolio & resume highlighting WebAssembly & Canvas rendering optimization.'),
      ),
    );
    await db.applicationDao.recordStatusChange(figmaId, ApplicationStage.applied, notes: 'Application submitted online');

    // 5. Linear (Wishlist)
    final linearId = await db.applicationDao.insertApplication(
      ApplicationTableCompanion.insert(
        company: 'Linear',
        role: 'Product Engineer (Full Stack & Sync)',
        currentStage: const drift.Value('wishlist'),
        salary: const drift.Value('\$190,000 - \$220,000'),
        jobUrl: const drift.Value('https://linear.app/careers'),
        nextActionDate: drift.Value(now.add(const Duration(days: 10))),
        notes: const drift.Value('Connect with engineers on Twitter/LinkedIn for insight on local-first SQLite sync architecture.'),
      ),
    );
    await db.applicationDao.recordStatusChange(linearId, ApplicationStage.wishlist, notes: 'Added to wishlist');

    // ── 7. Consistency Logs (Past 30 Days) ───────────────────────────────────
    final consistencyDao = db.consistencyDao;
    for (int i = 29; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      // 85% attendance rate with realistic rest days
      final isRestDay = (i == 4 || i == 11 || i == 18 || i == 25);
      final present = !isRestDay;
      final hours = present ? (1.5 + (i % 5) * 0.5) : 0.0;
      final note = present
          ? (i == 0
              ? 'Solved LRU cache and prepared Stripe negotiations.'
              : 'Focused study session (${hours.toStringAsFixed(1)} hrs). Solved DSA problems and revised notes.')
          : 'Scheduled rest day — recovered and took a long walk.';

      await consistencyDao.logDay(
        date,
        present,
        note: note,
        hoursStudied: hours,
      );
    }

    // ── 8. DSA Solved Problems ───────────────────────────────────────────────
    final dsaDao = db.dsaDao;
    await dsaDao.insertLog(
      DsaLogTableCompanion.insert(
        problemName: 'LRU Cache',
        topic: DsaTopic.linkedLists.name,
        difficulty: DsaDifficulty.medium.name,
        dateSolved: now,
        timeTakenMinutes: const drift.Value(22),
        revisitFlag: const drift.Value(false),
        notes: const drift.Value('Doubly linked list + hash map. O(1) get & put. Maintain head and tail sentinel nodes.'),
        problemUrl: const drift.Value('https://leetcode.com/problems/lru-cache/'),
      ),
    );

    await dsaDao.insertLog(
      DsaLogTableCompanion.insert(
        problemName: 'Merge K Sorted Lists',
        topic: DsaTopic.heaps.name,
        difficulty: DsaDifficulty.hard.name,
        dateSolved: now.subtract(const Duration(days: 1)),
        timeTakenMinutes: const drift.Value(35),
        revisitFlag: const drift.Value(true),
        notes: const drift.Value('Min-heap storing ListNode references. O(N log k) time. Remember to check for empty input list.'),
        problemUrl: const drift.Value('https://leetcode.com/problems/merge-k-sorted-lists/'),
      ),
    );

    await dsaDao.insertLog(
      DsaLogTableCompanion.insert(
        problemName: 'Trapping Rain Water',
        topic: DsaTopic.arrays.name,
        difficulty: DsaDifficulty.hard.name,
        dateSolved: now.subtract(const Duration(days: 2)),
        timeTakenMinutes: const drift.Value(38),
        revisitFlag: const drift.Value(true),
        notes: const drift.Value('Two-pointer technique with left_max and right_max tracks water bounded by lower wall.'),
        problemUrl: const drift.Value('https://leetcode.com/problems/trapping-rain-water/'),
      ),
    );

    await dsaDao.insertLog(
      DsaLogTableCompanion.insert(
        problemName: 'Course Schedule II',
        topic: DsaTopic.graphs.name,
        difficulty: DsaDifficulty.medium.name,
        dateSolved: now.subtract(const Duration(days: 3)),
        timeTakenMinutes: const drift.Value(24),
        revisitFlag: const drift.Value(false),
        notes: const drift.Value('Kahn’s algorithm using in-degree array. If result.length != numCourses, graph has cycle.'),
        problemUrl: const drift.Value('https://leetcode.com/problems/course-schedule-ii/'),
      ),
    );

    await dsaDao.insertLog(
      DsaLogTableCompanion.insert(
        problemName: 'Longest Palindromic Substring',
        topic: DsaTopic.dynamicProgramming.name,
        difficulty: DsaDifficulty.medium.name,
        dateSolved: now.subtract(const Duration(days: 4)),
        timeTakenMinutes: const drift.Value(19),
        revisitFlag: const drift.Value(false),
        notes: const drift.Value('Expand around center for 2n - 1 center positions. O(N^2) time, O(1) extra memory.'),
      ),
    );

    await dsaDao.insertLog(
      DsaLogTableCompanion.insert(
        problemName: 'Word Break',
        topic: DsaTopic.dynamicProgramming.name,
        difficulty: DsaDifficulty.medium.name,
        dateSolved: now.subtract(const Duration(days: 6)),
        timeTakenMinutes: const drift.Value(27),
        revisitFlag: const drift.Value(false),
        notes: const drift.Value('1D boolean DP array dp[i] where dp[i] is true if s[0...i] can be segmented.'),
      ),
    );

    // ── 9. Interview Prep Bank ───────────────────────────────────────────────
    final prepDao = db.interviewPrepDao;
    await prepDao.insertQuestion(
      InterviewPrepTableCompanion.insert(
        questionAsked: 'Tell me about a time you resolved a critical production incident under tight SLA',
        company: const drift.Value('Datadog'),
        role: const drift.Value('Senior Backend Engineer'),
        category: const drift.Value('Behavioral'),
        outcome: const drift.Value('Nailed it'),
        linkedApplicationId: drift.Value(datadogId),
        preparedAt: drift.Value(now.subtract(const Duration(days: 3))),
        lastInteractedAt: drift.Value(now.subtract(const Duration(days: 1))),
        answerNotes: const drift.Value(
          '**Situation**: Payment gateway latency spiked to 4.2s during major shopping holiday event.\n'
          '**Task**: Triage issue, prevent cascade failures, and restore p99 latency to <150ms within 20 mins.\n'
          '**Action**: Isolated un-indexed database query triggered by new promotion feature; rolled back flag and enabled circuit breaker.\n'
          '**Result**: Latency returned to 85ms in 9 minutes. Zero customer financial loss. Added synthetic query test to CI.',
        ),
      ),
    );

    await prepDao.insertQuestion(
      InterviewPrepTableCompanion.insert(
        questionAsked: 'Design a Distributed Rate Limiter capable of handling 1,000,000 requests/sec',
        company: const drift.Value('Stripe'),
        role: const drift.Value('Staff Infrastructure Engineer'),
        category: const drift.Value('System Design'),
        outcome: const drift.Value('Need practice'),
        linkedApplicationId: drift.Value(stripeId),
        preparedAt: drift.Value(now.subtract(const Duration(days: 5))),
        lastInteractedAt: drift.Value(now.subtract(const Duration(days: 2))),
        answerNotes: const drift.Value(
          'Token bucket algorithm with Redis Cluster.\n'
          'Client-side batching and local token allocation to reduce Redis round trips.\n'
          'Handled synchronization drift and fallback modes (fail-open vs fail-close).',
        ),
      ),
    );

    await prepDao.insertQuestion(
      InterviewPrepTableCompanion.insert(
        questionAsked: 'Why are you looking to leave your current role and join our team?',
        company: const drift.Value('Stripe'),
        role: const drift.Value('Staff Infrastructure Engineer'),
        category: const drift.Value('Culture & Leadership'),
        outcome: const drift.Value('Nailed it'),
        linkedApplicationId: drift.Value(stripeId),
        preparedAt: drift.Value(now.subtract(const Duration(days: 4))),
        lastInteractedAt: drift.Value(now),
        answerNotes: const drift.Value(
          'Seeking higher leverage technical ownership in foundational distributed payment systems.\n'
          'Strong affinity for Stripe’s engineering rigor, API craftsmanship, and long-term infrastructure investment.',
        ),
      ),
    );

    await prepDao.insertQuestion(
      InterviewPrepTableCompanion.insert(
        questionAsked: 'Reverse Nodes in k-Group (Linked List)',
        company: const drift.Value('Google'),
        role: const drift.Value('Senior Software Engineer'),
        category: const drift.Value('DSA'),
        outcome: const drift.Value('Good'),
        linkedApplicationId: drift.Value(googleId),
        preparedAt: drift.Value(now.subtract(const Duration(days: 7))),
        lastInteractedAt: drift.Value(now.subtract(const Duration(days: 3))),
        answerNotes: const drift.Value(
          'Count k elements first; if fewer than k remain, leave intact.\n'
          'Iteratively reverse subsegment and reconnect with dummy head sentinel.',
        ),
      ),
    );

    // ── 10. Notes & Cheatsheets ──────────────────────────────────────────────
    final notesDao = db.notesDao;
    final note1Id = await notesDao.insertNote(
      NoteTableCompanion.insert(
        title: const drift.Value('System Design: CAP Theorem & Distributed Consensus'),
        content: '# CAP Theorem & Consensus Cheatsheet\n\n'
            '- **CP**: Consistency + Partition Tolerance (e.g. Zookeeper, Raft, etcd). Rejects writes during partitions rather than returning stale data.\n'
            '- **AP**: Availability + Partition Tolerance (e.g. Cassandra, DynamoDB). Eventually consistent, always accepts writes.\n\n'
            '### Raft Invariant Checklist\n'
            '1. Election Safety: At most one leader can be elected in a given term.\n'
            '2. Leader Append-Only: A leader never overwrites or truncates its log.\n'
            '3. Log Matching: If two logs contain an entry with the same index and term, they are identical up to that index.',
        linkedTopic: const drift.Value('System Design'),
        linkedCompany: const drift.Value('Stripe'),
        createdAt: drift.Value(now.subtract(const Duration(days: 8))),
        updatedAt: drift.Value(now.subtract(const Duration(days: 1))),
        lastInteractedAt: drift.Value(now),
      ),
    );
    await notesDao.addTag(note1Id, 'system-design');
    await notesDao.addTag(note1Id, 'cheatsheet');

    final note2Id = await notesDao.insertNote(
      NoteTableCompanion.insert(
        title: const drift.Value('Behavioral STAR Stories Matrix (Leadership & Conflicts)'),
        content: '# STAR Stories Matrix\n\n'
            '### Story 1: Disagree and Commit\n'
            '- **Situation**: Architect pushed for GraphQL across entire backend, but frontend team lacked query tooling.\n'
            '- **Task**: Prevent 3-month roadmap delay while modernizing API layer.\n'
            '- **Action**: Built lightweight REST+BFF proxy service as stepping stone with OpenAPI automated types.\n'
            '- **Result**: Shipped on time; reduced payload latency by 35%.\n\n'
            '### Story 2: Mentoring & Growing Engineers\n'
            '- Paired with 2 junior developers on distributed tracing project; both promoted within 12 months.',
        linkedTopic: const drift.Value('Behavioral'),
        linkedCompany: const drift.Value('Datadog'),
        createdAt: drift.Value(now.subtract(const Duration(days: 12))),
        updatedAt: drift.Value(now.subtract(const Duration(days: 2))),
        lastInteractedAt: drift.Value(now.subtract(const Duration(days: 1))),
      ),
    );
    await notesDao.addTag(note2Id, 'behavioral');
    await notesDao.addTag(note2Id, 'interview-qa');

    final note3Id = await notesDao.insertNote(
      NoteTableCompanion.insert(
        title: const drift.Value('Database Sharding & Caching Patterns'),
        content: '# Caching Patterns\n\n'
            '1. **Cache-Aside (Lazy Loading)**: Application reads cache; on miss, queries DB and fills cache.\n'
            '2. **Write-Through**: Application writes to cache; cache writes to DB synchronously.\n'
            '3. **Write-Behind (Write-Back)**: Cache queues async writes to database. High throughput, risk on crash.',
        linkedTopic: const drift.Value('Architecture'),
        createdAt: drift.Value(now.subtract(const Duration(days: 15))),
        updatedAt: drift.Value(now.subtract(const Duration(days: 5))),
        lastInteractedAt: drift.Value(now.subtract(const Duration(days: 4))),
      ),
    );
    await notesDao.addTag(note3Id, 'system-design');
    await notesDao.addTag(note3Id, 'cheatsheet');

    // ── 11. Resume Vault ─────────────────────────────────────────────────────
    final resumeDao = db.resumeDao;
    try {
      final appDocDir = await getApplicationDocumentsDirectory();
      final resumesDir = Directory(p.join(appDocDir.path, 'resumes'));
      if (!await resumesDir.exists()) {
        await resumesDir.create(recursive: true);
      }

      final file1 = File(p.join(resumesDir.path, 'Alex_Chen_Staff_SWE_2026.pdf'));
      await file1.writeAsString(
        '%PDF-1.4\n% Alex Chen - Staff Infrastructure Engineer Resume\n1 0 obj\n<< /Title (Alex Chen Resume) >>\nendobj\n%%EOF',
      );
      final size1 = await file1.length();

      final file2 = File(p.join(resumesDir.path, 'Alex_Chen_General_Fullstack.pdf'));
      await file2.writeAsString(
        '%PDF-1.4\n% Alex Chen - Senior Full Stack Engineer Resume\n1 0 obj\n<< /Title (Alex Chen Resume) >>\nendobj\n%%EOF',
      );
      final size2 = await file2.length();

      await resumeDao.insertResume(
        ResumeTableCompanion.insert(
          versionLabel: 'v3 - Staff Infrastructure (Stripe Tailored)',
          filePath: file1.path,
          fileSize: drift.Value(size1),
          tailoredForCompany: const drift.Value('Stripe'),
          linkedApplicationId: drift.Value(stripeId),
          notes: const drift.Value('Emphasizes high-scale distributed payments, reliability, and Go/C++ performance.'),
        ),
      );

      await resumeDao.insertResume(
        ResumeTableCompanion.insert(
          versionLabel: 'v2 - General Senior SWE (Google & Figma)',
          filePath: file2.path,
          fileSize: drift.Value(size2),
          tailoredForCompany: const drift.Value('Google'),
          linkedApplicationId: drift.Value(googleId),
          notes: const drift.Value('Highlights cross-functional leadership, full-stack systems, and distributed caching.'),
        ),
      );
    } catch (_) {
      // Fallback if filesystem is mock/isolated in test environment
    }

    // ── 15. Finance Records ───────────────────────────────────────────────
    await db.financeDao.setOverallBudget(20000.0, dailyLimit: 600.0);
    await db.financeDao.insertTransaction(
      FinanceTransactionTableCompanion.insert(
        title: 'Books & Courseware',
        amount: 850.0,
        type: const drift.Value('expense'),
        category: const drift.Value('Education'),
        date: now.subtract(const Duration(days: 2)),
        account: const drift.Value('UPI'),
      ),
    );
    await db.financeDao.insertTransaction(
      FinanceTransactionTableCompanion.insert(
        title: 'Morning Chai & Snacks',
        amount: 45.0,
        type: const drift.Value('expense'),
        category: const drift.Value('Food & Groceries'),
        date: now,
        account: const drift.Value('UPI'),
      ),
    );
    await db.financeDao.insertSavingsGoal(
      SavingsGoalTableCompanion.insert(
        title: 'Emergency Fund',
        targetAmount: 50000.0,
        savedAmount: const drift.Value(15000.0),
      ),
    );

    // ── 16. Walking & Activity Records ────────────────────────────────────
    await db.walkDao.setActivityGoal(5000.0, 45);
    await db.walkDao.insertWalk(
      WalkSessionTableCompanion.insert(
        startTime: now.subtract(const Duration(hours: 4)),
        endTime: drift.Value(now.subtract(const Duration(hours: 3, minutes: 25))),
        durationSeconds: const drift.Value(2100),
        distanceMeters: const drift.Value(2450.0),
        calories: const drift.Value(155),
        avgPaceSecondsPerKm: const drift.Value(857.0),
        isCompleted: const drift.Value(true),
        notes: const drift.Value('Brisk evening park loop'),
      ),
    );

    // ── 17. Daily Habits ──────────────────────────────────────────────────
    final h1 = await db.habitDao.insertHabit(
      const HabitTableCompanion(
        title: drift.Value('Daily 30m LeetCode / DSA'),
        category: drift.Value('Study'),
      ),
    );
    await db.habitDao.insertHabit(
      const HabitTableCompanion(
        title: drift.Value('30-Minute Outdoor Walk'),
        category: drift.Value('Fitness'),
      ),
    );
    await db.habitDao.insertHabit(
      const HabitTableCompanion(
        title: drift.Value('Drink 3L Water'),
        category: drift.Value('Health'),
      ),
    );
    await db.habitDao.toggleHabitToday(h1);
  }
}
