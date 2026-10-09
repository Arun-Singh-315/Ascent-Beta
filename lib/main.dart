import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'app/router.dart';
import 'core/notifications/notification_service.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/time_tracking_provider.dart';
import 'core/learning_hub/learning_hub_provider.dart';
import 'core/walk/walk_tracking_service.dart';
import 'features/chai_break/chai_break_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await NotificationService.instance.initialize();
  NotificationService.instance.requestPermissions();
  await NotificationService.instance.scheduleDailyMomentumGuardianNudges();

  final prefs = await SharedPreferences.getInstance();
  await touchLastOpened(prefs);

  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
    ],
  );

  NotificationService.setNotificationNavigateHandler((route) {
    if (route.isNotEmpty) {
      final currentUri = ascentRouter.routerDelegate.currentConfiguration.uri.toString();
      if (currentUri != route) {
        ascentRouter.go(route);
      }
    }
  });

  NotificationService.setNotificationActionHandler((actionId, payload) {
    final effectivePayload = payload?.isNotEmpty == true ? payload : null;
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
      }
    } else if (effectivePayload == '/focus') {
      final sessionNotifier = container.read(timeTrackingProvider.notifier);
      if (actionId == NotificationService.actionPause) {
        sessionNotifier.pauseSession();
      } else if (actionId == NotificationService.actionResume) {
        sessionNotifier.resumeSession();
      }
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
        if (actionId == NotificationService.actionPause) container.read(learningHubProvider.notifier).pause();
      } else if (learning.currentElapsedSeconds > 0) {
        if (actionId == NotificationService.actionResume) container.read(learningHubProvider.notifier).play();
      } else {
        final focusState = container.read(timeTrackingProvider);
        if (focusState.isRunning) {
          if (actionId == NotificationService.actionPause) container.read(timeTrackingProvider.notifier).pauseSession();
        } else if (focusState.isPaused) {
          if (actionId == NotificationService.actionResume) container.read(timeTrackingProvider.notifier).resumeSession();
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
      container: container,
      child: const AscentApp(),
    ),
  );
}
