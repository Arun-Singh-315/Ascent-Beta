import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/glass_theme.dart';
import '../../../core/providers/daily_briefing_provider.dart';
import '../../../core/providers/settings_provider.dart';
import '../../../shared/widgets/ascent_card.dart';
import '../../today/add_activity_sheet.dart';

class DailyBriefingCard extends ConsumerWidget {
  const DailyBriefingCard({super.key, required this.day});
  final DateTime day;

  static Future<void> show(BuildContext context, DateTime day) =>
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        useRootNavigator: true,
        useSafeArea: true,
        showDragHandle: true,
        builder: (context) => ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(
              24,
              8,
              24,
              24 + MediaQuery.viewPaddingOf(context).bottom,
            ),
            child: _BriefingBody(day: day, inSheet: true),
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: AscentCard(child: _BriefingBody(day: day)),
  );
}

class _BriefingBody extends ConsumerWidget {
  const _BriefingBody({required this.day, this.inSheet = false});
  final DateTime day;
  final bool inSheet;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final briefing = ref.watch(dailyBriefingProvider(day));
    final g = context.glass;
    final name = ref.watch(assistantNameProvider);
        final hostContext = context;
    void navigate(String route) {
      final router = GoRouter.of(context);
      if (inSheet) Navigator.pop(context);
      router.push(route);
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Icon(Icons.waving_hand_outlined, color: g.clay),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Let’s get you moving',
                style:
                    (inSheet
                            ? Theme.of(context).textTheme.titleLarge
                            : Theme.of(context).textTheme.titleMedium)
                        ?.copyWith(color: g.ink),
              ),
            ),
            if (inSheet)
              IconButton(
                tooltip: 'Dismiss daily briefing',
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close),
              ),
          ],
        ),
        const SizedBox(height: 12),
        briefing.when(
          loading: () => const Text('Gathering your recorded activity…'),
          error: (_, _) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Your summary could not load. You can still take a next step below.',
              ),
              TextButton(
                onPressed: () => ref.invalidate(dailyBriefingProvider(day)),
                child: const Text('Try again'),
              ),
            ],
          ),
          data: (data) => Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                inSheet
                    ? data.yesterdaySummary
                    : data.completedYesterday == 0 &&
                          data.trackedMinutesYesterday == 0
                    ? 'No progress logged yesterday. Let’s start small today.'
                    : 'Yesterday · ${data.completedYesterday} tasks done · ${data.trackedMinutesYesterday} min tracked',
                maxLines: inSheet ? null : 2,
                overflow: inSheet
                    ? TextOverflow.visible
                    : TextOverflow.ellipsis,
                style: TextStyle(color: g.inkMuted),
              ),
              const SizedBox(height: 12),
              if (inSheet) ...[
                Text(data.encouragement, style: TextStyle(color: g.ink)),
                const SizedBox(height: 12),
              ],
              Text(
                '${data.dueToday} due today · ${data.overdue} overdue · ${data.unscheduled} unscheduled',
                style: Theme.of(
                  context,
                ).textTheme.labelLarge?.copyWith(color: g.clay),
              ),
              const SizedBox(height: 12),
              if (data.nextTask != null) ...[
                if (inSheet) ...[
                  Text(
                    'A place to start: ${data.nextTask}',
                    style: TextStyle(color: g.ink),
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton.icon(
                  onPressed: () => navigate('/today'),
                  icon: const Icon(Icons.arrow_forward_rounded),
                  label: const Text('Take me to my tasks'),
                ),
              ] else ...[
                if (inSheet) ...[
                  const Text(
                    'Nothing queued for today. What is one thing you want to do?',
                  ),
                  const SizedBox(height: 8),
                ],
                FilledButton.icon(
                  onPressed: () async {
                    // Close this sheet before opening the task composer.
                    final navigator = Navigator.of(context);
                    final rootContext = navigator.context;
                    if (inSheet) navigator.pop();
                    await AddActivitySheet.show(
                      inSheet ? rootContext : hostContext,
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Plan one small task'),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            TextButton.icon(
              onPressed: () => navigate('/thought-wall'),
              icon: const Icon(Icons.edit_note_rounded),
              label: const Text('Capture a thought'),
            ),
            TextButton.icon(
              onPressed: () => navigate('/ai-assistant'),
              icon: const Icon(Icons.chat_bubble_outline_rounded),
              label: Text('Ask $name'),
            ),
            if (inSheet)
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('I’ll explore on my own'),
              )
            else
              TextButton(
                onPressed: () => DailyBriefingCard.show(context, day),
                child: const Text('Open daily check-in'),
              ),
          ],
        ),
        if (inSheet) ...[
          const SizedBox(height: 16),
          Divider(color: g.line),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('Welcome me each new day'),
            subtitle: const Text(
              'Open this check-in automatically. You can always find it on Home.',
            ),
            value: ref.watch(dailyBriefingAutoOpenProvider),
            onChanged: (enabled) async {
              try {
                await ref
                    .read(dailyBriefingAutoOpenProvider.notifier)
                    .setEnabled(enabled);
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Could not save. Please try again.'),
                    ),
                  );
                }
              }
            },
          ),
        ],
      ],
    );
  }
}
