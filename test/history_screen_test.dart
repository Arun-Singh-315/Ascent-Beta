import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/history/history_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/history/history_screen.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:ascent/features/today/things_hub_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Time extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  late AppDatabase db;
  late SharedPreferences prefs;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() => db.close());
  final now = DateTime.now();
  HistoryEvent event(
    String id,
    String title, {
    String module = 'tasks',
    bool private = false,
  }) => HistoryEvent(
    id: id,
    module: module,
    entityId: id,
    action: 'completed',
    title: title,
    detail: 'A small step, kept in your history.',
    occurredAt: now,
    isPrivate: private,
    imported: false,
  );
  Widget app(
    Widget screen, {
    List<HistoryEvent>? entries,
    bool dark = false,
    double scale = 1,
    GlobalKey? capture,
  }) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      timeTrackingProvider.overrideWith(_Time.new),
      sharedPreferencesProvider.overrideWithValue(prefs),
      allPromisesStreamProvider.overrideWith((ref) => Stream.value([])),
      if (entries != null)
        historyEventsProvider.overrideWith((ref) => Stream.value(entries)),
      todayActivitiesProvider.overrideWith(
        (ref) => Stream.value([
          TodayActivityItem(
            id: 'task_1',
            title: 'Finish proposal',
            kind: ActivityKind.todo,
            status: TodayActivityStatus.notStarted,
            sourceType: 'task',
            categoryTag: 'Task',
            elapsedSecondsToday: 0,
            priority: 'high',
            linkedTaskId: 1,
          ),
          TodayActivityItem(
            id: 'session_2',
            title: 'Read a chapter',
            kind: ActivityKind.duration,
            status: TodayActivityStatus.inProgress,
            sourceType: 'session',
            categoryTag: 'Focus',
            elapsedSecondsToday: 300,
          ),
        ]),
      ),
    ],
    child: MaterialApp(
      theme: dark ? AscentTheme.dark() : AscentTheme.light(),
      home: Builder(
        builder: (ctx) => MediaQuery(
          data: MediaQuery.of(
            ctx,
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: RepaintBoundary(key: capture, child: screen),
        ),
      ),
    ),
  );
  Future<void> settle(WidgetTester t) async {
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
  }

  testWidgets('History searches surviving snapshots and opens details', (
    t,
  ) async {
    await t.pumpWidget(
      app(
        const HistoryScreen(),
        entries: [
          event('1', 'Finish proposal'),
          event('2', 'Outdoor walk', module: 'walks'),
        ],
      ),
    );
    await settle(t);
    expect(find.text('Finish proposal'), findsOneWidget);
    expect(find.text('Outdoor walk'), findsOneWidget);
    await t.enterText(find.byKey(const ValueKey('history_search')), 'proposal');
    await settle(t);
    expect(find.text('Outdoor walk'), findsNothing);
    await t.tap(find.text('Finish proposal'));
    await settle(t);
    expect(find.text('A small step, kept in your history.'), findsOneWidget);
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    await settle(t);
  });
  testWidgets(
    'Privacy is applied before search, counts and timeline rendering',
    (t) async {
      await t.runAsync(() async {
        await db
            .into(db.historyEventTable)
            .insert(
              event(
                'private',
                'Private title',
                private: true,
              ).toCompanion(true),
            );
        await db
            .into(db.historyEventTable)
            .insert(event('public', 'Public title').toCompanion(true));
      });
      await t.pumpWidget(app(const HistoryScreen()));
      for (var i = 0; i < 5; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await settle(t);
      }
      expect(find.text('Public title'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Text && w.data == 'Private title'),
        findsNothing,
      );
      await t.enterText(
        find.byKey(const ValueKey('history_search')),
        'Private title',
      );
      await settle(t);
      expect(
        find.descendant(
          of: find.byKey(const ValueKey('history_timeline')),
          matching: find.text('Private title'),
        ),
        findsNothing,
      );
      expect(
        find.text(
          'No history in this view. Try another activity or date range.',
        ),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
      await settle(t);
      await settle(t);
    },
  );
  testWidgets(
    'History and Things hub fit phones, large text, light and dark themes',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      for (final width in [320.0, 390.0]) {
        for (final dark in [false, true]) {
          for (final scale in [1.0, 2.0]) {
            for (final history in [true, false]) {
              t.view.physicalSize = Size(width, 844);
              await t.pumpWidget(const SizedBox());
              await settle(t);
              await settle(t);
              final key = GlobalKey();
              await t.pumpWidget(
                app(
                  history ? const HistoryScreen() : const ThingsHubScreen(),
                  entries: [
                    event('1', 'Finish proposal'),
                    event('2', 'Outdoor walk', module: 'walks'),
                  ],
                  dark: dark,
                  scale: scale,
                  capture: key,
                ),
              );
              await settle(t);
              expect(t.takeException(), isNull);
              if (width == 390 && scale == 1) {
                await t.runAsync(() async {
                  final img =
                      await (key.currentContext!.findRenderObject()
                              as RenderRepaintBoundary)
                          .toImage(pixelRatio: 2);
                  final data = await img.toByteData(
                    format: ui.ImageByteFormat.png,
                  );
                  await File(
                    '/tmp/ascent-${history ? 'history' : 'things'}-${dark ? 'dark' : 'light'}.png',
                  ).writeAsBytes(data!.buffer.asUint8List());
                  img.dispose();
                });
              }
            }
          }
        }
      }
      await t.pumpWidget(const SizedBox());
      await settle(t);
      await settle(t);
    },
  );
}
