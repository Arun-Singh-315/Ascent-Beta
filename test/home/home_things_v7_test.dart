import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/features/feature_registry.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/model/home_things.dart';
import 'package:ascent/features/home/v7/home_things_v7.dart';
import 'package:ascent/features/today/models/things_sections.dart';
import 'package:ascent/features/today/things_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _AllUnlocked extends UnlockedFeaturesNotifier {
  @override
  Set<AscentFeature> build() => AscentFeature.values.toSet();
}

DateTime _at(int h) => DateTime(2026, 11, 28, h);

TodayActivityItem _item(
  String id, {
  int? hour,
  bool done = false,
  bool overdue = false,
  String source = 'task',
  int? taskId,
}) => TodayActivityItem(
  id: id,
  title: id,
  sourceType: source,
  status: done ? TodayActivityStatus.done : TodayActivityStatus.notStarted,
  elapsedSecondsToday: 0,
  categoryTag: 'general',
  isOverdue: overdue,
  linkedTaskId: taskId,
  plannedDate: overdue ? _at(0).subtract(const Duration(days: 1)) : _at(0),
  scheduledTime: hour == null ? null : _at(hour),
);

final _items = [
  _item('Vitamin', hour: 8, source: 'medicine'),
  _item('Standup', hour: 10, done: true),
  _item('Gym', hour: 7),
  _item('Pitch deck', hour: 15),
  _item('Call mom', hour: 18, done: true),
  _item('Invoice', overdue: true, taskId: 9),
];

void main() {
  group('buildHomeThingsToday', () {
    test('splits by part of day, keeps done, leaves out medicine', () {
      final t = buildHomeThingsToday(_items);
      expect(t.parts.map((p) => p.$1), [
        DayPart.morning,
        DayPart.afternoon,
        DayPart.evening,
      ]);
      expect(t.parts.first.$2.map((a) => a.title), ['Gym', 'Standup']);
      expect(t.done, 2);
      expect(t.total, 4);
      expect(t.overdue.single.title, 'Invoice');
      expect(t.movableOverdue, [9]);
    });

    test('opens the current part when it has something left', () {
      final t = buildHomeThingsToday(_items);
      expect(defaultOpenPart(t.parts, _at(14)), DayPart.afternoon);
      // Evening is all done, so the first part with work left opens.
      expect(defaultOpenPart(t.parts, _at(20)), DayPart.morning);
      expect(defaultOpenPart(const [], _at(9)), isNull);
    });

    test('handles 100+ things', () {
      final many = [
        for (var i = 0; i < 120; i++) _item('T$i', hour: 6 + i % 17),
      ];
      final t = buildHomeThingsToday(many);
      expect(t.total, 120);
      expect(t.parts.fold<int>(0, (n, p) => n + p.$2.length), 120);
    });
  });

  Future<void> pump(
    WidgetTester tester,
    List<TodayActivityItem> items, {
    bool dark = false,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          unlockedFeaturesProvider.overrideWith(_AllUnlocked.new),
          todayActivitiesProvider.overrideWith((ref) => Stream.value(items)),
          upcomingThingsProvider.overrideWith((ref) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: dark ? AscentTheme.dark() : AscentTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(child: HomeThingsSection()),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
  }

  testWidgets('shows count, overdue line and day groups', (tester) async {
    await pump(tester, _items);
    expect(find.text('Things'), findsOneWidget);
    expect(find.text('2 of 4'), findsOneWidget);
    expect(find.text('1 overdue from earlier'), findsOneWidget);
    expect(find.text('Move to today'), findsOneWidget);
    expect(find.text('Morning'), findsOneWidget);
    expect(find.text('Evening'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a group opens and closes', (tester) async {
    await pump(tester, _items, dark: true);
    final evening = find.byKey(const ValueKey('home_thing_Call mom'));
    final wasOpen = evening.evaluate().isNotEmpty;
    await tester.tap(find.text('Evening'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(evening.evaluate().isNotEmpty, !wasOpen);
  });

  testWidgets('select mode shows the bulk bar', (tester) async {
    await pump(tester, _items);
    await tester.tap(find.byKey(const ValueKey('home_things_select')));
    await tester.pump(const Duration(milliseconds: 300));
    expect(
      find.byKey(const ValueKey('home_things_select_bar')),
      findsOneWidget,
    );
    expect(find.text('0 selected'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('empty day explains itself', (tester) async {
    await pump(tester, const []);
    expect(find.byKey(const ValueKey('home_things_empty')), findsOneWidget);
  });

  testWidgets('no overflow at 320 px and text scale 2', (tester) async {
    tester.view.physicalSize = const Size(320, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pump(tester, [
      ..._items,
      for (var i = 0; i < 100; i++) _item('Thing number $i', hour: 9),
    ]);
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 2400),
          textScaler: TextScaler.linear(2),
        ),
        child: tester.widget(find.byType(ProviderScope)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
  });
}
