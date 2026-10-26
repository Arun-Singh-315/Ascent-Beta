import 'package:flutter/material.dart';
import 'package:ascent/features/promises/widgets/promise_actions.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/text_styles.dart';
import '../../../shared/widgets/glass_surface.dart';
import '../models/promise_model.dart';
import '../providers/promise_providers.dart';
import 'promise_action_button.dart';
import 'promise_detail_sheet.dart';

/// Reusable Apple glass card for displaying a Promise.
class PromiseCard extends ConsumerWidget {
  const PromiseCard({
    super.key,
    required this.promise,
    this.showIntention = true,
  });

  final PromiseModel promise;
  final bool showIntention;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final g = context.glass;

    return InkWell(
      onTap: () {
        HapticFeedback.selectionClick();
        PromiseDetailSheet.show(context, promise);
      },
      borderRadius: BorderRadius.circular(20),
      child: GlassSurface(
        borderRadius: BorderRadius.circular(20),
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row: Category / Privacy & 3-dots menu
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Container(
                        constraints: const BoxConstraints(maxWidth: 180),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: g.fill.withValues(alpha: 0.6),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: g.line),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Flexible(
                              child: Text(
                                promise.category.toUpperCase(),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                                style: TextStyle(
                                  color: g.inkSecondary,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 0.8,
                                ),
                              ),
                            ),
                            if (promise.isPrivate) ...[
                              const SizedBox(width: 4),
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 11,
                                color: g.inkMuted,
                              ),
                            ],
                          ],
                        ),
                      ),
                      if (promise.isPaused) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text(
                            'PAUSED',
                            style: TextStyle(
                              color: Colors.amber,
                              fontSize: 9.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_horiz_rounded,
                    color: g.inkMuted,
                    size: 20,
                  ),
                  padding: EdgeInsets.zero,
                  color: Theme.of(context).colorScheme.surface,
                  onSelected: (val) async {
                    final messenger = ScaffoldMessenger.of(context);
                    try {
                      final repo = ref.read(promiseRepositoryProvider);
                      if (val == 'toggle_pause') {
                        final newStatus = promise.isPaused
                            ? PromiseStatus.active
                            : PromiseStatus.paused;
                        await repo.setPromiseStatus(promise.id, newStatus);
                      } else if (val == 'delete') {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (ctx) => AlertDialog(
                            title: const Text('Delete this promise?'),
                            content: const Text(
                              'Its progress history will also be removed.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, false),
                                child: const Text('Cancel'),
                              ),
                              TextButton(
                                onPressed: () => Navigator.pop(ctx, true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed == true) {
                          await repo.deletePromise(promise.id);
                        }
                      }
                    } catch (_) {
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                            'Could not save this change. Please try again.',
                          ),
                        ),
                      );
                    }
                  },
                  itemBuilder: (ctx) => [
                    if (!promise.isCompleted)
                      PopupMenuItem(
                        value: 'toggle_pause',
                        child: Text(promise.isPaused ? 'Resume' : 'Pause'),
                      ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        'Delete',
                        style: TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 10),

            // Title
            Text(
              promise.title,
              style: AscentTextStyles.homeTitle.copyWith(
                color: g.ink,
                fontSize: 16.5,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),

            if (promise.schedule != null) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Icon(Icons.repeat_rounded, size: 13, color: g.inkMuted),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      promise.schedule!.summary,
                      style: TextStyle(color: g.inkMuted, fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ],
            if (showIntention &&
                promise.schedule == null &&
                promise.intention.isNotEmpty &&
                promise.intention != promise.title) ...[
              const SizedBox(height: 4),
              Text(
                promise.intention,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(color: g.inkMuted, fontSize: 13, height: 1.35),
              ),
            ],
            const SizedBox(height: 14),

            // Progress Bar
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: promise.progressFraction,
                minHeight: 4,
                backgroundColor: g.track,
                valueColor: AlwaysStoppedAnimation<Color>(g.sage),
              ),
            ),
            const SizedBox(height: 14),

            // Bottom footer: Progress summary & Direct Action Button
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 12,
              runSpacing: 10,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 160),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          color: promise.isCompleted
                              ? g.sage
                              : (promise.isDoneToday ? g.sage : g.amber),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          promise.progressSummary,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: g.inkSecondary,
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                PromiseActionButton(
                  promise: promise,
                  onPressed: () {
                    _triggerAction(context, ref);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _triggerAction(BuildContext context, WidgetRef ref) {
    PromiseActions.perform(context, ref, promise);
  }
}
