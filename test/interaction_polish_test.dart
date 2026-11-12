import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/capture/quick_capture_sheet.dart';
import 'package:ascent/features/home/widgets/activity_composer.dart';
import 'package:ascent/features/home/widgets/activity_hub_card.dart';
import 'package:ascent/features/home/widgets/activity_row_item.dart';
import 'package:ascent/shared/widgets/ascent_press_feedback.dart';
import 'package:ascent/shared/widgets/ascent_sheet.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Tracker extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  late GlobalKey captureKey;
  late AppDatabase db;
  late SharedPreferences prefs;
  late ProviderContainer container;
  setUp(() async {
    captureKey = GlobalKey();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        timeTrackingProvider.overrideWith(_Tracker.new),
        todayActivitiesProvider.overrideWith((ref) => Stream.value([])),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> flush(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await t.pump(const Duration(milliseconds: 80));
    }
  }

  Widget app(
    Widget child, {
    double scale = 1,
    bool dark = false,
    bool reduce = false,
  }) => UncontrolledProviderScope(
    container: container,
    child: RepaintBoundary(
      key: captureKey,
      child: MaterialApp(
        theme: dark ? AscentTheme.dark() : AscentTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(scale),
            disableAnimations: reduce,
          ),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: child,
          ),
        ),
      ),
    ),
  );
  Future<void> snapshot(WidgetTester t, String name) async {
    if (!const bool.fromEnvironment('POLISH_SCREENSHOTS')) return;
    await t.runAsync(() async {
      final boundary =
          captureKey.currentContext!.findRenderObject()
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      final path = File('build/qa/interaction-polish/$name.png');
      await path.parent.create(recursive: true);
      await path.writeAsBytes(data!.buffer.asUint8List());
      image.dispose();
    });
  }

  TodayActivityItem row({int? task, bool standing = false}) =>
      TodayActivityItem(
        id: 'sample',
        title: 'Review the proposal and prepare the final notes',
        sourceType: 'task',
        status: TodayActivityStatus.notStarted,
        elapsedSecondsToday: 0,
        categoryTag: 'Task',
        linkedTaskId: task,
        isDailyStanding: standing,
      );

  testWidgets('Press feedback releases on scroll and never triggers a tap', (
    t,
  ) async {
    var taps = 0;
    await t.pumpWidget(
      app(
        AscentPressFeedback(
          child: Material(
            child: InkWell(
              onTap: () => taps++,
              child: const SizedBox(
                width: 220,
                height: 160,
                child: Text('Open card'),
              ),
            ),
          ),
        ),
      ),
    );
    final gesture = await t.startGesture(t.getCenter(find.text('Open card')));
    await t.pump(const Duration(milliseconds: 120));
    await gesture.moveBy(const Offset(0, 80));
    await gesture.up();
    await t.pumpAndSettle();
    expect(taps, 0);
    expect(t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    expect(t.takeException(), isNull);
  });

  testWidgets('Reduced motion preserves touch actions without scaling', (
    t,
  ) async {
    var taps = 0;
    await t.pumpWidget(
      app(
        AscentPressFeedback(
          child: Material(
            child: InkWell(
              onTap: () => taps++,
              child: const SizedBox(
                width: 220,
                height: 100,
                child: Text('Open card'),
              ),
            ),
          ),
        ),
        reduce: true,
      ),
    );
    final gesture = await t.startGesture(t.getCenter(find.text('Open card')));
    await t.pump(const Duration(milliseconds: 120));
    expect(t.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
    await gesture.up();
    await t.pumpAndSettle();
    expect(taps, 1);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'Task details sheet fits 320px at 2x and cancels without writes dark=$dark',
      (t) async {
        t.view.physicalSize = const Size(320, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        await t.pumpWidget(
          app(
            ActivityRowItem(
              activity: row(standing: true),
              compact: true,
              ground: true,
            ),
            scale: 2,
            dark: dark,
          ),
        );
        await t.tap(
          find.text('Review the proposal and prepare the final notes'),
        );
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('activity_detail_sheet')),
          findsOneWidget,
        );
        expect(find.byType(AscentSheetHandle), findsOneWidget);
        expect(t.takeException(), isNull);
        await snapshot(t, 'details-${dark ? 'dark' : 'light'}-large-text');
        await t.tapAt(const Offset(8, 8));
        await t.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('activity_detail_sheet')),
          findsNothing,
        );
        expect(await t.runAsync(() => db.select(db.taskTable).get()), isEmpty);
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'Empty suggestions preserve an existing inline draft and never create a task on cancel',
    (t) async {
      await prefs.setString(
        'ascent_note_draft_home_activity',
        'Keep this draft',
      );
      await t.pumpWidget(app(const ActivityHubCard()));
      await flush(t);
      await t.ensureVisible(find.byKey(const ValueKey('starter_add_timer')));
      await snapshot(t, 'empty-suggestions');
      await t.tap(find.byKey(const ValueKey('starter_add_timer')));
      await t.pumpAndSettle();
      expect(find.byType(AscentSheetHandle), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tapAt(const Offset(8, 8));
      await t.pumpAndSettle();
      final field = t.widget<TextField>(
        find
            .descendant(
              of: find.byType(ActivityComposer),
              matching: find.byType(TextField),
            )
            .first,
      );
      expect(field.controller!.text, 'Keep this draft');
      expect(
        prefs.getString('ascent_note_draft_home_activity'),
        'Keep this draft',
      );
      expect(await t.runAsync(() => db.select(db.taskTable).get()), isEmpty);
      expect(t.takeException(), isNull);
    },
  );

  testWidgets('Rapid completion is safe and Undo restores the original task', (
    t,
  ) async {
    final id = (await t.runAsync(
      () => db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Original task',
          plannedDate: Value(DateTime.now()),
        ),
      ),
    ))!;
    await t.pumpWidget(
      app(
        ActivityRowItem(activity: row(task: id), compact: true, ground: true),
      ),
    );
    final target = find.byKey(const ValueKey('activity_action_sample'));
    await t.tap(target);
    await t.tap(target);
    await flush(t);
    expect(
      (await t.runAsync(() => db.taskDao.getTaskById(id)))!.actualCompletedDate,
      isNotNull,
    );
    expect(find.text('Undo'), findsOneWidget);
    await t.tap(find.text('Undo'));
    await flush(t);
    final restored = (await t.runAsync(() => db.taskDao.getTaskById(id)))!;
    expect(restored.actualCompletedDate, isNull);
    expect(restored.title, 'Original task');
    expect(await t.runAsync(() => db.select(db.taskTable).get()), hasLength(1));
    expect(t.takeException(), isNull);
  });

  testWidgets(
    'Press feedback keeps both swipe directions safe; archive cancellation preserves task',
    (t) async {
      final id = (await t.runAsync(
        () => db.taskDao.insertTask(
          TaskTableCompanion.insert(title: 'Keep task'),
        ),
      ))!;
      await t.pumpWidget(
        app(
          ActivityRowItem(activity: row(task: id), compact: true, ground: true),
        ),
      );
      final tile = find.byKey(const ValueKey('activity_dismiss_sample'));
      await t.drag(tile, const Offset(500, 0));
      await flush(t);
      expect(find.text('Keep'), findsNothing);
      expect(
        (await t.runAsync(() => db.taskDao.getTaskById(id)))!.isArchived,
        isFalse,
      );
      await t.drag(tile, const Offset(-600, 0));
      await flush(t);
      expect(find.text('Keep'), findsOneWidget);
      await t.tap(find.text('Keep'));
      await flush(t);
      expect(
        (await t.runAsync(() => db.taskDao.getTaskById(id)))!.isArchived,
        isFalse,
      );
      expect(t.takeException(), isNull);
    },
  );

  testWidgets(
    'Quick capture uses one shared handle and preserves cancellation',
    (t) async {
      await t.pumpWidget(
        app(
          Builder(
            builder: (context) => TextButton(
              onPressed: () => showQuickCapture(context),
              child: const Text('Capture'),
            ),
          ),
        ),
      );
      await t.tap(find.text('Capture'));
      await flush(t);
      expect(find.byType(AscentSheetHandle), findsOneWidget);
      expect(t.takeException(), isNull);
      await t.tap(find.byTooltip('Close capture'));
      await flush(t);
      expect(find.byType(QuickCaptureSheet), findsNothing);
      expect(await t.runAsync(() => db.select(db.taskTable).get()), isEmpty);
    },
  );
}
