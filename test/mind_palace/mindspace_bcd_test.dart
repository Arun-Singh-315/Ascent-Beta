import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/services/voice_input.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:ascent/features/thought_wall/board/thought_board_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeVoice implements VoiceInput {
  _FakeVoice({this.available = true});
  final bool available;
  void Function()? _done;

  @override
  Future<bool> start({
    required void Function(String words) onText,
    required void Function() onDone,
  }) async {
    if (!available) return false;
    _done = onDone;
    onText('buy oat milk');
    return true;
  }

  @override
  Future<void> stop() async {
    final done = _done;
    _done = null;
    done?.call();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late ProviderContainer container;

  Future<void> setUpWith(VoiceInput voice) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        privatePromiseIdsProvider.overrideWith((ref) => <int>{}),
        voiceInputProvider.overrideWithValue(voice),
      ],
    );
  }

  tearDown(() async {
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

  Future<void> pump(WidgetTester tester, {bool dark = false}) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: dark ? AscentTheme.dark() : AscentTheme.light(),
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

  Future<int> add(String text, {String? category}) =>
      db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: text,
          category: category == null
              ? const drift.Value.absent()
              : drift.Value(category),
        ),
      );

  testWidgets('search finds thoughts in Today, Done and Archive at once', (
    tester,
  ) async {
    await setUpWith(_FakeVoice());
    await add('Plan the garden');
    final done = await add('Plan the budget');
    final archived = await add('Plan a trip');
    await add('Something else');
    await db.thoughtDao.setCompleted(
      done,
      true,
      now: DateTime.now().subtract(const Duration(days: 3)),
    );
    await db.thoughtDao.archiveThought(archived);
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('palace_search_toggle')));
    await settle(tester);
    await tester.enterText(find.byKey(const ValueKey('palace_search')), 'plan');
    await settle(tester);

    expect(find.text('Plan the garden'), findsOneWidget);
    expect(find.text('Plan the budget'), findsOneWidget);
    expect(find.text('Plan a trip'), findsOneWidget);
    expect(find.text('Something else'), findsNothing);
    expect(find.byKey(const ValueKey('palace_tabs')), findsNothing);

    await tester.enterText(find.byKey(const ValueKey('palace_search')), 'zzz');
    await settle(tester);
    expect(find.textContaining('No thoughts match'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('convert to to-do opens quick add pre-filled and links back', (
    tester,
  ) async {
    await setUpWith(_FakeVoice());
    final id = await add('Call the bank\nAsk about the card fee');
    await pump(tester);

    await tester.longPress(find.textContaining('Call the bank'));
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('select_more')));
    await settle(tester);
    await tester.tap(find.text('Convert to to-do'));
    await settle(tester);

    expect(find.byKey(const ValueKey('thought_quick_add')), findsOneWidget);
    final field = tester.widget<TextField>(
      find.byKey(const ValueKey('activity_quick_input')),
    );
    expect(field.controller!.text, 'Call the bank');

    await tester.tap(find.byTooltip('Add activity'));
    await settle(tester);
    expect(find.byKey(const ValueKey('thought_quick_add')), findsNothing);

    final task = await db.taskDao.getTaskLinkedToThought(id);
    expect(task, isNotNull);
    expect(task!.title, 'Call the bank');
    expect(task.notes, contains('card fee'));
    await unmount(tester);
  });

  testWidgets('the mic dictates into the composer without saving', (
    tester,
  ) async {
    await setUpWith(_FakeVoice());
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('message_composer_mic')));
    await settle(tester);
    expect(find.text('buy oat milk'), findsOneWidget);
    expect(await db.select(db.thoughtTable).get(), isEmpty);
    await unmount(tester);
  });

  testWidgets('voice that is unavailable explains and keeps typing', (
    tester,
  ) async {
    await setUpWith(_FakeVoice(available: false));
    await pump(tester);

    await tester.tap(find.byKey(const ValueKey('message_composer_mic')));
    await settle(tester);
    expect(find.textContaining('Voice isn’t available'), findsOneWidget);
    await unmount(tester);
  });

  testWidgets('dragging a card onto a space files it there, with Undo', (
    tester,
  ) async {
    await setUpWith(_FakeVoice());
    final key = await db.thoughtDao.createCategoryAndMove('Movies', const []);
    final id = await add('Watch Dune');
    await pump(tester);

    final gesture = await tester.startGesture(
      tester.getCenter(find.text('Watch Dune')),
    );
    await tester.pump(kLongPressTimeout + const Duration(milliseconds: 100));
    await gesture.moveBy(const Offset(0, 20));
    await tester.pump();
    expect(find.byKey(const ValueKey('palace_drop_dock')), findsOneWidget);

    await gesture.moveTo(
      tester.getCenter(find.byKey(ValueKey('drop_space_$key'))),
    );
    await tester.pump();
    await gesture.up();
    await settle(tester);

    expect((await db.thoughtDao.getThoughtById(id))!.category, key);
    expect(find.text('Moved to Movies'), findsOneWidget);
    expect(find.byKey(const ValueKey('palace_drop_dock')), findsNothing);

    await tester.tap(find.text('Undo'));
    await settle(tester);
    expect((await db.thoughtDao.getThoughtById(id))!.category, isNot(key));
    await unmount(tester);
  });

  for (final dark in [false, true]) {
    testWidgets(
      'search results fit 320 px at 2.0x text (${dark ? 'dark' : 'light'})',
      (tester) async {
        await setUpWith(_FakeVoice());
        await add('Plan the garden with a very long title that wraps');
        tester.view.physicalSize = const Size(320, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: dark ? AscentTheme.dark() : AscentTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(
                  context,
                ).copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const ThoughtBoardScreen(),
            ),
          ),
        );
        await settle(tester);
        await tester.tap(find.byKey(const ValueKey('palace_search_toggle')));
        await settle(tester);
        await tester.enterText(
          find.byKey(const ValueKey('palace_search')),
          'plan',
        );
        await settle(tester);
        expect(tester.takeException(), isNull);
        await unmount(tester);
      },
    );
  }
}
