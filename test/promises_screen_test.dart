import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/promises/promises_screen.dart';
import 'package:ascent/features/promises/models/promise_model.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:ascent/features/promises/services/promise_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final dark in [false, true])
    testWidgets(
      'promise list completes a one-time promise, opens completed tab and fits large text dark=$dark',
      (t) async {
        t.view.physicalSize = const Size(390, 900);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repo = PromiseRepository(
          db,
          cancelNotification: (_) async {},
          scheduleNotification: (_, title, body, at) async => true,
        );
        final p = (await t.runAsync(
          () => repo.createPromise(
            title: 'Make time for a quiet walk',
            intention: '',
            category: 'personal',
            trackingType: PromiseTrackingType.completion,
          ),
        ))!;
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            promiseRepositoryProvider.overrideWithValue(repo),
          ],
        );
        Future<void> flush() async {
          for (var i = 0; i < 30; i++) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await t.pump(const Duration(milliseconds: 100));
          }
        }

        Future<void> mount({double scale = 1}) async {
          await t.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: dark ? AscentTheme.dark() : AscentTheme.light(),
                builder: (ctx, child) => MediaQuery(
                  data: MediaQuery.of(
                    ctx,
                  ).copyWith(textScaler: TextScaler.linear(scale)),
                  child: child!,
                ),
                home: const PromisesScreen(),
              ),
            ),
          );
          await flush();
          await t.pumpAndSettle();
        }

        try {
          await mount();
          expect(find.byKey(ValueKey('promise_card_${p.id}')), findsOneWidget);
          expect(find.text(p.title), findsOneWidget);
          await t.tap(find.text('Mark Completed'));
          await flush();
          await t.pumpAndSettle();
          expect(find.text('No active commitments'), findsOneWidget);
          expect(
            (await t.runAsync(() => repo.getPromiseById(p.id)))!.isCompleted,
            true,
          );
          await t.tap(find.text('Completed'));
          await flush();
          await t.pumpAndSettle();
          expect(find.text(p.title), findsOneWidget);
          t.view.physicalSize = const Size(320, 1000);
          await mount(scale: 2);
          expect(t.takeException(), isNull);
        } finally {
          await t.pumpWidget(const SizedBox());
          container.dispose();
          await t.pump();
          await t.pump(const Duration(seconds: 2));
        }
      },
    );
}
