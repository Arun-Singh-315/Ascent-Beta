import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/home/widgets/home_shortcut_summary.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'today pause total counts completed sessions, excludes yesterday and extra events',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final now = DateTime.now();
      for (var i = 0; i < 12; i++) {
        await db
            .into(db.historyEventTable)
            .insert(
              HistoryEventTableCompanion.insert(
                id: 'completed-$i',
                module: 'breaks',
                entityId: 'session-$i',
                action: 'completed',
                title: 'Pause',
                occurredAt: now,
              ),
            );
      }
      for (final action in ['started', 'paused', 'resumed', 'completed']) {
        await db
            .into(db.historyEventTable)
            .insert(
              HistoryEventTableCompanion.insert(
                id: 'extra-$action',
                module: 'breaks',
                entityId: 'session-0',
                action: action,
                title: 'Pause',
                occurredAt: now,
              ),
            );
      }
      await db
          .into(db.historyEventTable)
          .insert(
            HistoryEventTableCompanion.insert(
              id: 'yesterday',
              module: 'breaks',
              entityId: 'yesterday',
              action: 'completed',
              title: 'Pause',
              occurredAt: DateTime(
                now.year,
                now.month,
                now.day,
              ).subtract(const Duration(seconds: 1)),
            ),
          );
      final container = ProviderContainer(
        overrides: [databaseProvider.overrideWithValue(db)],
      );
      final subscription = container.listen(todayPauseCountProvider, (_, _) {});
      expect(await container.read(todayPauseCountProvider.future), 12);
      expect(
        container.read(homeShortcutSummaryProvider('chai-break')),
        '12 pauses today',
      );
      subscription.close();
      container.dispose();
      await db.close();
    },
  );
}
