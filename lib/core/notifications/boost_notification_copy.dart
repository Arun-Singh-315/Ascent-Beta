import 'dart:math';

/// Curated, raw, brotherly motivation and accountability copy.
/// Designed to cut through hesitation, dismantle friction, and boost the user
/// using the 5-Minute Rule and streak protection.
class BoostNotificationCopy {
  static final _random = Random();

  /// Primary task reminder prompts (sent at the scheduled time).
  static NotificationMessage forScheduledTask(String taskTitle) {
    final list = [
      NotificationMessage(
        title: 'Time to lock in: $taskTitle 🔥',
        body:
            'Bro, you scheduled this for now. Don\'t overthink it — just sit down, open it up, and give it 5 minutes. Momentum will do the rest.',
        summary: '⚡ 5-Min Rule',
      ),
      NotificationMessage(
        title: 'Your move: $taskTitle 👊',
        body:
            '5 minutes only, bro. That\'s the deal. Show up, start the timer, and let\'s conquer this block.',
        summary: '🎯 Lock In',
      ),
      NotificationMessage(
        title: 'Future you is watching: $taskTitle 🚀',
        body:
            'Zero friction, bro. Open the screen, take 1 breath, and give it 5 solid minutes. You\'ll thank yourself tonight.',
        summary: '⚡ Momentum',
      ),
      NotificationMessage(
        title: 'Let\'s get this win: $taskTitle ⚡',
        body:
            'The hardest part is just starting. 300 seconds on the clock. Start now, bro.',
        summary: '🔥 5-Min Rule',
      ),
    ];
    return list[_random.nextInt(list.length)];
  }

  /// Follow-up nudge (sent 20 minutes later if the user hasn't shown up).
  static NotificationMessage forMissingYouFollowUp(String taskTitle) {
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
