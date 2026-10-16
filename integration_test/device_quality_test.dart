import 'dart:io';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:ascent/main.dart' as app;
import 'package:ascent/app/router.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/backup/workspace_backup_service.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/core/ai/riya_capabilities.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'quick entry, real disk backup, verified actions and native scheduling',
    (tester) async {
      final package = await PackageInfo.fromPlatform();
      expect(package.packageName, 'com.arun.ascent.debug');
      final testPrefs = await SharedPreferences.getInstance();
      await testPrefs.clear();
      await app.main();
      Future<void> until(Finder finder) async {
        for (var i = 0; i < 40 && finder.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 500));
        }
        expect(finder, findsAtLeastNWidgets(1));
      }

      await until(find.text('Start now'));
      await tester.tap(find.text('Start now'));
      await until(find.text('Your space'));
      debugPrint('QA: Quick Start reached Home');
      expect(find.text('Target Companies'), findsNothing);
      expect(tester.takeException(), isNull);
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase();
      final docs = await getApplicationDocumentsDirectory();
      final service = WorkspaceBackupService(
        db,
        SharedBackupPreferences(prefs),
        docs,
      );
      final thought = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Device QA thought'),
      );
      await prefs.setString('ascent_note_draft_home', 'Device QA unsent ☕');
      final executor = RiyaExecutor(db);
      final command = const RiyaCommand('expenses.create', {
        'amount': 200,
        'title': 'QA coffee',
      });
      await executor.execute(
        command,
        requestId: 'device-qa-expense',
        approved: true,
      );
      await executor.execute(
        command,
        requestId: 'device-qa-expense',
        approved: true,
      );
      expect(
        (await db.financeDao.watchAllTransactions().first).where(
          (t) => t.title == 'QA coffee',
        ),
        hasLength(1),
      );
      debugPrint('QA: duplicate Riya write verified');
      final raw = await service.export();
      final snapshot = File('${docs.path}/device-qa-backup.json');
      await snapshot.writeAsString(raw, flush: true);
      await db.thoughtDao.deleteThought(thought);
      await service.restore(await snapshot.readAsString(), confirmed: true);
      expect(
        (await db.thoughtDao.watchAllThoughts().first).any(
          (t) => t.content == 'Device QA thought',
        ),
        isTrue,
      );
      expect(prefs.getString('ascent_note_draft_home'), 'Device QA unsent ☕');
      debugPrint('QA: disk backup and restore verified');
      ascentRouter.go('/backup');
      await tester.pump(const Duration(seconds: 2));
      await tester.ensureVisible(find.text('Restore backup'));
      await tester.tap(find.text('Restore backup'));
      await tester.pump(const Duration(seconds: 1));
      debugPrint('QA: native backup chooser requested');
      await tester.pump(const Duration(seconds: 12));
      expect(
        tester
            .widget<OutlinedButton>(
              find.widgetWithText(OutlinedButton, 'Restore backup'),
            )
            .onPressed,
        isNotNull,
      );
      expect(
        (await db.thoughtDao.watchAllThoughts().first).any(
          (t) => t.content == 'Device QA thought',
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
      debugPrint('QA: native chooser cancellation preserved records');
      expect(await NotificationService.refreshLocalTimeZone(), isTrue);
      for (
        var i = 0;
        i < 30 && !await NotificationService.instance.areNotificationsEnabled();
        i++
      ) {
        await tester.pump(const Duration(seconds: 1));
      }
      expect(
        await NotificationService.instance.areNotificationsEnabled(),
        isTrue,
      );
      final at = DateTime.now().add(const Duration(seconds: 30));
      final scheduled = await NotificationService.instance
          .scheduleReminderNotificationChecked(
            id: 810007,
            title: 'Device QA scheduled alert',
            scheduledAt: at,
            scheduleFollowUp: false,
          );
      expect(scheduled, isTrue);
      final pending = await FlutterLocalNotificationsPlugin()
          .pendingNotificationRequests();
      expect(pending.any((r) => r.id == 810007), isTrue);
      debugPrint('QA: native alert 810007 scheduled');
      // Leave QA running briefly so external ADB checks can verify delivery.
      await tester.pump(const Duration(seconds: 45));
      await db.close();
      await tester.pumpWidget(const SizedBox());
    },
  );
}
