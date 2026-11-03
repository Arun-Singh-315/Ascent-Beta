import 'package:flutter/material.dart';
import '../../../core/providers/database_provider.dart';

/// The 5 Human Energy & Time Lenses for Things Hub.
/// Instead of rigid database kinds, human days are organized by cognitive load.
enum ThingsSmartLens {
  all(
    id: 'all',
    label: 'All',
    icon: Icons.auto_awesome_mosaic_rounded,
  ),
  quickWins(
    id: 'quick_wins',
    label: '⚡ Quick Wins',
    icon: Icons.bolt_rounded,
  ),
  deepFocus(
    id: 'deep_focus',
    label: '🎯 Deep Focus',
    icon: Icons.center_focus_strong_rounded,
  ),
  lifeErrands(
    id: 'life_errands',
    label: '🏃 Life & Errands',
    icon: Icons.local_mall_outlined,
  ),
  windDown(
    id: 'wind_down',
    label: '🌙 Wind-down',
    icon: Icons.nights_stay_rounded,
  );

  final String id;
  final String label;
  final IconData icon;

  const ThingsSmartLens({
    required this.id,
    required this.label,
    required this.icon,
  });
}

/// Action chip types that can be triggered directly from an enriched card.
enum ThingsActionType {
  focusTimer,
  moneyLog,
  reminder,
  complete,
  custom,
}

class ThingsActionChipData {
  final String label;
  final IconData icon;
  final ThingsActionType type;

  const ThingsActionChipData({
    required this.label,
    required this.icon,
    required this.type,
  });
}

/// The intelligent metadata synthesized for any task.
/// Things Hub never just reflects dumb text; it attaches domain blueprints,
/// micro-steps, and contextual action chips.
class ThingsEnrichment {
  final String categoryLabel;
  final IconData categoryIcon;
  final Color categoryColor;
  final ThingsSmartLens smartLens;
  final int suggestedMinutes;
  final List<String> microSteps;
  final List<ThingsActionChipData> actionChips;
  final String proTip;

  const ThingsEnrichment({
    required this.categoryLabel,
    required this.categoryIcon,
    required this.categoryColor,
    required this.smartLens,
    required this.suggestedMinutes,
    required this.microSteps,
    required this.actionChips,
    required this.proTip,
  });
}

/// Intelligence Engine: Analyzes raw task titles and notes using NLP-style
/// semantic intent detection, generating immediate domain blueprints.
class ThingsEnrichmentEngine {
  ThingsEnrichmentEngine._();

  static ThingsEnrichment analyze(TodayActivityItem activity) {
    return analyzeText(
      activity.title,
      notes: activity.notes,
      targetMinutes: activity.targetMinutes,
      sourceType: activity.sourceType,
    );
  }

  static ThingsEnrichment analyzeText(
    String rawTitle, {
    String? notes,
    int? targetMinutes,
    String? sourceType,
  }) {
    final query = '${rawTitle.toLowerCase()} ${(notes ?? '').toLowerCase()}';

    // 1. Medicine & Prescription
    if (sourceType == 'medicine' ||
        _matches(query, [
          'medicine',
          'doctor',
          'pill',
          'tablet',
          'capsule',
          'dose',
          'prescription',
          'blood',
          'clinic',
          'hospital',
          'vitamin',
          'thyroid',
          'bp',
          'insulin',
          'dentist',
          'lab report',
          'test report',
        ])) {
      return const ThingsEnrichment(
        categoryLabel: 'Health & Medical',
        categoryIcon: Icons.medical_services_outlined,
        categoryColor: Color(0xFF34D399), // Glacial Eucalyptus
        smartLens: ThingsSmartLens.quickWins,
        suggestedMinutes: 5,
        microSteps: [
          'Review questions or symptom list before appointment',
          'Verify latest lab reports and prescription details',
          'Log doctor notes or refill instructions immediately',
        ],
        actionChips: [
          ThingsActionChipData(
            label: 'Mark Taken',
            icon: Icons.check_circle_outline_rounded,
            type: ThingsActionType.complete,
          ),
          ThingsActionChipData(
            label: 'Set Dose Alert',
            icon: Icons.alarm_rounded,
            type: ThingsActionType.reminder,
          ),
        ],
        proTip: 'Consistency in health is the anchor for high cognitive stamina.',
      );
    }

    // 2. Finance, Bills & Payments
    if (_matches(query, [
      'pay',
      'bill',
      'electricity',
      'rent',
      'emi',
      'sip',
      'hdfc',
      'card',
      'recharge',
      'wifi',
      'broadband',
      'tax',
      'invoice',
      'subscription',
      'payment',
      'fees',
      'due',
    ])) {
      return const ThingsEnrichment(
        categoryLabel: 'Finance & Bills',
        categoryIcon: Icons.account_balance_wallet_outlined,
        categoryColor: Color(0xFFFACC15), // Matte Brass
        smartLens: ThingsSmartLens.quickWins,
        suggestedMinutes: 3,
        microSteps: [
          'Verify exact due amount & billing period',
          'Complete payment via UPI or banking app',
          'Log transaction in Money hub & save confirmation',
        ],
        actionChips: [
          ThingsActionChipData(
            label: 'Log in Money',
            icon: Icons.account_balance_wallet_outlined,
            type: ThingsActionType.moneyLog,
          ),
          ThingsActionChipData(
            label: 'Mark Paid',
            icon: Icons.done_all_rounded,
            type: ThingsActionType.complete,
          ),
        ],
        proTip: 'Clearing financial micro-tasks early eliminates low-grade mental friction.',
      );
    }

    // 3. Deep Work, Engineering, Coding & DSA
    if (sourceType == 'lecture' ||
        (targetMinutes != null && targetMinutes >= 25) ||
        _matches(query, [
          'system design',
          'uber',
          'dsa',
          'leetcode',
          'code',
          'coding',
          'interview',
          'algo',
          'algorithm',
          'architecture',
          'study',
          'course',
          'lecture',
          'pr review',
          'refactor',
          'api',
          'debug',
          'database',
          'schema',
          'bug fix',
          'git',
        ])) {
      final mins = targetMinutes != null && targetMinutes > 0 ? targetMinutes : 45;
      return ThingsEnrichment(
        categoryLabel: 'Deep Focus & Engineering',
        categoryIcon: Icons.code_rounded,
        categoryColor: const Color(0xFFA78BFA), // Lavender Violet
        smartLens: ThingsSmartLens.deepFocus,
        suggestedMinutes: mins,
        microSteps: const [
          'Clarify scope, requirements & target constraints (2m)',
          'Draft core architecture, components & data flow',
          'Implement cleanly, verify edge cases & benchmark',
        ],
        actionChips: const [
          ThingsActionChipData(
            label: 'Start Focus Timer',
            icon: Icons.play_arrow_rounded,
            type: ThingsActionType.focusTimer,
          ),
          ThingsActionChipData(
            label: 'Unpack Details',
            icon: Icons.auto_awesome_rounded,
            type: ThingsActionType.custom,
          ),
        ],
        proTip: 'Deep focus delivers 4x the output in half the time when notifications are silenced.',
      );
    }

    // 4. Travel, Booking & Logistics
    if (_matches(query, [
      'flight',
      'ticket',
      'train',
      'booking',
      'hotel',
      'pack',
      'trip',
      'travel',
      'delhi',
      'mumbai',
      'bangalore',
      'airport',
      'cab',
      'uber',
      'ola',
      'journey',
      'passport',
      'visa',
    ])) {
      return const ThingsEnrichment(
        categoryLabel: 'Travel & Logistics',
        categoryIcon: Icons.flight_takeoff_rounded,
        categoryColor: Color(0xFF38BDF8), // Glacial Sky
        smartLens: ThingsSmartLens.lifeErrands,
        suggestedMinutes: 15,
        microSteps: [
          'Verify departure times, boarding terminal & PNR ticket',
          'Check official IDs, passes & charging cables',
          'Pack essentials in checklist order & lock luggage',
        ],
        actionChips: [
          ThingsActionChipData(
            label: 'Set Departure Alert',
            icon: Icons.alarm_rounded,
            type: ThingsActionType.reminder,
          ),
          ThingsActionChipData(
            label: 'Mark Done',
            icon: Icons.check_circle_outline_rounded,
            type: ThingsActionType.complete,
          ),
        ],
        proTip: 'Double checking travel documents before leaving prevents 95% of travel stress.',
      );
    }

    // 5. Groceries, Errands & Shopping
    if (_matches(query, [
      'grocery',
      'groceries',
      'buy',
      'milk',
      'vegetables',
      'market',
      'supermarket',
      'store',
      'order',
      'shopping',
      'fruits',
      'bread',
      'almonds',
      'supplies',
      'laundry',
      'clean',
    ])) {
      return const ThingsEnrichment(
        categoryLabel: 'Errands & Home',
        categoryIcon: Icons.shopping_basket_outlined,
        categoryColor: Color(0xFFF97316), // Warm Tangerine
        smartLens: ThingsSmartLens.lifeErrands,
        suggestedMinutes: 15,
        microSteps: [
          'Scan pantry and jot down missing items',
          'Pick high-priority fresh essentials first',
          'Confirm items and record expense if needed',
        ],
        actionChips: [
          ThingsActionChipData(
            label: 'Log Expense',
            icon: Icons.account_balance_wallet_outlined,
            type: ThingsActionType.moneyLog,
          ),
          ThingsActionChipData(
            label: 'Done',
            icon: Icons.check_circle_outline_rounded,
            type: ThingsActionType.complete,
          ),
        ],
        proTip: 'A quick 3-item list keeps shopping swift and avoids impulse purchases.',
      );
    }

    // 6. People, Communication & Meetings
    if (_matches(query, [
      'call',
      'talk to',
      'ring',
      'discuss',
      'meet',
      'meeting',
      'zoom',
      'sync',
      'message',
      'email',
      'reply',
      'whatsapp',
      'connect with',
    ])) {
      return const ThingsEnrichment(
        categoryLabel: 'People & Comms',
        categoryIcon: Icons.forum_outlined,
        categoryColor: Color(0xFFFB7185), // Champagne Rose
        smartLens: ThingsSmartLens.quickWins,
        suggestedMinutes: 10,
        microSteps: [
          'Clarify the single primary objective of the conversation',
          'Reach out or send succinct, respectful bullet notes',
          'Record decisions or next mutual steps immediately',
        ],
        actionChips: [
          ThingsActionChipData(
            label: 'Connect Now',
            icon: Icons.phone_forwarded_rounded,
            type: ThingsActionType.custom,
          ),
          ThingsActionChipData(
            label: 'Done',
            icon: Icons.check_circle_outline_rounded,
            type: ThingsActionType.complete,
          ),
        ],
        proTip: 'Direct, empathetic communication turns complex blockers into quick agreements.',
      );
    }

    // 7. Evening Wind-down, Habit & Reading
    if (_matches(query, [
      'read',
      'book',
      'journal',
      'reflect',
      'wind down',
      'sleep',
      'relax',
      'meditate',
      'walk',
      'chai',
      'tea',
      'evening',
    ])) {
      return const ThingsEnrichment(
        categoryLabel: 'Sanctuary & Unwind',
        categoryIcon: Icons.spa_outlined,
        categoryColor: Color(0xFF818CF8), // Twilight Indigo
        smartLens: ThingsSmartLens.windDown,
        suggestedMinutes: 20,
        microSteps: [
          'Step away from high-stimulus screens & notifications',
          'Immerse in a slow, relaxing pause or quiet chapter',
          'Close today’s loops with calm peace of mind',
        ],
        actionChips: [
          ThingsActionChipData(
            label: 'Start Sanctuary Pause',
            icon: Icons.spa_rounded,
            type: ThingsActionType.focusTimer,
          ),
          ThingsActionChipData(
            label: 'Done for Day',
            icon: Icons.nightlight_round,
            type: ThingsActionType.complete,
          ),
        ],
        proTip: 'Protecting your wind-down routine guarantees peak vitality tomorrow morning.',
      );
    }

    // 8. General Actionable Item
    final isFocus = targetMinutes != null && targetMinutes >= 20;
    return ThingsEnrichment(
      categoryLabel: isFocus ? 'Focus Task' : 'Quick Action',
      categoryIcon: isFocus ? Icons.timer_outlined : Icons.check_circle_outline_rounded,
      categoryColor: isFocus ? const Color(0xFFA78BFA) : const Color(0xFF94A3B8),
      smartLens: isFocus ? ThingsSmartLens.deepFocus : ThingsSmartLens.quickWins,
      suggestedMinutes: targetMinutes ?? (isFocus ? 25 : 5),
      microSteps: const [
        'Define the immediate 2-minute starting action',
        'Eliminate nearby distractions and dive in',
        'Inspect completed result and mark done',
      ],
      actionChips: [
        ThingsActionChipData(
          label: isFocus ? 'Start Focus' : 'Mark Done',
          icon: isFocus ? Icons.play_arrow_rounded : Icons.check_circle_outline_rounded,
          type: isFocus ? ThingsActionType.focusTimer : ThingsActionType.complete,
        ),
      ],
      proTip: 'Action precedes motivation. Taking the first 2-minute step unlocks momentum.',
    );
  }

  static bool _matches(String text, List<String> keywords) {
    for (final kw in keywords) {
      if (text.contains(kw)) return true;
    }
    return false;
  }
}
