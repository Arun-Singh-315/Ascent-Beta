import '../models/promise_model.dart';

/// Intelligent, deterministic natural-language intent parser for promises.
/// Interprets user statements into structured commitments with zero AI latency,
/// providing an instant, warm, and highly dependable experience.
class PromiseIntentParser {
  /// Parse a natural language statement into a [PromiseProposal].
  static PromiseProposal parse(String input) {
    final raw = input.trim();
    final lower = raw.toLowerCase();

    // 1. Detect Privacy
    final isPrivate = _detectPrivacy(lower);

    // 2. Detect Duration
    final durationMatch = _extractDuration(lower);

    // 3. Detect Frequency
    final frequencyMatch = _extractFrequency(lower);

    // 4. Detect Target Date / Milestone
    final targetDate = _extractTargetDate(lower);

    // 5. Detect Reflection / Behavioral
    final isReflection = _detectReflection(lower);

    // 6. Detect Category
    final category = _detectCategory(lower);

    // Determine tracking type
    PromiseTrackingType trackingType;
    double targetValue = 1.0;
    String unit = '';
    int frequencyPerWeek = 0;

    if (durationMatch != null) {
      trackingType = PromiseTrackingType.duration;
      targetValue = durationMatch.toDouble();
      unit = 'minutes';
      if (frequencyMatch != null) {
        frequencyPerWeek = frequencyMatch;
      }
    } else if (frequencyMatch != null) {
      trackingType = PromiseTrackingType.frequency;
      frequencyPerWeek = frequencyMatch;
      targetValue = frequencyMatch.toDouble();
      unit = 'sessions';
    } else if (targetDate != null || lower.contains('course') || lower.contains('exam') || lower.contains('project') || lower.contains('reach') || lower.contains('save')) {
      trackingType = PromiseTrackingType.milestone;
      targetValue = 100.0;
      unit = 'percent';
    } else if (isReflection) {
      trackingType = PromiseTrackingType.reflection;
      targetValue = 1.0;
      unit = 'reflections';
    } else {
      trackingType = PromiseTrackingType.completion;
      targetValue = 1.0;
      unit = 'tasks';
    }

    final title = _generateTitle(raw, lower, trackingType, targetValue, unit, frequencyPerWeek);
    final coachReflection = _generateReflection(title, trackingType, targetValue, unit, frequencyPerWeek, targetDate);

    // Default reminder days: weekdays or daily
    List<int> reminderDays = const [1, 2, 3, 4, 5, 6, 7];
    if (lower.contains('weekday') || lower.contains('workday')) {
      reminderDays = const [1, 2, 3, 4, 5];
    } else if (lower.contains('weekend')) {
      reminderDays = const [6, 7];
    } else if (lower.contains('sunday')) {
      reminderDays = const [7];
    } else if (lower.contains('monday')) {
      reminderDays = const [1];
    }

    String? reminderTime;
    if (lower.contains('morning')) {
      reminderTime = '08:00';
    } else if (lower.contains('afternoon')) {
      reminderTime = '14:00';
    } else if (lower.contains('evening') || lower.contains('night')) {
      reminderTime = '20:30';
    } else {
      reminderTime = '09:00';
    }

    return PromiseProposal(
      title: title,
      intention: raw,
      category: category,
      trackingType: trackingType,
      targetValue: targetValue,
      unit: unit,
      frequencyPerWeek: frequencyPerWeek,
      targetDate: targetDate,
      isPrivate: isPrivate,
      reminderTime: reminderTime,
      reminderDays: reminderDays,
      coachReflection: coachReflection,
    );
  }

  /// Apply natural language modification/edits to an existing proposal.
  static PromiseProposal applyAdjustment(PromiseProposal proposal, String text) {
    final lower = text.toLowerCase();
    var adjusted = proposal;

    // Privacy adjustment
    if (lower.contains('private') || lower.contains('secret') || lower.contains('discreet')) {
      adjusted = adjusted.copyWith(isPrivate: true);
    } else if (lower.contains('public') || lower.contains('not private')) {
      adjusted = adjusted.copyWith(isPrivate: false);
    }

    // Duration adjustment: e.g. "Make it 30 minutes"
    final durationMatch = _extractDuration(lower);
    if (durationMatch != null) {
      adjusted = adjusted.copyWith(
        targetValue: durationMatch.toDouble(),
        unit: 'minutes',
        trackingType: PromiseTrackingType.duration,
      );
    }

    // Frequency adjustment: e.g. "Only on weekdays", "3 times a week"
    if (lower.contains('weekday') || lower.contains('workdays')) {
      adjusted = adjusted.copyWith(reminderDays: const [1, 2, 3, 4, 5]);
    } else if (lower.contains('weekend')) {
      adjusted = adjusted.copyWith(reminderDays: const [6, 7]);
    } else if (lower.contains('every day') || lower.contains('daily')) {
      adjusted = adjusted.copyWith(reminderDays: const [1, 2, 3, 4, 5, 6, 7]);
    }

    final freqMatch = _extractFrequency(lower);
    if (freqMatch != null) {
      adjusted = adjusted.copyWith(
        frequencyPerWeek: freqMatch,
        trackingType: PromiseTrackingType.frequency,
      );
    }

    // Reminder time adjustment: e.g. "Don't remind me at night", "Remind in morning"
    if (lower.contains("don't remind me at night") || lower.contains('not at night') || lower.contains('morning')) {
      adjusted = adjusted.copyWith(reminderTime: '09:00');
    } else if (lower.contains('no reminder') || lower.contains('disable reminder')) {
      adjusted = adjusted.copyWith(reminderTime: null, reminderDays: const []);
    }

    // Target date adjustment
    final targetDate = _extractTargetDate(lower);
    if (targetDate != null) {
      adjusted = adjusted.copyWith(
        targetDate: targetDate,
        trackingType: PromiseTrackingType.milestone,
      );
    }

    // "Make the goal easier"
    if (lower.contains('easier') || lower.contains('smaller')) {
      if (adjusted.trackingType == PromiseTrackingType.duration && adjusted.targetValue > 15) {
        adjusted = adjusted.copyWith(targetValue: (adjusted.targetValue * 0.7).roundToDouble());
      } else if (adjusted.trackingType == PromiseTrackingType.frequency && adjusted.frequencyPerWeek > 2) {
        adjusted = adjusted.copyWith(frequencyPerWeek: adjusted.frequencyPerWeek - 1);
      }
    }

    return adjusted;
  }

  static bool _detectPrivacy(String lower) {
    return lower.contains('private') ||
        lower.contains('keep this private') ||
        lower.contains('discreet') ||
        lower.contains('secret') ||
        lower.contains('confidential') ||
        lower.contains('alone') && lower.contains('myself');
  }

  static int? _extractDuration(String lower) {
    // Check minutes
    final minRegex = RegExp(r'(\d+)\s*(mins?|minutes?)');
    final minMatch = minRegex.firstMatch(lower);
    if (minMatch != null) {
      return int.tryParse(minMatch.group(1)!);
    }

    // Check hours
    final hourRegex = RegExp(r'(\d+)\s*(hours?|hrs?)');
    final hourMatch = hourRegex.firstMatch(lower);
    if (hourMatch != null) {
      final hours = int.tryParse(hourMatch.group(1)!);
      if (hours != null) return hours * 60;
    }

    // Word numbers like "two hours"
    if (lower.contains('two hours') || lower.contains('2 hours')) return 120;
    if (lower.contains('one hour') || lower.contains('1 hour') || lower.contains('an hour')) return 60;
    if (lower.contains('half an hour') || lower.contains('half hour')) return 30;

    return null;
  }

  static int? _extractFrequency(String lower) {
    final freqRegex = RegExp(r'(\d+)\s*(times?|days?)\s*(a|per)\s*week');
    final match = freqRegex.firstMatch(lower);
    if (match != null) {
      return int.tryParse(match.group(1)!);
    }

    if (lower.contains('once a week')) return 1;
    if (lower.contains('twice a week')) return 2;
    if (lower.contains('weekdays') || lower.contains('workdays')) return 5;
    if (lower.contains('daily') || lower.contains('every day')) return 7;

    return null;
  }

  static DateTime? _extractTargetDate(String lower) {
    final now = DateTime.now();

    // Months mapping
    final months = {
      'january': 1,
      'february': 2,
      'march': 3,
      'april': 4,
      'may': 5,
      'june': 6,
      'july': 7,
      'august': 8,
      'september': 9,
      'october': 10,
      'november': 11,
      'december': 12,
    };

    for (final entry in months.entries) {
      if (lower.contains(entry.key)) {
        final year = entry.value < now.month ? now.year + 1 : now.year;
        // Last day of month
        final lastDay = DateTime(year, entry.value + 1, 0);
        return lastDay;
      }
    }

    if (lower.contains('tomorrow')) {
      return now.add(const Duration(days: 1));
    }
    if (lower.contains('next week')) {
      return now.add(const Duration(days: 7));
    }

    return null;
  }

  static bool _detectReflection(String lower) {
    return lower.contains('stop') ||
        lower.contains('scroll') ||
        lower.contains('doubt') ||
        lower.contains('mindset') ||
        lower.contains('peace') ||
        lower.contains('reflect') ||
        lower.contains('work on myself') ||
        lower.contains('consistent');
  }

  static String _detectCategory(String lower) {
    if (lower.contains('study') || lower.contains('spring boot') || lower.contains('java') || lower.contains('code') || lower.contains('course') || lower.contains('learn') || lower.contains('read')) {
      return 'study';
    }
    if (lower.contains('gym') || lower.contains('workout') || lower.contains('exercise') || lower.contains('weight') || lower.contains('run') || lower.contains('walk')) {
      return 'health';
    }
    if (lower.contains('call') || lower.contains('parent') || lower.contains('mom') || lower.contains('dad') || lower.contains('friend') || lower.contains('family')) {
      return 'relationships';
    }
    if (lower.contains('save') || lower.contains('money') || lower.contains('budget') || lower.contains('expense')) {
      return 'finance';
    }
    if (lower.contains('scroll') || lower.contains('doubt') || lower.contains('peace') || lower.contains('meditate') || lower.contains('myself')) {
      return 'wellness';
    }
    return 'personal';
  }

  static String _generateTitle(
    String raw,
    String lower,
    PromiseTrackingType trackingType,
    double targetValue,
    String unit,
    int frequencyPerWeek,
  ) {
    // Clean common prefixes
    String cleaned = raw
        .replaceAll(RegExp(r'^(i promise myself|i promise to|i want to|i need to|i have to)\s+', caseSensitive: false), '')
        .trim();

    // Strip trailing modifiers like ", keep this private"
    cleaned = cleaned.replaceAll(RegExp(r',?\s*keep this private.*$', caseSensitive: false), '').trim();

    // If cleaned starts with lowercase, capitalize first character
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }

    // Specific polish for common archetypes
    final studyMatch = RegExp(r'study\s+(.*?)(?:\s+for|\s+every|\s+daily|\s+each|$)', caseSensitive: false).firstMatch(cleaned);
    if (studyMatch != null && studyMatch.group(1)?.trim().isNotEmpty == true) {
      final subject = studyMatch.group(1)!.trim();
      return 'Study ${subject[0].toUpperCase()}${subject.substring(1)}';
    }

    final readMatch = RegExp(r'read\s+(.*?)(?:\s+for|\s+every|\s+daily|\s+each|$)', caseSensitive: false).firstMatch(cleaned);
    if (readMatch != null && readMatch.group(1)?.trim().isNotEmpty == true) {
      final subject = readMatch.group(1)!.trim();
      return 'Read ${subject[0].toUpperCase()}${subject.substring(1)}';
    }

    if (lower.contains('water') || lower.contains('hydration')) {
      return 'Drink Water Daily';
    }
    if (lower.contains('meditat')) {
      return 'Daily Meditation';
    }
    if (lower.contains('walk') || lower.contains('step')) {
      return 'Daily Walk';
    }
    if (lower.contains('gym') || lower.contains('workout') || lower.contains('exercise')) {
      return 'Gym Workout';
    }
    if (lower.contains('call') && (lower.contains('parent') || lower.contains('mom') || lower.contains('dad') || lower.contains('family'))) {
      return 'Call my parents';
    }
    if (lower.contains('finish this course') || lower.contains('finish course')) {
      return 'Finish Course';
    }
    if (lower.contains('stop') && lower.contains('scroll')) {
      return 'Limit Night Scrolling';
    }

    if (cleaned.length > 50) {
      return '${cleaned.substring(0, 47)}...';
    }
    return cleaned.isEmpty ? 'Personal Promise' : cleaned;
  }

  static String _generateReflection(
    String title,
    PromiseTrackingType trackingType,
    double targetValue,
    String unit,
    int frequencyPerWeek,
    DateTime? targetDate,
  ) {
    switch (trackingType) {
      case PromiseTrackingType.duration:
        return "Let's make this manageable. How about ${targetValue.toInt()} minutes of focused practice each session? We can track your time and adjust if needed.";
      case PromiseTrackingType.frequency:
        return "Consistency over intensity. Aiming for $frequencyPerWeek sessions a week is a sustainable rhythm that builds real lasting strength.";
      case PromiseTrackingType.milestone:
        return "Breaking a big goal into measurable steps prevents overwhelm. We'll keep the finish line in clear view.";
      case PromiseTrackingType.reflection:
        return "Mindfulness requires grace, not guilt. You'll have a discreet, quiet space to reflect whenever you need.";
      case PromiseTrackingType.completion:
        return "Clear, direct, and actionable. One deliberate step forward builds immediate trust in yourself.";
    }
  }
}
