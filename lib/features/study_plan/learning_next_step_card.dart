import 'package:flutter/material.dart';
import '../../app/theme/glass_theme.dart';
import '../../core/learning_hub/learning_hub_models.dart';
import '../../core/learning_hub/learning_plan_summary.dart';

/// One decision first; pace and syllabus are visible supporting actions.
class LearningNextStepCard extends StatelessWidget {
  const LearningNextStepCard({
    super.key,
    required this.course,
    required this.activeLecture,
    required this.elapsed,
    required this.playing,
    required this.onPlayer,
    required this.onSyllabus,
    this.compact = false,
  });
  final bool compact;
  final Course course;
  final Lecture? activeLecture;
  final int elapsed;
  final bool playing;
  final VoidCallback onPlayer, onSyllabus;
  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final empty = course.totalLectures == 0;
    final completed = !empty && course.nextLecture == null;
    final lesson = activeLecture?.isCompleted == false
        ? activeLecture
        : course.nextLecture;
    final plan = LearningPlanSummary(course);
    final label = empty
        ? 'Add lectures'
        : completed
        ? 'Review syllabus'
        : playing
        ? 'Return to player'
        : elapsed > 0
        ? 'Resume learning'
        : 'Start learning';
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: g.fill,
        border: Border.all(color: g.edge),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!compact)
            Text(
              empty
                  ? 'BUILD YOUR COURSE'
                  : completed
                  ? 'YOUR COURSE, COMPLETED'
                  : 'YOUR NEXT STEP',
              style: TextStyle(
                color: g.clay,
                fontWeight: FontWeight.w700,
                letterSpacing: 1,
                fontSize: 11,
              ),
            ),
          const SizedBox(height: 10),
          Text(
            compact ? (lesson?.title ?? course.title) : course.title,
            style: TextStyle(
              color: g.ink,
              fontSize: compact ? 18 : 23,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          if (!compact)
            Text(
              empty
                  ? 'Add modules and lectures to create your learning plan.'
                  : completed
                  ? 'All lectures are complete. Your syllabus and notes stay available.'
                  : lesson?.title ?? 'Add a lecture to begin',
              style: TextStyle(color: g.inkMuted, fontSize: 15),
            ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: course.progressFraction,
            color: g.sage,
            backgroundColor: g.edge,
            minHeight: 5,
            borderRadius: BorderRadius.circular(8),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              Text(
                '${course.completedLectures} of ${course.totalLectures} lectures complete',
                style: TextStyle(color: g.ink),
              ),
              if (!completed && !compact)
                Text(
                  '${(plan.remainingSeconds / 60).ceil()} min of learning left',
                  style: TextStyle(color: g.inkMuted),
                ),
            ],
          ),
          const SizedBox(height: 12),
          if (!compact)
            Text(plan.paceLabel, style: TextStyle(color: g.inkMuted)),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: completed || empty ? onSyllabus : onPlayer,
              icon: Icon(
                completed
                    ? Icons.check_circle_outline
                    : playing
                    ? Icons.equalizer
                    : Icons.play_arrow_rounded,
              ),
              label: Text(label),
            ),
          ),
          if (!completed && !compact)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onSyllabus,
                icon: const Icon(Icons.list_alt_outlined),
                label: const Text('Explore syllabus & notes'),
              ),
            ),
          const SizedBox(height: 8),
          if (!compact)
            Text(
              'Your daily course pace is a plan. The study streak has its own 120-minute target; only active study time counts.',
              style: TextStyle(color: g.inkMuted, fontSize: 12, height: 1.5),
            ),
        ],
      ),
    );
  }
}
