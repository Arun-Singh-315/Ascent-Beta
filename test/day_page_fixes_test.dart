import 'package:ascent/app/router.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/calm_blue_palette.dart';
import 'package:ascent/core/ai/riya_intents.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/shared/widgets/ascent_button.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

/// Every absolute path the app's router can open.
Set<String> _routerPaths() {
  final paths = <String>{};
  void walk(List<RouteBase> routes) {
    for (final r in routes) {
      if (r is GoRoute && r.path.startsWith('/')) paths.add(r.path);
      walk(r.routes);
    }
  }

  walk(ascentRouter.configuration.routes);
  return paths;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('No tap leads to a removed screen', () {
    test('every notification destination is a real route', () {
      final known = _routerPaths();
      for (final path in [
        '/home',
        '/things',
        '/today',
        '/reminders',
        '/calendar',
        '/plans',
        '/promises',
        '/thought-wall',
        '/ai-assistant',
        '/you',
        '/more',
        '/focus',
        '/medicine',
        '/hydration',
        '/money',
        '/vault',
        '/travel',
        '/history',
        '/settings',
        '/backup',
      ]) {
        expect(NotificationService.destinationForPayload(path), path);
        expect(known, contains(path), reason: '$path has no screen');
      }
    });

    test('"open …" shortcuts in Riya only open real screens', () async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final resolver = RiyaIntentResolver(
        db,
        clock: () => DateTime(2026, 11, 28, 10),
      );
      final known = _routerPaths();
      for (final name in [
        'reminders',
        'focus',
        'things',
        'tasks',
        'money',
        'calendar',
        'plans',
        'promises',
        'mindspace',
        'water',
        'medicine',
        'vault',
        'travel',
        'history',
        'settings',
      ]) {
        final res = await resolver.resolve('open $name');
        final route = res!.command!.arguments['route'] as String;
        expect(known, contains(route), reason: 'open $name → $route');
      }
      for (final retired in ['learning', 'momentum', 'chai', 'growth']) {
        final res = await resolver.resolve('open $retired');
        expect(res!.command, isNull, reason: 'open $retired');
      }
    });
  });

  testWidgets('ghost buttons use the readable link ink in dark mode', (
    tester,
  ) async {
    for (final (theme, ink) in [
      (AscentTheme.light(), CalmBluePalette.action),
      (AscentTheme.dark(), CalmBluePalette.darkAction),
    ]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: Scaffold(
            body: Center(
              child: AscentButton.ghost(label: 'Calendar', onPressed: () {}),
            ),
          ),
        ),
      );
      // MaterialApp animates theme changes; let it finish.
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.text('Calendar'));
      final color =
          text.style?.color ??
          DefaultTextStyle.of(
            tester.element(find.text('Calendar')),
          ).style.color;
      expect(color, ink);
    }
  });
}
