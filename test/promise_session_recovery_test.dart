import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/features/promises/models/promise_model.dart';
import 'package:ascent/features/promises/widgets/promise_session_sheet.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'running timer recovers real elapsed time, prevents silent replacement, persists pause',
    () async {
      SharedPreferences.setMockInitialValues({
        PromiseSessionNotifier.storageKey: jsonEncode({
          'id': 42,
          'seconds': 30,
          'started': DateTime.now()
              .subtract(const Duration(seconds: 90))
              .toIso8601String(),
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      var c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      expect(
        c.read(activePromiseSessionProvider).elapsedSeconds,
        inInclusiveRange(120, 123),
      );
      final n = c.read(activePromiseSessionProvider.notifier);
      await expectLater(n.startSession(43), throwsStateError);
      await n.pauseSession();
      final elapsed = c.read(activePromiseSessionProvider).elapsedSeconds;
      c.dispose();
      c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      expect(c.read(activePromiseSessionProvider).isRunning, false);
      expect(c.read(activePromiseSessionProvider).elapsedSeconds, elapsed);
      await c.read(activePromiseSessionProvider.notifier).startSession(42);
      expect(c.read(activePromiseSessionProvider).elapsedSeconds, elapsed);
      await c.read(activePromiseSessionProvider.notifier).stopSession();
      expect(prefs.getString(PromiseSessionNotifier.storageKey), isNull);
      c.dispose();
    },
  );
  testWidgets(
    'discard timer requires confirmation and cancellation keeps practice',
    (t) async {
      GoogleFonts.config.allowRuntimeFetching = false;
      SharedPreferences.setMockInitialValues({
        PromiseSessionNotifier.storageKey: jsonEncode({
          'id': 42,
          'seconds': 42,
          'started': null,
        }),
      });
      final prefs = await SharedPreferences.getInstance();
      final c = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: c,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: PromiseSessionSheet(
                promise: PromiseModel(
                  id: 42,
                  title: 'Read a little',
                  intention: '',
                  category: 'personal',
                  trackingType: PromiseTrackingType.duration,
                  targetValue: 20,
                  createdAt: DateTime.now(),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Discard timer'));
      await t.pumpAndSettle();
      await t.tap(find.text('Keep timer'));
      await t.pumpAndSettle();
      expect(c.read(activePromiseSessionProvider).elapsedSeconds, 42);
      await t.tap(find.text('Discard timer'));
      await t.pumpAndSettle();
      await t.tap(find.text('Discard'));
      await t.pumpAndSettle();
      expect(c.read(activePromiseSessionProvider).promiseId, isNull);
      expect(prefs.getString(PromiseSessionNotifier.storageKey), isNull);
      expect(t.takeException(), isNull);
      await t.pumpWidget(const SizedBox());
      c.dispose();
    },
  );
}
