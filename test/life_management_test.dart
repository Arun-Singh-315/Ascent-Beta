import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as drift;
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/ai/ai_service.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Personal Finance Module Tests', () {
    test('Records income, expenses, and calculates daily/monthly totals', () async {
      final now = DateTime.now();

      // Record an expense
      await db.financeDao.insertTransaction(
        FinanceTransactionTableCompanion.insert(
          title: 'Lunch with team',
          amount: 250.0,
          type: const drift.Value('expense'),
          category: const drift.Value('Food & Groceries'),
          date: now,
          account: const drift.Value('UPI'),
          notes: const drift.Value('Office cafeteria'),
        ),
      );

      // Record another expense on same day
      await db.financeDao.insertTransaction(
        FinanceTransactionTableCompanion.insert(
          title: 'Metro commute',
          amount: 50.0,
          type: const drift.Value('expense'),
          category: const drift.Value('Transport'),
          date: now,
          account: const drift.Value('Cash'),
          notes: const drift.Value('Metro fare'),
        ),
      );

      // Record an income
      await db.financeDao.insertTransaction(
        FinanceTransactionTableCompanion.insert(
          title: 'Stipend credit',
          amount: 5000.0,
          type: const drift.Value('income'),
          category: const drift.Value('Other'),
          date: now,
          account: const drift.Value('Bank Account'),
          notes: const drift.Value('Monthly earnings'),
        ),
      );

      // Verify today spending calculation
      final todaySpend = await db.financeDao.watchTodaySpending().first;
      expect(todaySpend, 300.0);

      // Verify month spending calculation
      final monthSpend = await db.financeDao.watchMonthSpending(now.year, now.month).first;
      expect(monthSpend, 300.0);

      // Verify category spending breakdown
      final categoryTotals = await db.financeDao.watchCategorySpending(now.year, now.month).first;
      expect(categoryTotals['Food & Groceries'], 250.0);
      expect(categoryTotals['Transport'], 50.0);

      // Set budget and verify remaining
      await db.financeDao.setOverallBudget(15000.0, dailyLimit: 500.0);
      final budget = await db.financeDao.watchOverallBudget().first;
      expect(budget, isNotNull);
      expect(budget!.monthlyLimit, 15000.0);
      expect(budget.dailyLimit, 500.0);

      // Insert and verify savings goal
      await db.financeDao.insertSavingsGoal(
        SavingsGoalTableCompanion.insert(
          title: 'Laptop Upgrade Fund',
          targetAmount: 80000.0,
          savedAmount: const drift.Value(15000.0),
          targetDate: drift.Value(now.add(const Duration(days: 180))),
        ),
      );
      final goals = await db.financeDao.watchSavingsGoals().first;
      expect(goals.length, 1);
      expect(goals.first.title, 'Laptop Upgrade Fund');
      expect(goals.first.savedAmount, 15000.0);
    });
  });

  group('GPS Walking & Distance Module Tests', () {
    test('Persists completed walks, calculates distance totals, and handles daily goals', () async {
      final now = DateTime.now();

      // Record a walk session
      final id = await db.walkDao.insertWalk(
        WalkSessionTableCompanion.insert(
          startTime: now,
          endTime: drift.Value(now.add(const Duration(minutes: 35))),
          durationSeconds: const drift.Value(35 * 60),
          distanceMeters: const drift.Value(2850.0),
          avgPaceSecondsPerKm: const drift.Value(736.0),
          calories: const drift.Value(145),
          routeCoordinatesJson: const drift.Value('[[28.6139, 77.2090], [28.6145, 77.2105]]'),
          isCompleted: const drift.Value(true),
        ),
      );
      expect(id, isPositive);

      // Verify completed walks
      final completed = await db.walkDao.watchCompletedWalks().first;
      expect(completed.length, 1);
      expect(completed.first.distanceMeters, 2850.0);
      expect(completed.first.durationSeconds, 2100);

      // Verify today's distance
      final todayDist = await db.walkDao.watchTodayDistance().first;
      expect(todayDist, 2850.0);

      // Verify week's distance
      final weekDist = await db.walkDao.watchWeekDistance().first;
      expect(weekDist, 2850.0);

      // Verify activity goal default and custom setting
      final defaultGoal = await db.walkDao.watchActivityGoal().first;
      expect(defaultGoal.targetDistanceMeters, 5000.0);

      await db.walkDao.setActivityGoal(6500.0, 50);
      final updatedGoal = await db.walkDao.watchActivityGoal().first;
      expect(updatedGoal.targetDistanceMeters, 6500.0);
      expect(updatedGoal.targetWalkMinutes, 50);
    });
  });

  group('Daily Habits & Routines Module Tests', () {
    test('Creates habits, toggles completion, and tracks completed IDs', () async {
      // Insert habit
      final habitId = await db.habitDao.insertHabit(
        HabitTableCompanion.insert(
          title: '30-minute morning walk',
          category: const drift.Value('Health'),
        ),
      );
      expect(habitId, isPositive);

      // Watch completed IDs for today (initially empty)
      final initialCompleted = await db.habitDao.watchTodayCompletedHabitIds().first;
      expect(initialCompleted.contains(habitId), isFalse);

      // Toggle completion for today
      final isNowCompleted = await db.habitDao.toggleHabitToday(habitId);
      expect(isNowCompleted, isTrue);

      // Check status after toggle
      final updatedCompleted = await db.habitDao.watchTodayCompletedHabitIds().first;
      expect(updatedCompleted.contains(habitId), isTrue);

      // Toggle again to uncomplete
      final toggledOff = await db.habitDao.toggleHabitToday(habitId);
      expect(toggledOff, isFalse);

      final finalCompleted = await db.habitDao.watchTodayCompletedHabitIds().first;
      expect(finalCompleted.contains(habitId), isFalse);
    });
  });

  group('Water Hydration Module Tests', () {
    test('Logs water intake, sums today ml, and tracks daily goal', () async {
      // Default goal
      final defaultGoal = await db.waterDao.watchDailyWaterGoal().first;
      expect(defaultGoal, 2500);

      // Log 250 mL
      final id1 = await db.waterDao.addWater(250);
      expect(id1, isPositive);

      // Log 500 mL
      final id2 = await db.waterDao.addWater(500);
      expect(id2, isPositive);

      // Check sum
      final total = await db.waterDao.watchTodayWaterMl().first;
      expect(total, 750);

      // Check logs list
      final logs = await db.waterDao.watchTodayWaterLogs().first;
      expect(logs.length, 2);
      expect(logs.first.amountMl, 500); // newest first

      // Delete one log (undo)
      await db.waterDao.deleteWater(id2);
      final afterDelete = await db.waterDao.watchTodayWaterMl().first;
      expect(afterDelete, 250);

      // Update goal
      await db.waterDao.setDailyWaterGoal(3000);
      final updatedGoal = await db.waterDao.watchDailyWaterGoal().first;
      expect(updatedGoal, 3000);
    });
  });

  group('Free-First Local Deterministic AI Engine Tests', () {
    final aiEngine = LocalDeterministicAiEngine();

    test('Parses natural language expense into structured transaction proposal', () {
      final parsed = aiEngine.tryParseExpense('Spent ₹120 on auto ride to metro');
      expect(parsed, isNotNull);
      expect(parsed!['amount'], 120.0);
      expect(parsed['category'], 'Transport');
    });

    test('Parses natural language food expense accurately', () {
      final parsed = aiEngine.tryParseExpense('Bought coffee and snack for Rs 180');
      expect(parsed, isNotNull);
      expect(parsed!['amount'], 180.0);
      expect(parsed['category'], 'Food & Groceries');
    });

    test('Parses natural language water hydration intake', () {
      final parsed500 = aiEngine.tryParseWater('Drank 500ml water after morning walk');
      expect(parsed500, isNotNull);
      expect(parsed500!['amountMl'], 500);

      final parsedGlass = aiEngine.tryParseWater('Log a glass of water');
      expect(parsedGlass, isNotNull);
      expect(parsedGlass!['amountMl'], 250);

      final parsedBottle = aiEngine.tryParseWater('Drank 1 bottle of water');
      expect(parsedBottle, isNotNull);
      expect(parsedBottle!['amountMl'], 500);
    });

    test('Parses natural language study task with time estimate', () {
      final parsed = aiEngine.tryParseTask('Remind me to practice dynamic programming tomorrow');
      expect(parsed, isNotNull);
      expect(parsed!['title'], contains('practice dynamic programming'));
      expect(parsed['priority'], 'medium');
    });

    test('Explains computer science and study concepts locally without API calls', () {
      final explanation = aiEngine.tryExplainConcept('Explain quicksort algorithm');
      expect(explanation, isNotNull);
      expect(explanation, contains('QuickSort'));
      expect(explanation, contains('Divide-and-Conquer'));
    });
  });

  group('Thought Wall & Me-to-Me Mind Space Module Tests', () {
    test('Pins thoughts, sorts pinned on top, toggles pin, and deletes thoughts', () async {
      // 1. Insert normal thought
      final id1 = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'You don\'t need to have it all figured out today. Just write clean code.',
          mood: const drift.Value('me_to_me'),
        ),
      );
      expect(id1, isPositive);

      // 2. Insert pinned thought
      final id2 = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Consistently showing up beats sporadic intensity every time.',
          mood: const drift.Value('win'),
          isPinned: const drift.Value(true),
        ),
      );
      expect(id2, isPositive);

      // 3. Verify thoughts order (pinned first)
      final list = await db.thoughtDao.watchAllThoughts().first;
      expect(list.length, 2);
      expect(list.first.id, id2); // Pinned is on top
      expect(list.first.isPinned, isTrue);

      // 4. Toggle pin on id2
      await db.thoughtDao.togglePin(id2);
      final afterToggle = await db.thoughtDao.watchAllThoughts().first;
      expect(afterToggle.firstWhere((t) => t.id == id2).isPinned, isFalse);

      // 5. Delete thought
      await db.thoughtDao.deleteThought(id1);
      final remaining = await db.thoughtDao.watchAllThoughts().first;
      expect(remaining.length, 1);
      expect(remaining.first.id, id2);
    });
  });
}
