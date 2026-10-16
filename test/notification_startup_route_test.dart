import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/notifications/notification_service.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/splash/splash_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets(
    'cold reminder destination survives splash rather than reverting to Home',
    (tester) async {
      SharedPreferences.setMockInitialValues({'ascent_quick_start_v1': true});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const SplashScreen()),
          GoRoute(path: '/home', builder: (_, _) => const Text('Wrong Home')),
          GoRoute(
            path: '/reminders',
            builder: (_, _) => const Text('Reminder destination'),
          ),
        ],
      );
      NotificationService.deferDestination('/reminders');
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.runAsync(() async {
        await Future<void>.delayed(const Duration(milliseconds: 1500));
      });
      await tester.pumpAndSettle();
      expect(find.text('Reminder destination'), findsOneWidget);
      expect(find.text('Wrong Home'), findsNothing);
      expect(NotificationService.consumePendingDestination(), isNull);
      await tester.pumpWidget(const SizedBox());
      router.dispose();
      await db.close();
    },
  );
}
