import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/services/promise_service.dart';
import 'package:ascent/features/promises/promise_composer.dart';
import 'package:ascent/features/thought_wall/drop_thought_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late DateTime now;
  late PromiseService service;
  late Map<int, String> alerts;
  late List<DateTime> times;
  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    now = DateTime(2026, 10, 24, 11);
    alerts = {};
    times = [];
    service = PromiseService(
      db,
      clock: () => now,
      scheduleNotification: (id, copy, at) async {
        alerts[id] = copy;
        times.add(at);
      },
      cancelNotification: (id) async {
        alerts.remove(id);
      },
    );
  });
  tearDown(() => db.close());

  test(
    'many promises share remaining daily alerts and personalize the whole list',
    () async {
      await db.userProfileDao.upsertProfile(
        UserProfileTableCompanion.insert(name: 'Arun Singh'),
      );
      final ids = await service.createBatch([
        'Go for a walk',
        'Read a chapter',
      ]);
      expect(ids, hasLength(2));
      expect(await db.select(db.taskTable).get(), isEmpty);
      expect(await db.select(db.reminderTable).get(), isEmpty);
      expect(alerts, hasLength(3));
      expect(times.map((at) => at.hour), [14, 18, 21]);
      expect(
        alerts.values.every(
          (copy) =>
              copy.contains('Hey Arun') &&
              copy.contains('1. Go for a walk') &&
              copy.contains('2. Read a chapter'),
        ),
        isTrue,
      );
      await service.update(thoughtId: ids.first, content: 'Walk slowly');
      expect(
        alerts.values.every(
          (copy) =>
              copy.contains('Walk slowly') && !copy.contains('Go for a walk'),
        ),
        isTrue,
      );
      await db.thoughtDao.setCompleted(ids.first, true);
      await service.syncCheckIns();
      expect(
        alerts.values.every((copy) => !copy.contains('Walk slowly')),
        isTrue,
      );
      await db.thoughtDao.archiveThought(ids.last);
      await service.syncCheckIns();
      expect(alerts, isEmpty);
    },
  );

  test(
    'invalid batches never partially save and yesterday never gets new check-ins',
    () async {
      await expectLater(
        service.createBatch(['Valid', '']),
        throwsArgumentError,
      );
      expect(await db.select(db.thoughtTable).get(), isEmpty);
      await service.create(content: 'Yesterday’s promise');
      now = DateTime(2026, 10, 25, 8);
      await service.syncCheckIns();
      expect(alerts, isEmpty);
      expect(await db.select(db.thoughtTable).get(), hasLength(1));
    },
  );

  test(
    'notification failure preserves promises and a later sync retries',
    () async {
      var unavailable = true;
      final retry = PromiseService(
        db,
        clock: () => now,
        cancelNotification: (_) async {},
        scheduleNotification: (id, copy, at) async {
          if (unavailable) throw StateError('denied');
          alerts[id] = copy;
        },
      );
      await retry.create(content: 'A small step');
      expect(await db.select(db.thoughtTable).get(), hasLength(1));
      expect(alerts, isEmpty);
      unavailable = false;
      expect(await retry.syncCheckIns(), isTrue);
      expect(alerts, hasLength(3));
    },
  );

  testWidgets(
    'guided composer adds multiple promises, edits review, and saves together at large text',
    (t) async {
      t.view.physicalSize = const Size(320, 1200);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      await t.runAsync(() => db.customSelect('SELECT 1').get());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          promiseServiceProvider.overrideWithValue(service),
          userProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
        ],
      );
      try {
        await t.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.dark(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: Scaffold(
                body: Builder(
                  builder: (context) => TextButton(
                    onPressed: () => DropThoughtSheet.showPromise(context),
                    child: const Text('Open'),
                  ),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('Open'));
        await t.pumpAndSettle();
        await t.enterText(
          find.byKey(const ValueKey('promise_input')),
          'Go outside',
        );
        await t.pump();
        final next = find.descendant(
          of: find.byKey(const ValueKey('promise_next')),
          matching: find.byType(FilledButton),
        );
        expect(t.widget<FilledButton>(next).onPressed, isNotNull);
        await t.ensureVisible(find.text('Next promise'));
        await t.tap(find.text('Next promise'));
        await t.pumpAndSettle();
        expect(find.byKey(const ValueKey('promise_next')), findsNothing);
        expect(
          t
              .widget<FilledButton>(
                find.widgetWithText(FilledButton, 'Review & save'),
              )
              .onPressed,
          isNotNull,
        );
        await t.enterText(
          find.byKey(const ValueKey('promise_input')),
          'Read something',
        );
        await t.pump();
        await t.ensureVisible(find.text('Review & save'));
        await t.tap(find.text('Review & save'));
        await t.pumpAndSettle();
        expect(find.text('Go outside'), findsOneWidget);
        expect(find.text('Read something'), findsOneWidget);
        await t.ensureVisible(find.byTooltip('Edit promise 1'));
        await t.tap(find.byTooltip('Edit promise 1'));
        await t.pumpAndSettle();
        await t.enterText(
          find.byKey(const ValueKey('promise_input')),
          'Take a walk',
        );
        await t.pump();
        await t.ensureVisible(find.text('Review & save'));
        await t.tap(find.text('Review & save'));
        await t.pumpAndSettle();
        expect(find.text('Take a walk'), findsOneWidget);
        expect(t.takeException(), isNull);
        await t.ensureVisible(find.text('Save 2 promises'));
        await t.tap(find.text('Save 2 promises'));
        for (
          var i = 0;
          i < 60 && find.byType(PromiseComposerDialog).evaluate().isNotEmpty;
          i++
        ) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await t.pump(const Duration(milliseconds: 100));
        }
        final rows = await t.runAsync(() => db.select(db.thoughtTable).get());
        expect(rows!.map((row) => row.content), [
          'Take a walk',
          'Read something',
        ]);
        expect(find.byType(PromiseComposerDialog), findsNothing);
      } finally {
        await t.pumpWidget(const SizedBox());
        container.dispose();
        await t.pump(const Duration(seconds: 2));
      }
    },
  );
}
