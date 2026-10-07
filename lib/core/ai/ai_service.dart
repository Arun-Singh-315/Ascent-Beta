import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../database/app_database.dart';
import '../providers/database_provider.dart';
import '../learning_hub/learning_hub_provider.dart';
import '../learning_hub/learning_hub_models.dart';
import '../walk/walk_tracking_service.dart';

enum AiActionType {
  taskCreated,
  activityCreated,
  expenseLogged,
  dailyPlanSuggested,
  conceptExplained,
  personalInsight,
  waterLogged,
  lectureMarkedComplete,
  scheduleRearranged,
  generalResponse,
}

class AiProposedAction {
  final AiActionType type;
  final String title;
  final String summary;
  final Map<String, dynamic> payload;
  final List<String> quickOptions;

  const AiProposedAction({
    required this.type,
    required this.title,
    required this.summary,
    required this.payload,
    this.quickOptions = const [],
  });
}

class AiResponse {
  final String text;
  final bool isLocalDeterministic;
  final AiProposedAction? proposedAction;
  final List<String> clarifyingOptions;

  const AiResponse({
    required this.text,
    this.isLocalDeterministic = true,
    this.proposedAction,
    this.clarifyingOptions = const [],
  });
}

/// Abstract AI Engine Interface
abstract class AiEngineInterface {
  Future<AiResponse> processUserPrompt(String prompt, WidgetRef ref);
}

/// Robust, Offline, Deterministic Local Rule-based AI Engine
class LocalDeterministicAiEngine implements AiEngineInterface {
  @override
  Future<AiResponse> processUserPrompt(String prompt, WidgetRef ref) async {
    final lower = prompt.toLowerCase().trim();

    // 1. Natural Language Expense Logging ("spent ₹150 on coffee", "₹45 chai and snacks")
    final expenseMatch = tryParseExpense(prompt);
    if (expenseMatch != null) {
      return AiResponse(
        text: 'I parsed your expense of ₹${expenseMatch['amount']} for "${expenseMatch['title']}". Confirm below to save it to your financial records.',
        proposedAction: AiProposedAction(
          type: AiActionType.expenseLogged,
          title: 'Log Expense: ₹${expenseMatch['amount']}',
          summary: 'Category: ${expenseMatch['category']} • Account: ${expenseMatch['account']}',
          payload: expenseMatch,
        ),
      );
    }

    // 2. Hydration Intake ("drank 250ml water", "drink 500ml water", "log 2 glasses of water")
    final waterMatch = tryParseWater(prompt);
    if (waterMatch != null) {
      final ml = waterMatch['amountMl'] as int;
      return AiResponse(
        text: 'Hydration recorded: $ml mL. Tap below to log it to your daily water target.',
        proposedAction: AiProposedAction(
          type: AiActionType.waterLogged,
          title: 'Log Water: +$ml mL',
          summary: 'Recorded to SQLite • Progress updates immediately',
          payload: waterMatch,
        ),
      );
    }

    // 3. Lecture Completion ("I finished the first two lectures", "completed lecture 1", "done with first 2 lectures")
    final lectureCompletion = _tryParseLectureCompletion(lower, ref);
    if (lectureCompletion != null) {
      return lectureCompletion;
    }

    // 4. Free Time & Contextual Guidance ("I have 45 minutes free. What should I work on?")
    if (lower.contains('free') && (lower.contains('minute') || lower.contains('min') || lower.contains('hour') || lower.contains('what should i') || lower.contains('work on'))) {
      return _generateFreeTimeGuidance(lower, ref);
    }

    // 5. Schedule Rescheduling / Rearranging ("move my workout to the evening", "couldn't complete today's study plan. Help me rearrange it")
    final rescheduleResponse = await _tryParseReschedule(lower, ref);
    if (rescheduleResponse != null) {
      return rescheduleResponse;
    }

    // 6. Sleep Schedule ("I want to sleep by 11 PM", "sleep at 10 pm")
    if (lower.contains('sleep') && (lower.contains('by') || lower.contains('at') || lower.contains('pm') || lower.contains('tonight'))) {
      return _handleSleepSchedule(prompt);
    }

    // 7. Ambiguous activity clarifying check (e.g. "I want to exercise tomorrow" without duration)
    final ambiguousClarification = _checkAmbiguousClarification(prompt, lower);
    if (ambiguousClarification != null) {
      return ambiguousClarification;
    }

    // 8. General Natural Language Task & Activity Creation
    // (Handles: "need to call saurabh at 2", "complete java spring boot today", "need to finish java tutorial today", "add todo need to complete java", "I want to exercise for 30 minutes after waking up", "remind me to apply for jobs tomorrow morning", "I need to study Java for two hours today", "add a task to call my friend")
    final taskMatch = tryParseActivityOrTask(prompt);
    if (taskMatch != null) {
      final dateStr = taskMatch['plannedDate'] != null
          ? DateFormat('EEE, MMM d').format(DateTime.parse(taskMatch['plannedDate']))
          : 'Today';
      final kindStr = taskMatch['kind'] == 'duration'
          ? 'Timed Activity (${taskMatch['estimatedMinutes']}m)'
          : taskMatch['kind'] == 'flexible'
              ? 'Flexible Activity'
              : 'To-do';
      final reminderInfo = taskMatch['reminderTime'] != null
          ? ' • Reminder at ${DateFormat('HH:mm').format(DateTime.parse(taskMatch['reminderTime']))}'
          : '';

      return AiResponse(
        text: 'I structured a new $kindStr: "${taskMatch['title']}" for $dateStr$reminderInfo. Confirm below to save it to your Activity Hub.',
        proposedAction: AiProposedAction(
          type: AiActionType.activityCreated,
          title: 'Add $kindStr: ${taskMatch['title']}',
          summary: 'Scheduled: $dateStr • Priority: ${taskMatch['priority']}$reminderInfo',
          payload: taskMatch,
        ),
      );
    }

    // 9. Smart Daily Planner ("plan my day", "daily plan", "schedule my study", "what should i do today")
    if (lower.contains('plan my day') || lower.contains('daily plan') || lower.contains('schedule my day') || lower.contains('what should i do')) {
      return await _generateDailyPlan(ref);
    }

    // 10. Personal Insights ("how am i doing", "insights", "my spending", "weekly summary", "progress")
    if (lower.contains('insight') || lower.contains('summary') || lower.contains('progress') || lower.contains('how am i doing') || lower.contains('spending status')) {
      return await _generatePersonalInsights(ref);
    }

    // 11. Concept Explanation ("explain dynamic programming", "what is binary search", "explain system design", etc.)
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

    // 12. Contextual Help & Guidance
    return const AiResponse(
      text: "I am your local on-device AI life assistant. Here is what I can do for you:\n\n"
          "• Manage Activities: \"Need to call Saurabh at 2\" or \"Study Java for 2 hours today\"\n"
          "• Track Learning: \"Finished the first two lectures\" or \"I have 45 mins free\"\n"
          "• Organize Day: \"Plan my day\" or \"Move my workout to the evening\"\n"
          "• Log Finances: \"Spent ₹120 on lunch\" or \"₹45 chai\"\n"
          "• Computer Science: \"Explain Dynamic Programming\" or \"What is QuickSort?\"\n\n"
          "Everything runs 100% on your device, completely free and private.",
      clarifyingOptions: [
        'Plan my day',
        'Need to call Saurabh at 2',
        'Study Java for 2 hours today',
        'Finished first two lectures',
      ],
    );
  }

  /// Parses Expenses with Indian Rupee and Category detection
  Map<String, dynamic>? tryParseExpense(String input) {
    final amountReg = RegExp(r'(?:₹|rs\.?|inr)?\s*([0-9]+(?:\.[0-9]{1,2})?)\s*(?:₹|rs\.?|inr|rupees)?', caseSensitive: false);
    final match = amountReg.firstMatch(input);
    if (match == null) return null;

    final amountStr = match.group(1);
    if (amountStr == null) return null;
    final amount = double.tryParse(amountStr);
    if (amount == null || amount <= 0) return null;

    final lower = input.toLowerCase();
    final isExpenseKeyword = lower.contains('spent') ||
        lower.contains('bought') ||
        lower.contains('expense') ||
        lower.contains('paid') ||
        lower.contains('chai') ||
        lower.contains('lunch') ||
        lower.contains('dinner') ||
        lower.contains('₹') ||
        lower.contains('rs');

    if (!isExpenseKeyword && !lower.startsWith(amountStr)) return null;

    String cleanTitle = input
        .replaceAll(RegExp(r'(?:spent|paid|bought|add expense|expense of|for|on|₹|rs\.?|rupees|inr|[0-9]+(?:\.[0-9]+)?)', caseSensitive: false), ' ')
        .trim();
    if (cleanTitle.isEmpty) cleanTitle = 'Quick Expense';

    String category = 'Other';
    final tLower = cleanTitle.toLowerCase();
    if (tLower.contains('tea') || tLower.contains('chai') || tLower.contains('coffee') || tLower.contains('lunch') || tLower.contains('dinner') || tLower.contains('food') || tLower.contains('grocer') || tLower.contains('snack') || tLower.contains('swiggy') || tLower.contains('zomato')) {
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

  /// Parses Water intake in ml, glasses, or bottles
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

  /// Parses Natural Language Activity, To-do, or Duration-based item
  Map<String, dynamic>? tryParseActivityOrTask(String input) {
    final lower = input.toLowerCase().trim();

    // Trigger patterns
    final isExplicitIntent = RegExp(
          r'^(?:i\s+)?(?:need to|have to|want to|plan to|must|remind me|add\s+(?:a\s+)?(?:task|todo)|create\s+(?:a\s+)?task|todo|complete|finish|call|buy|pay|submit|study|exercise|workout|meditate|walk)\b',
          caseSensitive: false,
        ).hasMatch(lower) ||
        lower.contains('after waking up') ||
        lower.contains('tomorrow morning') ||
        lower.contains('for two hours') ||
        lower.contains('for 30 minutes') ||
        (lower.contains('at ') && RegExp(r'at\s+\d+').hasMatch(lower));

    if (!isExplicitIntent) return null;

    // 1. Extract duration if mentioned
    int? durationMinutes;
    final minMatch = RegExp(r'(?:for\s+)?(\d+)\s*(?:minutes?|mins?|m\b)', caseSensitive: false).firstMatch(lower);
    final hrMatch = RegExp(r'(?:for\s+)?(\d+)\s*(?:hours?|hrs?|h\b)', caseSensitive: false).firstMatch(lower);
    final wordHrMatch = RegExp(r'(?:for\s+)?(one|two|three|four|half(?:\s+an)?)\s*(?:hours?|hr)', caseSensitive: false).firstMatch(lower);

    if (minMatch != null) {
      durationMinutes = int.tryParse(minMatch.group(1) ?? '');
    } else if (hrMatch != null) {
      final hrs = int.tryParse(hrMatch.group(1) ?? '');
      if (hrs != null) durationMinutes = hrs * 60;
    } else if (wordHrMatch != null) {
      final word = wordHrMatch.group(1)?.toLowerCase();
      if (word == 'one') {
        durationMinutes = 60;
      } else if (word == 'two') {
        durationMinutes = 120;
      } else if (word == 'three') {
        durationMinutes = 180;
      } else if (word == 'four') {
        durationMinutes = 240;
      } else if (word != null && word.startsWith('half')) {
        durationMinutes = 30;
      }
    }

    // 2. Extract date
    DateTime plannedDate = DateTime.now();
    if (lower.contains('tomorrow')) {
      plannedDate = plannedDate.add(const Duration(days: 1));
    } else if (lower.contains('in 2 days')) {
      plannedDate = plannedDate.add(const Duration(days: 2));
    }

    // 3. Extract time / reminder
    DateTime? reminderTime;
    final timeMatch = RegExp(r'at\s+(\d{1,2})(?::(\d{2}))?\s*(am|pm)?', caseSensitive: false).firstMatch(lower);
    if (timeMatch != null) {
      int hour = int.tryParse(timeMatch.group(1) ?? '') ?? 9;
      final minute = int.tryParse(timeMatch.group(2) ?? '0') ?? 0;
      final amPm = timeMatch.group(3)?.toLowerCase();

      if (amPm == 'pm' && hour < 12) hour += 12;
      if (amPm == 'am' && hour == 12) hour = 0;
      // If no AM/PM specified, guess based on context:
      // "at 2" -> afternoon 14:00 if hour < 7
      if (amPm == null && hour <= 6) hour += 12;

      reminderTime = DateTime(
        plannedDate.year,
        plannedDate.month,
        plannedDate.day,
        hour,
        minute,
      );
      // If time already passed today, push to tomorrow
      if (reminderTime.isBefore(DateTime.now()) && !lower.contains('tomorrow')) {
        reminderTime = reminderTime.add(const Duration(days: 1));
        plannedDate = reminderTime;
      }
    } else if (lower.contains('tomorrow morning') || lower.contains('after waking up') || lower.contains('in the morning')) {
      reminderTime = DateTime(plannedDate.year, plannedDate.month, plannedDate.day, 9, 0);
    } else if (lower.contains('tonight') || lower.contains('this evening')) {
      reminderTime = DateTime(plannedDate.year, plannedDate.month, plannedDate.day, 20, 0);
    }

    // 4. Clean title
    String cleanTitle = input
        .replaceAll(RegExp(r'^(?:i\s+)?(?:need to|have to|want to|plan to|must|remind me to|remind me|add\s+(?:a\s+)?(?:task|todo)(?:\s+to)?|create\s+(?:a\s+)?task|todo:?)\s*', caseSensitive: false), '')
        .replaceAll(RegExp(r'\s*(?:for\s+\d+\s*(?:minutes?|mins?|hours?|hrs?)|for\s+(?:one|two|three|half(?:\s+an)?)\s*hours?|tomorrow\s+morning|tomorrow|today|tonight|this\s+evening|after\s+waking\s+up|in\s+the\s+morning|at\s+\d{1,2}(?::\d{2})?\s*(?:am|pm)?)\b', caseSensitive: false), ' ')
        .trim();

    if (cleanTitle.isEmpty) cleanTitle = 'Focus Activity';

    // 5. Determine activity kind
    String kind = 'todo';
    if (durationMinutes != null && durationMinutes > 0) {
      kind = 'duration';
    } else {
      final tLower = cleanTitle.toLowerCase();
      final isToDotask = tLower.startsWith('call') ||
          tLower.startsWith('buy') ||
          tLower.startsWith('pay') ||
          tLower.startsWith('submit') ||
          tLower.contains('grocer') ||
          tLower.contains('bill') ||
          tLower.contains('friend') ||
          lower.contains('todo') ||
          lower.contains('remind me');

      if (!isToDotask && (tLower.contains('exercise') || tLower.contains('workout') || tLower.contains('study') || tLower.contains('meditate') || tLower.contains('walk'))) {
        kind = 'flexible';
      }
    }

    final isHighPriority = lower.contains('urgent') ||
        lower.contains('priority') ||
        lower.contains('important') ||
        lower.contains('must') ||
        lower.contains('today');

    return {
      'title': cleanTitle.length > 100 ? cleanTitle.substring(0, 100) : cleanTitle,
      'kind': kind,
      'estimatedMinutes': durationMinutes ?? (kind == 'flexible' ? -1 : null),
      'plannedDate': plannedDate.toIso8601String(),
      'reminderTime': reminderTime?.toIso8601String(),
      'priority': isHighPriority ? 'high' : 'medium',
    };
  }

  /// Backward-compatible alias for task parsing
  Map<String, dynamic>? tryParseTask(String input) => tryParseActivityOrTask(input);

  /// Parses Lecture Completion commands
  AiResponse? _tryParseLectureCompletion(String lower, WidgetRef ref) {
    if (!lower.contains('lecture') && !lower.contains('lectures')) return null;
    if (!lower.contains('finish') && !lower.contains('completed') && !lower.contains('done')) return null;

    final learningState = ref.read(learningHubProvider);
    final activeCourse = learningState.course;

    int countToMark = 1;
    final numMatch = RegExp(r'(?:first\s+)?(\d+)\s*lectures?').firstMatch(lower);
    final wordMatch = RegExp(r'(?:first\s+)?(one|two|three|four)\s*lectures?').firstMatch(lower);

    if (numMatch != null) {
      countToMark = int.tryParse(numMatch.group(1) ?? '1') ?? 1;
    } else if (wordMatch != null) {
      final w = wordMatch.group(1);
      if (w == 'one') {
        countToMark = 1;
      } else if (w == 'two') {
        countToMark = 2;
      } else if (w == 'three') {
        countToMark = 3;
      } else if (w == 'four') {
        countToMark = 4;
      }
    }

    // Collect unfinished lectures
    final unfinishedLectures = <Lecture>[];
    for (final m in activeCourse.modules) {
      for (final l in m.lectures) {
        if (!l.isCompleted) {
          unfinishedLectures.add(l);
          if (unfinishedLectures.length >= countToMark) break;
        }
      }
      if (unfinishedLectures.length >= countToMark) break;
    }

    if (unfinishedLectures.isEmpty) {
      return AiResponse(
        text: 'All lectures in "${activeCourse.title}" are already completed! Outstanding work.',
      );
    }

    final titles = unfinishedLectures.map((l) => '"${l.title}"').join(', ');
    final lectureIds = unfinishedLectures.map((l) => l.id).toList();

    return AiResponse(
      text: 'Great work! I can mark ${unfinishedLectures.length} lecture(s) completed in "${activeCourse.title}": $titles. Tap below to confirm and update your course progress.',
      proposedAction: AiProposedAction(
        type: AiActionType.lectureMarkedComplete,
        title: 'Complete ${unfinishedLectures.length} Lecture(s)',
        summary: 'Course: ${activeCourse.title} • Updates course completion immediately',
        payload: {
          'courseId': activeCourse.id,
          'lectureIds': lectureIds,
          'count': unfinishedLectures.length,
        },
      ),
    );
  }

  /// Handles "I have 45 minutes free. What should I work on?"
  AiResponse _generateFreeTimeGuidance(String lower, WidgetRef ref) {
    int availableMins = 45;
    final minMatch = RegExp(r'(\d+)\s*(?:minutes?|mins?|m\b)').firstMatch(lower);
    if (minMatch != null) {
      availableMins = int.tryParse(minMatch.group(1) ?? '45') ?? 45;
    }

    final learningState = ref.read(learningHubProvider);
    final activeCourse = learningState.course;

    Lecture? recommendedLecture;
    for (final m in activeCourse.modules) {
      for (final l in m.lectures) {
        if (!l.isCompleted) {
          recommendedLecture = l;
          break;
        }
      }
      if (recommendedLecture != null) break;
    }

    final buffer = StringBuffer();
    buffer.writeln("With **$availableMins minutes free**, here is your optimal focus recommendation:\n");

    if (recommendedLecture != null) {
      final lecMins = (recommendedLecture.durationSeconds / 60).round();
      buffer.writeln("🎯 **Recommended Study Session:**");
      buffer.writeln("• **${recommendedLecture.title}** in *${activeCourse.title}*");
      buffer.writeln("• Estimated: ~$lecMins mins. Fits perfectly into your time window!");
    } else {
      buffer.writeln("🎯 **Study Status:** All lectures in ${activeCourse.title} are up to date!");
    }

    buffer.writeln("\n💡 **Action:** Tap below to start your study focus session or open your Activity Hub.");

    return AiResponse(
      text: buffer.toString(),
      proposedAction: recommendedLecture != null
          ? AiProposedAction(
              type: AiActionType.generalResponse,
              title: 'Study: ${recommendedLecture.title}',
              summary: '${activeCourse.title} • ${(recommendedLecture.durationSeconds / 60).round()} mins',
              payload: {
                'action': 'open_study',
                'lectureId': recommendedLecture.id,
              },
            )
          : null,
      clarifyingOptions: [
        if (recommendedLecture != null) 'Start ${recommendedLecture.title}',
        'Plan my day',
        'Show my spending & study summary',
      ],
    );
  }

  /// Handles Rescheduling / Rearranging
  Future<AiResponse?> _tryParseReschedule(String lower, WidgetRef ref) async {
    final isReschedule = lower.contains('rearrange') ||
        lower.contains('reschedule') ||
        lower.contains('move my') ||
        lower.contains('couldn\'t complete') ||
        lower.contains('shift my');

    if (!isReschedule) return null;

    List<Task> pending = [];
    try {
      final taskDao = ref.read(taskDaoProvider);
      final todayTasks = await taskDao.watchTasksByDate(DateTime.now()).first.timeout(
        const Duration(milliseconds: 600),
        onTimeout: () => <Task>[],
      );
      pending = todayTasks.where((t) => t.actualCompletedDate == null).toList();
    } catch (_) {}

    if (lower.contains('workout') || lower.contains('exercise')) {
      final workoutTask = pending.where((t) =>
          t.title.toLowerCase().contains('workout') ||
          t.title.toLowerCase().contains('exercise')).firstOrNull;

      final evening = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day, 18, 0);

      return AiResponse(
        text: workoutTask != null
            ? 'I found "${workoutTask.title}". I can reschedule it to this evening at 6:00 PM.'
            : 'I can schedule an evening workout session for you today at 6:00 PM.',
        proposedAction: AiProposedAction(
          type: AiActionType.scheduleRearranged,
          title: 'Reschedule Workout: 6:00 PM',
          summary: 'Moved to this evening (18:00) • Reminder set',
          payload: {
            'taskId': workoutTask?.id,
            'title': workoutTask?.title ?? 'Workout',
            'newDate': evening.toIso8601String(),
          },
        ),
      );
    }

    if (lower.contains('study plan') || lower.contains('study')) {
      final tomorrowMorning = DateTime.now().add(const Duration(days: 1));
      final newDate = DateTime(tomorrowMorning.year, tomorrowMorning.month, tomorrowMorning.day, 9, 0);

      return AiResponse(
        text: 'Consistency means adapting! I found ${pending.length} pending items today. I can rollover your remaining study tasks to tomorrow morning starting at 9:00 AM.',
        proposedAction: AiProposedAction(
          type: AiActionType.scheduleRearranged,
          title: 'Rollover Study Plan to Tomorrow',
          summary: 'Re-allocates ${pending.length} pending tasks to tomorrow morning (09:00)',
          payload: {
            'taskIds': pending.map((t) => t.id).toList(),
            'newDate': newDate.toIso8601String(),
          },
        ),
      );
    }

    return null;
  }

  /// Sleep Routine Handler
  AiResponse _handleSleepSchedule(String prompt) {
    final now = DateTime.now();
    final sleepTime = DateTime(now.year, now.month, now.day, 23, 0);

    return AiResponse(
      text: 'Good sleep is essential for optimal learning and cognitive recovery. I can set a Sleep Schedule for 11:00 PM tonight with an 8-hour target and a wind-down reminder at 10:30 PM.',
      proposedAction: AiProposedAction(
        type: AiActionType.activityCreated,
        title: 'Schedule Sleep Routine (11:00 PM)',
        summary: 'Target: 8h duration • Wind-down reminder at 10:30 PM',
        payload: {
          'title': 'Sleep',
          'kind': 'duration',
          'estimatedMinutes': 480,
          'plannedDate': sleepTime.toIso8601String(),
          'reminderTime': sleepTime.subtract(const Duration(minutes: 30)).toIso8601String(),
          'priority': 'high',
        },
      ),
    );
  }

  /// Intelligent clarifying questions for ambiguous duration activities
  AiResponse? _checkAmbiguousClarification(String input, String lower) {
    final isAmbiguousWorkout = (lower == 'i want to exercise tomorrow' ||
        lower == 'exercise tomorrow' ||
        lower == 'workout tomorrow' ||
        lower == 'i want to workout tomorrow' ||
        lower == 'i want to study tomorrow' ||
        lower == 'study tomorrow');

    if (!isAmbiguousWorkout) return null;

    final tomorrow = DateTime.now().add(const Duration(days: 1));
    final activityName = lower.contains('study') ? 'Study Session' : 'Workout';

    return AiResponse(
      text: 'Sure! Do you want to add $activityName as a simple to-do, or track it with a timer? And roughly how long should I schedule for it?',
      clarifyingOptions: [
        'Track 30m $activityName',
        'Track 45m $activityName',
        'Add as simple to-do',
      ],
      proposedAction: AiProposedAction(
        type: AiActionType.activityCreated,
        title: 'Schedule 30m $activityName',
        summary: 'Tomorrow • 30 mins timer • Ready to confirm or adjust',
        payload: {
          'title': activityName,
          'kind': 'duration',
          'estimatedMinutes': 30,
          'plannedDate': tomorrow.toIso8601String(),
          'priority': 'medium',
        },
      ),
    );
  }

  Future<AiResponse> _generateDailyPlan(WidgetRef ref) async {
    final profile = ref.read(userProfileStreamProvider).value;
    final userName = profile?.name.isNotEmpty == true ? profile!.name : 'Arun';

    // 1. Pending tasks with safe timeout
    List<Task> pending = [];
    try {
      final taskDao = ref.read(taskDaoProvider);
      final todayTasks = await taskDao.watchTasksByDate(DateTime.now()).first.timeout(
        const Duration(milliseconds: 600),
        onTimeout: () => <Task>[],
      );
      pending = todayTasks.where((t) => t.actualCompletedDate == null).toList();
    } catch (_) {}

    // 2. Walk status & distance
    final walkState = ref.read(walkTrackingProvider);
    final todayDistanceMeters = ref.read(todayWalkDistanceStreamProvider).value ?? 0.0;
    final kmWalked = (todayDistanceMeters / 1000.0).toStringAsFixed(1);
    final isWalkActive = walkState.status == WalkTrackingStatus.tracking;

    // 3. Finance status
    final todaySpend = ref.read(todaySpendingStreamProvider).value ?? 0.0;
    final budget = ref.read(overallBudgetStreamProvider).value;

    // 4. Hydration status
    final waterMl = ref.read(todayWaterMlStreamProvider).value ?? 0;
    final waterGoal = ref.read(dailyWaterGoalStreamProvider).value ?? 2500;

    // 5. Learning Hub status
    final learningState = ref.read(learningHubProvider);
    final course = learningState.course;
    Lecture? nextLecture;
    for (final m in course.modules) {
      for (final l in m.lectures) {
        if (!l.isCompleted) {
          nextLecture = l;
          break;
        }
      }
      if (nextLecture != null) break;
    }

    // 6. Upcoming Reminders
    final nextReminder = ref.read(nextUpcomingReminderProvider).value;

    final buffer = StringBuffer();
    buffer.writeln("Hi $userName! Here is your live situation & daily game plan:\n");

    // Critical Focus Areas
    if (waterMl < 1000) {
      buffer.writeln("💧 **Hydration Alert:** You've only logged $waterMl / $waterGoal mL. Drink a glass of water now!");
    } else {
      buffer.writeln("💧 **Hydration:** $waterMl / $waterGoal mL consumed — stay hydrated!");
    }

    if (isWalkActive) {
      buffer.writeln("🚶 **Walk Tracker:** Active outdoor session running (${(walkState.distanceKm).toStringAsFixed(2)} km). Pace: ${walkState.formattedPace}/km.");
    } else if (todayDistanceMeters < 2500) {
      buffer.writeln("🚶 **Physical Routine:** ${kmWalked}km walked today. Plan an evening walk to hit your 5.0km goal.");
    } else {
      buffer.writeln("🚶 **Physical Routine:** Great job! ${kmWalked}km covered today.");
    }

    if (nextReminder != null) {
      final dueTime = DateFormat('h:mm a').format(nextReminder.scheduledAt);
      buffer.writeln("🔔 **Upcoming Reminder:** \"${nextReminder.title}\" scheduled for $dueTime.");
    }

    buffer.writeln("");
    if (pending.isNotEmpty) {
      buffer.writeln("🎯 **Priority Activities (${pending.length} pending today):**");
      for (int i = 0; i < pending.take(3).length; i++) {
        final p = pending[i];
        final dur = p.estimatedMinutes != null && p.estimatedMinutes! > 0 ? " (${p.estimatedMinutes}m timer)" : "";
        buffer.writeln("  ${i + 1}. ${p.title}$dur");
      }
    } else {
      buffer.writeln("🎯 **Activities:** All today's activities are finished! Zero backlog.");
    }

    if (nextLecture != null) {
      buffer.writeln("\n🎓 **Study Target:** Next in \"${course.title}\" is \"${nextLecture.title}\" (${(nextLecture.durationSeconds ~/ 60)}m).");
    }

    buffer.writeln("\n💰 **Daily Budget:** ₹${todaySpend.toStringAsFixed(0)} spent today"
        "${budget != null && budget.monthlyLimit > 0 ? " (Monthly limit: ₹${budget.monthlyLimit.toStringAsFixed(0)})" : ""}.");

    return AiResponse(
      text: buffer.toString(),
      clarifyingOptions: [
        if (nextLecture != null) 'Start ${nextLecture.title}',
        'Log 250ml water',
        'Add a new activity',
        'Check pending activities',
      ],
      proposedAction: AiProposedAction(
        type: AiActionType.dailyPlanSuggested,
        title: 'Apply Daily Game Plan',
        summary: '${pending.length} tasks organized • Water & Walk monitored',
        payload: {
          'taskCount': pending.length,
          'walkTargetKm': 5.0,
        },
      ),
    );
  }

  Future<AiResponse> _generatePersonalInsights(WidgetRef ref) async {
    int dsaSolved = 0;
    try {
      final dsaDao = ref.read(dsaDaoProvider);
      dsaSolved = await dsaDao.getSolvedCountThisWeek().timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => 0,
      );
    } catch (_) {}

    final todayDistanceMeters = ref.read(todayWalkDistanceStreamProvider).value ?? 0.0;
    final weekKm = (todayDistanceMeters / 1000.0).toStringAsFixed(1);

    final todaySpend = ref.read(todaySpendingStreamProvider).value ?? 0.0;
    final budget = ref.read(overallBudgetStreamProvider).value;

    final streak = ref.read(currentStreakStreamProvider).value ?? 0;

    final learningState = ref.read(learningHubProvider);
    final course = learningState.course;

    final buffer = StringBuffer();
    buffer.writeln("📊 **Your Deterministic Life Insights:**\n");
    final pct = (course.progressFraction * 100).round();
    buffer.writeln("• **Course Progress:** $pct% completed in \"${course.title}\" (${course.completedLectures}/${course.totalLectures} lectures).");
    if (dsaSolved > 0) {
      buffer.writeln("• **Study & Practice:** $dsaSolved algorithm problems mastered this week.");
    }
    buffer.writeln("• **Physical Wellness:** $weekKm km active walk recorded.");
    buffer.writeln(
      '• **Financial Health:** ₹${todaySpend.toStringAsFixed(0)} spent today'
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
