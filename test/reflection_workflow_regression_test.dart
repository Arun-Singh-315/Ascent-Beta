import 'package:ascent/shared/widgets/message_composer.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/medicine/medicine_time_dialog.dart';
import 'package:ascent/features/thought_wall/thought_wall_preferences.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'package:ascent/shared/widgets/thought_excerpt.dart';
import 'package:drift/drift.dart' as d;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 8; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  test('planning arrows are hidden without losing prose or line breaks', () {
    expect(ThoughtExcerpt.displayContent('→ One\n\n--> Two\n→ '), 'One\n\nTwo');
    expect(
      ThoughtExcerpt.displayContent('A → B\n• Keep bullet'),
      'A → B\n• Keep bullet',
    );
  });

  test(
    'quick categories persist including an intentionally empty list',
    () async {
      SharedPreferences.setMockInitialValues({
        'feature_guide_v1_Thought Wall': true,
      });
      final prefs = await SharedPreferences.getInstance();
      ProviderContainer create() => ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      var container = create();
      await container
          .read(thoughtCategoryShortcutsProvider.notifier)
          .toggle('bugs');
      await container
          .read(thoughtCategoryShortcutsProvider.notifier)
          .toggle('suggestions');
      container.dispose();
      container = create();
      expect(container.read(thoughtCategoryShortcutsProvider), isEmpty);
      await container
          .read(thoughtCategoryShortcutsProvider.notifier)
          .toggle('general');
      expect(prefs.getStringList(thoughtCategoryShortcutsKey), ['general']);
      container.dispose();
    },
  );

  testWidgets('adding a list line reveals the caret inside a long composer', (
    t,
  ) async {
    final controller = TextEditingController(
      text: List.generate(20, (i) => 'Line $i').join('\n'),
    );
    await t.pumpWidget(
      MaterialApp(
        theme: AscentTheme.light(),
        home: Scaffold(
          body: MessageComposer(
            controller: controller,
            hint: 'Write',
            onSend: (_) {},
          ),
        ),
      ),
    );
    await t.tap(find.byType(TextField));
    await t.pumpAndSettle();
    controller.selection = TextSelection.collapsed(
      offset: controller.text.length,
    );
    await t.tap(find.byTooltip('Add plan item (→) • Long press for guide'));
    await t.pumpAndSettle();
    final editable = t.state<EditableTextState>(find.byType(EditableText));
    final caret = editable.renderEditable.getLocalRectForCaret(
      controller.selection.extent,
    );
    expect(caret.top, greaterThanOrEqualTo(0));
    expect(
      caret.bottom,
      lessThanOrEqualTo(editable.renderEditable.size.height + 1.0),
    );
    expect(controller.text.endsWith('\n\n→ '), isTrue);
    await t.pumpWidget(const SizedBox());
    controller.dispose();
  });

  for (final dark in [false, true]) {
    testWidgets(
      'medicine time fits short keyboard viewport and validates 24-hour input dark=$dark',
      (t) async {
        t.view.physicalSize = const Size(320, 568);
        t.view.devicePixelRatio = 1;
        t.view.viewInsets = const FakeViewPadding(bottom: 300);
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        addTearDown(t.view.resetViewInsets);
        TimeOfDay? saved;
        await t.pumpWidget(
          MaterialApp(
            theme: dark
                ? AscentTheme.dark(preset: DayThemePreset.merlotLinen)
                : AscentTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: const TextScaler.linear(2)),
              child: child!,
            ),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () async {
                    saved = await showDialog<TimeOfDay>(
                      context: context,
                      builder: (_) => const MedicineTimeDialog(
                        initialTime: TimeOfDay(hour: 6, minute: 23),
                        dose: 1,
                      ),
                    );
                  },
                  child: const Text('Choose'),
                ),
              ),
            ),
          ),
        );
        await t.tap(find.text('Choose'));
        await t.pumpAndSettle();
        expect(t.takeException(), isNull);
        await t.enterText(find.byType(TextFormField).first, '29');
        await t.ensureVisible(find.text('Save time'));
        await t.tap(find.text('Save time'));
        await t.pumpAndSettle();
        expect(find.text('Use 0–23'), findsOneWidget);
        await t.enterText(find.byType(TextFormField).first, '23');
        await t.enterText(find.byType(TextFormField).last, '08');
        await t.ensureVisible(find.text('Save time'));
        await t.tap(find.text('Save time'));
        await t.pumpAndSettle();
        expect(saved, const TimeOfDay(hour: 23, minute: 8));
        expect(t.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'category combines with completion, dates and archive while swiping left keeps notes',
    (t) async {
      SharedPreferences.setMockInitialValues({
        'feature_guide_v1_Thought Wall': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
      );
      final now = DateTime.now();
      final today = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'New open bug',
          category: const d.Value('bugs'),
        ),
      );
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: 'Archived done bug',
          category: const d.Value('bugs'),
          createdAt: d.Value(now.subtract(const Duration(days: 2))),
          isArchived: const d.Value(true),
          isCompleted: const d.Value(true),
        ),
      );
      await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(content: 'Unrelated note'),
      );
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const ThoughtWallScreen(),
          ),
        ),
      );
      await settle(t);
      await t.tap(find.text('Bugs').first);
      await t.pumpAndSettle();
      expect(find.text('New open bug'), findsOneWidget);
      expect(find.text('Archived done bug'), findsNothing);
      await t.tap(find.text('All'));
      await t.pumpAndSettle();
      expect(find.text('Archived done bug'), findsOneWidget);
      expect(find.text('Unrelated note'), findsNothing);
      await t.tap(find.byTooltip('Category filter'));
      await t.pumpAndSettle();
      await t.tap(find.text('Done').first);
      await t.tap(find.text('Apply filters'));
      await t.pumpAndSettle();
      expect(find.text('New open bug'), findsNothing);
      expect(find.text('Archived done bug'), findsOneWidget);
      await t.tap(find.byTooltip('Category filter'));
      await t.pumpAndSettle();
      await t.tap(find.text('Any status'));
      await t.tap(find.text('Apply filters'));
      await t.pumpAndSettle();
      await t.drag(
        find.byKey(ValueKey('thought_$today')),
        const Offset(-500, 0),
      );
      await settle(t);
      expect(
        await t.runAsync(() => db.thoughtDao.getThoughtById(today)),
        isNotNull,
      );
      await t.tap(find.byTooltip('Mark done').first);
      await settle(t);
      expect(
        (await t.runAsync(
          () => db.thoughtDao.getThoughtById(today),
        ))!.isCompleted,
        isTrue,
      );
      await t.tap(find.text('New open bug'));
      await t.pump(const Duration(milliseconds: 80));
      await t.tap(find.text('New open bug'));
      await settle(t);
      expect(
        (await t.runAsync(
          () => db.thoughtDao.getThoughtById(today),
        ))!.isCompleted,
        isFalse,
      );
      await t.longPress(find.text('New open bug'));
      await t.pumpAndSettle();
      expect(find.widgetWithText(TextButton, 'Category'), findsOneWidget);
      expect(find.byTooltip('More selected actions'), findsOneWidget);
      expect(find.text('Todo & Reminder'), findsNothing);
      await t.tap(find.byTooltip('Exit selection'));
      await t.pumpAndSettle();
      await t.drag(
        find.byKey(ValueKey('thought_$today')),
        const Offset(500, 0),
      );
      await settle(t);
      final archived = (await t.runAsync(
        () => db.thoughtDao.getThoughtById(today),
      ))!;
      expect(archived.isArchived, isTrue);
      expect(archived.category, 'bugs');
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      container.dispose();
      await t.pump(const Duration(seconds: 2));
    },
  );

  testWidgets('create a category directly on an empty wall', (t) async {
    SharedPreferences.setMockInitialValues({
      'feature_guide_v1_Thought Wall': true,
    });
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(
          await SharedPreferences.getInstance(),
        ),
      ],
    );
    await t.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const ThoughtWallScreen(),
        ),
      ),
    );
    await settle(t);
    await t.tap(find.byTooltip('Category filter'));
    await t.pumpAndSettle();
    await t.tap(find.byTooltip('Create category'));
    await t.pumpAndSettle();
    await t.enterText(find.byType(TextField).last, 'Personal');
    await t.tap(find.text('Create'));
    await settle(t);
    expect(
      (await t.runAsync(() => db.thoughtDao.watchCategories().first))!.values,
      contains('Personal'),
    );
    expect(
      await t.runAsync(() => db.thoughtDao.watchAllThoughts().first),
      isEmpty,
    );
    expect(t.takeException(), isNull);
    await t.pumpWidget(const SizedBox());
    container.dispose();

    await t.pump(const Duration(seconds: 2));
  });
}
