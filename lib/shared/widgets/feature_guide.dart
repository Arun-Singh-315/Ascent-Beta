import 'package:ascent/app/theme/surface_tokens.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

const featureGuides = <String, String>{
  'Mindspace':
      'Write · Send a note like a message.\nOrganize · Swipe right to archive; left to delete with Undo.\nMore · Long-press for selection. Open Commitments at the top for your daily commitments.',
  'Reminders & Alerts':
      'Create · Set a title, date and time. Normal notifications are the default.\nAlarm · Turn on Ring as an alarm for looping sound, Snooze and Done. Enable Android alarm access for popups.\nManage · Missed reminders stay Overdue. Snooze moves the time; Done completes the reminder, while tasks keep their own status.',
  'Focus Timer':
      'Start · Choose a timed task or a free Focus session. Study-category time counts toward the study streak; entertainment does not.\nControl · Pause when stepping away. Notification controls stay synchronized; tap the player card to return here.\nFinish · Save your session. Timed tasks complete only when their target is reached.',
  'Dayboard':
      'Plan · Add a Todo or timed activity.\nComplete · Check Todos; use Focus for timed work.\nReturn · Add a reminder when useful.',
  'Today':
      'Plan · Add a Todo or timed activity.\nComplete · Check Todos; use Focus for timed work.\nEdit · Open an activity for its actions.',
  'Hydration Tracker':
      'Goal · Set your daily water target.\nLog · Use the drink buttons.\nReview · Check your recent water history.',
  'Medicine & Health':
      'Add · Enter a prescription and dose times.\nRecord · Mark each dose when taken.\nReview · Check past doses in history.',
  'Money':
      'Record · Add income or expenses.\nReview · Choose a period to inspect spending.\nPlan · Set budget limits or savings goals.',
  'Settings':
      'Customize · Appearance, goals and notifications.\nProtect · Export a backup before restoring or clearing.\nHelp · Replay guides with the question-mark button.',
  'More':
      'Explore · Open your Life tools, Vault, History and Settings from You.\nLearn · Read short first-use tips when needed.\nReturn · Use the feature help button to revisit tips.',
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
    return featureGuides['Growth'];
  }
  if (name.contains('study')) return featureGuides['Study Plan'];
  if (name.contains('pipeline')) return featureGuides['Job Pipeline'];
  if (name.contains('task') || name.contains('activity hub')) {
    return featureGuides['Dayboard'];
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
  Widget build(BuildContext context) => widget.child;
}

/// Ambient inline hint displayed in empty states showing key feature tips
/// without interrupting or modal popups.
class FeatureEmptyStateHint extends StatelessWidget {
  const FeatureEmptyStateHint({
    super.key,
    required this.feature,
    this.title,
  });

  final String feature;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final guide = guideFor(feature);
    if (guide == null) return const SizedBox.shrink();

    final g = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFFE2E8F0)
        : const Color(0xFF1E293B);
    final muted = Theme.of(context).brightness == Brightness.dark
        ? const Color(0xFF94A3B8)
        : const Color(0xFF64748B);
    final border = Theme.of(context).brightness == Brightness.dark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);
    final tips = guide.split('\n');

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).brightness == Brightness.dark
            ? Colors.white.withValues(alpha: 0.04)
            : Colors.black.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline_rounded, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title ?? 'Tips for $feature',
                  style: TextStyle(
                    color: g,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ...tips.map((tip) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(
                tip,
                style: TextStyle(
                  color: muted,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

final _tour = <(String, String, String)>[
  (
    'Your daily dashboard',
    'Home brings together your day, Mindspace and care. Write straight into the boxes on Home and press Enter. New items appear right away.',
    '/home',
  ),
  (
    'Plan your work',
    'Add a quick Todo or a timed activity. Quick tasks use checkboxes; timed activities use Focus sessions.',
    '/today',
  ),
  (
    'Give thoughts a place',
    'Send notes, swipe right to archive, swipe left to delete, or long-press to select. Selected notes can become Todos or reminders.',
    '/thought-wall',
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
  ('Money', featureGuides['Money']!, '/money'),
  ('Settings', featureGuides['Settings']!, '/settings'),
  (
    'Everything else',
    'Open You for water, medicine, money, Vault, History and Settings.',
    '/you',
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
