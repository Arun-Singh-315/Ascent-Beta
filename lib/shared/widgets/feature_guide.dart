import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

const featureGuides = <String, String>{
  'Thought Wall':
      'Write · Send a note like a message.\nOrganize · Swipe right to archive; left to delete with Undo.\nMore · Long-press for selection. Add Promise is at the top.',
  'Challenge Partner':
      'Create · Add independent challenges.\nChoose · Tap a card for status; its home icon selects the preview.\nProgress · Linked study and Focus update active challenges.',
  'Reminders & Alerts':
      'Create · Set a title, date and time. Normal notifications are the default.\nAlarm · Turn on Ring as an alarm for looping sound, Snooze and Done. Enable Android alarm access for popups.\nManage · Missed reminders stay Overdue. Snooze moves the time; Done completes the reminder, while tasks keep their own status.',
  'Focus Timer':
      'Start · Choose a timed task or a free Focus session. Study-category time counts toward the study streak; entertainment does not.\nControl · Pause when stepping away. Notification controls stay synchronized; tap the player card to return here.\nFinish · Save your session. Timed tasks complete only when their target is reached.',
  'Activity Hub':
      'Plan · Add a Todo or timed activity.\nComplete · Check Todos; use Focus for timed work.\nReturn · Add a reminder when useful.',
  'Today':
      'Plan · Add a Todo or timed activity.\nComplete · Check Todos; use Focus for timed work.\nEdit · Open an activity for its actions.',
  'Learning Hub':
      'Next step · Start or resume from the top card. Search and filter courses to find what you need.\nSyllabus · Open a course for modules, lectures, editing and notes. The player tracks your study time.\nGoals · Course pace is a plan; the study streak needs 120 active study minutes before local midnight. Paused time and manual completion checks do not count.',
  'Hydration Tracker':
      'Goal · Set your daily water target.\nLog · Use the drink buttons.\nReview · Check your recent water history.',
  'Walking & Activity':
      'Start · Allow location and begin an outdoor walk.\nPause · Stop tracking when taking a break.\nSave · Finish to store your route and history.',
  'Medicine & Health':
      'Add · Enter a prescription and dose times.\nRecord · Mark each dose when taken.\nReview · Check past doses in history.',
  'Job Pipeline':
      'Add · Save an application.\nMove · Change its stage as you progress.\nPrepare · Open a card for notes and linked tasks.',
  'Study Plan':
      'Organize · Create your courses and phases.\nStudy · Work through linked lectures and activities.\nReview · Adjust targets as your schedule changes.',
  'DSA Tracker':
      'Log · Add a problem, topic and difficulty.\nRevisit · Flag problems for another attempt.\nReview · Check practice history.',
  'Interview Prep':
      'Save · Add questions, company notes and dates.\nPractice · Review your question bank.\nFind · Search by question, company or topic.',
  'Consistency':
      'Review · Check daily study presence.\nBuild · Real study sessions count toward progress.\nToday · Home shows your study target.',
  'Resume Vault':
      'Upload · Add a resume version.\nOrganize · Name versions by role.\nUse · Open or share a saved file.',
  'Analytics & Velocity':
      'Review · Study hours, series and applications.\nCompare · Inspect progress over time.\nAdjust · Use the results to plan your next week.',
  'Money':
      'Record · Add income or expenses.\nReview · Choose a period to inspect spending.\nPlan · Set budget limits or savings goals.',
  'Settings':
      'Customize · Appearance, goals and notifications.\nProtect · Export a backup before restoring or clearing.\nHelp · Replay guides with the question-mark button.',
  'More':
      'Explore · Open study, career and daily tools.\nLearn · Read short first-use tips when needed.\nReturn · Use the feature help button to revisit tips.',
  'Chai & Coffee':
      'Rest · Choose a short break.\nRelax · Pick music or follow breathing.\nBrew · Follow a recipe with Brew With Me.',
  'Riya':
      'Ask · Try “What are my tasks today?”\nReview · Confirm an expense, task or water log before saving.\nLimits · Local rules; use feature screens for other actions.',
};

String? guideFor(String? feature) {
  if (feature == null) return null;
  if (featureGuides.containsKey(feature)) return featureGuides[feature];
  final name = feature.toLowerCase();
  for (final entry in featureGuides.entries) {
    if (name.contains(entry.key.toLowerCase())) return entry.value;
  }
  if (name.contains('consistency')) return featureGuides['Consistency'];
  if (name.contains('learning') || name.contains('courses')) {
    return featureGuides['Learning Hub'];
  }
  if (name.contains('study')) return featureGuides['Study Plan'];
  if (name.contains('pipeline')) return featureGuides['Job Pipeline'];
  if (name.contains('task') || name.contains('activity hub')) {
    return featureGuides['Activity Hub'];
  }
  if (name.contains('finance') || name.contains('money')) {
    return featureGuides['Money'];
  }
  return null;
}

Future<void> showFeatureGuide(BuildContext context, String feature) async {
  final copy = guideFor(feature);
  if (copy == null) return;
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(feature),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: copy
              .split('\n')
              .map(
                (tip) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpace.s12),
                  child: Text(tip),
                ),
              )
              .toList(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext),
          child: const Text('Got it'),
        ),
      ],
    ),
  );
}

class FeatureGuideHost extends StatefulWidget {
  const FeatureGuideHost({
    super.key,
    required this.feature,
    required this.child,
  });
  final String? feature;
  final Widget child;
  @override
  State<FeatureGuideHost> createState() => _FeatureGuideHostState();
}

class _FeatureGuideHostState extends State<FeatureGuideHost> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _introduce());
  }

  Future<void> _introduce() async {
    final feature = widget.feature;
    if (feature == null || guideFor(feature) == null) return;
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = 'feature_guide_v1_$feature';
      if (!mounted ||
          prefs.getBool(key) == true ||
          ModalRoute.of(context)?.isCurrent == false) {
        return;
      }
      await showFeatureGuide(context, feature);
      await prefs.setBool(key, true);
    } catch (_) {
      /* Guidance must never prevent opening a feature. */
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

final _tour = <(String, String, String)>[
  (
    'Your daily dashboard',
    'Home brings together today’s work, learning, Mind Space and health. Write directly under Mind Space and tap Send. New notes appear in the preview.',
    '/home',
  ),
  (
    'Plan your work',
    'Add a quick Todo or a timed activity. Quick tasks use checkboxes; timed activities use Focus sessions.',
    '/today',
  ),
  (
    'Build your learning',
    'Create a course, add modules and lectures, and open a lecture to study.',
    '/learning',
  ),
  (
    'Give thoughts a place',
    'Send notes, swipe right to archive, swipe left to delete, or long-press to select. Selected notes can become Todos or reminders. Use Add Promise at the top.',
    '/thought-wall',
  ),
  (
    'Choose a challenge',
    'Create several goals and pick any card to see its status. The home icon chooses which challenge appears on Home.',
    '/momentum',
  ),
  (
    'Remember what matters',
    'Set a date, time and repeat schedule. Home reminders take space only when there is something to show.',
    '/reminders',
  ),
  ('Focus Timer', featureGuides['Focus Timer']!, '/focus'),
  ('Riya', featureGuides['Riya']!, '/ai-assistant'),
  ('Hydration Tracker', featureGuides['Hydration Tracker']!, '/hydration'),
  ('Medicine & Health', featureGuides['Medicine & Health']!, '/medicine'),
  ('Walking & Activity', featureGuides['Walking & Activity']!, '/walk'),
  ('Chai & Coffee', featureGuides['Chai & Coffee']!, '/chai-break'),
  ('Job Pipeline', featureGuides['Job Pipeline']!, '/pipeline'),
  ('Study Plan', featureGuides['Study Plan']!, '/study-plan'),
  ('DSA Tracker', featureGuides['DSA Tracker']!, '/dsa'),
  ('Interview Prep', featureGuides['Interview Prep']!, '/interview-prep'),
  ('Consistency', featureGuides['Consistency']!, '/consistency'),
  ('Resume Vault', featureGuides['Resume Vault']!, '/resume-vault'),
  (
    'Analytics & Velocity',
    featureGuides['Analytics & Velocity']!,
    '/analytics',
  ),
  ('Money', featureGuides['Money']!, '/money'),
  ('Settings', featureGuides['Settings']!, '/settings'),
  (
    'Care for your day',
    'Use Life & Health for medicine, water and breaks. More contains your remaining career, study and tracking tools.',
    '/more',
  ),
];

Future<void> showAscentTour(BuildContext context, {int start = 0}) async {
  var index = start;
  while (context.mounted && index < _tour.length) {
    final step = _tour[index];
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text('${index + 1}/${_tour.length} · ${step.$1}'),
        content: Text(step.$2),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'close'),
            child: const Text('Later'),
          ),
          if (index > 0)
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'back'),
              child: const Text('Back'),
            ),
          if (index > 0 &&
              index < _tour.length - 1 &&
              !{'/home', '/reminders', '/money', '/more'}.contains(step.$3))
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, 'try'),
              child: const Text('Try it'),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, 'next'),
            child: Text(index == _tour.length - 1 ? 'Finish' : 'Next'),
          ),
        ],
      ),
    );
    if (result == null || result == 'close') return;
    if (result == 'back') {
      index--;
      continue;
    }
    if (result == 'try' && context.mounted) {
      await context.push(step.$3);
      if (!context.mounted) return;
    }
    index++;
  }
}
