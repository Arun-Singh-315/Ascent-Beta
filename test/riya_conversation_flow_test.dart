import 'package:ascent/core/ai/riya_alert_effects.dart';
import 'package:ascent/core/ai/riya_conversation_provider.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/ai_assistant/ai_assistant_screen.dart';
import 'package:ascent/features/promises/services/promise_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final dark in [false, true]) {
    testWidgets('create, rename and delete a Promise inline dark=$dark', (
      t,
    ) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await t.runAsync(() => PromiseRepository(db).initialize());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          riyaAlertEffectsProvider.overrideWithValue(
            RiyaAlertEffects(
              db,
              cancel: (_) async => true,
              schedule: (_) async => true,
              syncPromise: (_) async => true,
            ),
          ),
        ],
      );
      var closed = false;
      Future<void> cleanup() async {
        if (closed) return;
        closed = true;
        await t.pumpWidget(const SizedBox());
        container.dispose();
        await t.pump();
        await t.pump(const Duration(seconds: 2));
        await t.runAsync(db.close);
        await t.pump();
      }

      addTearDown(cleanup);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: dark ? AscentTheme.dark() : AscentTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(dark ? 1.5 : 1)),
              child: child!,
            ),
            home: const AiAssistantScreen(),
          ),
        ),
      );
      Future<void> flush() async {
        for (var i = 0; i < 45; i++) {
          await t.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await t.pump(const Duration(milliseconds: 100));
        }
      }

      Future<void> send(String text) async {
        await t.enterText(find.byType(TextField).last, text);
        await t.pump();
        await t.tap(find.byKey(const ValueKey('message_composer_send')));
        await flush();
      }

      Future<void> save() async {
        await t.ensureVisible(find.text('Save').last);
        await t.tap(find.text('Save').last);
        await flush();
      }

      await flush();
      await send('New promise');
      expect(find.textContaining('Kis cheez ka Promise'), findsOneWidget);
      await send('Read every day');
      expect(find.byType(AlertDialog), findsNothing);
      expect(await t.runAsync(() => db.select(db.thoughtTable).get()), isEmpty);
      await save();
      expect(
        find.text('Promise created. One small step at a time.'),
        findsOneWidget,
      );
      final p = (await t.runAsync(
        () => PromiseRepository(db).getActivePromises(),
      ))!.single;
      expect(
        find.byKey(ValueKey('riya_entity_promises_${p.id}')),
        findsOneWidget,
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      await t.ensureVisible(find.text('Edit').last);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Edit').last);
      await flush();
      expect(find.textContaining('What should'), findsOneWidget);
      await send('Read a book every day');
      await save();
      expect(
        (await t.runAsync(
          () => PromiseRepository(db).getPromiseById(p.id),
        ))!.title,
        'Read a book every day',
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      await t.ensureVisible(find.byTooltip('More Promise actions').last);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.byTooltip('More Promise actions').last);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Delete').last);
      await flush();
      expect(
        await t.runAsync(() => PromiseRepository(db).getPromiseById(p.id)),
        isNotNull,
      );
      await t.ensureVisible(find.text('Delete').last);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      await t.tap(find.text('Delete').last);
      await flush();
      expect(
        await t.runAsync(() => PromiseRepository(db).getPromiseById(p.id)),
        isNull,
      );
      expect(find.textContaining('Promise deleted'), findsOneWidget);
      expect(find.byTooltip('More Promise actions'), findsNothing);
      expect(t.takeException(), isNull);
      await cleanup();
    });
  }
  testWidgets(
    'Home sheet asks a missing field and keeps input usable above keyboard',
    (t) async {
      t.view.physicalSize = const Size(390, 844);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          riyaAlertEffectsProvider.overrideWithValue(
            RiyaAlertEffects(
              db,
              cancel: (_) async => true,
              schedule: (_) async => true,
              syncPromise: (_) async => true,
            ),
          ),
        ],
      );
      var closed = false;
      Future<void> cleanup() async {
        if (closed) return;
        closed = true;
        await t.pumpWidget(const SizedBox());
        container.dispose();
        await t.pump();
        await t.pump(const Duration(seconds: 2));
        await t.runAsync(db.close);
        await t.pump();
      }

      addTearDown(cleanup);
      await t.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () => AiAssistantScreen.showFromHome(context),
                  child: const Text('Ask'),
                ),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Ask'));
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      expect(
        t.widget<AiAssistantScreen>(find.byType(AiAssistantScreen)).compact,
        isTrue,
      );
      await t.enterText(find.byType(TextField).last, 'New todo');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('message_composer_send')));
      for (var i = 0; i < 30; i++) {
        await t.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await t.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('What do you want to get done?'), findsOneWidget);
      t.view.viewInsets = const FakeViewPadding(bottom: 300);
      await t.pump();
      await t.pump(const Duration(milliseconds: 400));
      await t.pump(const Duration(milliseconds: 400));
      expect(
        find.byKey(const ValueKey('message_composer_send')).hitTestable(),
        findsOneWidget,
      );
      expect(t.takeException(), isNull);
      await cleanup();
      t.view.resetViewInsets();
    },
  );
}
