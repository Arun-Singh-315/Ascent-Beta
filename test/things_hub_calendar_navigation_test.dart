import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:drift/native.dart';

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/today/things_hub_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  late AppDatabase db;
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('Things Hub Navigation & Symmetry Tests', () {
    testWidgets(
      'Tapping calendar button navigates cleanly to /calendar?scope=things without red screen',
      (tester) async {
        String navigatedUri = '';
        final router = GoRouter(
          initialLocation: '/things',
          routes: [
            GoRoute(
              path: '/things',
              builder: (context, state) => const ThingsHubScreen(),
            ),
            GoRoute(
              path: '/calendar',
              builder: (context, state) {
                navigatedUri = state.uri.toString();
                return const Scaffold(
                  body: Text('Things Calendar Destination'),
                );
              },
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              todayActivitiesProvider.overrideWith(
                (ref) => Stream.value(<TodayActivityItem>[]),
              ),
            ],
            child: MaterialApp.router(
              theme: AscentTheme.dark(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Find calendar button
        final calButton = find.byKey(const ValueKey('things_calendar_button'));
        expect(calButton, findsOneWidget);

        await tester.tap(calButton);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(navigatedUri, '/calendar?scope=things');
        expect(find.text('Things Calendar Destination'), findsOneWidget);
      },
    );


    testWidgets(
      'Rule 13: Things Hub is immune to overflow at 320px width with 2.0x text scale',
      (tester) async {
        tester.view.physicalSize = const Size(320 * 2, 700 * 2);
        tester.view.devicePixelRatio = 2.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final router = GoRouter(
          initialLocation: '/things',
          routes: [
            GoRoute(
              path: '/things',
              builder: (context, state) => const MediaQuery(
                data: MediaQueryData(
                  size: Size(320, 700),
                  textScaler: TextScaler.linear(2.0),
                ),
                child: ThingsHubScreen(),
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
              todayActivitiesProvider.overrideWith(
                (ref) => Stream.value(<TodayActivityItem>[]),
              ),
            ],
            child: MaterialApp.router(
              theme: AscentTheme.dark(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  });
}
