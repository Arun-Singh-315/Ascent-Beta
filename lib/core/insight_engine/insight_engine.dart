import 'dart:math';

enum InsightType {
  staleNote,
  upcomingNoteRecap,
  pipelineStale,
  seriesAtRisk,
  taskLagging,
  consistencyDip,
  consistencyStreak,
  skillImbalance,
  generalPositivity,
}

class InsightItem {
  final String id;
  final InsightType type;
  final String headline;
  final String message;
  final String why;
  final String? actionLabel;
  final String? actionRoute;
  final DateTime generatedAt;

  InsightItem({
    required this.id,
    required this.type,
    required this.headline,
    required this.message,
    required this.why,
    this.actionLabel,
    this.actionRoute,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();
}

/// Intelligent Insight Engine that analyzes on-device data deterministically
/// and produces empathetic, actionable coaching insights with varied phrasing.
class InsightEngine {
  static final Random _rng = Random();

  /// Phrasing variant selector
  static String _pick(List<String> variants) => variants[_rng.nextInt(variants.length)];

  /// Generates a streak encouragement insight
  static InsightItem? forStreak(int streak) {
    if (streak < 2) return null;

    final variants = [
      '$streak-day streak going strong — keep the momentum alive today!',
      'You have shown up $streak days in a row. Small daily steps lead to massive outcomes.',
      'Consistency is your superpower: $streak days straight and climbing.',
      'Day $streak on lock. Let us keep the chain unbroken today!',
    ];

    return InsightItem(
      id: 'streak_$streak',
      type: InsightType.consistencyStreak,
      headline: 'Streak Active',
      message: _pick(variants),
      why: 'Based on: $streak consecutive active study days logged',
      actionLabel: 'Check in today',
      actionRoute: '/consistency',
    );
  }

  /// Generates a gentle check-in when consistency dips (2+ absent days)
  static InsightItem forConsistencyDip(int absentDays) {
    final variants = [
      'Rough few days? Let us scale down today\'s target so you can secure an easy win.',
      'Progress is not linear. Even 15 minutes today resets your momentum.',
      'Take a breath. No guilt, no stress — let us pick one small action for today.',
      'Every setback is a setup for a comeback. A quick session today gets you right back on track.',
    ];

    return InsightItem(
      id: 'consistency_dip_$absentDays',
      type: InsightType.consistencyDip,
      headline: 'Gentle Reset',
      message: _pick(variants),
      why: 'Based on: $absentDays days without an active study check-in',
      actionLabel: 'Log 15 min win',
      actionRoute: '/consistency',
    );
  }

  /// Generates pipeline follow-up nudge
  static InsightItem forStaleApplication({
    required String company,
    required String stage,
    required int daysInStage,
  }) {
    final variants = [
      '$company has been in "$stage" for $daysInStage days. Want to send a follow-up or check status?',
      'It has been $daysInStage days since updating $company ($stage). Time for a quick touchpoint?',
      'No news from $company for $daysInStage days. A polite check-in email could revive traction.',
      'Keep your pipeline warm: $company has been in $stage for $daysInStage days.',
    ];

    return InsightItem(
      id: 'pipeline_stale_${company}_$daysInStage',
      type: InsightType.pipelineStale,
      headline: 'Pipeline Follow-up',
      message: _pick(variants),
      why: 'Based on: $daysInStage days in "$stage" with no status update',
      actionLabel: 'View card',
      actionRoute: '/pipeline',
    );
  }

  /// Generates stale note nudge
  static InsightItem forStaleNote({
    required String topic,
    required int daysUntouched,
  }) {
    final variants = [
      'Haven\'t opened your notes on "$topic" in $daysUntouched days — keep, merge, or archive?',
      'Your "$topic" notes have been quiet for $daysUntouched days. Still relevant for your prep?',
      'Reviewing beats re-learning: your notes on "$topic" have sat for $daysUntouched days.',
    ];

    return InsightItem(
      id: 'stale_note_${topic}_$daysUntouched',
      type: InsightType.staleNote,
      headline: 'Note Review',
      message: _pick(variants),
      why: 'Based on: note has not been read or edited in $daysUntouched days',
      actionLabel: 'Open notes',
      actionRoute: '/notes',
    );
  }

  /// Generates note recap before interview deadline
  static InsightItem forUpcomingInterviewNoteRecap({
    required String topic,
    required String companyOrInterview,
    required int daysUntilInterview,
  }) {
    final variants = [
      'You wrote notes on "$topic" recently. Want a 3-minute recap before your $companyOrInterview interview in $daysUntilInterview days?',
      'Interview in $daysUntilInterview days: a quick skim of your "$topic" notes will freshen your recall.',
      'Prime your confidence: review your high-yield "$topic" notes before $companyOrInterview.',
    ];

    return InsightItem(
      id: 'recap_${topic}_$daysUntilInterview',
      type: InsightType.upcomingNoteRecap,
      headline: 'Interview Prep Recap',
      message: _pick(variants),
      why: 'Based on: $daysUntilInterview days until $companyOrInterview, notes on $topic exist',
      actionLabel: 'Review note',
      actionRoute: '/notes',
    );
  }

  /// Generates series at-risk nudge
  static InsightItem forSeriesAtRisk({
    required String seriesTitle,
    required int daysRemaining,
  }) {
    final variants = [
      'Series "$seriesTitle" is slipping behind schedule with $daysRemaining days left. Catch-up mode can rebalance it.',
      'Current pace on "$seriesTitle" is below target. Redistribute remaining items to stay on track?',
      'Heads up: "$seriesTitle" pace needs a slight boost to finish on time.',
    ];

    return InsightItem(
      id: 'series_at_risk_$seriesTitle',
      type: InsightType.seriesAtRisk,
      headline: 'Pace Alert',
      message: _pick(variants),
      why: 'Based on: completion pace vs required pace for series deadline',
      actionLabel: 'Redistribute pace',
      actionRoute: '/today',
    );
  }

  /// Generates skill balance nudge
  static InsightItem forSkillImbalance({
    required String weakTopic,
    required int solvedOtherCount,
  }) {
    final variants = [
      'You solved $solvedOtherCount problems this week, but 0 in "$weakTopic" (your self-rated growth area). Add 1 today?',
      'Targeted growth: "$weakTopic" was marked as needing attention. Try one beginner or medium problem today.',
      'Balancing your skills: sneak in one problem on "$weakTopic" before tackling comfortable topics.',
    ];

    return InsightItem(
      id: 'skill_imbalance_$weakTopic',
      type: InsightType.skillImbalance,
      headline: 'Skill Balance',
      message: _pick(variants),
      why: 'Based on: $solvedOtherCount problems logged without any in self-rated weak area ($weakTopic)',
      actionLabel: 'Log problem',
      actionRoute: '/dsa',
    );
  }

  /// Default daily positivity line when no specific nudge fires
  static String getDailyPositivity({
    int streak = 0,
    int? daysToInterview,
    String? targetRole,
  }) {
    if (daysToInterview != null && daysToInterview > 0) {
      if (daysToInterview <= 3) {
        return 'Final countdown: trust the hours you\'ve invested. Focus on calm execution.';
      } else if (daysToInterview <= 7) {
        return 'Interview in $daysToInterview days — high-yield reviews and mock practice today.';
      } else {
        return '$daysToInterview days until your target interview. Consistent daily effort wins the offer.';
      }
    }

    if (streak >= 3) {
      return '$streak-day streak going strong. Keep compounding your progress today.';
    }

    final generalVariants = [
      'One focused action today moves your career forward.',
      'Prepare with purpose — clarity comes from daily reps.',
      'Every interview is won during the quiet days of preparation.',
      'Focus on the process today; the results will take care of themselves.',
      'Build competence daily. Confidence follows competence.',
    ];

    return _pick(generalVariants);
  }
}
