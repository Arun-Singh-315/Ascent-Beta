import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:drift/drift.dart' show Value;
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/services/plan_service.dart';
import '../../../shared/widgets/app_surfaces.dart';
import '../../../shared/widgets/ascent_button.dart';
import '../../../shared/widgets/undo_snackbar.dart';
import '../plan_progress.dart';

/// Last 7 days, streak, and on-track / behind with a one-tap catch up.
class PlanProgressCard extends ConsumerWidget {
  const PlanProgressCard({super.key, required this.collectionId});
  final String collectionId;

  /// Plan sessions are protected (their reminders and history belong to the
  /// plan), so catching up skips each missed session and adds a one-off
  /// "(catch up)" to-do for today. Undo reverses both.
  Future<void> _catchUp(
    BuildContext context,
    WidgetRef ref,
    PlanProgress p,
  ) async {
    HapticFeedback.lightImpact();
    final db = ref.read(databaseProvider);
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final created = <int>[];
    final skipped = <String>[];
    await db.transaction(() async {
      for (final s in p.missed) {
        final occ = s.occurrenceId;
        if (occ == null) continue;
        if (!await PlanService(db).skipOccurrence(occ)) continue;
        skipped.add(occ);
        created.add(
          await db.taskDao.insertTask(
            TaskTableCompanion.insert(
              title: '${s.title} (catch up)',
              plannedDate: Value(today),
              estimatedMinutes: Value(s.minutes),
            ),
          ),
        );
      }
    });
    if (!context.mounted || created.isEmpty) return;
    final n = created.length;
    showUndoSnackbar(
      context,
      message: n == 1
          ? '1 catch-up added to today'
          : '$n catch-ups added to today',
      onUndo: () => db.transaction(() async {
        for (final id in created) {
          await db.taskDao.deleteTask(id);
        }
        for (final occ in skipped) {
          await db.planDao.updateOccurrence(
            PlanOccurrenceTableCompanion(
              id: Value(occ),
              outcome: const Value('scheduled'),
              answeredAt: const Value(null),
            ),
          );
        }
      }),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sessions = ref.watch(planSessionsProvider(collectionId)).value;
    if (sessions == null || sessions.isEmpty) return const SizedBox.shrink();
    final g = context.glass;
    final p = PlanProgress.from(sessions, DateTime.now());
    const letters = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
    return AppCard(
      key: const ValueKey('plan_progress_card'),
      padding: const EdgeInsets.all(AppSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                p.onTrack ? Icons.check_circle_rounded : Icons.schedule_rounded,
                size: 20,
                color: p.onTrack ? g.sage : g.amber,
              ),
              const SizedBox(width: AppSpace.s8),
              Expanded(
                child: Text(
                  p.onTrack
                      ? 'On track'
                      : '${p.behind} ${p.behind == 1 ? 'session' : 'sessions'} behind',
                  key: const ValueKey('plan_progress_status'),
                  style: AscentTextStyles.homeHeadline.copyWith(color: g.ink),
                ),
              ),
              if (p.streak > 0)
                Text(
                  '${p.streak}-day streak',
                  key: const ValueKey('plan_progress_streak'),
                  style: AscentTextStyles.caption.copyWith(
                    color: g.inkSecondary,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppSpace.s12),
          Row(
            children: [
              for (final (day, state) in p.week)
                Expanded(
                  child: Semantics(
                    label: '${letters[day.weekday - 1]}: ${state.name}',
                    child: Column(
                      children: [
                        Text(
                          letters[day.weekday - 1],
                          style: AscentTextStyles.caption.copyWith(
                            color: g.inkMuted,
                          ),
                        ),
                        const SizedBox(height: AppSpace.s4),
                        _Dot(state: state),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          if (p.missed.isNotEmpty) ...[
            const SizedBox(height: AppSpace.s12),
            AscentButton.tonal(
              key: const ValueKey('plan_catch_up'),
              label: 'Catch up today',
              icon: Icons.redo_rounded,
              compact: true,
              onPressed: () => _catchUp(context, ref, p),
            ),
          ],
        ],
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({required this.state});
  final PlanDayState state;

  @override
  Widget build(BuildContext context) {
    final g = context.glass;
    final (fill, border, icon) = switch (state) {
      PlanDayState.done => (g.sage, g.sage, Icons.check_rounded),
      PlanDayState.partial => (g.amber.withValues(alpha: .25), g.amber, null),
      PlanDayState.missed => (Colors.transparent, g.coral, null),
      PlanDayState.upcoming => (Colors.transparent, g.actionInk, null),
      PlanDayState.none => (Colors.transparent, g.line, null),
    };
    return Container(
      width: 22,
      height: 22,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: fill,
        border: Border.all(color: border, width: 1.5),
      ),
      child: icon == null ? null : Icon(icon, size: 14, color: g.bg),
    );
  }
}
