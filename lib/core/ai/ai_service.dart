import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../providers/database_provider.dart';

enum AiActionType {
  taskCreated,
  expenseLogged,
  dailyPlanSuggested,
  conceptExplained,
  personalInsight,
  waterLogged,
  generalResponse,
}

class AiProposedAction {
  final AiActionType type;
  final String title;
  final String summary;
  final Map<String, dynamic> payload;

  const AiProposedAction({
    required this.type,
    required this.title,
    required this.summary,
    required this.payload,
  });
}

class AiResponse {
  final String text;
  final bool isLocalDeterministic;
  final AiProposedAction? proposedAction;

  const AiResponse({
    required this.text,
    this.isLocalDeterministic = true,
    this.proposedAction,
  });
}

/// Abstract AI Engine Interface
abstract class AiEngineInterface {
  Future<AiResponse> processUserPrompt(String prompt, WidgetRef ref);
}

/// Free, 100% Offline, Deterministic Local Rule-based AI Engine
class LocalDeterministicAiEngine implements AiEngineInterface {
  @override
  Future<AiResponse> processUserPrompt(String prompt, WidgetRef ref) async {
    final lower = prompt.toLowerCase().trim();

    // 1. Natural Language Expense Logging ("spent ₹150 on coffee", "₹45 snacks", "add expense 200 uber")
    final expenseMatch = tryParseExpense(prompt);
    if (expenseMatch != null) {
      return AiResponse(
        text: 'I parsed your expense of ₹${expenseMatch['amount']} for "${expenseMatch['title']}". Tap below to confirm and save it to your financial records.',
        proposedAction: AiProposedAction(
          type: AiActionType.expenseLogged,
          title: 'Log Expense: ₹${expenseMatch['amount']}',
          summary: 'Category: ${expenseMatch['category']} • Account: ${expenseMatch['account']}',
          payload: expenseMatch,
        ),
      );
    }

    // 2. Natural Language Task Creation ("remind me to study java tomorrow", "add task complete binary trees")
    final taskMatch = tryParseTask(prompt);
    if (taskMatch != null) {
      final dateStr = taskMatch['plannedDate'] != null
          ? DateFormat('EEE, MMM d').format(DateTime.parse(taskMatch['plannedDate']))
          : 'Today';
      return AiResponse(
        text: 'I structured a new task: "${taskMatch['title']}" scheduled for $dateStr. Tap below to confirm and add it to your Task Board.',
        proposedAction: AiProposedAction(
          type: AiActionType.taskCreated,
          title: 'Create Task: ${taskMatch['title']}',
          summary: 'Scheduled: $dateStr • Priority: ${taskMatch['priority']}',
          payload: taskMatch,
        ),
      );
    }

    // 3. Natural Language Water Logging ("drank 250ml water", "drink 500ml water", "log 2 glasses of water")
    final waterMatch = tryParseWater(prompt);
    if (waterMatch != null) {
      final ml = waterMatch['amountMl'] as int;
      return AiResponse(
        text: 'I parsed hydration intake of $ml mL. Tap below to confirm and log it to your daily water target.',
        proposedAction: AiProposedAction(
          type: AiActionType.waterLogged,
          title: 'Log Water: +$ml mL',
          summary: 'Recorded to SQLite • Progress updates immediately',
          payload: waterMatch,
        ),
      );
    }

    // 3. Smart Daily Planner ("plan my day", "daily plan", "schedule my study", "what should i do today")
    if (lower.contains('plan my day') || lower.contains('daily plan') || lower.contains('schedule my day') || lower.contains('what should i do')) {
      return await _generateDailyPlan(ref);
    }

    // 4. Personal Insights ("how am i doing", "insights", "my spending", "weekly summary", "progress")
    if (lower.contains('insight') || lower.contains('summary') || lower.contains('progress') || lower.contains('how am i doing') || lower.contains('spending status')) {
      return await _generatePersonalInsights(ref);
    }

    // 5. Concept Explanation ("explain dynamic programming", "what is binary search", "explain system design", etc.)
    final explanation = tryExplainConcept(lower);
    if (explanation != null) {
      return AiResponse(
        text: explanation,
        proposedAction: const AiProposedAction(
          type: AiActionType.conceptExplained,
          title: 'Study Concept Card',
          summary: 'Review key principles, time complexity, and practical tips.',
          payload: {},
        ),
      );
    }

    // 6. Helpful General Guidance
    return const AiResponse(
      text: "I am your local on-device AI life assistant. Here is what I can do for you:\n\n"
          "• Log expenses: \"Spent ₹120 on lunch\" or \"₹45 chai and snacks\"\n"
          "• Create tasks: \"Remind me to practice LeetCode tomorrow\"\n"
          "• Plan your day: \"Plan my day\" or \"Schedule today's study\"\n"
          "• Cross-module insights: \"Show my spending & study summary\"\n"
          "• Explain CS concepts: \"Explain Dynamic Programming\" or \"What is Two Pointers?\"\n\n"
          "Everything runs 100% on your device, completely free and private.",
    );
  }

  Map<String, dynamic>? tryParseExpense(String input) {
    // Regular expressions for amounts: ₹35, Rs. 150, 250 rs, etc.
    final amountReg = RegExp(r'(?:₹|rs\.?|inr)?\s*([0-9]+(?:\.[0-9]{1,2})?)\s*(?:₹|rs\.?|inr|rupees)?', caseSensitive: false);
    final match = amountReg.firstMatch(input);
    if (match == null) return null;

    final amountStr = match.group(1);
    if (amountStr == null) return null;
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return null;

    // Check if input indicates spending/expense
    final lower = input.toLowerCase();
    final isExpenseKeyword = lower.contains('spent') ||
        lower.contains('bought') ||
        lower.contains('expense') ||
        lower.contains('paid') ||
        lower.contains('₹') ||
        lower.contains('rs');

    if (!isExpenseKeyword && !lower.startsWith(amountStr)) return null;

    // Extract title & category
    String cleanTitle = input
        .replaceAll(RegExp(r'(?:spent|paid|bought|add expense|expense of|for|on|₹|rs\.?|rupees|inr|[0-9]+(?:\.[0-9]+)?)', caseSensitive: false), ' ')
        .trim();
    if (cleanTitle.isEmpty) cleanTitle = 'Quick Expense';

    String category = 'Other';
    final tLower = cleanTitle.toLowerCase();
    if (tLower.contains('tea') || tLower.contains('coffee') || tLower.contains('lunch') || tLower.contains('dinner') || tLower.contains('food') || tLower.contains('grocer') || tLower.contains('snack') || tLower.contains('swiggy') || tLower.contains('zomato')) {
      category = 'Food & Groceries';
    } else if (tLower.contains('uber') || tLower.contains('ola') || tLower.contains('metro') || tLower.contains('bus') || tLower.contains('auto') || tLower.contains('fuel') || tLower.contains('petrol') || tLower.contains('cab')) {
      category = 'Transport';
    } else if (tLower.contains('book') || tLower.contains('course') || tLower.contains('exam') || tLower.contains('tutor') || tLower.contains('study')) {
      category = 'Education';
    } else if (tLower.contains('movie') || tLower.contains('netflix') || tLower.contains('game') || tLower.contains('hotstar') || tLower.contains('show')) {
      category = 'Entertainment';
    } else if (tLower.contains('recharge') || tLower.contains('wifi') || tLower.contains('electric') || tLower.contains('rent') || tLower.contains('bill')) {
      category = 'Bills & Subscriptions';
    } else if (tLower.contains('doctor') || tLower.contains('medicine') || tLower.contains('gym') || tLower.contains('health')) {
      category = 'Health';
    } else if (tLower.contains('shirt') || tLower.contains('shoes') || tLower.contains('amazon') || tLower.contains('myntra') || tLower.contains('flipkart')) {
      category = 'Shopping';
    }

    return {
      'amount': amount,
      'title': cleanTitle.length > 50 ? cleanTitle.substring(0, 50) : cleanTitle,
      'category': category,
      'account': 'UPI',
      'date': DateTime.now().toIso8601String(),
    };
  }

  Map<String, dynamic>? tryParseWater(String input) {
    final lower = input.toLowerCase();
    if (!lower.contains('water') && !lower.contains('hydrat') && !lower.contains('drank') && !lower.contains('drink')) {
      return null;
    }

    final mlReg = RegExp(r'([0-9]+)\s*(?:ml|milliliters?|millilitres?)', caseSensitive: false);
    final match = mlReg.firstMatch(input);
    int ml = 250;
    if (match != null && match.group(1) != null) {
      final parsed = int.tryParse(match.group(1)!);
      if (parsed != null && parsed > 0 && parsed <= 5000) {
        ml = parsed;
      }
    } else if (lower.contains('bottle')) {
      final countReg = RegExp(r'([0-9]+)\s*bottle');
      final cMatch = countReg.firstMatch(lower);
      final count = cMatch != null ? int.tryParse(cMatch.group(1) ?? '1') ?? 1 : 1;
      ml = 500 * count;
    } else if (lower.contains('glass')) {
      final countReg = RegExp(r'([0-9]+)\s*glass');
      final cMatch = countReg.firstMatch(lower);
      final count = cMatch != null ? int.tryParse(cMatch.group(1) ?? '1') ?? 1 : 1;
      ml = 250 * count;
    } else if (lower.contains('cup')) {
      final countReg = RegExp(r'([0-9]+)\s*cup');
      final cMatch = countReg.firstMatch(lower);
      final count = cMatch != null ? int.tryParse(cMatch.group(1) ?? '1') ?? 1 : 1;
      ml = 150 * count;
    }

    return {'amountMl': ml};
  }

  Map<String, dynamic>? tryParseTask(String input) {
    final lower = input.toLowerCase();
    final isTaskIntent = lower.startsWith('remind me') ||
        lower.startsWith('plan a') ||
        lower.startsWith('add task') ||
        lower.startsWith('todo') ||
        lower.startsWith('create task');

    if (!isTaskIntent) return null;

    DateTime plannedDate = DateTime.now();
    if (lower.contains('tomorrow')) {
      plannedDate = plannedDate.add(const Duration(days: 1));
    } else if (lower.contains('in 2 days')) {
      plannedDate = plannedDate.add(const Duration(days: 2));
    }

    String cleanTitle = input
        .replaceAll(RegExp(r'^(remind me to|plan a|add task|todo|create task)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*(tomorrow|today|after lunch|in the morning|tonight|next week)\s*', caseSensitive: false), ' ')
        .trim();

    if (cleanTitle.isEmpty) cleanTitle = 'Focus Activity';

    return {
      'title': cleanTitle.length > 100 ? cleanTitle.substring(0, 100) : cleanTitle,
      'plannedDate': plannedDate.toIso8601String(),
      'priority': lower.contains('urgent') || lower.contains('priority') ? 'high' : 'medium',
    };
  }

  Future<AiResponse> _generateDailyPlan(WidgetRef ref) async {
    final taskDao = ref.read(taskDaoProvider);
    final todayTasks = await taskDao.watchTasksByDate(DateTime.now()).first;
    final pending = todayTasks.where((t) => t.actualCompletedDate == null).toList();

    final walkDao = ref.read(walkDaoProvider);
    final todayDistance = await walkDao.watchTodayDistance().first;

    final financeDao = ref.read(financeDaoProvider);
    final todaySpend = await financeDao.watchTodaySpending().first;
    final budget = await financeDao.watchOverallBudget().first;

    final buffer = StringBuffer();
    buffer.writeln("Here is your recommended Daily Life Plan:");
    buffer.writeln("");

    if (pending.isNotEmpty) {
      buffer.writeln("🎯 **Core Priorities (Study & Work):**");
      for (int i = 0; i < pending.take(3).length; i++) {
        buffer.writeln("  ${i + 1}. ${pending[i].title} (High focus session)");
      }
      buffer.writeln("");
    } else {
      buffer.writeln("🎯 **Core Priorities:** All scheduled tasks completed! Great time to revisit DSA or review notes.");
      buffer.writeln("");
    }

    // Walking routine
    final kmWalked = (todayDistance / 1000.0).toStringAsFixed(1);
    if (todayDistance < 3000) {
      buffer.writeln("🚶 **Physical Routine:** You have walked ${kmWalked}km today. Plan a 30-minute evening walk to reach 5.0km.");
    } else {
      buffer.writeln("🚶 **Physical Routine:** Excellent progress on activity! ${kmWalked}km completed today.");
    }
    buffer.writeln("");

    // Finance status
    buffer.writeln(
      '💰 **Daily Finance:** Spent ₹${todaySpend.toStringAsFixed(0)} today'
      '${budget != null ? " of your ₹${budget.monthlyLimit.toStringAsFixed(0)}/month budget." : "."}',
    );
    buffer.writeln("");

    // Water intake status
    final waterDao = ref.read(waterDaoProvider);
    final waterMl = await waterDao.watchTodayWaterMl().first;
    final waterGoal = await waterDao.watchDailyWaterGoal().first;
    buffer.writeln('💧 **Hydration:** $waterMl / $waterGoal mL consumed today.');

    return AiResponse(
      text: buffer.toString(),
      proposedAction: AiProposedAction(
        type: AiActionType.dailyPlanSuggested,
        title: 'Apply Daily Life Schedule',
        summary: '${pending.length} tasks organized • 1 walk planned • Budget monitored',
        payload: {
          'taskCount': pending.length,
          'walkTargetKm': 5.0,
        },
      ),
    );
  }

  Future<AiResponse> _generatePersonalInsights(WidgetRef ref) async {
    final dsaDao = ref.read(dsaDaoProvider);
    final dsaSolved = await dsaDao.getSolvedCountThisWeek();

    final walkDao = ref.read(walkDaoProvider);
    final weekMeters = await walkDao.watchWeekDistance().first;
    final weekKm = (weekMeters / 1000.0).toStringAsFixed(1);

    final financeDao = ref.read(financeDaoProvider);
    final now = DateTime.now();
    final monthSpend = await financeDao.watchMonthSpending(now.year, now.month).first;
    final budget = await financeDao.watchOverallBudget().first;

    final streak = await ref.read(consistencyDaoProvider).watchCurrentStreak().first;

    final buffer = StringBuffer();
    buffer.writeln("📊 **Your Deterministic Life Insights:**\n");
    buffer.writeln("• **Study & Practice:** $dsaSolved algorithm problems mastered this week.");
    buffer.writeln("• **Physical Wellness:** $weekKm km walked this week.");
    buffer.writeln(
      '• **Financial Health:** ₹${monthSpend.toStringAsFixed(0)} spent this month'
      '${budget != null ? " (Monthly limit: ₹${budget.monthlyLimit.toStringAsFixed(0)})" : ""}.',
    );
    buffer.writeln("• **Streak Consistency:** $streak-day continuous momentum active.");

    return AiResponse(
      text: buffer.toString(),
      proposedAction: const AiProposedAction(
        type: AiActionType.personalInsight,
        title: 'Weekly Life Health Card',
        summary: 'Cross-module metrics updated in real-time from SQLite database.',
        payload: {},
      ),
    );
  }

  String? tryExplainConcept(String prompt) {
    if (prompt.contains('quicksort') || prompt.contains('quick sort')) {
      return "📘 **QuickSort (Divide-and-Conquer)**\n\n"
          "QuickSort picks an element as a pivot and partitions the given array around the picked pivot.\n\n"
          "**Key Steps:**\n"
          "1. **Partition:** Place pivot at correct position, move smaller elements left, larger elements right.\n"
          "2. **Recurse:** Recursively sort left and right partitions.\n"
          "• Average Time: O(N log N)\n"
          "• Space: O(log N) stack frames\n"
          "• Worst Case: O(N²) when poorly chosen pivot (mitigate with randomized pivot).";
    }

    if (prompt.contains('dynamic programming') || prompt.contains('dp')) {
      return "📘 **Dynamic Programming (DP)**\n\n"
          "Dynamic Programming solves complex problems by breaking them down into overlapping subproblems with optimal substructure.\n\n"
          "**Key Steps:**\n"
          "1. **Identify the State:** What parameters define a subproblem? (e.g., `dp[i]` = max profit up to index i).\n"
          "2. **Find the Recurrence Relation:** How does state `i` depend on previous states? (e.g., `dp[i] = max(dp[i-1], dp[i-2] + val[i])`).\n"
          "3. **Base Cases:** Smallest subproblems that can be answered immediately.\n"
          "4. **Approach:** Top-down with Memoization OR Bottom-up Tabulation.\n\n"
          "**Classic Problems:** Climbing Stairs, 0/1 Knapsack, Longest Common Subsequence.";
    }

    if (prompt.contains('binary search')) {
      return "📘 **Binary Search (O(log N))**\n\n"
          "Efficient search algorithm on a **sorted array or monotonic search space**.\n\n"
          "**Template:**\n"
          "```dart\n"
          "int binarySearch(List<int> arr, int target) {\n"
          "  int low = 0, high = arr.length - 1;\n"
          "  while (low <= high) {\n"
          "    int mid = low + (high - low) ~/ 2;\n"
          "    if (arr[mid] == target) return mid;\n"
          "    if (arr[mid] < target) low = mid + 1;\n"
          "    else high = mid - 1;\n"
          "  }\n"
          "  return -1;\n"
          "}\n"
          "```\n"
          "**Key Pro-Tip:** Always compute `mid = low + (high - low) ~/ 2` to prevent 32-bit integer overflow!";
    }

    if (prompt.contains('system design') || prompt.contains('caching')) {
      return "📘 **System Design: Caching Tier**\n\n"
          "Caching stores frequently accessed data in fast in-memory stores (e.g., Redis, Memcached) to reduce database load and cut latency.\n\n"
          "**Common Patterns:**\n"
          "• **Cache-Aside:** Application reads cache first; on miss, reads DB, writes to cache.\n"
          "• **Write-Through:** Writes update cache and DB synchronously.\n"
          "• **Eviction Policies:** LRU (Least Recently Used), LFU (Least Frequently Used), TTL (Time-To-Live expiration).";
    }

    if (prompt.contains('two pointer')) {
      return "📘 **Two Pointers Technique**\n\n"
          "Used extensively for linear arrays and linked lists to achieve O(N) time and O(1) space.\n\n"
          "**Variations:**\n"
          "1. **Opposite Ends:** One pointer at start (0), one at end (n-1). Useful for sorted array pairs, palindrome verification.\n"
          "2. **Fast & Slow:** Floyd's cycle detection, finding middle of linked list.\n"
          "3. **Sliding Window:** Subarray sum, longest substring without repeating characters.";
    }

    return null;
  }
}

final aiEngineProvider = Provider<AiEngineInterface>((ref) {
  return LocalDeterministicAiEngine();
});
