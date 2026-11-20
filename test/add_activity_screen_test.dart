import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:ascent/features/today/screens/add_activity_screen.dart';
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
          child: const AddActivityScreen(),
        ),
      ),
    );
  }

  testWidgets('AddActivityScreen creates a task and saves to database', (
    tester,
  ) async {
    await tester.pumpWidget(buildSubject());
    await tester.pumpAndSettle();

    expect(find.text('New Activity'), findsOneWidget);
    expect(find.text('What needs to be done?'), findsOneWidget);

    // Enter text
    await tester.enterText(
      find.byType(TextField).first,
      'Read Clean Code Chapter 4',
    );
    await tester.pumpAndSettle();

    // Tap "30m Focus"
    await tester.tap(find.text('30m Focus'));
    await tester.pumpAndSettle();

    // Tap "Create Activity"
    await tester.tap(find.text('Create Activity'));
    await tester.pumpAndSettle();

    // Verify task was inserted in database
    final tasks = await db.select(db.taskTable).get();
    expect(tasks.length, 1);
    expect(tasks.first.title, 'Read Clean Code Chapter 4');
    expect(tasks.first.estimatedMinutes, 30);
  });

  testWidgets('AddActivityScreen 320px width & 2.0x text scale immunity', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      buildSubject(size: const Size(320, 700), textScale: 2.0),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('New Activity'), findsOneWidget);
  });
}
