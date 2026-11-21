import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/services/share_intake.dart';
import 'package:ascent/features/thought_wall/board/thought_board_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late ProviderContainer container;
  String? clipboard;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
      ],
    );
    clipboard = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          switch (call.method) {
            case 'Clipboard.hasStrings':
              return {'value': clipboard != null};
            case 'Clipboard.getData':
              return clipboard == null ? null : {'text': clipboard};
          }
          return null;
        });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    container.dispose();
    await db.close();
  });

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> pump(WidgetTester tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const ThoughtBoardScreen(),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> unmount(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 1));
  }

  Future<int> add(String text) => db.thoughtDao.insertThought(
    ThoughtTableCompanion.insert(content: text),
  );

  Future<void> openMore(WidgetTester tester, String text) async {
    await tester.longPress(find.text(text));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('select_more')));
    await settle(tester);
  }

  testWidgets('Select all picks every visible thought; None clears it', (
    tester,
  ) async {
    await add('First');
    await add('Second');
    await add('Third');
    await pump(tester);

    await tester.longPress(find.text('First'));
    await settle(tester);
    expect(find.text('1 selected'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('select_all')));
    await settle(tester);
    expect(find.text('3 selected'), findsWidgets);

    await tester.tap(find.byKey(const ValueKey('select_all')));
    await settle(tester);
    expect(find.textContaining('selected'), findsNothing);
    await unmount(tester);
  });

  testWidgets('deleting several thoughts at once is undone in one tap', (
    tester,
  ) async {
    final a = await add('Alpha');
    final b = await add('Beta');
    await pump(tester);

    await tester.longPress(find.text('Alpha'));
    await settle(tester);
    await tester.tap(find.text('Beta'));
    await settle(tester);
    expect(find.text('2 selected'), findsWidgets);
    await tester.tap(find.byKey(const ValueKey('select_more')));
    await settle(tester);
    await tester.tap(find.text('Delete'));
    await settle(tester);

    expect(await db.thoughtDao.getThoughtById(a), isNull);
    expect(await db.thoughtDao.getThoughtById(b), isNull);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect(await db.thoughtDao.getThoughtById(a), isNotNull);
    expect(await db.thoughtDao.getThoughtById(b), isNotNull);
    await unmount(tester);
  });

  testWidgets('Set reminder opens quick add with a reminder already on', (
    tester,
  ) async {
    final id = await add('Pay rent');
    await pump(tester);

    await openMore(tester, 'Pay rent');
    await tester.tap(find.text('Set reminder'));
    await settle(tester);

    expect(find.text('Remind me'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('quick_add_chip_reminder')),
      findsOneWidget,
    );
    await tester.tap(find.byTooltip('Add activity'));
    await settle(tester);

    final task = await db.taskDao.getTaskLinkedToThought(id);
    expect(task, isNotNull);
    final reminders = await db.reminderDao.getRemindersByTaskId(task!.id);
    expect(reminders.where((r) => r.isActive), isNotEmpty);
    await unmount(tester);
  });

  testWidgets('copied text can be saved as a thought in one tap, with Undo', (
    tester,
  ) async {
    clipboard = 'Book flights before Friday';
    await pump(tester);

    expect(find.byKey(const ValueKey('palace_paste')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('palace_paste')));
    await settle(tester);

    var rows = await db.select(db.thoughtTable).get();
    expect(rows.single.content, 'Book flights before Friday');
    expect(find.text('Saved from clipboard'), findsOneWidget);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    rows = await db.select(db.thoughtTable).get();
    expect(rows, isEmpty);
    await unmount(tester);
  });

  testWidgets('no paste chip when the clipboard is empty or text is typed', (
    tester,
  ) async {
    await pump(tester);
    expect(find.byKey(const ValueKey('palace_paste')), findsNothing);
    await unmount(tester);
  });

  testWidgets('dropping a card on another offers merge or same space', (
    tester,
  ) async {
    final movies = await db.thoughtDao.createCategoryAndMove('Movies', const []);
    final target = await add('Dune part two');
    await db.thoughtDao.moveToCategory([target], movies);
    final dragged = await add('Arrival');
    await pump(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Arrival')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    await gesture.moveTo(tester.getCenter(find.text('Dune part two')));
    await tester.pump();
    await gesture.up();
    await settle(tester);

    expect(find.text('Put these together'), findsOneWidget);
    expect(find.text('Merge into one thought'), findsOneWidget);
    await tester.tap(find.text('Move to Movies'));
    await settle(tester);
    expect((await db.thoughtDao.getThoughtById(dragged))!.category, movies);
    await unmount(tester);
  });

  test('shared text and links become one thought; files are ignored', () async {
    final id = await ShareIntake.save([
      SharedMediaFile(path: 'Try the ramen place', type: SharedMediaType.text),
      SharedMediaFile(path: 'https://maps.example/ramen', type: SharedMediaType.url),
      SharedMediaFile(path: '/tmp/photo.jpg', type: SharedMediaType.image),
    ], db.thoughtDao);
    final thought = await db.thoughtDao.getThoughtById(id!);
    expect(
      thought!.content,
      'Try the ramen place\nhttps://maps.example/ramen',
    );
    expect(
      await ShareIntake.save([
        SharedMediaFile(path: '/tmp/a.png', type: SharedMediaType.image),
      ], db.thoughtDao),
      isNull,
    );
  });
}
