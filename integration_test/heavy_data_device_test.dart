// Heavy-data walk-through on a real phone, in the separate QA install only.
//
// Run: ORG_GRADLE_PROJECT_ascentDeviceQa=true flutter test --no-uninstall \
//        integration_test/heavy_data_device_test.dart -d <device>
//
// Seeds a large dummy dataset into the QA package's own database (never the
// personal app), visits every main screen, scrolls it, and prints frame
// timings (PERF:) plus SHOT: markers a host script can turn into screenshots.
import 'dart:ui';

import 'package:ascent/app/router.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/features/feature_registry.dart';
import 'package:ascent/core/medicine/medicine_service.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/main.dart' as app;
import 'package:drift/drift.dart' as drift;
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  testWidgets('every main screen stays smooth with a lot of data', (
    tester,
  ) async {
    // Safety: only ever write dummy data into the QA install.
    final pkg = (await PackageInfo.fromPlatform()).packageName;
    if (pkg != 'com.arun.ascent.qa') {
      fail('Refusing to seed data into $pkg. Build with ascentDeviceQa=true.');
    }

    Future<void> wait(int ms) =>
        tester.pump(Duration(milliseconds: ms)).then(
          (_) => Future<void>.delayed(Duration(milliseconds: ms)),
        );
    Future<void> until(Finder f, {int tries = 60}) async {
      for (var i = 0; i < tries && f.evaluate().isEmpty; i++) {
        await wait(150);
      }
    }

    await app.main();
    await until(find.text('Skip'));
    if (find.text('Skip').evaluate().isNotEmpty) {
      await tester.tap(find.text('Skip').first);
    }
    await until(find.byKey(const ValueKey('home_scroll')));
    await wait(500);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(const ValueKey('home_scroll'))),
      listen: false,
    );
    await container
        .read(unlockedFeaturesProvider.notifier)
        .set(AscentFeature.values.toSet());
    final db = container.read(databaseProvider);

    // ── Seed ──────────────────────────────────────────────────────────────
    final seedWatch = Stopwatch()..start();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    const words = [
      'Review', 'Call', 'Plan', 'Buy', 'Write', 'Fix', 'Read', 'Clean',
      'Book', 'Pay', 'Email', 'Prepare', 'Walk', 'Cook', 'Study', 'Design',
    ];
    const things = [
      'design docs', 'mom', 'weekend trip', 'groceries', 'blog post',
      'bike brakes', 'chapter 4', 'kitchen', 'dentist', 'electricity bill',
      'the team', 'interview notes', 'the dog', 'dinner', 'DSA graphs',
      'landing page',
    ];
    String title(int i) =>
        '${words[i % words.length]} ${things[(i * 7) % things.length]} #$i';

    await db.batch((b) {
      b.insertAll(db.taskTable, [
        for (var i = 0; i < 600; i++)
          TaskTableCompanion.insert(
            title: title(i),
            plannedDate: drift.Value(
              today.add(Duration(hours: 6 + (i % 16), minutes: (i * 13) % 60)),
            ),
            estimatedMinutes: drift.Value(i % 5 == 0 ? 30 : null),
            priority: drift.Value(i % 9 == 0 ? 'high' : 'low'),
          ),
        for (var i = 0; i < 400; i++)
          TaskTableCompanion.insert(
            title: title(600 + i),
            plannedDate: drift.Value(today.add(Duration(days: 1 + i % 60))),
          ),
        for (var i = 0; i < 150; i++)
          TaskTableCompanion.insert(title: 'Someday: ${title(1000 + i)}'),
      ]);
      b.insertAll(db.thoughtTable, [
        for (var i = 0; i < 300; i++)
          ThoughtTableCompanion.insert(
            content: i % 6 == 0
                ? '- [x] ${title(i)}\n- [ ] ${title(i + 1)}\n- [ ] ${title(i + 2)}'
                : i % 4 == 0
                ? 'A longer idea #$i: ${List.filled(8, 'keep the day calm and the list short,').join(' ')}'
                : 'Idea #$i: ${title(i)}',
            isPinned: drift.Value(i % 50 == 0),
            createdAt: drift.Value(now.subtract(Duration(hours: i * 3))),
          ),
      ]);
      b.insertAll(db.reminderTable, [
        for (var i = 0; i < 200; i++)
          ReminderTableCompanion.insert(
            title: 'Reminder: ${title(i)}',
            scheduledAt: now.add(Duration(hours: 2 + i * 5)),
          ),
      ]);
      b.insertAll(db.financeTransactionTable, [
        for (var i = 0; i < 500; i++)
          FinanceTransactionTableCompanion.insert(
            title: i % 10 == 0 ? 'Salary part $i' : 'Spent on ${things[i % 16]}',
            amount: 50.0 + (i * 37) % 900,
            type: drift.Value(i % 10 == 0 ? 'income' : 'expense'),
            date: now.subtract(Duration(hours: i * 4)),
          ),
      ]);
      b.insertAll(db.waterLogTable, [
        for (var i = 0; i < 8; i++)
          WaterLogTableCompanion.insert(
            amountMl: 250,
            timestamp: drift.Value(today.add(Duration(hours: 7 + i))),
            date: today,
          ),
      ]);
    });
    final meds = MedicineService(db, syncAlerts: false);
    for (var i = 0; i < 10; i++) {
      await meds.addMedicine(
        name: 'Medicine ${String.fromCharCode(65 + i)}',
        dosage: '${(i + 1) * 50} mg',
        scheduledTimes: ['08:00', '14:00', '21:00'],
        durationDays: 30,
        startDate: today,
      );
    }
    seedWatch.stop();
    // ignore: avoid_print
    print(
      'SEED: 1150 things, 300 thoughts, 200 reminders, 500 money, '
      '10 medicines x3 doses in ${seedWatch.elapsedMilliseconds} ms',
    );

    // ── Frame timing per screen ──────────────────────────────────────────
    final timings = <FrameTiming>[];
    void collect(List<FrameTiming> t) => timings.addAll(t);
    SchedulerBinding.instance.addTimingsCallback(collect);

    Future<void> visit(
      String name,
      String route, {
      int flings = 4,
      Finder? scrollable,
    }) async {
      final open = Stopwatch()..start();
      ascentRouter.go(route);
      await wait(1200);
      open.stop();
      // ignore: avoid_print
      print('SHOT:${name}_top');
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      timings.clear();
      // The screen's main list: the tallest vertical Scrollable.
      Finder? mainList() {
        Element? best;
        var bestH = 0.0;
        for (final e in find.byType(Scrollable).evaluate()) {
          final w = e.widget as Scrollable;
          if (w.axisDirection != AxisDirection.down) continue;
          final box = e.renderObject;
          if (box is! RenderBox || !box.hasSize) continue;
          if (box.size.height > bestH) {
            bestH = box.size.height;
            best = e;
          }
        }
        return best == null ? null : find.byElementPredicate((e) => e == best);
      }

      for (var i = 0; i < flings; i++) {
        final s = scrollable ?? mainList();
        if (s == null) break;
        try {
          await tester.fling(s, const Offset(0, -900), 2500);
        } catch (_) {
          break;
        }
        await wait(700);
      }
      // ignore: avoid_print
      print('SHOT:${name}_scrolled');
      await Future<void>.delayed(const Duration(milliseconds: 1500));
      final build = timings.map((t) => t.buildDuration.inMicroseconds / 1000);
      final raster = timings.map(
        (t) => t.rasterDuration.inMicroseconds / 1000,
      );
      double avg(Iterable<double> v) =>
          v.isEmpty ? 0 : v.reduce((a, b) => a + b) / v.length;
      double worst(Iterable<double> v) =>
          v.isEmpty ? 0 : v.reduce((a, b) => a > b ? a : b);
      final janky = timings
          .where(
            (t) =>
                t.buildDuration.inMilliseconds + t.rasterDuration.inMilliseconds >
                16,
          )
          .length;
      final error = tester.takeException();
      // ignore: avoid_print
      print(
        'PERF:$name open=${open.elapsedMilliseconds}ms frames=${timings.length} '
        'build avg=${avg(build).toStringAsFixed(1)} worst=${worst(build).toStringAsFixed(1)} '
        'raster avg=${avg(raster).toStringAsFixed(1)} worst=${worst(raster).toStringAsFixed(1)} '
        'janky=$janky${error == null ? '' : ' ERROR=$error'}',
      );
    }

    await visit('home', '/home', flings: 5);
    await visit('things_today', '/things', flings: 6);
    await visit('mind', '/thought-wall', flings: 5);
    await visit('calendar', '/calendar');
    await visit('reminders', '/reminders', flings: 5);
    await visit('medicine', '/medicine');
    await visit('money', '/money', flings: 5);
    await visit('hydration', '/hydration', flings: 2);
    await visit('history', '/history', flings: 5);
    await visit('assistant', '/ai-assistant', flings: 1);
    await visit('you', '/you', flings: 2);

    SchedulerBinding.instance.removeTimingsCallback(collect);
    ascentRouter.go('/home');
    await wait(800);
    // ignore: avoid_print
    print('DONE');
  });
}
