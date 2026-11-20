
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/home_layout_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_shortcut_panel.dart';
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
  setUpAll(() async {
    final icons = FontLoader('MaterialIcons')
      ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
    await icons.load();
  });
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
      ],
    );
  });
  tearDown(() async {
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

  Widget app(
    Widget child, {
    GlobalKey? capture,
    double scale = 1,
    bool dark = false,
    double keyboardInset = 0,
  }) => UncontrolledProviderScope(
    container: container,
    child: RepaintBoundary(
      key: capture,
      child: MaterialApp(
        theme: dark ? AscentTheme.dark() : AscentTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(
            textScaler: TextScaler.linear(scale),
            viewInsets: EdgeInsets.only(bottom: keyboardInset),
          ),
          child: child,
        ),
      ),
    ),
  );

  testWidgets(
    'Empty shortcuts remain editable and save directly from the card',
    (tester) async {
      await container
          .read(homeLayoutProvider.notifier)
          .save(HomeLayout.defaults().copyWith(shortcuts: []));
      await tester.pumpWidget(
        app(
          Scaffold(
            body: Consumer(
              builder: (context, ref, _) => Padding(
                padding: const EdgeInsets.all(24),
                child: HomeShortcutPanel(
                  shortcuts: ref.watch(homeLayoutProvider).shortcuts,
                  badgeCounts: const {},
                ),
              ),
            ),
          ),
        ),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('edit_home_shortcuts')));
      await settle(tester);
      await tester.tap(find.text('Focus'));
      await tester.tap(find.text('Save shortcuts'));
      await settle(tester);
      expect(container.read(homeLayoutProvider).shortcuts, ['focus']);
      expect(find.byKey(const ValueKey('shortcut_focus')), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );

  testWidgets('Shortcut editor actions sit above shell navigation', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(
        Scaffold(
          body: Stack(
            children: [
              Navigator(
                onGenerateRoute: (_) => MaterialPageRoute<void>(
                  builder: (_) => Scaffold(
                    body: Padding(
                      padding: const EdgeInsets.all(24),
                      child: HomeShortcutPanel(
                        shortcuts: const [],
                        badgeCounts: const {},
                      ),
                    ),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.bottomCenter,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {},
                  child: const SizedBox(
                    height: 160,
                    width: double.infinity,
                    child: ColoredBox(color: Colors.grey),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    await settle(tester);
    await tester.tap(find.byKey(const ValueKey('edit_home_shortcuts')));
    await settle(tester);
    await tester.tap(find.text('Save shortcuts'));
    await settle(tester);
    expect(find.text('Your shortcuts'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
  });
}
