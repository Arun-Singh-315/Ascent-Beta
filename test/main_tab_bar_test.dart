import 'package:ascent/app/app_navigation.dart';
import 'package:ascent/app/router.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/you/you_screen.dart';
import 'package:ascent/shared/widgets/glass_surface.dart';
import 'package:ascent/shared/widgets/main_scaffold.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A shell with the real [MainScaffold] and stub tab pages that echo their
/// location, plus one pushed (non-tab) page and the legacy `/more` redirect.
GoRouter _router({String initial = '/home', Widget? you}) {
  final root = GlobalKey<NavigatorState>();
  return GoRouter(
    navigatorKey: root,
    initialLocation: initial,
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (_, _, shell) => MainScaffold(shell: shell),
        branches: [
          for (final path in AscentTabs.roots)
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: path,
                  builder: (context, state) => path == AscentTabs.you && you != null
                      ? you
                      : Scaffold(
                          body: Center(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('page ${state.uri}'),
                                TextButton(
                                  onPressed: () => context.open('/pushed'),
                                  child: const Text('open pushed'),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            ),
        ],
      ),
      GoRoute(path: AscentRoutes.more, redirect: (_, _) => AscentRoutes.you),
      GoRoute(
        parentNavigatorKey: root,
        path: '/pushed',
        builder: (context, _) => Scaffold(
          body: TextButton(
            onPressed: () => context.open('/thought-wall?thought=7'),
            child: const Text('open thought'),
          ),
        ),
      ),
      for (final group in youGroups)
        for (final entry in group.entries)
          if (AscentTabs.indexOf(entry.route) == null)
            GoRoute(
              parentNavigatorKey: root,
              path: Uri.parse(entry.route).path,
              builder: (_, state) =>
                  Scaffold(body: Text('module ${state.uri.path}')),
            ),
    ],
  );
}

Future<(GoRouter, AppDatabase)> _pump(
  WidgetTester tester, {
  String initial = '/home',
  bool dark = false,
  double textScale = 1,
  Size size = const Size(390, 844),
  Widget? you,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final router = _router(initial: initial, you: you);
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  addTearDown(router.dispose);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
        userProfileStreamProvider.overrideWith((ref) => Stream.value(null)),
      ],
      child: MaterialApp.router(
        routerConfig: router,
        theme: dark ? AscentTheme.dark() : AscentTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return (router, db);
}

Future<void> _dispose(WidgetTester tester, AppDatabase db) async {
  await tester.pumpWidget(const SizedBox());
  await db.close();
}

bool _selected(WidgetTester tester, String id) {
  final semantics = tester.getSemantics(find.byKey(ValueKey('tab_$id')));
  return isSemantics(isSelected: true).matches(semantics, {});
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  test('the app shell has Home, Things, Assistant, Mind and You', () {
    final shell =
        ascentRouter.configuration.routes.whereType<StatefulShellRoute>().single;
    final paths = [
      for (final branch in shell.branches)
        (branch.routes.single as GoRoute).path,
    ];
    expect(paths, AscentTabs.roots);
    expect(paths, [
      '/home',
      '/things',
      '/ai-assistant',
      '/thought-wall',
      '/you',
    ]);
  });

  test('old tab locations still resolve as routes', () {
    final top = ascentRouter.configuration.routes.whereType<GoRoute>();
    GoRoute route(String path) => top.firstWhere((r) => r.path == path);
    expect(route(AscentRoutes.reminders).builder, isNotNull);
    expect(route(AscentRoutes.vault).builder, isNotNull);
    expect(route(AscentRoutes.more).redirect, isNotNull);
  });

  test('every You destination is a real route', () {
    final known = <String>{};
    void collect(List<RouteBase> routes, String parent) {
      for (final r in routes) {
        if (r is GoRoute) {
          final full = r.path.startsWith('/')
              ? r.path
              : '${parent == '/' ? '' : parent}/${r.path}';
          known.add(full);
          collect(r.routes, full);
        } else if (r is StatefulShellRoute) {
          for (final b in r.branches) {
            collect(b.routes, parent);
          }
        } else if (r is ShellRoute) {
          collect(r.routes, parent);
        }
      }
    }

    collect(ascentRouter.configuration.routes, '');
    for (final group in youGroups) {
      for (final entry in group.entries) {
        expect(known, contains(Uri.parse(entry.route).path), reason: entry.title);
      }
    }
  });

  test('You keeps every entry point the old More tab and drawer had', () {
    final routes = {
      for (final g in youGroups)
        for (final e in g.entries) e.route,
    };
    // Old More tab and side-drawer destinations, minus the ones that are now
    // tabs of their own (Assistant, Mind, Things).
    const previouslyReachable = [
      '/walk',
      '/medicine',
      '/chai-break',
      '/learning',
      '/momentum',
      '/reminders',
      '/money',
      '/vault',
      '/history',
      '/analytics',
      '/settings',
      '/study-plan',
      '/dsa',
      '/interview-prep',
      '/consistency',
      '/resume-vault',
    ];
    for (final route in previouslyReachable) {
      expect(routes, contains(route));
    }
  });

  test('tab roots open with go, everything else is pushed', () {
    expect(AscentTabs.indexOf('/home'), 0);
    expect(AscentTabs.indexOf('/things?tab=upcoming'), 1);
    expect(AscentTabs.indexOf('/ai-assistant?prompt=hi'), 2);
    expect(AscentTabs.indexOf('/thought-wall?thought=3'), 3);
    expect(AscentTabs.indexOf('/you'), 4);
    expect(AscentTabs.indexOf('/reminders'), isNull);
    expect(AscentTabs.indexOf('/thought-wall/space?key=x'), isNull);
  });

  testWidgets('tapping each tab selects it and shows its page', (tester) async {
    final (_, db) = await _pump(tester);
    expect(find.byKey(const ValueKey('ascent_tab_bar')), findsOneWidget);
    expect(
      find.ancestor(
        of: find.byKey(const ValueKey('tab_home')),
        matching: find.byType(GlassSurface),
      ),
      findsOneWidget,
    );
    // The assistant tab uses the configured assistant name.
    expect(find.text('Riya'), findsOneWidget);
    const ids = ['home', 'things', 'assistant', 'mind', 'you'];
    for (var i = 0; i < ids.length; i++) {
      await tester.tap(find.byKey(ValueKey('tab_${ids[i]}')));
      await tester.pumpAndSettle();
      expect(find.text('page ${AscentTabs.roots[i]}'), findsOneWidget);
      for (final other in ids) {
        expect(_selected(tester, other), other == ids[i], reason: other);
      }
    }
    await _dispose(tester, db);
  });

  for (final (link, tab, page) in [
    ('/things?tab=upcoming', 'things', 'page /things?tab=upcoming'),
    ('/ai-assistant?prompt=plan', 'assistant', 'page /ai-assistant?prompt=plan'),
    ('/thought-wall?thought=4', 'mind', 'page /thought-wall?thought=4'),
    ('/more', 'you', 'page /you'),
    ('/home', 'home', 'page /home'),
  ]) {
    testWidgets('deep link $link opens the $tab tab', (tester) async {
      final (router, db) = await _pump(tester, initial: '/you');
      router.open(link);
      await tester.pumpAndSettle();
      expect(find.text(page), findsOneWidget);
      expect(_selected(tester, tab), isTrue);
      await _dispose(tester, db);
    });
  }

  testWidgets('a cold-start deep link lands on its tab', (tester) async {
    final (_, db) = await _pump(tester, initial: '/thought-wall?thought=9');
    expect(find.text('page /thought-wall?thought=9'), findsOneWidget);
    expect(_selected(tester, 'mind'), isTrue);
    await _dispose(tester, db);
  });

  testWidgets('opening a tab link from a pushed page switches tabs', (
    tester,
  ) async {
    final (_, db) = await _pump(tester);
    await tester.tap(find.text('open pushed'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('open thought'));
    await tester.pumpAndSettle();
    expect(find.text('page /thought-wall?thought=7'), findsOneWidget);
    expect(_selected(tester, 'mind'), isTrue);
    expect(_selected(tester, 'home'), isFalse);
    await _dispose(tester, db);
  });

  testWidgets('back from a non-Home tab goes Home; double back exits', (
    tester,
  ) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    final (_, db) = await _pump(tester);
    for (final id in ['things', 'assistant', 'mind', 'you']) {
      await tester.tap(find.byKey(ValueKey('tab_$id')));
      await tester.pumpAndSettle();
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(_selected(tester, 'home'), isTrue, reason: 'back from $id');
      expect(find.text('page /home'), findsOneWidget);
    }
    calls.clear();

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(find.text('Press back again to exit'), findsOneWidget);
    expect(calls, isNot(contains('SystemNavigator.pop')));

    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(calls, contains('SystemNavigator.pop'));
    await tester.pumpAndSettle(const Duration(seconds: 3));
    await _dispose(tester, db);
  });

  testWidgets('a You row opens its module over the shell', (tester) async {
    final (_, db) = await _pump(tester, initial: '/you', you: const YouScreen());
    expect(find.byKey(const ValueKey('large_title')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('you_row_/hydration')));
    await tester.pumpAndSettle();
    expect(find.text('module /hydration'), findsOneWidget);
    await _dispose(tester, db);
  });

  testWidgets('the You large title collapses into the nav bar on scroll', (
    tester,
  ) async {
    final (_, db) = await _pump(tester, initial: '/you', you: const YouScreen());
    double opacity() => tester
        .widget<Opacity>(
          find
              .ancestor(
                of: find.byKey(const ValueKey('large_title')),
                matching: find.byType(Opacity),
              )
              .first,
        )
        .opacity;
    expect(opacity(), 1);
    await tester.drag(
      find.byKey(const ValueKey('you_list')),
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    expect(opacity(), 0);
    await _dispose(tester, db);
  });

  for (final dark in [false, true]) {
    testWidgets('320 px at 2.0x text has no overflow: dark=$dark', (
      tester,
    ) async {
      final (router, db) = await _pump(
        tester,
        dark: dark,
        textScale: 2,
        size: const Size(320, 640),
        initial: '/you',
        you: const YouScreen(),
      );
      expect(tester.takeException(), isNull);
      for (final id in ['tab_home', 'tab_things', 'tab_assistant', 'tab_mind']) {
        expect(
          tester.getSize(find.byKey(ValueKey(id))).height,
          greaterThanOrEqualTo(44),
        );
      }
      // Scroll the whole You list so every row lays out.
      await tester.drag(
        find.byKey(const ValueKey('you_list')),
        const Offset(0, -3000),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      router.go('/things');
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await _dispose(tester, db);
    });
  }
}
