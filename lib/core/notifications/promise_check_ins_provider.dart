import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';
import '../../features/promises/providers/promise_providers.dart';

/// Refresh a shared bundle after edits, completion, archive, restart and resume.
final promiseCheckInsProvider = Provider<void>((ref) {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(promiseServiceProvider);
  Timer? debounce;
  Timer? midnight;
  bool disposed = false;
  bool fullSync = true;
  Future<void> sync() async {
    await service.syncCheckIns();
    try {
      await ref.read(promiseRepositoryProvider).syncAllReminders();
    } catch (_) {
      /* Retry on next resume. */
    }
  }

  void refresh({bool changed = false}) {
    if (disposed) return;
    fullSync = fullSync || !changed;
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () {
      if (!disposed) {
        final all = fullSync;
        fullSync = false;
        unawaited(all ? sync() : service.syncCheckIns());
      }
    });
    midnight?.cancel();
    final now = DateTime.now();
    midnight = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      () => refresh(),
    );
  }

  final thoughts =
      (db.select(db.thoughtTable)..where((t) => t.mood.equals('promise')))
          .watch()
          .listen((_) => refresh(changed: true));
  final profile = db.userProfileDao.watchProfile().listen(
    (_) => refresh(changed: true),
  );
  refresh();
  final lifecycle = AppLifecycleListener(onResume: () => refresh());
  ref.onDispose(() {
    disposed = true;
    debounce?.cancel();
    midnight?.cancel();
    lifecycle.dispose();
    unawaited(thoughts.cancel());
    unawaited(profile.cancel());
  });
});
