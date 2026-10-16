import 'dart:async';
import 'package:drift/drift.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../ai/riya_alert_effects.dart';
import '../providers/database_provider.dart';
import 'reminder_alert_sync.dart';

/// Retry committed work on changes and resume, without polling.
final pendingReminderEffectsProvider = Provider<void>((ref) {
  final db = ref.watch(databaseProvider);
  bool running = false, disposed = false, dirty = false;
  Timer? debounce;
  void request() {
    if (disposed) return;
    if (running) {
      dirty = true;
      return;
    }
    debounce?.cancel();
    debounce = Timer(const Duration(milliseconds: 250), () async {
      if (disposed || running) return;
      running = true;
      try {
        do {
          dirty = false;
          await RiyaAlertEffects.device(db).syncPending();
          await ReminderAlertSync.device(db).sync(onlyPending: true);
        } while (dirty && !disposed);
      } catch (_) {
        /* Persisted work survives platform failure. */
      } finally {
        running = false;
      }
    });
  }

  final rows =
      (db.select(
        db.reminderTable,
      )..where((r) => r.alertSyncPending.equals(true))).watch().listen((rows) {
        if (rows.isNotEmpty) request();
      });
  final receipts =
      (db.select(db.aiCommandTable)
            ..where((r) => r.resultJson.like('%"alertEffectsPending":true%')))
          .watch()
          .listen((rows) {
            if (rows.isNotEmpty) request();
          });
  final lifecycle = AppLifecycleListener(onResume: request);
  ref.onDispose(() {
    disposed = true;
    debounce?.cancel();
    lifecycle.dispose();
    unawaited(rows.cancel());
    unawaited(receipts.cancel());
  });
});
