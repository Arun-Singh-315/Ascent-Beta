import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/services/quick_capture_service.dart';
import 'package:ascent/features/capture/quick_capture_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });
  late AppDatabase db;
  late SharedPreferences prefs;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() => db.close());
  Widget app({
    bool dark = false,
    double scale = 1,
    double keyboard = 0,
    GlobalKey? capture,
  }) => ProviderScope(
    overrides: [
      databaseProvider.overrideWithValue(db),
      sharedPreferencesProvider.overrideWithValue(prefs),
      thoughtCategoriesStreamProvider.overrideWith(
        (ref) => Stream.value({'general': 'Wall'}),
      ),
    ],
    child: MaterialApp(
      theme: dark ? AscentTheme.dark() : AscentTheme.light(),
      home: Builder(
        builder: (ctx) => MediaQuery(
          data: MediaQuery.of(ctx).copyWith(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboard),
          ),
          child: RepaintBoundary(
            key: capture,
            child: const Scaffold(body: QuickCaptureSheet()),
          ),
        ),
      ),
    ),
  );
  Future<void> settle(WidgetTester t) async {
    for (var i = 0; i < 4; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  testWidgets(
    'one reviewed batch saves to the right places and shows a useful receipt',
    (t) async {
      await t.pumpWidget(app());
      await settle(t);
      await t.enterText(
        find.byKey(const ValueKey('quick_capture_input')),
        'Todo: send proposal\nThought: a quiet idea\nExpense: 120 for lunch',
      );
      await t.tap(find.byKey(const ValueKey('quick_capture_review')));
      await settle(t);
      expect(find.text('Check the details'), findsOneWidget);
      expect((await t.runAsync(() => db.select(db.taskTable).get()))!, isEmpty);
      await t.tap(find.byKey(const ValueKey('quick_capture_save')));
      await settle(t);
      expect(find.text('All in place'), findsOneWidget);
      expect(find.text('A little less on your mind.'), findsOneWidget);
      expect(
        (await t.runAsync(() => db.select(db.taskTable).get()))!.length,
        1,
      );
      expect(
        (await t.runAsync(
          () => db.select(db.thoughtTable).get(),
        ))!.single.content,
        'a quiet idea',
      );
      expect(
        (await t.runAsync(
          () => db.select(db.financeTransactionTable).get(),
        ))!.single.title,
        'lunch',
      );
      expect(prefs.containsKey('ascent_quick_capture_draft_v1'), isFalse);
      await t.pumpWidget(const SizedBox());
      await settle(t);
    },
  );
  testWidgets(
    'missing details explain the next step without saving partial records',
    (t) async {
      await t.pumpWidget(app());
      await settle(t);
      await t.enterText(
        find.byKey(const ValueKey('quick_capture_input')),
        'Reminder: call Sam',
      );
      await t.tap(find.byKey(const ValueKey('quick_capture_review')));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('quick_capture_save')));
      await settle(t);
      expect(find.text('Choose a date and time.'), findsOneWidget);
      expect(
        (await t.runAsync(() => db.select(db.reminderTable).get()))!,
        isEmpty,
      );
      await t.pumpWidget(const SizedBox());
      await settle(t);
      expect(prefs.containsKey('ascent_quick_capture_draft_v1'), isTrue);
      await t.pumpWidget(app());
      await settle(t);
      expect(find.text('Check the details'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      await settle(t);
    },
  );
  testWidgets(
    'going back to unchanged writing preserves reviewed field edits',
    (t) async {
      await t.pumpWidget(app());
      await settle(t);
      await t.enterText(
        find.byKey(const ValueKey('quick_capture_input')),
        'Todo: proposal',
      );
      await t.tap(find.byKey(const ValueKey('quick_capture_review')));
      await settle(t);
      await t.enterText(
        find.byKey(const ValueKey('0.title')),
        'Reviewed proposal',
      );
      await settle(t);
      await t.tap(find.text('Back to writing'));
      await settle(t);
      await t.tap(find.byKey(const ValueKey('quick_capture_review')));
      await settle(t);
      final input = find.descendant(
        of: find.byKey(const ValueKey('0.title')),
        matching: find.byType(EditableText),
      );
      expect(
        t.widget<EditableText>(input).controller.text,
        'Reviewed proposal',
      );
      await t.pumpWidget(const SizedBox());
      await settle(t);
    },
  );

  testWidgets(
    'a committed batch reopens its receipt instead of creating duplicates',
    (t) async {
      final draft = CaptureDraft(key: 'restore', title: 'Already saved');
      await t.runAsync(
        () => QuickCaptureService(db).save([draft], requestId: 'committed'),
      );
      await prefs.setString(
        'ascent_quick_capture_draft_v1',
        jsonEncode({
          'requestId': 'committed',
          'text': 'Todo: Already saved',
          'review': true,
          'drafts': [draft.toJson()],
        }),
      );
      await t.pumpWidget(app());
      await settle(t);
      expect(find.text('All in place'), findsOneWidget);
      expect(
        (await t.runAsync(() => db.select(db.taskTable).get()))!.length,
        1,
      );
      await t.pumpWidget(const SizedBox());
      await settle(t);
    },
  );

  testWidgets(
    'write and review screens stay usable on small phones, with keyboard and large text',
    (t) async {
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetDevicePixelRatio);
      addTearDown(t.view.resetPhysicalSize);
      for (final width in [320.0, 390.0]) {
        for (final dark in [false, true]) {
          for (final scale in [1.0, 2.0]) {
            for (final keyboard in [0.0, 300.0]) {
              for (final review in [false, true]) {
                await t.pumpWidget(const SizedBox());
                await settle(t);
                await prefs.remove('ascent_quick_capture_draft_v1');
                if (review) {
                  await prefs.setString(
                    'ascent_quick_capture_draft_v1',
                    jsonEncode({
                      'requestId': 'visual',
                      'text': 'Todo: send proposal',
                      'review': true,
                      'drafts': [
                        CaptureDraft(
                          key: 'visual',
                          title: 'Send proposal',
                          notes: 'Attach the latest version',
                        ).toJson(),
                      ],
                    }),
                  );
                }
                t.view.physicalSize = Size(width, 844);
                final key = GlobalKey();
                await t.pumpWidget(
                  app(
                    dark: dark,
                    scale: scale,
                    keyboard: keyboard,
                    capture: key,
                  ),
                );
                await settle(t);
                expect(t.takeException(), isNull);
                if (width == 390 && scale == 1 && keyboard == 0) {
                  await t.runAsync(() async {
                    final image =
                        await (key.currentContext!.findRenderObject()
                                as RenderRepaintBoundary)
                            .toImage(pixelRatio: 2);
                    final bytes = await image.toByteData(
                      format: ui.ImageByteFormat.png,
                    );
                    await File(
                      '/tmp/ascent-capture-${review ? 'review' : 'write'}-${dark ? 'dark' : 'light'}.png',
                    ).writeAsBytes(bytes!.buffer.asUint8List());
                    image.dispose();
                  });
                }
              }
            }
          }
        }
      }
      await t.pumpWidget(const SizedBox());
      await settle(t);
    },
  );
}
