import 'dart:io';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/promises/models/promise_model.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:ascent/features/promises/services/promise_repository.dart';
import 'package:ascent/features/promises/widgets/promise_chat_composer.dart';
import 'package:ascent/features/promises/widgets/promise_detail_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  testWidgets(
    'simple promise creation, real pickers, daily tracking and calendar on Android',
    (t) async {
      expect(
        (await PackageInfo.fromPlatform()).packageName,
        'com.arun.ascent.qa',
      );
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repo = PromiseRepository(
        db,
        cancelNotification: (_) async {},
        scheduleNotification: (_, title, body, at) async => true,
      );
      await repo.initialize();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          promiseRepositoryProvider.overrideWithValue(repo),
        ],
      );
      PromiseModel? saved;
      Future<void> until(Finder f) async {
        for (var i = 0; i < 60 && f.evaluate().isEmpty; i++) {
          await t.pump(const Duration(milliseconds: 100));
        }
        expect(f, findsAtLeastNWidgets(1));
      }

      bool converted = false;
      Future<void> capture(String name) async {
        if (!converted) {
          await binding.convertFlutterSurfaceToImage();
          converted = true;
        }
        await t.pump();
        final bytes = await binding.takeScreenshot(name);
        await File(
          '${(await getTemporaryDirectory()).path}/$name.png',
        ).writeAsBytes(bytes);
      }

      Future<void> mount({bool dark = false}) async {
        await t.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: dark ? AscentTheme.dark() : AscentTheme.light(),
              home: Scaffold(
                body: Builder(
                  builder: (ctx) => Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        FilledButton(
                          onPressed: () => PromiseChatComposer.show(ctx),
                          child: const Text('Make a promise'),
                        ),
                        TextButton(
                          onPressed: () => PromiseDetailSheet.show(ctx, saved!),
                          child: const Text('Open promise'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.pumpAndSettle();
      }

      await mount();
      await t.tap(find.text('Make a promise'));
      await t.pumpAndSettle();
      await capture('promise-write-day');
      await t.enterText(
        find.byType(TextField),
        'Read for 20 minutes every day',
      );
      await t.pump();
      await t.tap(find.byKey(const ValueKey('message_composer_send')));
      await until(find.text('When?'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('promise_planned_time')));
      await t.pumpAndSettle();
      expect(find.byType(TimePickerDialog), findsOneWidget);
      await t.tap(find.text('OK'));
      await t.pumpAndSettle();
      await t.tap(find.byKey(const ValueKey('promise_end_date')));
      await t.pumpAndSettle();
      expect(find.byType(DatePickerDialog), findsOneWidget);
      await t.tap(find.text('Cancel'));
      await t.pumpAndSettle();
      await capture('promise-review-day');
      await t.tap(find.byKey(const ValueKey('promise_save')));
      await until(find.text('Promise saved. One small step at a time.'));
      await t.pumpAndSettle();
      saved = (await repo.getActivePromises()).single;
      expect(saved!.schedule!.repeat, PromiseRepeat.daily);
      await repo.markDayDone(saved!.id);
      saved = (await repo.getPromiseById(saved!.id))!;
      expect(saved!.isActive, true);
      expect(saved!.isDoneToday, true);
      await t.tap(find.text('Open promise'));
      await until(find.byKey(const ValueKey('promise_calendar')));
      await t.pumpAndSettle();
      expect(find.text('Done today'), findsWidgets);
      await capture('promise-calendar-day');
      expect(t.takeException(), isNull);
      await t.tap(find.byTooltip('Close'));
      await t.pumpAndSettle();
      await mount(dark: true);
      await t.tap(find.text('Make a promise'));
      await t.pumpAndSettle();
      await capture('promise-write-night');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      container.dispose();
      await db.close();
    },
  );
}
