import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascent/features/plans/screens/plan_creator_screen.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:drift/native.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget buildSubject({
    double textScale = 1.0,
    Size size = const Size(390, 844),
  }) {
    return ProviderScope(
      overrides: [databaseProvider.overrideWithValue(db)],
      child: MaterialApp(
        theme: ThemeData(
          brightness: Brightness.light,
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFBF5A36)),
        ),
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: const PlanCreatorScreen(initialSpan: '3d', initialTasks: []),
        ),
      ),
    );
  }

  testWidgets('PlanCreatorScreen 4-step tap-first flow works seamlessly', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    // ── STEP 1: SPAN ──
    expect(find.text('How long is this plan for?'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('3 days'), findsOneWidget);
    expect(find.text('This week'), findsOneWidget);
    expect(find.text('2 weeks'), findsOneWidget);
    expect(find.text('Repeating'), findsOneWidget);

    // Tap "This week"
    await tester.tap(find.text('This week'));
    await tester.pumpAndSettle();

    // Tap "Next"
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // ── STEP 2: TASKS ──
    expect(find.text('What do you want to do?'), findsOneWidget);
    expect(find.text('Add a task'), findsOneWidget);
    expect(find.text('Your tasks'), findsOneWidget);

    // Tap a suggestion chip (e.g. 'Study' or 'Meditate')
    final studyChip = find.text('Study');
    if (studyChip.evaluate().isNotEmpty) {
      await tester.tap(studyChip);
      await tester.pumpAndSettle();
    }

    // Type a custom task and tap the add button
    await tester.enterText(find.byType(TextField).first, 'Build rocket engine');
    await tester.tap(find.byIcon(Icons.add_circle_rounded));
    await tester.pumpAndSettle();

    expect(find.text('Build rocket engine'), findsOneWidget);

    // Tap "Next"
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // ── STEP 3: PLACE ──
    expect(find.text('When will you do each?'), findsOneWidget);
    expect(find.text('Spread evenly'), findsOneWidget);

    // Tap "Spread evenly"
    await tester.tap(find.text('Spread evenly'));
    await tester.pumpAndSettle();

    // Tap "Next"
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();

    // ── STEP 4: CONFIRM ──
    expect(find.text('Looks good?'), findsOneWidget);
    expect(find.text('Reminders'), findsOneWidget);
    expect(find.text('Morning nudge'), findsOneWidget);
    expect(find.text('Create plan'), findsOneWidget);
  });

  testWidgets('PlanCreatorScreen 320px width & 2.0x text scale immunity', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildSubject(size: const Size(320, 700), textScale: 2.0),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('How long is this plan for?'), findsOneWidget);
  });
}
