import 'dart:async';

import 'core/services/plan_collection_service.dart';
import 'core/notifications/alarm_lifecycle.dart';
import 'core/notifications/reminder_alarm_bridge.dart';
import 'core/providers/database_provider.dart';
import 'core/notifications/reminder_alert_sync.dart';
import 'core/ai/riya_alert_effects.dart';
import 'package:path_provider/path_provider.dart';
import 'core/database/app_database.dart';
import 'core/backup/workspace_backup_service.dart';
import 'core/backup/workspace_restart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'app/theme/app_theme.dart';
import 'app/router.dart';
import 'core/notifications/notification_service.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/time_tracking_provider.dart';
import 'core/learning_hub/learning_hub_provider.dart';
import 'core/walk/walk_tracking_service.dart';
import 'features/chai_break/chai_break_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  final prefs = await SharedPreferences.getInstance();
  final bootstrapDb = AppDatabase();
  try {
    try {
      await WorkspaceBackupService(
        bootstrapDb,
        SharedBackupPreferences(prefs),
        await getApplicationDocumentsDirectory(),
      ).recoverPreferences();
    } catch (e) {
      debugPrint('Startup preferences recovery failed: $e');
      await bootstrapDb.close();
      runApp(
        MaterialApp(
          theme: AscentTheme.light(),
          home: Scaffold(
            body: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Finish restoring settings',
                        style: TextStyle(fontSize: 24),
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Your restored records are safe. Settings could not be synchronized. Free some storage and retry.',
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: main,
                        child: const Text('Retry recovery'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      return;
    }

    await PlanCollectionService(bootstrapDb).importLegacy();
  } finally {
    await bootstrapDb.close();
  }
  await touchLastOpened(prefs);

  late ProviderContainer container;
  ProviderContainer createContainer() => ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      restartWorkspaceProvider.overrideWithValue(() async {
        final previous = container;
        container = createContainer();
        ascentRouter.go('/');
        runApp(
          UncontrolledProviderScope(
            key: UniqueKey(),
            container: container,
            child: const AscentApp(),
          ),
        );
        await WidgetsBinding.instance.endOfFrame;
        previous.dispose();
      }),
    ],
  );
  container = createContainer();

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
      ascentRouter.go(destination);
    }
  });

  NotificationService.onNotificationSeek = (route, seconds) {
    if (route != '/learning') return;
    final duration = container
        .read(learningHubProvider)
        .activeLecture
        .durationSeconds;
    if (duration > 0) {
      container.read(learningHubProvider.notifier).seekTo(seconds / duration);
    }
  };

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
    if (effectivePayload == '/walk') {
      final walkNotifier = container.read(walkTrackingProvider.notifier);
      if (actionId == NotificationService.actionPause) {
        walkNotifier.pauseWalk();
      } else if (actionId == NotificationService.actionResume) {
        walkNotifier.resumeWalk();
      }
    } else if (effectivePayload == '/learning') {
      final learningNotifier = container.read(learningHubProvider.notifier);
      if (actionId == NotificationService.actionPause) {
        learningNotifier.pause();
      } else if (actionId == NotificationService.actionResume) {
        learningNotifier.play();
      } else if (actionId == NotificationService.actionRewind) {
        learningNotifier.seekBy(-10);
      } else if (actionId == NotificationService.actionForward) {
        learningNotifier.seekBy(30);
      } else if (actionId == NotificationService.actionDone) {
        learningNotifier.pause(updateNotification: false);
        NotificationService.instance.cancelOngoingLectureNotification();
      }
    } else if (effectivePayload == '/focus') {
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
    } else if (effectivePayload == '/chai-break') {
      final chaiNotifier = container.read(chaiBreakProvider.notifier);
      if (actionId == NotificationService.actionPause) {
        chaiNotifier.pause();
      } else if (actionId == NotificationService.actionResume) {
        chaiNotifier.resume();
      }
    } else {
      // Robust fallback if payload was not preserved by OS
      final learning = container.read(learningHubProvider);
      if (learning.isPlaying) {
        if (actionId == NotificationService.actionPause) {
          container.read(learningHubProvider.notifier).pause();
        }
      } else if (learning.currentElapsedSeconds > 0) {
        if (actionId == NotificationService.actionResume) {
          container.read(learningHubProvider.notifier).play();
        }
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
