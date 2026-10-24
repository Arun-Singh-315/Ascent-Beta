import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/database_provider.dart';

/// Refresh a shared bundle after edits, completion, archive, restart and resume.
final promiseCheckInsProvider = Provider<void>((ref) {
  final db = ref.watch(databaseProvider);
  final service = ref.watch(promiseServiceProvider);
  Timer? debounce;
  Timer? midnight;
  bool disposed = false;
  void refresh() {
    if (disposed) return;
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 350), () {
      if (!disposed) unawaited(service.syncCheckIns());
    });
    midnight?.cancel();
    final now = DateTime.now();
    midnight = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      refresh,
    );
  }

  final thoughts = (db.select(
    db.thoughtTable,
  )..where((t) => t.mood.equals('promise'))).watch().listen((_) => refresh());
  final profile = db.userProfileDao.watchProfile().listen((_) => refresh());
  final lifecycle = AppLifecycleListener(onResume: refresh);
  ref.onDispose(() {
    disposed = true;
    debounce?.cancel();
    midnight?.cancel();
    lifecycle.dispose();
    unawaited(thoughts.cancel());
    unawaited(profile.cancel());
  });
});
