import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/notifications/reminder_alert_sync.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/plans/planning_providers.dart';
import 'package:ascent/features/plans/widgets/plan_collection_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late ProviderContainer container;
  late SharedPreferences prefs;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        planningAlertSyncProvider.overrideWith(
          (ref) => ReminderAlertSync(
            db,
            enabled: () async => true,
            reset: () async => true,
            cancel: (_) async => true,
            schedule: (_) async => true,
          ),
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
  });
  Future<void> mount(WidgetTester t) async {
    t.view.physicalSize = const Size(390, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const Scaffold(
            body: SingleChildScrollView(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: ThoughtWallHomePreview(),
              ),
            ),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  Future<void> flush(WidgetTester t) async {
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pumpAndSettle();
  }

  testWidgets('ordinary capture remains a note without creating activities', (
    t,
  ) async {
    await mount(t);
    await t.enterText(find.byType(TextField), 'A quiet thought');
    await t.pump();
    await t.tap(find.byTooltip('Send capture'));
    await flush(t);
    expect(await db.select(db.thoughtTable).get(), hasLength(1));
    expect(await db.select(db.taskTable).get(), isEmpty);
    expect(find.text('Plan'), findsOneWidget);
    await t.pump(const Duration(seconds: 9));
    await t.pumpAndSettle();
    expect(find.text('Plan'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('capture list reviews independent rows and saves a named plan', (
    t,
  ) async {
    await mount(t);
    await t.enterText(find.byType(TextField), 'list:\n-- Java\n--> RAG');
    await t.pump();
    await t.tap(find.byTooltip('Send capture'));
    await flush(t);
    await t.tap(find.text('Plan'));
    await t.pumpAndSettle();
    expect(find.byType(PlanCollectionEditor), findsOneWidget);
    expect(await db.select(db.taskTable).get(), isEmpty);
    final name = find.byKey(const ValueKey('plan_name_field'));
    await t.enterText(name, 'Interview preparation');
    await t.tap(find.widgetWithText(FilledButton, 'Save plan'));
    await flush(t);
    expect(await db.select(db.planCollectionTable).get(), hasLength(1));
    expect(await db.select(db.planCollectionItemTable).get(), hasLength(2));
    expect(await db.select(db.taskTable).get(), hasLength(2));
    expect(await db.select(db.reminderTable).get(), isEmpty);
    expect(find.text('Up next'), findsNothing);
    expect(
      (await db.select(db.thoughtTable).get()).single.content,
      'list:\n-- Java\n--> RAG',
    );
    await t.pumpWidget(const SizedBox());
  });
  testWidgets('closing and reopening restores unsaved plan rows', (t) async {
    await mount(t);
    await t.enterText(find.byType(TextField), 'Java');
    await t.pump();
    await t.tap(find.byTooltip('Send capture'));
    await flush(t);
    await t.tap(find.text('Plan'));
    await t.pumpAndSettle();
    await t.enterText(
      find.byKey(const ValueKey('plan_name_field')),
      'My saved draft',
    );
    await flush(t);
    await t.tap(find.byTooltip('Close'));
    await t.pumpAndSettle();
    await t.tap(find.text('Review & schedule'));
    await t.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(PlanCollectionEditor),
        matching: find.text('My saved draft'),
      ),
      findsOneWidget,
    );
    expect(await db.select(db.planCollectionTable).get(), isEmpty);
    await t.pumpWidget(const SizedBox());
  });
}
