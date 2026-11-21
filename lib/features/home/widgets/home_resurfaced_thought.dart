import 'package:drift/drift.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_navigation.dart';
import '../../../app/theme/glass_theme.dart';
import '../../../app/theme/surface_tokens.dart';
import '../../../app/theme/text_styles.dart';
import '../../../core/database/app_database.dart';
import '../../../core/providers/database_provider.dart';
import '../../../core/providers/local_day_provider.dart';
import '../../thought_wall/board/board_logic.dart';

/// One open thought from 3–60 days ago, a different one each day, so Home
/// shows something worth a second look instead of the same cards.
final resurfacedThoughtProvider = FutureProvider<Thought?>((ref) async {
  final today = ref.watch(localDayProvider);
  final db = ref.watch(databaseProvider);
  final from = today.subtract(const Duration(days: 60));
  final to = today.subtract(const Duration(days: 3));
  final rows =
      await (db.select(db.thoughtTable)
            ..where(
              (t) =>
                  t.isArchived.equals(false) &
                  t.isCompleted.equals(false) &
                  t.createdAt.isBiggerOrEqualValue(from) &
                  t.createdAt.isSmallerThanValue(to),
            )
            ..orderBy([(t) => OrderingTerm.asc(t.id)])
            ..limit(200))
          .get();
  final candidates = rows
      .where(
        (t) => displayContent(t.content).trim().length >= 8,
      )
      .toList();
  if (candidates.isEmpty) return null;
  final dayNumber = today.difference(DateTime(2020)).inDays;
  return candidates[dayNumber % candidates.length];
});

/// "From 6 days ago" line under the Mind preview. Tap opens the thought.
class HomeResurfacedThought extends ConsumerWidget {
  const HomeResurfacedThought({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final thought = ref.watch(resurfacedThoughtProvider).value;
    if (thought == null) return const SizedBox.shrink();
    final g = context.glass;
    final today = ref.watch(localDayProvider);
    final created = DateTime(
      thought.createdAt.year,
      thought.createdAt.month,
      thought.createdAt.day,
    );
    final days = today.difference(created).inDays;
    final when = days >= 14 ? '${days ~/ 7} weeks ago' : '$days days ago';
    final text = displayContent(
      thought.content,
    ).trim().split(RegExp(r'\r?\n')).first;
    return Padding(
      padding: const EdgeInsets.only(top: AppSpace.s12),
      child: Semantics(
        button: true,
        label: 'From $when: $text. Open in Mindspace',
        child: InkWell(
          key: const ValueKey('home_resurfaced_thought'),
          borderRadius: BorderRadius.circular(12),
          onTap: () {
            HapticFeedback.selectionClick();
            context.open('/thought-wall?thought=${thought.id}');
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpace.s4,
                vertical: AppSpace.s8,
              ),
              child: ExcludeSemantics(
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 18, color: g.inkMuted),
                    const SizedBox(width: AppSpace.s8),
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(
                              text: 'From $when  ',
                              style: AscentTextStyles.caption.copyWith(
                                color: g.inkMuted,
                              ),
                            ),
                            TextSpan(
                              text: text,
                              style: AscentTextStyles.bodyMedium.copyWith(
                                color: g.ink,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    Icon(
                      Icons.chevron_right_rounded,
                      size: 20,
                      color: g.inkMuted,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
