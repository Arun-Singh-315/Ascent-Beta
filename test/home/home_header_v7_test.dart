import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/model/home_day_provider.dart';
import 'package:ascent/features/home/v7/home_header_v7.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

final _now = DateTime(2026, 11, 28, 10);

TodayActivityItem _item(String id, {bool done = false, DateTime? at}) =>
    TodayActivityItem(
      id: id,
      title: id,
      sourceType: 'task',
      status: done ? TodayActivityStatus.done : TodayActivityStatus.notStarted,
      elapsedSecondsToday: 0,
      categoryTag: 'general',
      plannedDate: DateTime(2026, 11, 28),
      scheduledTime: at,
    );

HomeDay _day({int done = 0, int open = 0, int water = 0, DateTime? nextAt}) =>
    buildHomeDay(
      now: _now,
      activities: [
        for (var i = 0; i < done; i++) _item('Done $i', done: true),
        for (var i = 0; i < open; i++) _item('Open $i'),
        if (nextAt != null) _item('Standup', at: nextAt),
      ],
      reminders: const [],
      hasLiveSession: false,
      waterMl: water,
      waterGoalMl: 2500,
      focusMinutes: 0,
      focusGoalMinutes: 60,
    );

class _IdleTracking extends TimeTrackingNotifier {
  @override
  TimeTrackingState build() => const TimeTrackingState();
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  required HomeDay day,
  bool dark = false,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        homeDayProvider.overrideWithValue(day),
        homeMinuteProvider.overrideWith((ref) => Stream.value(_now)),
        homeYesterdayProvider.overrideWith(
          (ref) async => const YesterdayStats(
            thingsDone: 1,
            waterMl: 500,
            focusMinutes: 0,
          ),
        ),
        timeTrackingProvider.overrideWith(_IdleTracking.new),
      ],
      child: MaterialApp(
        theme: dark ? AscentTheme.dark() : AscentTheme.light(),
        home: Scaffold(body: SingleChildScrollView(child: child)),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('masthead greets by name and states the share done', (
    tester,
  ) async {
    await _pump(
      tester,
      const HomeMasthead(name: 'arun'),
      day: _day(done: 3, open: 2),
    );
    final text = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .join('\n');
    expect(text, contains('Good morning, Arun.'));
    expect(text, contains('60% of today is done.'));
    expect(tester.takeException(), isNull);
  });

  testWidgets('summary panel shows three lines, deltas and the insight', (
    tester,
  ) async {
    await _pump(
      tester,
      const HomeSummaryPanel(),
      day: _day(done: 3, open: 2, water: 900),
      dark: true,
    );
    expect(find.text('Things done'), findsOneWidget);
    expect(find.text('Water'), findsOneWidget);
    expect(find.text('Focus'), findsOneWidget);
    expect(find.text('+2'), findsOneWidget);
    final texts = tester
        .widgetList<RichText>(find.byType(RichText))
        .map((r) => r.text.toPlainText())
        .toList();
    // Empty focus shows a dash, never 0.
    expect(texts.any((t) => t.startsWith('–')), isTrue);
    expect(texts.any((t) => t.startsWith('0 min')), isFalse);
    final insight = texts.firstWhere((t) => t.contains('ahead'));
    expect(insight, contains('2 tasks ahead'));
  });

  testWidgets('compact bar shows progress and switches tabs', (tester) async {
    int? tapped;
    await _pump(
      tester,
      HomeCompactBar(
        tabs: const ['Now', 'Things', 'Thoughts', 'Life'],
        current: 1,
        onTab: (i) => tapped = i,
      ),
      day: _day(done: 1, open: 3),
    );
    expect(find.text('Today'), findsOneWidget);
    expect(find.textContaining('1 of 4'), findsOneWidget);
    await tester.tap(find.text('Life'));
    expect(tapped, 3);
  });

  testWidgets('live pill counts down to the next thing within 3 hours', (
    tester,
  ) async {
    await _pump(
      tester,
      const HomeLivePill(),
      day: _day(nextAt: _now.add(const Duration(minutes: 42))),
    );
    expect(find.byKey(const ValueKey('home_live_pill')), findsOneWidget);
    expect(find.text('in 42 min'), findsOneWidget);
  });

  testWidgets('live pill stays hidden when nothing is close', (tester) async {
    await _pump(
      tester,
      const HomeLivePill(),
      day: _day(nextAt: _now.add(const Duration(hours: 5))),
    );
    expect(find.byKey(const ValueKey('home_live_pill')), findsNothing);
  });

  testWidgets('header survives 320 px at text scale 2', (tester) async {
    tester.view.physicalSize = const Size(320, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      MediaQuery(
        data: const MediaQueryData(
          size: Size(320, 1400),
          textScaler: TextScaler.linear(2),
        ),
        child: const Column(
          children: [
            HomeMasthead(name: 'Arun'),
            HomeSummaryPanel(),
          ],
        ),
      ),
      day: _day(done: 3, open: 2, water: 900),
    );
    expect(tester.takeException(), isNull);
  });
}
