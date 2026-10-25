import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'package:ascent/features/today/task_board_screen.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  Future<void> settleDb(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<(AppDatabase, ProviderContainer)> prepare() async {
    SharedPreferences.setMockInitialValues({
      'feature_guide_v1_Thought Wall': true,
      'feature_guide_v1_Tasks & Today': true,
    });
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    return (
      db,
      ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      ),
    );
  }

  Widget harness(
    ProviderContainer container,
    Widget child, {
    double textScale = 1,
  }) => UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: AscentTheme.dark(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: child,
    ),
  );
  testWidgets(
    'selection fits 320px at 2x, hides menus and counts surviving thoughts',
    (tester) async {
      tester.view.physicalSize = const Size(320, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final (db, container) = await prepare();
      addTearDown(db.close);
      final first = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Live selection A'),
      );
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Live selection B'),
      );
      try {
        await tester.pumpWidget(
          harness(container, const ThoughtWallScreen(), textScale: 2),
        );
        await settleDb(tester);
        await tester.ensureVisible(find.textContaining('Live selection A'));
        await tester.pumpAndSettle();
        await tester.longPress(find.textContaining('Live selection A'));
        await tester.pumpAndSettle();
        await tester.ensureVisible(find.textContaining('Live selection B'));
        await tester.pumpAndSettle();
        await tester.tap(find.textContaining('Live selection B'));
        await tester.pumpAndSettle();
        expect(find.text('2 Selected'), findsOneWidget);
        expect(find.byTooltip('Share selected notes'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == 'Merge selected notes',
                ),
              )
              .onPressed,
          isNotNull,
        );
        expect(
          find.descendant(
            of: find.byType(ThoughtCardBubble),
            matching: find.byType(PopupMenuButton<String>),
          ),
          findsNothing,
        );
        expect(find.byTooltip('Share to WhatsApp'), findsNothing);
        expect(find.byTooltip('Exit Selection'), findsNothing);
        await tester.runAsync(() => db.thoughtDao.deleteThought(first));
        await settleDb(tester);
        expect(find.text('1 Selected'), findsOneWidget);
        expect(
          tester
              .widget<IconButton>(
                find.byWidgetPredicate(
                  (w) => w is IconButton && w.tooltip == 'Merge selected notes',
                ),
              )
              .onPressed,
          isNull,
        );
        await tester.runAsync(
          () => db.thoughtDao.insertThought(
            ThoughtTableCompanion.insert(content: 'New unselected thought'),
          ),
        );
        await settleDb(tester);
        expect(find.text('1 Selected'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('thought_selection_actions')),
          findsOneWidget,
        );
        expect(tester.takeException(), isNull);
      } finally {
        await tester.pumpWidget(const SizedBox());
        container.dispose();
        await tester.pump(const Duration(seconds: 2));
      }
    },
  );

  testWidgets(
    'Selection actions are visible; Cancel retains selection and saved Todo returns to the normal wall',
    (tester) async {
      final (db, container) = await prepare();
      addTearDown(db.close);
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Selection note A'),
      );
      try {
        await tester.pumpWidget(harness(container, const ThoughtWallScreen()));
        await settleDb(tester);
        await tester.ensureVisible(find.textContaining('Selection note A'));
        await tester.pumpAndSettle();
        await tester.longPress(find.textContaining('Selection note A'));
        await tester.pumpAndSettle();
        expect(find.widgetWithText(TextButton, 'Done'), findsOneWidget);
        expect(find.widgetWithText(TextButton, 'Category'), findsOneWidget);
        expect(find.text('Create Todo'), findsNothing);
        await tester.tap(find.byTooltip('More selected actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create Todo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('thought_selection_actions')),
          findsOneWidget,
        );
        await tester.tap(find.byTooltip('More selected actions'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Create Todo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Save action'));
        await settleDb(tester);
        expect(
          find.byKey(const ValueKey('thought_selection_actions')),
          findsNothing,
        );
        expect(find.text('Thought Wall'), findsOneWidget);
        final tasks = await tester.runAsync(
          () => db.taskDao.watchAllTasks().first,
        );
        expect(tasks, hasLength(1));
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        container.dispose();
        await tester.pump(const Duration(seconds: 2));
      }
    },
  );
  testWidgets('Saving a merge exits selection and keeps source notes', (
    tester,
  ) async {
    final (db, container) = await prepare();
    addTearDown(db.close);
    for (final text in ['Selection note A', 'Selection note B']) {
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: text),
      );
    }
    try {
      await tester.pumpWidget(harness(container, const ThoughtWallScreen()));
      await settleDb(tester);
      await tester.ensureVisible(find.textContaining('Selection note A'));
      await tester.pumpAndSettle();
      await tester.longPress(find.textContaining('Selection note A'));
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.textContaining('Selection note B'));
      await tester.pumpAndSettle();
      await tester.tap(find.textContaining('Selection note B'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Merge selected notes'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Save merged note'));
      await settleDb(tester);
      expect(
        find.byKey(const ValueKey('thought_selection_actions')),
        findsNothing,
      );
      final notes = await tester.runAsync(
        () => db.thoughtDao.watchAllThoughts().first,
      );
      expect(notes, hasLength(3));
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    } finally {
      await tester.pumpWidget(const SizedBox());
      await tester.pump();
      container.dispose();
      await tester.pump(const Duration(seconds: 2));
    }
  });
  testWidgets(
    'A Home note opens in its past wall view without a detail popup',
    (tester) async {
      final (db, container) = await prepare();
      addTearDown(db.close);
      final id = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Older Home note',
          createdAt: drift.Value(
            DateTime.now().subtract(const Duration(days: 2)),
          ),
        ),
      );
      try {
        await tester.pumpWidget(
          harness(container, ThoughtWallScreen(initialThoughtId: id)),
        );
        await settleDb(tester);
        expect(find.textContaining('Older Home note'), findsOneWidget);
        expect(find.byType(BottomSheet), findsNothing);
        expect(find.text('OLDER REFLECTIONS'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        container.dispose();
        await tester.pump(const Duration(seconds: 2));
      }
    },
  );
  testWidgets(
    'Timed activity detail offers a timer while ordinary Todos retain Mark Done',
    (tester) async {
      final (db, container) = await prepare();
      addTearDown(db.close);
      await db.taskDao.insertTask(
        TaskTableCompanion.insert(
          title: 'Timed practice',
          estimatedMinutes: const drift.Value(20),
        ),
      );
      await db.taskDao.insertTask(
        TaskTableCompanion.insert(title: 'Plain Todo'),
      );
      try {
        await tester.pumpWidget(harness(container, const TaskBoardScreen()));
        await settleDb(tester);
        await tester.tap(find.text('Timed practice'));
        await tester.pumpAndSettle();
        expect(find.text('Open timer'), findsOneWidget);
        expect(find.text('Mark Done'), findsNothing);
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Plain Todo'));
        await tester.pumpAndSettle();
        expect(find.text('Mark Done'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pumpAndSettle();
      } finally {
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        container.dispose();
        await tester.pump(const Duration(seconds: 2));
      }
    },
  );
}
