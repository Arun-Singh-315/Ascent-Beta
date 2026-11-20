import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/services/plan_collection_service.dart';
import 'package:ascent/features/plans/plan_templates.dart';
import 'package:ascent/features/plans/plans_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  group('template maths', () {
    // Saturday 21 Nov 2026, 10:00.
    final now = DateTime(2026, 11, 21, 10);
    const study = PlanStep(title: 'Study', time: TimeOfDay(hour: 7, minute: 0));
    const revise = PlanStep(
      title: 'Revise',
      time: TimeOfDay(hour: 21, minute: 0),
      repeat: PlanRepeat.weekdays,
    );

    test('a time already passed today starts tomorrow', () {
      expect(firstSession(study, now, now), DateTime(2026, 11, 22, 7));
    });

    test('weekday steps skip the weekend', () {
      expect(firstSession(revise, now, now), DateTime(2026, 11, 23, 21));
    });

    test('drafts run the chosen weeks and drop switched-off steps', () {
      final drafts = draftsFor(
        [study, revise.copyWith(enabled: false)],
        start: now,
        weeks: 4,
        now: now,
      );
      expect(drafts, hasLength(1));
      expect(drafts.single.recurrence, 'daily');
      expect(drafts.single.endDate, DateTime(2026, 12, 18));
    });

    test('never beyond the 90-day limit', () {
      final d = draftsFor([study], start: now, weeks: 52, now: now).single;
      expect(d.endDate!.difference(d.at!).inDays, lessThanOrEqualTo(90));
    });

    test('sessions per week', () {
      expect(sessionsPerWeek([study, revise]), 12);
    });

    test('every template saves as a valid plan', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final service = PlanCollectionService(db, clock: () => now);
      for (final t in planTemplates) {
        final id = await service.save(
          title: t.title,
          items: draftsFor(t.steps, start: now, weeks: t.weeks, now: now),
          requestId: 'test_${t.id}',
        );
        final items = await service.watchItems(id).first;
        expect(items, hasLength(t.steps.length), reason: t.id);
        expect(items.every((i) => i.recurring), isTrue, reason: t.id);
      }
    });
  });

  testWidgets('a template starts a real plan in two taps', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const PlansScreen(),
        ),
      ),
    );
    Future<void> settle() async {
      for (var i = 0; i < 8; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 150));
      }
    }

    await settle();
    expect(find.text('Start a plan'), findsOneWidget);
    expect(find.text('Plan anything, one tap to start'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan_template_study')));
    await settle();
    expect(find.byKey(const ValueKey('plan_template_sheet')), findsOneWidget);
    expect(find.textContaining('sessions a week'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('plan_template_start')));
    await settle();

    final plans = await tester.runAsync(
      () => db.select(db.planCollectionTable).get(),
    );
    expect(plans, hasLength(1));
    expect(plans!.single.title, 'Study routine');
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  });

  for (final dark in [false, true]) {
    testWidgets('Plans fits 320 px at 2.0x text (dark=$dark)', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp(
            theme: dark ? AscentTheme.dark() : AscentTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: const PlansScreen(),
          ),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 30)),
        );
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });
  }
}
