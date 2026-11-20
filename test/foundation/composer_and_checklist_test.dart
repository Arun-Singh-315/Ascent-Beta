import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:ascent/features/thought_wall/board/thought_board_screen.dart';
import 'package:ascent/features/thought_wall/board/thought_lines.dart';
import 'package:ascent/features/thought_wall/utils/thought_checklist_helper.dart';
import 'package:ascent/shared/utils/smart_list_input_formatter.dart';
import 'package:ascent/shared/widgets/ascent_composer.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  Widget host(Widget child, {bool dark = false, double scale = 1}) =>
      MaterialApp(
        theme: dark ? AscentTheme.dark() : AscentTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 640),
          ).copyWith(textScaler: TextScaler.linear(scale)),
          child: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: Padding(padding: const EdgeInsets.all(16), child: child),
            ),
          ),
        ),
      );

  group('AscentComposer', () {
    for (final dark in [false, true]) {
      for (final scale in [1.0, 2.0]) {
        testWidgets('is big, tidy and fits 320 px (dark=$dark, x$scale)', (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 640);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          final c = TextEditingController();
          await tester.pumpWidget(
            host(
              AscentComposer(
                controller: c,
                hint: 'e.g. Idea for the weekend trip',
                onSend: (_) {},
                checklist: true,
                onMic: () {},
              ),
              dark: dark,
              scale: scale,
            ),
          );
          expect(
            tester.getSize(find.byType(AscentComposer)).height,
            greaterThanOrEqualTo(56),
          );
          expect(find.byKey(const ValueKey('composer_mic')), findsOneWidget);
          await tester.enterText(find.byType(TextField), 'Buy milk');
          await tester.pump();
          expect(find.byKey(const ValueKey('composer_mic')), findsNothing);
          expect(find.byTooltip('Send'), findsOneWidget);
          expect(tester.takeException(), isNull);
        });
      }
    }

    testWidgets('send works on the first frame after typing', (tester) async {
      final c = TextEditingController();
      String? sent;
      await tester.pumpWidget(
        host(
          AscentComposer(
            controller: c,
            hint: 'e.g. x',
            onSend: (v) => sent = v,
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'Call mom');
      await tester.pump();
      await tester.tap(find.byTooltip('Send'));
      expect(sent, 'Call mom');
    });

    testWidgets('the checklist button starts tick-box lines', (tester) async {
      final c = TextEditingController();
      await tester.pumpWidget(
        host(
          AscentComposer(
            controller: c,
            hint: 'e.g. x',
            onSend: (_) {},
            checklist: true,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('composer_checklist')));
      await tester.pump();
      expect(c.text, '☐ ');
    });
  });

  group('checklist lines', () {
    test('a plain line becomes a checklist line in place', () {
      final c = TextEditingController(text: 'Milk');
      c.selection = const TextSelection.collapsed(offset: 4);
      AscentComposer.insertChecklistItem(c);
      expect(c.text, '☐ Milk');
    });

    test('Enter on a tick-box line continues the checklist', () {
      const f = SmartListInputFormatter();
      final out = f.formatEditUpdate(
        const TextEditingValue(
          text: '☐ Milk',
          selection: TextSelection.collapsed(offset: 6),
        ),
        const TextEditingValue(
          text: '☐ Milk\n',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(out.text, '☐ Milk\n☐ ');
    });

    test('Enter on a plain bullet stays a plain bullet', () {
      const f = SmartListInputFormatter();
      final out = f.formatEditUpdate(
        const TextEditingValue(
          text: '• Idea',
          selection: TextSelection.collapsed(offset: 6),
        ),
        const TextEditingValue(
          text: '• Idea\n',
          selection: TextSelection.collapsed(offset: 7),
        ),
      );
      expect(out.text, '• Idea\n• ');
    });

    test('as written: only tick-box lines get a circle', () {
      final lines = parseThoughtLines(
        'Trip ideas\n• Goa\n☐ Book hotel\n☑ Pack',
      );
      final circles = lines.where(BulletStyle.asWritten.showsCircle).toList();
      expect(circles.map((l) => l.text), ['Book hotel', 'Pack']);
      expect(lines.where(BulletStyle.todo.showsCircle), hasLength(3));
      expect(lines.where(BulletStyle.bullet.showsCircle), isEmpty);
    });

    test('ticking writes a clean ☑ and keeps older [x] lines working', () {
      final t = ThoughtChecklistHelper.toggleItemDone('☐ Milk\n- [x] Eggs', 0);
      expect(t, '☑ Milk\n- [x] Eggs');
      final items = ThoughtChecklistHelper.parseItems(t);
      expect(items.every((i) => i.isDone), isTrue);
    });
  });

  group('next steps after saving a thought', () {
    late AppDatabase db;
    late ProviderContainer container;
    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      db = AppDatabase.forTesting(NativeDatabase.memory());
      container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          privatePromiseIdsProvider.overrideWith((ref) => <int>{}),
        ],
      );
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'Clipboard.hasStrings') return {'value': false};
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
      for (var i = 0; i < 6; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> send(WidgetTester tester, String text) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
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
      await tester.enterText(find.byType(TextField).last, text);
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('message_composer_send')));
      await settle(tester);
    }

    testWidgets('a thought with a time offers a reminder', (tester) async {
      await send(tester, 'Call mom tomorrow 6pm');
      expect(find.byKey(const ValueKey('next_step_remind')), findsOneWidget);
      expect(find.textContaining('Remind me tomorrow'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    testWidgets('a checklist offers to become to-dos', (tester) async {
      await send(tester, '☐ Milk\n☐ Eggs');
      expect(find.text('Make these 2 to-dos'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });

    testWidgets('a plain thought offers nothing', (tester) async {
      await send(tester, 'What a lovely evening');
      expect(find.byType(Chip), findsNothing);
      expect(find.textContaining('Remind me'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 13));
    });
  });
}
