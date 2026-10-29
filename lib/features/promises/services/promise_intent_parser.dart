import '../models/promise_model.dart';

/// Intelligent, deterministic natural-language intent parser for promises.
/// Interprets user statements into structured commitments with zero AI latency,
/// providing an instant, warm, and highly dependable experience.
class PromiseIntentParser {
  /// Parse a natural language statement into a [PromiseProposal].
  static PromiseProposal parse(String input, {DateTime? now}) {
    now ??= DateTime.now();
    final raw = input.trim();
    final lower = raw.toLowerCase();

    // 1. Detect Privacy
    final isPrivate = _detectPrivacy(lower);

    // 2. Detect Duration
    final durationMatch = _extractDuration(lower);

    // 3. Detect Frequency
    final frequencyMatch = _extractFrequency(lower);

    // 4. Detect Target Date / Milestone
    final targetDate = extractTargetDate(lower, now: now);

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
    } else if (frequencyMatch != null &&
        !lower.contains('daily') &&
        !lower.contains('every day') &&
        !lower.contains('weekday')) {
      trackingType = PromiseTrackingType.frequency;
      frequencyPerWeek = frequencyMatch;
      targetValue = frequencyMatch.toDouble();
      unit = 'sessions';
    } else if (lower.contains('course') ||
        lower.contains('exam') ||
        lower.contains('project') ||
        lower.contains('reach') ||
        lower.contains('save')) {
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

    final title = _generateTitle(
      raw,
      lower,
      trackingType,
      targetValue,
      unit,
      frequencyPerWeek,
    );
    final coachReflection = _generateReflection(
      title,
      trackingType,
      targetValue,
      unit,
      frequencyPerWeek,
      targetDate,
    );

    final dayNames = [
      'monday',
      'tuesday',
      'wednesday',
      'thursday',
      'friday',
      'saturday',
      'sunday',
    ];
    var reminderDays = [
      for (var i = 0; i < dayNames.length; i++)
        if (lower.contains(dayNames[i])) i + 1,
    ];
    if (lower.contains('weekday')) reminderDays = [1, 2, 3, 4, 5];
    if (lower.contains('weekend')) reminderDays = [6, 7];
    final repeat = reminderDays.isNotEmpty
        ? PromiseRepeat.selectedDays
        : lower.contains('every day') ||
              lower.contains('daily') ||
              lower.contains('each day')
        ? PromiseRepeat.daily
        : frequencyMatch != null
        ? PromiseRepeat.weekly
        : PromiseRepeat.once;
    if (reminderDays.isEmpty) reminderDays = [1, 2, 3, 4, 5, 6, 7];
    final plannedTime = extractTime(lower);
    final reminderTime =
        lower.contains('remind') && !lower.contains('no reminder')
        ? plannedTime ?? '09:00'
        : null;
    final schedule = PromiseSchedule(
      startDate: promiseDay(now),
      repeat: repeat,
      endDate: targetDate,
      plannedTime: plannedTime,
      days: reminderDays,
    );

    return PromiseProposal(
      title: title,
      intention: raw,
      category: category,
      trackingType: trackingType,
      targetValue: targetValue,
      unit: unit,
      frequencyPerWeek: frequencyPerWeek,
      targetDate: targetDate,
      schedule: schedule,
      isPrivate: isPrivate,
      reminderTime: reminderTime,
      reminderDays: reminderDays,
      coachReflection: coachReflection,
    );
  }

  /// Apply natural language modification/edits to an existing proposal.
  static PromiseProposal applyAdjustment(
    PromiseProposal proposal,
    String text,
  ) {
    final lower = text.toLowerCase();
    var adjusted = proposal;

    // Privacy adjustment
    if (!lower.contains('not private') &&
        (lower.contains('private') ||
            lower.contains('secret') ||
            lower.contains('discreet'))) {
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
        trackingType: adjusted.trackingType == PromiseTrackingType.duration
            ? PromiseTrackingType.duration
            : PromiseTrackingType.frequency,
      );
    }

    // Reminder time adjustment: e.g. "Don't remind me at night", "Remind in morning"
    if (lower.contains("don't remind me at night") ||
        lower.contains('not at night') ||
        lower.contains('morning')) {
      adjusted = adjusted.copyWith(reminderTime: '09:00');
    } else if (lower.contains('no reminder') ||
        lower.contains('disable reminder')) {
      adjusted = adjusted.copyWith(reminderTime: null, reminderDays: const []);
    }

    // Target date adjustment
    final targetDate = extractTargetDate(lower);
    if (targetDate != null) {
      adjusted = adjusted.copyWith(
        targetDate: targetDate,
        trackingType: PromiseTrackingType.milestone,
      );
    }

    // "Make the goal easier"
    if (lower.contains('easier') || lower.contains('smaller')) {
      if (adjusted.trackingType == PromiseTrackingType.duration &&
          adjusted.targetValue > 15) {
        adjusted = adjusted.copyWith(
          targetValue: (adjusted.targetValue * 0.7).roundToDouble(),
        );
      } else if (adjusted.trackingType == PromiseTrackingType.frequency &&
          adjusted.frequencyPerWeek > 2) {
        adjusted = adjusted.copyWith(
          frequencyPerWeek: adjusted.frequencyPerWeek - 1,
        );
      }
    }

    final old =
        adjusted.schedule ??
        PromiseSchedule(startDate: promiseDay(DateTime.now()));
    if (lower.contains('weekday') ||
        lower.contains('weekend') ||
        lower.contains('every day') ||
        lower.contains('daily') ||
        freqMatch != null) {
      adjusted = adjusted.copyWith(
        schedule: old.copyWith(
          repeat: lower.contains('weekday') || lower.contains('weekend')
              ? PromiseRepeat.selectedDays
              : lower.contains('daily') || lower.contains('every day')
              ? PromiseRepeat.daily
              : PromiseRepeat.weekly,
          days: adjusted.reminderDays,
        ),
      );
    }
    if (targetDate != null) {
      adjusted = adjusted.copyWith(schedule: old.copyWith(endDate: targetDate));
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
    if (lower.contains('one hour') ||
        lower.contains('1 hour') ||
        lower.contains('an hour')) {
      return 60;
    }
    if (lower.contains('half an hour') || lower.contains('half hour')) {
      return 30;
    }

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

  static String? extractTime(String lower) {
    final explicit = RegExp(
      r'\b(\d{1,2})(?::(\d{2}))?\s*(am|pm)\b',
    ).firstMatch(lower);
    if (explicit != null) {
      var hour = int.parse(explicit[1]!);
      final minute = int.parse(explicit[2] ?? '0');
      if (hour < 1 || hour > 12 || minute > 59) return null;
      hour = hour % 12 + (explicit[3] == 'pm' ? 12 : 0);
      return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
    }
    final clock = RegExp(r'\b(\d{1,2}):(\d{2})\b').firstMatch(lower);
    if (clock != null) {
      final value = '${clock[1]!.padLeft(2, '0')}:${clock[2]}';
      if (validPromiseTime(value)) return value;
    }
    final baje = RegExp(r'\b(\d{1,2})(?::(\d{2}))?\s*(?:baje)?\b').firstMatch(lower);
    if (lower.contains('subah') || lower.contains('morning')) {
      final h = baje != null ? int.tryParse(baje.group(1)!) : null;
      if (h != null && h >= 1 && h <= 12) {
        return '${h.toString().padLeft(2, '0')}:00';
      }
      return '08:00';
    }
    if (lower.contains('afternoon') || lower.contains('dopahar')) {
      final h = baje != null ? int.tryParse(baje.group(1)!) : null;
      if (h != null && h >= 1 && h <= 12) {
        final hour = h < 12 ? h + 12 : h;
        return '${hour.toString().padLeft(2, '0')}:00';
      }
      return '14:00';
    }
    if (lower.contains('evening') || lower.contains('shaam')) {
      final h = baje != null ? int.tryParse(baje.group(1)!) : null;
      if (h != null && h >= 1 && h <= 12) {
        final hour = h < 12 ? h + 12 : h;
        return '${hour.toString().padLeft(2, '0')}:00';
      }
      return '19:00';
    }
    if (lower.contains('night') || lower.contains('raat')) {
      final h = baje != null ? int.tryParse(baje.group(1)!) : null;
      if (h != null && h >= 1 && h <= 12) {
        final hour = h < 12 ? h + 12 : h;
        return '${hour.toString().padLeft(2, '0')}:00';
      }
      return '21:00';
    }
    return null;
  }

  static DateTime? extractTargetDate(String text, {DateTime? now}) {
    now ??= DateTime.now();
    final lower = text.replaceFirst(
      RegExp(r'^.*?\b(?:until|by|before|tak)\s+'),
      '',
    );
    DateTime? valid(int year, int month, int day) {
      final date = DateTime(year, month, day);
      return date.year == year && date.month == month && date.day == day
          ? date
          : null;
    }

    final iso = RegExp(r'\b(20\d{2})-(\d{1,2})-(\d{1,2})\b').firstMatch(lower);
    if (iso != null) {
      return valid(int.parse(iso[1]!), int.parse(iso[2]!), int.parse(iso[3]!));
    }
    final numeric = RegExp(
      r'\b(\d{1,2})/(\d{1,2})(?:/(20\d{2}))?\b',
    ).firstMatch(lower);
    if (numeric != null) {
      return valid(
        int.parse(numeric[3] ?? '${now.year}'),
        int.parse(numeric[2]!),
        int.parse(numeric[1]!),
      );
    }
    const months = [
      'january',
      'february',
      'march',
      'april',
      'may',
      'june',
      'july',
      'august',
      'september',
      'october',
      'november',
      'december',
    ];
    for (var i = 0; i < months.length; i++) {
      final name = months[i];
      if (!RegExp('\\b(?:$name|${name.substring(0, 3)})\\b').hasMatch(lower)) {
        continue;
      }
      final yearMatch = RegExp(r'\b20\d{2}\b').firstMatch(lower);
      final year = yearMatch == null
          ? (i + 1 < now.month ? now.year + 1 : now.year)
          : int.parse(yearMatch[0]!);
      if (lower.contains('end of')) return DateTime(year, i + 2, 0);
      // Match either "3 November" or "November 3" without guessing month-end.
      final before = RegExp(
        r'\b(\d{1,2})(?:st|nd|rd|th)?\s+'
        '(?:$name|${name.substring(0, 3)})',
      ).firstMatch(lower);
      final after = RegExp(
        '(?:$name|${name.substring(0, 3)})'
        r'\s+(\d{1,2})(?:st|nd|rd|th)?\b',
      ).firstMatch(lower);
      final day = before?[1] ?? after?[1];
      if (day != null) return valid(year, i + 1, int.parse(day));
    }
    final daysMatch = RegExp(r'\b(\d+)\s*(?:days?|din)\b').firstMatch(lower);
    if (daysMatch != null) {
      final d = int.tryParse(daysMatch.group(1)!);
      if (d != null && d > 0 && d <= 365) {
        return DateTime(now.year, now.month, now.day + d);
      }
    }
    if (lower.contains('1 month') ||
        lower.contains('one month') ||
        lower.contains('ek mahina') ||
        lower.contains('next month') ||
        lower.contains('agle mahine')) {
      return DateTime(now.year, now.month + 1, now.day);
    }
    if (lower.contains('this week') || lower.contains('iss hafte')) {
      return DateTime(now.year, now.month, now.day + (7 - now.weekday));
    }
    if (lower.contains('end of month') ||
        lower.contains('end of this month') ||
        lower.contains('iss mahine ke aakhri')) {
      return DateTime(now.year, now.month + 1, 0);
    }
    if (lower.contains('tomorrow') || lower.contains('kal')) {
      return DateTime(now.year, now.month, now.day + 1);
    }
    if (lower.contains('today') || lower.contains('aaj')) return promiseDay(now);
    if (lower.contains('next week') || lower.contains('agle hafte')) {
      return DateTime(now.year, now.month, now.day + 7);
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
    if (lower.contains('study') ||
        lower.contains('spring boot') ||
        lower.contains('java') ||
        lower.contains('code') ||
        lower.contains('course') ||
        lower.contains('learn') ||
        lower.contains('read')) {
      return 'study';
    }
    if (lower.contains('gym') ||
        lower.contains('workout') ||
        lower.contains('exercise') ||
        lower.contains('weight') ||
        lower.contains('run') ||
        lower.contains('walk')) {
      return 'health';
    }
    if (lower.contains('call') ||
        lower.contains('parent') ||
        lower.contains('mom') ||
        lower.contains('dad') ||
        lower.contains('friend') ||
        lower.contains('family')) {
      return 'relationships';
    }
    if (lower.contains('save') ||
        lower.contains('money') ||
        lower.contains('budget') ||
        lower.contains('expense')) {
      return 'finance';
    }
    if (lower.contains('scroll') ||
        lower.contains('doubt') ||
        lower.contains('peace') ||
        lower.contains('meditate') ||
        lower.contains('myself')) {
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
        .replaceAll(
          RegExp(
            r'^(i promise myself|i promise to|i want to|i need to|i have to)\s+',
            caseSensitive: false,
          ),
          '',
        )
        .trim();

    // Strip trailing modifiers like ", keep this private"
    cleaned = cleaned
        .replaceAll(
          RegExp(r',?\s*keep this private.*$', caseSensitive: false),
          '',
        )
        .trim();

    // If cleaned starts with lowercase, capitalize first character
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
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
