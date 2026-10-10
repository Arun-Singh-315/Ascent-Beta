import 'dart:math';

enum ReminderIntent {
  payment,
  medicine,
  communication,
  studyOrTask,
}

/// Curated, raw, brotherly motivation and accountability copy.
/// Designed to cut through hesitation, dismantle friction, and boost the user
/// using the 5-Minute Rule, streak protection, or polite actionable intent templates.
class BoostNotificationCopy {
  static final _random = Random();

  static ReminderIntent detectIntent(String title) {
    final lower = title.toLowerCase();

    // Helper to check word boundaries or phrases
    bool matchesAny(List<String> keywords) {
      for (final kw in keywords) {
        if (kw.contains(' ')) {
          if (lower.contains(kw)) return true;
        } else {
          final regex = RegExp(r'\b' + RegExp.escape(kw) + r'\b', caseSensitive: false);
          if (regex.hasMatch(lower)) return true;
        }
      }
      return false;
    }

    // 1. Payment & Finance intent
    final paymentWords = [
      'sip', 'hdfc', 'emi', 'pay', 'payment', 'bill', 'rent', 'recharge',
      'fee', 'fees', 'due', 'card', 'transfer', 'credit', 'debit',
      'investment', 'mutual fund', 'tax', 'premium', 'invoice',
      'electricity', 'broadband', 'water bill',
    ];
    if (matchesAny(paymentWords)) return ReminderIntent.payment;

    // 2. Health & Medicine intent
    final medicineWords = [
      'medicine', 'pill', 'pills', 'tablet', 'tablets', 'capsule', 'capsules',
      'syrup', 'drops', 'dose', 'vitamin', 'vitamins', 'bp', 'thyroid',
      'insulin', 'ointment', 'injection', 'medication', 'doctor', 'clinic', 'hospital',
    ];
    if (matchesAny(medicineWords)) return ReminderIntent.medicine;

    // 3. Communication / Meetings
    final commWords = [
      'call', 'ring', 'reach out', 'meet', 'meeting', 'zoom',
      'talk to', 'appointment', 'connect with',
    ];
    if (matchesAny(commWords)) return ReminderIntent.communication;

    return ReminderIntent.studyOrTask;
  }

  /// Primary task reminder prompts (sent at the scheduled time).
  static NotificationMessage forScheduledTask(String taskTitle) {
    final intent = detectIntent(taskTitle);

    switch (intent) {
      case ReminderIntent.payment:
        final paymentList = [
          NotificationMessage(
            title: 'Payment Due: $taskTitle 💳',
            body: 'Hey, please pay $taskTitle. Clear this payment now to keep your finances stress-free and on track.',
            summary: '💳 Payment Reminder',
          ),
          NotificationMessage(
            title: 'Action Required: $taskTitle 💸',
            body: 'Hey! A quick reminder to complete your payment for "$taskTitle". Knock it out in a minute.',
            summary: '💳 Payment Due',
          ),
          NotificationMessage(
            title: 'Scheduled Payment: $taskTitle 🏦',
            body: 'Please pay $taskTitle today. Taking care of bills early keeps your momentum unbroken.',
            summary: '💳 Bill & SIP Alert',
          ),
        ];
        return paymentList[_random.nextInt(paymentList.length)];

      case ReminderIntent.medicine:
        final medList = [
          NotificationMessage(
            title: 'Time for your medicine: $taskTitle',
            body: 'Hey, please take your $taskTitle now. Consistency with your health comes first.',
            summary: 'Health Reminder',
          ),
          NotificationMessage(
            title: 'Health Dose: $taskTitle',
            body: 'Hey! Reminder to take $taskTitle. Stay on schedule and take care of yourself.',
            summary: 'Medicine Check',
          ),
        ];
        return medList[_random.nextInt(medList.length)];

      case ReminderIntent.communication:
        final commList = [
          NotificationMessage(
            title: 'Reminder to Connect: $taskTitle 📞',
            body: 'Hey, reminder to connect: $taskTitle. Take a minute and get in touch now.',
            summary: '📞 Call & Connect',
          ),
          NotificationMessage(
            title: 'Connect & Follow Up: $taskTitle 🤝',
            body: 'Time to connect and follow up on "$taskTitle". Make the call or send the message.',
            summary: '📞 Quick Connect',
          ),
        ];
        return commList[_random.nextInt(commList.length)];

      case ReminderIntent.studyOrTask:
        final list = [
          NotificationMessage(
            title: 'Time to lock in: $taskTitle 🔥',
            body:
                'Bro, you scheduled this for now. Don\'t overthink it — just sit down, open it up, and give it 5 mins. Momentum will do the rest.',
            summary: '⚡ 5-Min Rule',
          ),
          NotificationMessage(
            title: 'Your move: $taskTitle 👊',
            body:
                '5 mins only, bro. That\'s the deal. Show up, start the timer, and let\'s conquer this block.',
            summary: '🎯 Lock In',
          ),
          NotificationMessage(
            title: 'Future you is watching: $taskTitle 🚀',
            body:
                'Zero friction, bro. Open the screen, take 1 breath, and give it 5 mins. You\'ll thank yourself tonight.',
            summary: '⚡ Momentum',
          ),
          NotificationMessage(
            title: 'Let\'s get this win: $taskTitle ⚡',
            body:
                'The hardest part is just starting. 5 mins on the clock. Start now, bro.',
            summary: '🔥 5-Min Rule',
          ),
        ];
        return list[_random.nextInt(list.length)];
    }
  }

  /// Follow-up nudge (sent 20 minutes later if the user hasn't shown up).
  static NotificationMessage forMissingYouFollowUp(String taskTitle) {
    final intent = detectIntent(taskTitle);

    switch (intent) {
      case ReminderIntent.payment:
        return NotificationMessage(
          title: 'Pending Payment: $taskTitle 💳',
          body: 'Hey bro, "$taskTitle" is still pending. Don\'t let dues pile up — pay it now and stay relaxed.',
          summary: '💳 Payment Pending',
        );

      case ReminderIntent.medicine:
        return NotificationMessage(
          title: 'Health Check: $taskTitle',
          body: 'Hey bro, checking in — did you take your $taskTitle? Please take it now if you haven\'t yet.',
          summary: 'Medicine Pending',
        );

      case ReminderIntent.communication:
        return NotificationMessage(
          title: 'Follow-up: $taskTitle 📞',
          body: 'Hey, don\'t forget to connect for "$taskTitle". A quick ping takes 30 seconds.',
          summary: '📞 Call Pending',
        );

      case ReminderIntent.studyOrTask:
        final list = [
          NotificationMessage(
            title: 'Yo bro, where you at? 👀',
            body:
                'Still waiting on you for "$taskTitle". Missing you on the board bro. Just 5 mins. Sit down and open the screen, momentum will do the rest.',
            summary: '👊 Where You At?',
          ),
          NotificationMessage(
            title: 'Bro, don\'t let friction win today 🥊',
            body:
                'You planned "$taskTitle" today for a reason. Great streaks are built on days you didn\'t feel like starting. 5 mins only bro.',
            summary: '🛡️ Don\'t Break It',
          ),
          NotificationMessage(
            title: 'Missing you on the board bro ⚡',
            body:
                'Still waiting on "$taskTitle". Just 5 mins bro. That\'s all it takes to shift your entire trajectory today. Let\'s do it.',
            summary: '🔥 5-Min Rule',
          ),
          NotificationMessage(
            title: 'Bro, 5 minutes only. No excuses 🤝',
            body:
                '"$taskTitle" is still waiting. Don\'t let tomorrow carry yesterday\'s regret. Open Ascent and knock it out.',
            summary: '⚡ Just Start',
          ),
        ];
        return list[_random.nextInt(list.length)];
    }
  }

  /// Mid-day momentum check (14:30 daily).
  static NotificationMessage forMiddayCheck() {
    final list = [
      NotificationMessage(
        title: 'Yo bro, half the day is gone ⏳',
        body:
            'Where you at? Even 10 minutes of focus or study right now completely resets your trajectory for tonight. Lock in.',
        summary: '⚡ Mid-day Push',
      ),
      NotificationMessage(
        title: 'Mid-day check: Where\'s your head at? 🧠',
        body:
            'Don\'t coast through the afternoon. Close distractions, pick one task, and knock out 5 minutes.',
        summary: '🎯 Momentum Check',
      ),
    ];
    return list[_random.nextInt(list.length)];
  }

  /// Evening streak guardian (20:30 daily).
  static NotificationMessage forEveningStreakGuardian() {
    final list = [
      NotificationMessage(
        title: 'Bro, don\'t let the streak die tonight! 🔥',
        body:
            'Missing you today. Just 5 mins on your top priority tasks. Future you will be proud tomorrow morning. Let\'s do it.',
        summary: '⚡ Streak Guardian',
      ),
      NotificationMessage(
        title: 'Protect your streak, bro 🛡️',
        body:
            'Consistency is the only superpower that matters. 5 minutes before you call it a night. Keep the fire burning.',
        summary: '🔥 Keep The Fire',
      ),
    ];
    return list[_random.nextInt(list.length)];
  }

  /// Instant test boost preview.
  static NotificationMessage forTestBoost() {
    return const NotificationMessage(
      title: 'Yo bro! Momentum Engine is ACTIVE 🔥',
      body:
          'We\'ve got your back. Missing you? We\'ll nudge you. Just 5 minutes is all it takes to conquer any day. Let\'s do it bro!',
      summary: '⚡ Raw Boost Active',
    );
  }
}

class NotificationMessage {
  final String title;
  final String body;
  final String summary;

  const NotificationMessage({
    required this.title,
    required this.body,
    required this.summary,
  });
}
