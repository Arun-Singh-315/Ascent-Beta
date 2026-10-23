import 'dart:io';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/features/home/widgets/home_overview_card.dart';
import 'package:ascent/features/plans/planning_providers.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'package:ascent/features/thought_wall/thought_wall_appearance_sheet.dart';
import 'package:ascent/shared/widgets/glass_chip.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

TodayActivityItem row(int id, String type) => TodayActivityItem(
  id: 'task_$id',
  title: '$type activity $id',
  sourceType: type,
  categoryTag: type == 'medicine' ? 'Medicine' : 'Task',
  status: TodayActivityStatus.notStarted,
  elapsedSecondsToday: 0,
  kind: type == 'timer' ? ActivityKind.duration : ActivityKind.todo,
  plannedDate: DateTime.now().add(Duration(minutes: id)),
);

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    if (Platform.environment['ASCENT_REDESIGN_CAPTURE'] == '1') {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });
  Future<void> flush(WidgetTester t) async {
    for (var i = 0; i < 6; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> capture(WidgetTester t, String name) async {
    if (Platform.environment['ASCENT_REDESIGN_CAPTURE'] != '1') return;
    await t.runAsync(() async {
      final boundary = t.renderObject<RenderRepaintBoundary>(
        find.byKey(const ValueKey('redesign_capture')),
      );
      final picture = await boundary.toImage();
      final data = await picture.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/tmp/ascent-redesign-$name.png',
      ).writeAsBytes(data!.buffer.asUint8List());
      picture.dispose();
    });
  }

  testWidgets('long press saves priority and promotes urgent work', (t) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final first = await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Normal work',
        plannedDate: drift.Value(DateTime.now()),
        priority: const drift.Value('low'),
      ),
    );
    final second = await db.taskDao.insertTask(
      TaskTableCompanion.insert(
        title: 'Urgent work',
        plannedDate: drift.Value(DateTime.now()),
        priority: const drift.Value('low'),
      ),
    );
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        todayActivitiesProvider.overrideWith(
          (ref) => db.taskDao.watchTodayTasks().map(
            (tasks) => [
              for (final task in tasks)
                row(task.id, 'task').copyWith(
                  title: task.title,
                  linkedTaskId: task.id,
                  priority: task.priority,
                ),
            ],
          ),
        ),
      ],
    );
    try {
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(child: ActivityHubCard()),
            ),
          ),
        ),
      );
      await flush(t);
      await t.pumpAndSettle();
      expect(
        t
            .widgetList<ActivityRowItem>(find.byType(ActivityRowItem))
            .first
            .activity
            .linkedTaskId,
        first,
      );
      await t.longPress(find.text('Urgent work'));
      await t.pumpAndSettle();
      await t.tap(find.text('P0 · Urgent'));
      await flush(t);
      await t.pumpAndSettle();
      final saved = await t.runAsync(() => db.taskDao.getTaskById(second));
      expect(saved!.priority, 'high');
      expect(
        t
            .widgetList<ActivityRowItem>(find.byType(ActivityRowItem))
            .first
            .activity
            .linkedTaskId,
        second,
      );
      expect(find.text('P0'), findsOneWidget);
      expect(t.takeException(), isNull);
    } finally {
      await t.pumpWidget(const SizedBox());
      container.dispose();
      await t.pump(const Duration(seconds: 2));
    }
  });

  for (final preset in DayThemePreset.values) {
    for (final dark in [false, true]) {
      testWidgets(
        'compact rows bound 1000 tasks and chips fit $preset dark=$dark',
        (t) async {
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          addTearDown(db.close);
          final items = [
            for (var i = 0; i < 1000; i++) row(i, 'task'),
            for (var i = 1000; i < 1008; i++) row(i, 'medicine'),
            row(1009, 'lecture'),
            row(1010, 'timer'),
          ];
          t.view.physicalSize = const Size(390, 1000);
          t.view.devicePixelRatio = 1;
          addTearDown(t.view.resetPhysicalSize);
          addTearDown(t.view.resetDevicePixelRatio);
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              todayActivitiesProvider.overrideWith(
                (ref) => Stream.value(items),
              ),
              allRemindersProvider.overrideWith((ref) => Stream.value([])),
              planCollectionsProvider.overrideWith((ref) => Stream.value([])),
            ],
          );
          try {
            await t.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  theme: dark
                      ? AscentTheme.dark(preset: preset)
                      : AscentTheme.light(preset: preset),
                  home: RepaintBoundary(
                    key: const ValueKey('redesign_capture'),
                    child: const Scaffold(
                      body: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(16),
                          child: Column(
                            children: [HomeOverviewCard(), ActivityHubCard()],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            expect(find.byType(ActivityRowItem), findsNWidgets(4));
            expect(
              find.byKey(const ValueKey('activity_hub_type_filters')),
              findsNothing,
            );
            expect(
              find.descendant(
                of: find.byType(HomeOverviewCard),
                matching: find.byType(GlassChip),
              ),
              findsNWidgets(3),
            );
            await capture(t, 'hub-${preset.name}-${dark ? 'dark' : 'light'}');
            t.view.physicalSize = const Size(320, 1000);
            await t.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  theme: dark
                      ? AscentTheme.dark(preset: preset)
                      : AscentTheme.light(preset: preset),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!,
                  ),
                  home: const Scaffold(
                    body: SingleChildScrollView(
                      child: Padding(
                        padding: EdgeInsets.all(16),
                        child: ActivityHubCard(),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await t.pumpAndSettle();
            expect(t.takeException(), isNull);
            expect(find.byType(ActivityRowItem), findsNWidgets(4));
            expect(t.takeException(), isNull);
          } finally {
            await t.pumpWidget(const SizedBox());
            container.dispose();
            await t.pump(const Duration(seconds: 2));
          }
        },
      );
    }
  }

  testWidgets(
    'open thoughts precede done; archive is separate and edit stays visible',
    (t) async {
      SharedPreferences.setMockInitialValues({
        'feature_guide_v1_Thought Wall': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      t.view.physicalSize = const Size(390, 1000);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final open = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'An open note',
          createdAt: drift.Value(
            DateTime.now().subtract(const Duration(minutes: 2)),
          ),
        ),
      );
      final done = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'A completed note',
          isCompleted: const drift.Value(true),
        ),
      );
      final archived = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'An archived note',
          isArchived: const drift.Value(true),
        ),
      );
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      try {
        await t.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: AscentTheme.dark(preset: DayThemePreset.merlotLinen),
              home: const RepaintBoundary(
                key: ValueKey('redesign_capture'),
                child: ThoughtWallScreen(),
              ),
            ),
          ),
        );
        await flush(t);
        expect(find.text('An archived note'), findsNothing);
        expect(
          t.getTopLeft(find.text('An open note')).dy,
          lessThan(t.getTopLeft(find.text('A completed note')).dy),
        );
        expect(
          t
              .widget<GlassChip>(find.byKey(ValueKey('thought_done_$done')))
              .success,
          isTrue,
        );
        expect(find.byTooltip('Edit thought'), findsNWidgets(2));
        await capture(t, 'thoughts-dark');
        await t.tap(find.widgetWithText(GlassChip, 'Archive'));
        await flush(t);
        expect(find.text('An archived note'), findsOneWidget);
        expect(find.text('An open note'), findsNothing);
        expect(
          (await t.runAsync(
            () => db.thoughtDao.getThoughtById(archived),
          ))!.isArchived,
          isTrue,
        );
        await t.tap(find.widgetWithText(GlassChip, 'Archive'));
        await flush(t);
        await t.tap(find.byKey(ValueKey('thought_done_$open')));
        await flush(t);
        expect(
          (await t.runAsync(
            () => db.thoughtDao.getThoughtById(open),
          ))!.isCompleted,
          isTrue,
        );
        expect(t.takeException(), isNull);
      } finally {
        await t.pumpWidget(const SizedBox());
        container.dispose();
        await t.pump(const Duration(seconds: 2));
      }
    },
  );

  testWidgets('wall settings no longer offer ineffective card colours', (
    t,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await t.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const Scaffold(body: ThoughtWallAppearanceSheet()),
        ),
      ),
    );
    expect(find.text('Card colour'), findsNothing);
    expect(find.text('Sage'), findsNothing);
    expect(find.text('Spacing'), findsOneWidget);
    expect(find.text('Bubble'), findsOneWidget);
  });
}
