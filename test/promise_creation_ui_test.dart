import 'dart:convert';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:ascent/features/promises/services/promise_repository.dart';
import 'package:ascent/features/promises/widgets/promise_chat_composer.dart';
import 'package:ascent/shared/widgets/message_composer.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  Future<void> flush(WidgetTester t) async {
    for (var i = 0; i < 40; i++) {
      await t.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 25)),
      );
      await t.pump(const Duration(milliseconds: 100));
    }
  }

  Future<(AppDatabase, ProviderContainer, SharedPreferences)> setup(
    WidgetTester t, {
    bool dark = false,
    double scale = 1,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repo = PromiseRepository(
      db,
      cancelNotification: (_) async {},
      scheduleNotification: (_, title, body, at) async => true,
    );
    await t.runAsync(repo.initialize);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sharedPreferencesProvider.overrideWithValue(prefs),
        promiseRepositoryProvider.overrideWithValue(repo),
      ],
    );
    addTearDown(() async {
      await t.pumpWidget(const SizedBox());
      container.dispose();
      await t.pump();
      await t.pump(const Duration(seconds: 2));
    });
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
          home: Scaffold(
            body: Builder(
              builder: (ctx) => Center(
                child: FilledButton(
                  onPressed: () => PromiseChatComposer.show(ctx),
                  child: const Text('Create'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await t.tap(find.text('Create'));
    await t.pumpAndSettle();
    return (db, container, prefs);
  }

  for (final dark in [false, true]) {
    testWidgets(
      'write first, real capsule input, review, save once dark=$dark',
      (t) async {
        final (db, container, prefs) = await setup(t, dark: dark);
        expect(find.byType(MessageComposer), findsOneWidget);
        expect(find.text('All'), findsNothing);
        expect(find.text('When?'), findsNothing);
        final field = t.widget<TextField>(find.byType(TextField));
        expect(field.minLines, 1);
        expect(field.maxLines, 4);
        expect(field.decoration!.enabledBorder, InputBorder.none);
        expect(field.decoration!.focusedBorder, InputBorder.none);
        await t.enterText(
          find.byType(TextField),
          'Read for 20 minutes every day',
        );
        await t.pump();
        await t.tap(find.byKey(const ValueKey('message_composer_send')));
        await t.pumpAndSettle();
        expect(find.text('When?'), findsOneWidget);
        expect(find.text('Every day'), findsOneWidget);
        expect(
          find.byKey(const ValueKey('promise_start_date')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('promise_planned_time')),
          findsOneWidget,
        );
        expect(
          t
              .widget<SwitchListTile>(
                find.byKey(const ValueKey('promise_reminder_toggle')),
              )
              .value,
          false,
        );
        await t.tap(find.byKey(const ValueKey('promise_save')));
        await flush(t);
        await t.pumpAndSettle();
        expect(find.byType(PromiseChatComposer), findsNothing);
        final saved = await t.runAsync(
          () => container.read(promiseRepositoryProvider).getActivePromises(),
        );
        expect(saved, hasLength(1));
        expect(saved!.single.schedule!.repeats, true);
        expect(prefs.getString('ascent_promise_creation_draft_v3'), isNull);
        expect(t.takeException(), isNull);
      },
    );
  }
  testWidgets(
    'narrow keyboard layout at twice text size and restored review draft',
    (t) async {
      t.view.physicalSize = const Size(320, 740);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final (_, _, prefs) = await setup(t, scale: 2);
      t.view.viewInsets = const FakeViewPadding(bottom: 280);
      addTearDown(t.view.resetViewInsets);
      await t.pump();
      expect(t.takeException(), isNull);
      await t.enterText(find.byType(TextField), 'Call my parents every Sunday');
      await t.pump();
      await t.tap(find.byKey(const ValueKey('message_composer_send')));
      await t.pumpAndSettle();
      expect(t.takeException(), isNull);
      t.view.resetViewInsets();
      await t.pumpAndSettle();
      await flush(t);
      final draft =
          jsonDecode(prefs.getString('ascent_promise_creation_draft_v3')!)
              as Map;
      expect(draft['proposal']['schedule']['days'], [7]);
      await t.tap(find.byTooltip('Close'));
      await t.pumpAndSettle();
      await t.tap(find.text('Create'));
      await t.pumpAndSettle();
      expect(find.text('Make it yours'), findsOneWidget);
      expect(find.text('Call my parents every Sunday'), findsOneWidget);
      await t.ensureVisible(find.byKey(const ValueKey('promise_repeat')));
      await t.tap(find.byKey(const ValueKey('promise_repeat')));
      await t.pumpAndSettle();
      await t.tap(find.text('A few times a week'));
      await t.pumpAndSettle();
      expect(find.text('Weekly target'), findsOneWidget);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('invalid target cannot save and text stays editable', (t) async {
    final (_, container, _) = await setup(t);
    await t.enterText(find.byType(TextField), 'Read for 20 minutes every day');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('message_composer_send')));
    await t.pumpAndSettle();
    await t.ensureVisible(find.text('Tracking options'));
    await t.tap(find.text('Tracking options'));
    await t.pumpAndSettle();
    await t.ensureVisible(find.byType(TextFormField));
    await t.enterText(find.byType(TextFormField), '0');
    await t.pump();
    await t.tap(find.byKey(const ValueKey('promise_save')));
    await flush(t);
    expect(find.byType(PromiseChatComposer), findsOneWidget);
    expect(find.textContaining('greater than zero'), findsWidgets);
    expect(
      await t.runAsync(
        () => container.read(promiseRepositoryProvider).getActivePromises(),
      ),
      isEmpty,
    );
    expect(t.takeException(), isNull);
  });
}
