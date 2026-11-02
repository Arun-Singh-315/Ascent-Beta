import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';
import '../providers/settings_provider.dart';
import '../security/app_lock_provider.dart';
import '../../features/promises/providers/promise_providers.dart';
import 'notification_service.dart';
import 'things_check_in.dart';

/// Refresh on edits, resume and day changes. Serialize replacement so a completed
/// task cannot be reintroduced by an older in-flight scheduling pass.
final thingsCheckInsProvider = Provider<void>((ref) {
  final db = ref.watch(databaseProvider);
  final service = NotificationService.instance;
  Timer? debounce, midnight;
  var disposed = false, running = false, dirty = false;

  Future<void> sync() async {
    if (running || disposed) return;
    running = true;
    try {
      do {
        dirty = false;
        for (var id = 830100; id < 830104; id++) {
          await service.cancel(id);
        }
        if (disposed) break;
        final enabled = ref.read(thingsCheckInsEnabledProvider);
        final lock = ref.read(appLockProvider);
        final promises = ref.read(allPromisesStreamProvider);
        if (!enabled ||
            (lock.isEnabled && !lock.allowNotifications) ||
            !promises.hasValue) {
          continue;
        }
        final tasks = await db.select(db.taskTable).get();
        final reminders = await db.select(db.reminderTable).get();
        if (disposed || dirty) continue;
        final plan = ThingsCheckIn.plan(
          now: DateTime.now(),
          tasks: tasks,
          reminders: reminders,
          privateThoughtIds: ref.read(privatePromiseIdsProvider),
          redact: lock.isEnabled && lock.redactNotificationContent,
        );
        for (var i = 0; i < plan.length && !disposed && !dirty; i++) {
          final item = plan[i];
          await service.scheduleThingsCheckIn(
            id: 830100 + i,
            at: item.at,
            title: item.message.title,
            body: item.message.body,
          );
        }
      } while (dirty && !disposed);
    } catch (error) {
      debugPrint('Things check-ins deferred: $error');
    } finally {
      running = false;
    }
  }

  void refresh() {
    if (disposed) return;
    dirty = true;
    debounce?.cancel();
    debounce = Timer(
      const Duration(milliseconds: 400),
      () => unawaited(sync()),
    );
    midnight?.cancel();
    final now = DateTime.now();
    midnight = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      refresh,
    );
  }

  final tasks = db.select(db.taskTable).watch().listen((_) => refresh());
  final reminders = db
      .select(db.reminderTable)
      .watch()
      .listen((_) => refresh());
  ref.listen(thingsCheckInsEnabledProvider, (_, _) => refresh());
  ref.listen(appLockProvider, (_, _) => refresh());
  ref.listen(allPromisesStreamProvider, (_, _) => refresh());
  final lifecycle = AppLifecycleListener(onResume: refresh);
  refresh();
  ref.onDispose(() {
    disposed = true;
    debounce?.cancel();
    midnight?.cancel();
    lifecycle.dispose();
    unawaited(tasks.cancel());
    unawaited(reminders.cancel());
  });
});
