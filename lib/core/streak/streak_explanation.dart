import 'study_streak_models.dart';

String streakExplanation(StudyStreakStatus status) =>
    '''A study streak is consecutive days when you meet the study-time target. The first completed day starts day 1.

What counts: time actively running in Learning or a Focus session in the Study category. Running Learning and Study Focus together counts each real second once. Time while paused, Chai breaks, walking, and ticking a task checkbox do not count. Marking a lecture complete manually does not add study minutes.

The normal target is 120 minutes before local midnight. Your course's daily pace is a separate planning goal; it does not change this streak target.

${status.isRescueMode ? 'Recovery today: 120 minutes + ${status.yesterdayDeficitMinutes} minutes missed yesterday = ${status.targetMinutes} minutes. You need ${status.remainingMinutes} more minutes today.' : 'One missed target can be recovered the next day by adding yesterday’s missing minutes to 120. Missing the recovery day resets the streak; your saved learning progress stays.'}

Current streak: consecutive qualifying days. Longest: your best run. Start a timer to earn real study time.''';
