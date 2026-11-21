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

  Future<AppDatabase> pump(WidgetTester tester, {int plans = 0}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    if (plans > 0) {
      await tester.runAsync(() async {
        final now = DateTime.now();
        final service = PlanCollectionService(db, clock: () => now);
        for (final t in planTemplates.take(plans)) {
          await service.save(
            title: t.title,
            items: draftsFor(t.steps, start: now, weeks: t.weeks, now: now),
            requestId: 'layout_${t.id}',
          );
        }
      });
    }
    tester.view.physicalSize = const Size(390, 1400);
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
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 30)),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
    return db;
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  testWidgets('with plans, yours come first and starting follows', (
    tester,
  ) async {
    await pump(tester, plans: 2);
    final yours = tester.getTopLeft(find.text('Your plans')).dy;
    final another = tester.getTopLeft(find.text('Start another plan')).dy;
    expect(yours, lessThan(another));
    expect(find.text('Start a plan'), findsNothing);
    expect(
      tester.getTopLeft(find.byKey(const ValueKey('plans_status'))).dy,
      lessThan(another),
    );
    await unmount(tester);
  });

  testWidgets('with none, starting leads and the empty note does not repeat '
      'the templates', (tester) async {
    await pump(tester);
    expect(find.text('Start a plan'), findsOneWidget);
    expect(find.text('Your plans'), findsNothing);
    expect(find.byKey(const ValueKey('plans_status')), findsNothing);
    expect(find.text('Plan anything, one tap to start'), findsOneWidget);
    // The template carousel is the only place each template appears.
    expect(find.text(planTemplates.first.title), findsOneWidget);
    await unmount(tester);
  });
}
