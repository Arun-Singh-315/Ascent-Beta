import 'package:ascent/shared/widgets/date_range_calendar.dart';
import 'package:ascent/app/theme/glass_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/features/thought_wall/thought_conversion_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Widget host(Widget child) => MaterialApp(
  theme: ThemeData.light().copyWith(extensions: const [AscentGlass.light]),
  home: Scaffold(body: SingleChildScrollView(child: child)),
);

void main() {
  testWidgets('Single-day calendar fits narrow dark UI with large text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData.dark().copyWith(extensions: const [AscentGlass.dark]),
        home: Scaffold(
          body: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(2)),
            child: SingleChildScrollView(
              child: DateRangeCalendar(
                start: DateTime(2026, 10, 15),
                end: DateTime(2026, 10, 15),
                today: DateTime(2026, 10, 16),
              ),
            ),
          ),
        ),
      ),
    );
    final endpoint = tester.widget<Text>(
      find.byKey(const ValueKey('calendar-day-2026-10-15')),
    );
    final outside = tester.widget<Text>(
      find.byKey(const ValueKey('calendar-day-2026-10-14')),
    );
    expect(endpoint.style!.decoration, TextDecoration.lineThrough);
    expect(outside.style!.decoration, isNull);
    expect(find.byTooltip('Next month'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Calendar marks elapsed dates, today and inclusive endpoints', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DateRangeCalendar(
          start: DateTime(2026, 10, 13),
          end: DateTime(2026, 10, 17),
          today: DateTime(2026, 10, 15, 12),
        ),
      ),
    );
    expect(find.text('Start · Oct 13, 2026'), findsOneWidget);
    expect(find.text('Finish · Oct 17, 2026'), findsOneWidget);
    final past = tester.widget<Text>(
      find.byKey(const ValueKey('calendar-day-2026-10-14')),
    );
    final today = tester.widget<Text>(
      find.byKey(const ValueKey('calendar-day-2026-10-15')),
    );
    expect(past.style!.decoration, TextDecoration.lineThrough);
    expect(today.style!.decoration, isNull);
    expect(find.byTooltip('Previous month'), findsNothing);
    expect(find.byTooltip('Next month'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Calendar navigates year boundaries and resets for a new range', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        DateRangeCalendar(
          start: DateTime(2026, 12, 30),
          end: DateTime(2027, 1, 2),
          today: DateTime(2026, 12, 30),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Next month'));
    await tester.pump();
    expect(find.text('January 2027'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    await tester.pumpWidget(
      host(
        DateRangeCalendar(
          start: DateTime(2028, 2, 28),
          end: DateTime(2028, 2, 29),
          today: DateTime(2028, 2, 28),
        ),
      ),
    );
    expect(find.text('February 2028'), findsOneWidget);
    expect(find.text('29'), findsOneWidget);
  });

  testWidgets(
    'Long grouped conversion keeps Cancel visible above keyboard without writing',
    (tester) async {
      tester.view.physicalSize = const Size(360, 640);
      tester.view.devicePixelRatio = 1;
      tester.view.viewInsets = const FakeViewPadding(bottom: 240);
      addTearDown(tester.view.reset);
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final notes = <Thought>[];
      for (var i = 0; i < 8; i++) {
        final id = await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'A long thought $i to convert into an action',
          ),
        );
        notes.add((await db.thoughtDao.getThoughtById(id))!);
      }
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    showThoughtConversion(context, db, notes, grouped: true),
                child: const Text('Open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open'));
      await tester.pumpAndSettle();
      expect(tester.getBottomLeft(find.text('Cancel')).dy, lessThan(400));
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Turn thoughts into action'), findsNothing);
      expect(await db.select(db.taskTable).get(), isEmpty);
      expect(await db.select(db.reminderTable).get(), isEmpty);
      expect(await db.select(db.thoughtTable).get(), hasLength(8));
      expect(tester.takeException(), isNull);
    },
  );
}
