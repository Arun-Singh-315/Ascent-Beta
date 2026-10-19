import 'package:ascent/features/home/widgets/activity_composer.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/services/activity_entry_service.dart';
import 'package:ascent/core/services/plan_collection_service.dart';
import 'package:ascent/shared/widgets/note_list_button.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  test('list button inserts a real new line and parser produces two items', () {
    final controller = TextEditingController(text: 'Read Java');
    NoteListButton.insertNextItem(controller);
    expect(controller.text, 'Read Java\n→ ');
    controller.text += 'Practise RAG';
    expect(PlanItemDraft.parseList(controller.text), [
      'Read Java',
      'Practise RAG',
    ]);
    controller.dispose();
  });
  test(
    'repeated taps reuse an empty list row rather than adding empty tasks',
    () {
      final controller = TextEditingController(text: 'Read\n→ ');
      NoteListButton.insertNextItem(controller);
      NoteListButton.insertNextItem(controller);
      expect(controller.text, 'Read\n→ ');
      controller.dispose();
    },
  );
  test('inserting in the middle preserves the following text', () {
    final controller = TextEditingController(text: 'ReadApply')
      ..selection = const TextSelection.collapsed(offset: 4);
    NoteListButton.insertNextItem(controller);
    expect(controller.text, 'Read\n→ Apply');
    controller.dispose();
  });
  test(
    'batch to-do entry creates separate tasks and rolls back invalid batches',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      try {
        final service = ActivityEntryService(db);
        await service.saveMany(titles: ['Read', 'Apply'], date: DateTime.now());
        expect((await db.select(db.taskTable).get()).map((t) => t.title), [
          'Read',
          'Apply',
        ]);
        await expectLater(
          service.saveMany(titles: ['Valid', ''], date: DateTime.now()),
          throwsStateError,
        );
        expect((await db.select(db.taskTable).get()).length, 2);
      } finally {
        await db.close();
      }
    },
  );
  testWidgets(
    'the labelled action keeps the keyboard focused on the next line',
    (t) async {
      final controller = TextEditingController(text: 'First');
      final focus = FocusNode();
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Column(
              children: [
                TextField(controller: controller, focusNode: focus),
                NoteListToolbar(controller: controller, focusNode: focus),
              ],
            ),
          ),
        ),
      );
      await t.tap(find.text('Add next item'));
      await t.pump();
      expect(controller.text, 'First\n→ ');
      expect(focus.hasFocus, isTrue);
      expect(
        find.text('One line per item. Tap Plan to review your list.'),
        findsOneWidget,
      );
      await t.pumpWidget(const SizedBox());
      controller.dispose();
      focus.dispose();
    },
  );
  testWidgets('quick to-do entry saves list rows as independent tasks', (
    t,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    try {
      await t.pumpWidget(
        ProviderScope(
          overrides: [databaseProvider.overrideWithValue(db)],
          child: const MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(child: ActivityComposer()),
            ),
          ),
        ),
      );
      final input = find.byKey(const ValueKey('activity_quick_input'));
      await t.enterText(input, 'First task');
      await t.pump();
      await t.tap(find.byType(InlineListAddButton));
      await t.pump();
      expect(t.widget<TextField>(input).controller!.text, 'First task\n→ ');
      await t.enterText(input, 'First task\n→ Second task');
      await t.pump();
      await t.tap(find.byTooltip('Add activity'));
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 150)),
      );
      await t.pumpAndSettle();
      expect((await db.select(db.taskTable).get()).map((x) => x.title), [
        'First task',
        'Second task',
      ]);
      await t.pumpWidget(const SizedBox());
    } finally {
      await db.close();
    }
  });
}
