import 'dart:io';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
  late AppDatabase db;
  late SharedPreferences prefs;
  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });
  tearDown(() => db.close());
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 8; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 50));
    }
  }

  testWidgets(
    'Home shows one newest message even behind six older pinned thoughts; opens full thought',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (var i = 0; i < 6; i++) {
        await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'Old pinned $i',
            isPinned: const Value(true),
            createdAt: Value(DateTime(2026, 1, 1)),
          ),
        );
      }
      final message = List.filled(16, 'A little room for a thought.').join(' ');
      final latestId = await db.thoughtDao.insertThought(
        ThoughtTableCompanion.insert(
          content: message,
          createdAt: Value(DateTime(2026, 10, 30)),
        ),
      );
      final key = GlobalKey();
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: RepaintBoundary(
                key: key,
                child: const ColoredBox(
                  color: Color(0xFFF2F2F7),
                  child: Padding(
                    padding: EdgeInsets.all(20),
                    child: ThoughtWallHomePreview(compact: true),
                  ),
                ),
              ),
            ),
          ),
          GoRoute(
            path: '/thought-wall',
            builder: (_, state) => Scaffold(
              body: Text('Opened ${state.uri.queryParameters['thought']}'),
            ),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp.router(
            theme: AscentTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await settle(tester);
      final bubble = find.byKey(const ValueKey('home_latest_thought_bubble'));
      expect(bubble, findsOneWidget);
      expect(find.textContaining('Old pinned'), findsNothing);
      final text = tester.widget<Text>(
        find.byKey(const ValueKey('home_latest_thought_text')),
      );
      expect(text.data, message);
      expect(text.maxLines, 2);
      expect(text.overflow, TextOverflow.ellipsis);
      expect(tester.getSize(bubble).height, lessThan(80));
      expect(tester.getTopLeft(bubble).dx, 20);
      expect(tester.takeException(), isNull);
      await tester.runAsync(() async {
        final rendered =
            await (key.currentContext!.findRenderObject()
                    as RenderRepaintBoundary)
                .toImage(pixelRatio: 2);
        final bytes = await rendered.toByteData(format: ui.ImageByteFormat.png);
        await File(
          '/tmp/ascent-home-compact-thought.png',
        ).writeAsBytes(bytes!.buffer.asUint8List());
        rendered.dispose();
      });
      await tester.tap(bubble);
      await tester.pumpAndSettle();
      expect(find.text('Opened $latestId'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    },
  );
  testWidgets(
    'Empty Home has no message bubble; private thoughts stay masked',
    (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            privatePromiseIdsProvider.overrideWithValue({1}),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const Scaffold(body: ThoughtWallHomePreview(compact: true)),
          ),
        ),
      );
      await settle(tester);
      expect(
        find.byKey(const ValueKey('home_latest_thought_bubble')),
        findsNothing,
      );
      await tester.runAsync(
        () => db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content: 'Private secret',
            mood: const Value('promise'),
          ),
        ),
      );
      await settle(tester);
      expect(find.text('Private secret'), findsNothing);
      expect(find.text('Private thought'), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
