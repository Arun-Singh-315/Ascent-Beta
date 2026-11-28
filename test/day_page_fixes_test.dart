import 'package:ascent/app/router.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/calm_blue_palette.dart';
import 'package:ascent/core/ai/riya_intents.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/features/home/widgets/home_feed_cards.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
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

  group('Mind card subtitle', () {
    final now = DateTime(2026, 11, 28, 15);
    test('counts today when there is something today', () {
      expect(
        mindSubtitle(todayCount: 1, latest: now, now: now),
        '1 thought today',
      );
      expect(
        mindSubtitle(todayCount: 3, latest: now, now: now),
        '3 thoughts today',
      );
    });
    test('names the latest day instead of "nothing captured"', () {
      expect(
        mindSubtitle(todayCount: 0, latest: null, now: now),
        'Nothing captured yet',
      );
      expect(
        mindSubtitle(
          todayCount: 0,
          latest: DateTime(2026, 11, 27, 22),
          now: now,
        ),
        'Latest from yesterday',
      );
      expect(
        mindSubtitle(
          todayCount: 0,
          latest: DateTime(2026, 11, 25, 9),
          now: now,
        ),
        'Latest from Wednesday',
      );
      expect(
        mindSubtitle(
          todayCount: 0,
          latest: DateTime(2026, 11, 17, 10, 30),
          now: now,
        ),
        'Latest from 17 Nov',
      );
    });
  });

  test('only rain, snow and storms animate the header', () {
    expect(hasPrecipitation(null), isFalse);
    expect(hasPrecipitation(0), isFalse); // clear
    expect(hasPrecipitation(3), isFalse); // overcast
    expect(hasPrecipitation(45), isFalse); // fog
    expect(hasPrecipitation(61), isTrue); // rain
    expect(hasPrecipitation(73), isTrue); // snow
    expect(hasPrecipitation(81), isTrue); // showers
    expect(hasPrecipitation(95), isTrue); // thunderstorm
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
