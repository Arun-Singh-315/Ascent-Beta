import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app/app.dart';
import 'app/router.dart';
import 'core/notifications/notification_service.dart';
import 'core/providers/settings_provider.dart';
import 'core/providers/time_tracking_provider.dart';
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
      ascentRouter.push(route);
    }
  });

  NotificationService.setNotificationActionHandler((actionId, payload) {
    if (payload == '/walk') {
      final walkNotifier = container.read(walkTrackingProvider.notifier);
      if (actionId == NotificationService.actionPause) {
        walkNotifier.pauseWalk();
      } else if (actionId == NotificationService.actionResume) {
        walkNotifier.resumeWalk();
      } else if (actionId == NotificationService.actionFinish) {
        ascentRouter.push('/walk');
      }
    } else if (payload == '/focus') {
      final sessionNotifier = container.read(timeTrackingProvider.notifier);
      if (actionId == NotificationService.actionPause) {
        sessionNotifier.pauseSession();
      } else if (actionId == NotificationService.actionResume) {
        sessionNotifier.resumeSession();
      } else if (actionId == NotificationService.actionFinish) {
        sessionNotifier.completeSession();
      }
    } else if (payload == '/chai-break') {
      final chaiNotifier = container.read(chaiBreakProvider.notifier);
      if (actionId == NotificationService.actionPause) {
        chaiNotifier.pause();
      } else if (actionId == NotificationService.actionResume) {
        chaiNotifier.resume();
      } else if (actionId == NotificationService.actionFinish) {
        chaiNotifier.pause();
        NotificationService.instance.cancelOngoingChaiBreakNotification();
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
