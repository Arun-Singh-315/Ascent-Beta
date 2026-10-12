import 'package:ascent/main.dart' as app;
import 'package:ascent/app/router.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/core/notifications/reminder_alarm_bridge.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('native Learning and Focus controls and player routing', (
    tester,
  ) async {
    expect(
      (await PackageInfo.fromPlatform()).packageName,
      'com.arun.ascent.debug',
    );
    await (await SharedPreferences.getInstance()).clear();
    await app.main();
    for (var i = 0; i < 40 && find.text('Start now').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    await tester.tap(find.text('Start now'));
    for (var i = 0; i < 40 && find.text('Your space').evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 500));
    }
    final container = ProviderScope.containerOf(
      tester.element(find.text('Your space')),
    );
    final db = container.read(databaseProvider);
    debugPrint('QA: ready for alarm permissions');
    for (var i = 0; i < 30; i++) {
      final access = await ReminderAlarmBridge.access();
      if (access['notifications'] == true &&
          access['exact'] == true &&
          access['fullScreen'] == true) {
        break;
      }
      await tester.pump(const Duration(seconds: 1));
    }
    final access = await ReminderAlarmBridge.access();
    expect(access['notifications'], true);
    expect(access['exact'], true);
    expect(access['fullScreen'], true);
    final learning = container.read(learningHubProvider.notifier);
    final original = container.read(learningHubProvider);
    learning.updateCourse(
      original.course.copyWith(
        title: 'QA Learning course',
        modules: original.course.modules
            .map(
              (m) => m.copyWith(
                lectures: m.lectures
                    .map(
                      (l) => l.id == original.activeLecture.id
                          ? l.copyWith(title: 'QA Learning timer')
                          : l,
                    )
                    .toList(),
              ),
            )
            .toList(),
      ),
    );
    learning.play();
    await tester.pump(const Duration(seconds: 2));
    expect(container.read(learningHubProvider).isPlaying, true);
    debugPrint('QA: Learning notification ready for Pause');
    await tester.pump(const Duration(seconds: 14));
    expect(container.read(learningHubProvider).isPlaying, false);
    final pausedAt = container.read(learningHubProvider).currentElapsedSeconds;
    debugPrint('QA: Learning paused; Resume and open player');
    await tester.pump(const Duration(seconds: 14));
    expect(container.read(learningHubProvider).isPlaying, true);
    expect(
      ascentRouter.routerDelegate.currentConfiguration.uri.path,
      '/learning',
    );
    expect(
      container.read(learningHubProvider).currentElapsedSeconds,
      greaterThanOrEqualTo(pausedAt),
    );
    learning.seekBy(30);
    learning.pause();
    final category = (await db.select(db.sessionCategoryTable).get())
        .firstWhere((c) => c.name == 'Study');
    final focus = container.read(timeTrackingProvider.notifier);
    final focusId = await focus.startSession(
      label: 'QA Focus timer',
      categoryId: category.id,
    );
    await tester.pump(const Duration(seconds: 2));
    debugPrint('QA: Focus notification ready for Pause');
    await tester.pump(const Duration(seconds: 14));
    expect(
      (await (db.select(
        db.timeSessionTable,
      )..where((r) => r.id.equals(focusId))).getSingleOrNull())!.status,
      'paused',
    );
    debugPrint('QA: Focus paused; Resume and open player');
    await tester.pump(const Duration(seconds: 14));
    expect(
      (await (db.select(
        db.timeSessionTable,
      )..where((r) => r.id.equals(focusId))).getSingleOrNull())!.status,
      'running',
    );
    expect(ascentRouter.routerDelegate.currentConfiguration.uri.path, '/focus');
    await focus.pauseSession();
    await NotificationService.instance.cancelOngoingSessionNotification();
    debugPrint('QA: Learning and Focus native controls verified');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
