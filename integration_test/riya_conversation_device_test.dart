import 'package:ascent/main.dart' as app;
import 'package:ascent/app/router.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/medicine/medicine_service.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/home/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'Riya conversation framing, selected edits and confirmation on device',
    (tester) async {
      expect(
        (await PackageInfo.fromPlatform()).packageName,
        'com.arun.ascent.debug',
      );
      final prefs = await SharedPreferences.getInstance();
      for (final feature in [
        'Thought Wall',
        'Tasks & Today',
        'Focus Timer',
        'Medicine & Health',
        'Riya',
      ]) {
        await prefs.setBool('feature_guide_v1_$feature', true);
      }
      await app.main();
      Future<void> until(Finder finder) async {
        for (var i = 0; i < 50 && finder.evaluate().isEmpty; i++) {
          await tester.pump(const Duration(milliseconds: 200));
        }
        expect(finder, findsAtLeastNWidgets(1));
      }

      await until(find.text('Start now'));
      await tester.tap(find.text('Start now'));
      await until(find.byType(HomeScreen));
      final db = ProviderScope.containerOf(
        tester.element(find.byType(HomeScreen)),
        listen: false,
      ).read(databaseProvider);
      final id = await MedicineService(db, syncAlerts: false).addMedicine(
        name: 'Device QA schedule',
        dosage: 'User recorded dose',
        scheduledTimes: ['09:00'],
        durationDays: 1,
        startDate: DateTime.now().add(const Duration(days: 1)),
      );
      ascentRouter.go('/ai-assistant');
      await until(find.byKey(const ValueKey('message_composer_send')));
      Future<AiChatMessage> send(
        String prompt, {
        bool confirm = false,
        Future<void> Function()? beforeConfirm,
      }) async {
        final before =
            (await db.aiAssistantDao.watchRecentMessages().first)
                .lastOrNull
                ?.id ??
            0;
        await tester.enterText(find.byType(TextField).last, prompt);
        await tester.pump(const Duration(milliseconds: 200));
        await tester.tap(find.byKey(const ValueKey('message_composer_send')));
        if (confirm) {
          await until(find.text('Confirm'));
          await beforeConfirm?.call();
          await tester.tap(find.text('Confirm'));
        }
        for (var i = 0; i < 50; i++) {
          await tester.pump(const Duration(milliseconds: 200));
          final rows = await db.aiAssistantDao.watchRecentMessages().first;
          final replies = rows.where(
            (m) => m.id > before && m.sender == 'assistant',
          );
          if (replies.isNotEmpty) {
            await tester.pump(const Duration(milliseconds: 200));
            return replies.last;
          }
        }
        throw StateError('No assistant response for $prompt');
      }

      expect((await send('meri medicines dikhao')).actionType, 'medicine.list');
      expect(
        (await send('medicine Device QA schedule dikhao')).actionType,
        'medicine.read',
      );
      expect(
        (await send('isko edit karo')).message,
        contains('Which schedule field'),
      );
      expect(
        (await send(
          'name to Device QA corrected',
          confirm: true,
          beforeConfirm: () async {
            expect(
              (await db.medicineDao.getMedicineById(id))!.name,
              'Device QA schedule',
            );
          },
        )).actionType,
        'medicine.edit',
      );
      expect(
        (await db.medicineDao.getMedicineById(id))!.name,
        'Device QA corrected',
      );
      expect(await db.select(db.medicineTable).get(), hasLength(1));
      expect(
        (await send('course Device AM Basics banao', confirm: true)).actionType,
        'learning.course.create',
      );
      expect(
        (await send(
          'Please rename that to Device New Course',
          confirm: true,
        )).actionType,
        'learning.course.edit',
      );
      expect(
        (await db.courseDao.getAllCourses()).where(
          (c) => c.title == 'Device New Course',
        ),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
      debugPrint(
        'QA: conversational Medicine and Learning edits verified through chat with confirmation',
      );
    },
  );
}
