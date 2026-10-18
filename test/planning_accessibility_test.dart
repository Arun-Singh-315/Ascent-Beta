import 'dart:io';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/reminder_alert_sync.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/services/plan_collection_service.dart';
import 'package:ascent/features/plans/planning_providers.dart';
import 'package:ascent/features/plans/plans_screen.dart';
import 'package:ascent/features/plans/widgets/plan_collection_detail.dart';
import 'package:ascent/features/plans/widgets/plan_collection_editor.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;
  late ProviderContainer container;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
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
  Future<void> mount(
    WidgetTester t,
    Widget child,
    ThemeData theme, {
    double width = 320,
    double scale = 2,
    GlobalKey? capture,
  }) async {
    t.view.physicalSize = Size(width, 844);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.resetPhysicalSize);
    addTearDown(t.view.resetDevicePixelRatio);
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: theme,
          builder: (ctx, child) => MediaQuery(
            data: MediaQuery.of(
              ctx,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: Scaffold(
            body: RepaintBoundary(key: capture, child: Material(color: theme.scaffoldBackgroundColor, child: child)),
          ),
        ),
      ),
    );
    await t.pumpAndSettle();
  }

  for (final theme in [
    ('light', AscentTheme.light()),
    ('dark', AscentTheme.dark()),
    ('frozen', AscentTheme.light(preset: DayThemePreset.nordicSky)),
  ]) {
    testWidgets('editor and item settings fit 320px at 2x in ${theme.$1}', (
      t,
    ) async {
      await mount(
        t,
        const PlanCollectionEditor(
          initialText:
              'list:\n-- Application based preparation\n--> Spring and Java lecture\n-- RAG practice',
        ),
        theme.$2,
      );
      expect(t.takeException(), isNull);
      final details = find.text('Time & details');
      for (var n = 0; n < 12 && details.hitTestable().evaluate().isEmpty; n++) {
        await t.drag(find.byType(ListView), const Offset(0, -160));
        await t.pumpAndSettle();
      }
      await t.tap(details.hitTestable().first);
      await t.pumpAndSettle();
      expect(find.text('Item details'), findsOneWidget);
      expect(t.takeException(), isNull);
      // Keyboard open must leave a scrollable settings form.
      await t.enterText(
        find.widgetWithText(TextField, 'Notes'),
        'Supporting notes',
      );
      await t.pump();
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
    testWidgets('detail and board fit 100 items at 320px and 2x in ${theme.$1}', (
      t,
    ) async {
      final service = container.read(planCollectionServiceProvider);
      final id = await service.save(
        title: 'Interview preparation with a long readable title',
        description: 'Original list retained for reference.',
        requestId: theme.$1,
        items: List.generate(
          100,
          (i) => PlanItemDraft(
            title:
                'Item $i: review application architecture and complete practice',
          ),
        ),
      );
      await mount(t, PlanCollectionDetail(id: id), theme.$2);
      expect(t.takeException(), isNull);
      await t.drag(find.byType(CustomScrollView), const Offset(0, -600));
      await t.pumpAndSettle();
      expect(find.byType(Checkbox), findsWidgets);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      await mount(t, const PlansScreen(), theme.$2);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
    });
  }
  testWidgets(
    'defaults preview schedules each row and save creates independent reminders',
    (t) async {
      await mount(
        t,
        const PlanCollectionEditor(initialText: '-- Java\n-- RAG'),
        AscentTheme.light(),
        width: 390,
        scale: 1,
      );
      await t.enterText(
        find.widgetWithText(TextField, 'Plan name'),
        'Study plan',
      );

      final defaults = find.text('Use schedule defaults');
      for (
        var n = 0;
        n < 12 && defaults.hitTestable().evaluate().isEmpty;
        n++
      ) {
        await t.drag(find.byType(ListView), const Offset(0, -160));
        await t.pumpAndSettle();
      }
      await t.tap(defaults.hitTestable());
      await t.pumpAndSettle();

      expect(find.text('Schedule defaults'), findsOneWidget);
      await t.tap(find.text('Preview schedule'));
      await t.pumpAndSettle();

      final summary = find.textContaining('2 scheduled · 2 reminders');
      for (var n = 0; n < 12 && summary.hitTestable().evaluate().isEmpty; n++) {
        await t.drag(find.byType(ListView), const Offset(0, -160));
        await t.pumpAndSettle();
      }
      expect(find.textContaining('2 scheduled · 2 reminders'), findsOneWidget);

      await t.tap(find.widgetWithText(FilledButton, 'Save plan'));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await t.pumpAndSettle();

      expect(await db.select(db.planCollectionItemTable).get(), hasLength(2));

      final alerts = await db.select(db.reminderTable).get();
      expect(alerts, hasLength(2));
      expect(
        alerts[1].scheduledAt.difference(alerts[0].scheduledAt).inMinutes,
        30,
      );
      await t.pumpWidget(const SizedBox());
    },
  );
  testWidgets('render planning detail for visual review', (t) async {
    final now = DateTime.now();
    final service = container.read(planCollectionServiceProvider);
    final id = await service.save(
      title: 'Interview preparation',
      description: 'A clear plan for the next step in your career.',
      requestId: 'preview',
      items: [
        const PlanItemDraft(title: 'Application-based preparation'),
        PlanItemDraft(
          title: 'Spring & Java lecture',
          at: DateTime(now.year, now.month, now.day + 1, 10),
        ),
        const PlanItemDraft(
          title: 'RAG practice',
          notes: 'Review retrieval, indexing and evaluation.',
        ),
        const PlanItemDraft(title: 'Code practice'),
      ],
    );
    final items = (await t.runAsync(() => service.watchItems(id).first))!;
    await t.runAsync(() => service.complete(items.first, true));
    final key = GlobalKey();
    await mount(
      t,
      PlanCollectionDetail(id: id),
      AscentTheme.light(preset: DayThemePreset.nordicSky),
      width: 390,
      scale: 1,
      capture: key,
    );
    expect(t.takeException(), isNull);
    final boundary =
        key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await t.runAsync(() async {
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/tmp/ascent-planning-detail.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await t.pumpWidget(const SizedBox());

    final darkKey = GlobalKey();
    await mount(
      t,
      PlanCollectionDetail(id: id),
      AscentTheme.dark(),
      width: 390,
      scale: 1,
      capture: darkKey,
    );
    expect(t.takeException(), isNull);
    final darkBoundary =
        darkKey.currentContext!.findRenderObject() as RenderRepaintBoundary;
    await t.runAsync(() async {
      final image = await darkBoundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      await File(
        '/tmp/ascent-planning-detail-dark.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
    await t.pumpWidget(const SizedBox());
  });
}
