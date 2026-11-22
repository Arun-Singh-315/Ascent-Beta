import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../notifications/notification_service.dart';
import '../providers/database_provider.dart';
import 'promise_service.dart';

/// Daily promise nudges as device notifications (they open /promises).
class DevicePromiseNudger implements PromiseNudger {
  const DevicePromiseNudger();

  @override
  Future<void> schedule(int id, String title, String body, DateTime at) =>
      NotificationService.instance.schedulePromiseCheckIn(
        id: id,
        title: title,
        body: body,
        scheduledAt: at,
      );

  @override
  Future<void> cancel(int id) => NotificationService.instance.cancel(id);
}

final promiseNudgerProvider = Provider<PromiseNudger?>(
  (ref) => const DevicePromiseNudger(),
);

final promiseServiceProvider = Provider<PromiseService>(
  (ref) => PromiseService(
    ref.watch(databaseProvider),
    nudger: ref.watch(promiseNudgerProvider),
  ),
);

/// Every promise (active, done and released), oldest first.
final promisesProvider = StreamProvider<List<PromiseView>>(
  (ref) => ref.watch(promiseServiceProvider).watchAll(),
);

/// Active promises in the order Home shows them: anything waiting for an
/// answer first (yesterday, then today), then the ones already answered.
final activePromisesProvider = Provider<AsyncValue<List<PromiseView>>>((ref) {
  return ref.watch(promisesProvider).whenData((all) {
    final active = all.where((p) => p.isActive).toList();
    int rank(PromiseView p) => p.progress.yesterdayOpen
        ? 0
        : p.progress.answeredToday
        ? 2
        : 1;
    active.sort((a, b) => rank(a).compareTo(rank(b)));
    return active;
  });
});

/// What Home shows: active promises (waiting ones first) plus any that
/// finished today, so the finish moment gets its own card.
final homePromisesProvider = Provider<AsyncValue<List<PromiseView>>>((ref) {
  final active = ref.watch(activePromisesProvider);
  return ref.watch(promisesProvider).whenData((all) {
    final today = dayOf(DateTime.now());
    final finishedToday = all.where(
      (p) =>
          p.promise.status == 'done' &&
          p.promise.endedAt != null &&
          dayOf(p.promise.endedAt!) == today,
    );
    return [...finishedToday, ...?active.value];
  });
});
