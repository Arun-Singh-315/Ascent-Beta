import 'dart:async';

import 'core/backup/backup_service.dart';
import 'core/backup/backup_providers.dart';
import 'core/services/plan_collection_service.dart';
import 'core/notifications/alarm_lifecycle.dart';
import 'core/notifications/reminder_alarm_bridge.dart';
import 'core/providers/database_provider.dart';
import 'core/notifications/reminder_alert_sync.dart';
import 'core/ai/riya_alert_effects.dart';
import 'core/database/app_database.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'app/app_navigation.dart';
import 'core/services/share_intake.dart';
import 'app/router.dart';
import 'core/notifications/notification_service.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/time_tracking_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final prefs = await SharedPreferences.getInstance();
  // A restore chosen last session is moved in before the database opens.
  try {
    await BackupService.applyPendingRestore(prefs);
  } catch (e) {
    debugPrint('Restore could not be applied: $e');
  }
  final bootstrapDb = AppDatabase();
  try {
    await PlanCollectionService(bootstrapDb).importLegacy();
  } finally {
    await bootstrapDb.close();
  }
  await touchLastOpened(prefs);

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  // Daily automatic backup, after start-up so it never slows the first frame.
  Future<void>.delayed(const Duration(seconds: 20), () async {
    try {
      await container.read(backupServiceProvider).runAutoIfDue();
    } catch (e) {
      debugPrint('Automatic backup skipped: $e');
    }
  });

  NotificationService.setNotificationNavigateHandler((route) {
    final destination = NotificationService.destinationForPayload(route);
    final currentUri = ascentRouter.routerDelegate.currentConfiguration.uri
        .toString();
    if (currentUri == '/' ||
        currentUri == '/onboarding' ||
        currentUri == '/login') {
      NotificationService.deferDestination(destination);
      return;
    }
    if (currentUri != destination) {
      // Tab roots (Home, Things, Assistant, Mind, You) open as their tab;
      // anything else opens over Home so back returns there.
      if (AscentTabs.indexOf(destination) == null) {
        ascentRouter.go(AscentTabs.home);
        ascentRouter.push(destination);
      } else {
        ascentRouter.go(destination);
      }
    }
  });

  // Text shared from another app becomes a thought in Mindspace. It opens
  // through the same path as a notification tap, which waits for splash.
  unawaited(
    ShareIntake.start(
      container: () => container,
      open: (location) =>
          NotificationService.onNotificationNavigate?.call(location),
    ),
  );

  NotificationService.setNotificationActionHandler((actionId, payload) {
    final effectivePayload = payload?.isNotEmpty == true ? payload : null;
    if ({'home_done', 'home_later', 'home_skip'}.contains(actionId) &&
        effectivePayload != null &&
        RegExp(
          r'^/home\?checkin=\d+&at=\d+(?:&occ=[a-zA-Z0-9_:.\-]+)?$',
        ).hasMatch(effectivePayload)) {
      NotificationService.onNotificationNavigate?.call(
        '$effectivePayload&answer=${actionId.substring(5)}',
      );
      return;
    }
    if (actionId == 'things_start' && effectivePayload != null) {
      NotificationService.onNotificationNavigate?.call(effectivePayload);
      return;
    }
    if (actionId == 'things_review') {
      NotificationService.onNotificationNavigate?.call('/things?mode=wrapup');
      return;
    }
    if (actionId == 'things_done' && effectivePayload != null) {
      final uri = Uri.tryParse(effectivePayload);
      final idStr = uri?.queryParameters['focus'] ?? uri?.queryParameters['task'];
      final taskId = int.tryParse(idStr ?? '');
      if (taskId != null) {
        final db = container.read(databaseProvider);
        unawaited(db.taskDao.markComplete(taskId));
      }
      return;
    }
    if (actionId == 'things_snooze' && effectivePayload != null) {
      unawaited(
        NotificationService.instance.scheduleThingsCheckIn(
          id: 830199,
          at: DateTime.now().add(const Duration(minutes: 30)),
          title: 'Snoozed check-in',
          body: 'Ready to take on this item now?',
          payload: effectivePayload,
        ),
      );
      return;
    }
    if (actionId == 'water_250') {
      final db = container.read(databaseProvider);
      unawaited(db.waterDao.addWater(250));
      return;
    }
    if (actionId == 'water_500') {
      final db = container.read(databaseProvider);
      unawaited(db.waterDao.addWater(500));
      return;
    }
    if (actionId == 'medicine_taken' && effectivePayload != null) {
      final uri = Uri.tryParse(effectivePayload);
      final logId = int.tryParse(uri?.queryParameters['logId'] ?? '');
      if (logId != null) {
        final db = container.read(databaseProvider);
        unawaited(db.medicineDao.setDoseTaken(logId, true));
      }
      return;
    }
    if (effectivePayload == '/focus') {
      () async {
        final dao = container.read(timeSessionDaoProvider);
        final active = await dao.getActiveFocusSession();
        if (active == null) return;
        if (actionId == NotificationService.actionPause) {
          await dao.pauseSession(active.id);
        } else if (actionId == NotificationService.actionResume) {
          await dao.resumeSession(active.id);
        } else if (actionId == NotificationService.actionDone) {
          await dao.completeSession(active.id);
          NotificationService.instance.cancelOngoingFocusNotification();
        }
      }();
    } else {
      final focusState = container.read(timeTrackingProvider);
      if (focusState.isRunning) {
        if (actionId == NotificationService.actionPause) {
          container.read(timeTrackingProvider.notifier).pauseSession();
        }
      } else if (focusState.isPaused) {
        if (actionId == NotificationService.actionResume) {
          container.read(timeTrackingProvider.notifier).resumeSession();
        }
      }
    }
  });

  // Edge-to-edge display (enforced by Android 15+; set explicitly for all versions)
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Lock to portrait orientation only (job-prep app, not a media player)
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    UncontrolledProviderScope(
      key: UniqueKey(),
      container: container,
      child: const AscentApp(),
    ),
  );
  // Draw the workspace before reconciling platform alarms. Restore recovery
  // and legacy imports above remain prerequisites for reading user records.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    unawaited(_reconcileStartupAlerts(container.read(databaseProvider), prefs));
  });
  AlarmLifecycle(
    () => container.read(databaseProvider),
    () => rootNavigatorKey.currentContext,
  ).start();
}

Future<void> _reconcileStartupAlerts(
  AppDatabase db,
  SharedPreferences prefs,
) async {
  try {
    await PlanCollectionService(db).reconcileLocalSchedules();

    if (!(prefs.getBool('ascent_restore_alert_sync_v1') ?? false)) {
      try {
        await ReminderAlarmBridge.reconcile(db);
      } catch (e) {
        debugPrint('ReminderAlarmBridge reconcile skipped or failed: $e');
      }
    }

    await NotificationService.instance.initialize();

    if (prefs.getBool('ascent_restore_alert_sync_v1') ?? false) {
      try {
        await finishRestoredAlerts(db, prefs);
      } catch (e) {
        debugPrint('finishRestoredAlerts failed: $e');
      }
    }

    try {
      await RiyaAlertEffects.device(db).syncPending();
      final grouped = prefs.getBool('ascent_notification_groups_v1') ?? false;
      final result = await ReminderAlertSync.device(
        db,
      ).sync(onlyPending: grouped);
      if (result.complete) {
        await prefs.setBool('ascent_notification_groups_v1', true);
      }
    } catch (e) {
      // Pending rows remain durable for retry when alerts become available.
      debugPrint('Alert sync skipped/deferred: $e');
    }
  } catch (e) {
    debugPrint('Startup maintenance deferred: $e');
  }
}
