import '../../plans/widgets/plan_notification_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/home_capture_service.dart';
import '../../../core/notifications/reminder_alert_sync.dart';
import '../../plans/planning_providers.dart';
import '../../plans/widgets/plan_collection_detail.dart';

/// Handles notification navigation without adding a second planning card to Home.
class PlanningNotificationHandler extends ConsumerStatefulWidget {
  const PlanningNotificationHandler({super.key, this.uri});
  final Uri? uri;
  @override
  ConsumerState<PlanningNotificationHandler> createState() => _HandlerState();
}

class _HandlerState extends ConsumerState<PlanningNotificationHandler> {
  String? _handled;
  @override
  void initState() {
    super.initState();
    _schedule();
  }

  @override
  void didUpdateWidget(covariant PlanningNotificationHandler oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    final uri = widget.uri;
    if (uri == null || uri.toString() == _handled) return;
    _handled = uri.toString();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final db = ref.read(databaseProvider);
      try {
        final id = int.tryParse(
          uri.queryParameters['checkin'] ??
              uri.queryParameters['reminder'] ??
              '',
        );
        final epoch = int.tryParse(uri.queryParameters['at'] ?? '');
        final answer = uri.queryParameters['answer'];
        String? occurrence =
            uri.queryParameters['session'] ?? uri.queryParameters['occ'];
        if (id != null && epoch != null) {
          final link = await db.planDao.getAlertLinkForReminder(id);
          occurrence = link?.occurrenceId ?? occurrence;
          if (answer != null) {
            final accepted = link == null
                ? await HomeCaptureService(db).answer(
                    id,
                    DateTime.fromMillisecondsSinceEpoch(epoch),
                    answer,
                  )
                : await ref
                      .read(planServiceProvider)
                      .answerReminder(
                        id,
                        DateTime.fromMillisecondsSinceEpoch(epoch),
                        answer,
                      );
            if (!accepted && mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'This check-in changed or was already handled.',
                  ),
                ),
              );
            }
            await ReminderAlertSync.device(db).sync(onlyPending: true);
          }
        }
        if (occurrence != null) {
          final occ = await db.planDao.getOccurrenceById(occurrence);
          if (occ == null) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'This activity was removed or rescheduled. Open Plans in Things hub for the latest version.',
                  ),
                ),
              );
            }
            return;
          }
          await ref.read(planCollectionServiceProvider).importLegacy();
          final owner = await (db.select(
            db.planCollectionItemTable,
          )..where((i) => i.definitionId.equals(occ.planId))).getSingleOrNull();
          if (owner != null && mounted) {
            if (answer != null) {
              await showPlanCollectionDetail(context, owner.collectionId);
            } else {
              final links = await db.planDao.getAlertLinksForOccurrence(occ.id);
              final fallback = links
                  .where((l) => l.role == 'start')
                  .firstOrNull;
              final rid = id ?? fallback?.reminderId;
              final reminder = rid == null
                  ? null
                  : await db.reminderDao.getReminderById(rid);
              if (!mounted) return;
              final viewPlan = await showPlanNotificationSheet(
                context,
                occurrenceId: occ.id,
                reminderId: rid,
                expectedAt: epoch == null
                    ? reminder?.scheduledAt
                    : DateTime.fromMillisecondsSinceEpoch(epoch),
              );
              if (viewPlan && mounted) {
                await showPlanCollectionDetail(context, owner.collectionId);
              }
            }
          }
        }
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Could not open this plan. Open Plans in Things hub to retry.',
              ),
            ),
          );
        }
      }
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
