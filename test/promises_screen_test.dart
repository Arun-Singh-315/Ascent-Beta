import 'dart:io';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/features/promises/promises_screen.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' as d;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  setUpAll(() async {
    if (Platform.environment['ASCENT_PROMISE_CAPTURE'] == '1') {
      final icons = FontLoader('MaterialIcons')
        ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
      await icons.load();
    }
  });
  for (final dark in [false, true]) {
    testWidgets(
      'personal promise check-in lists commitments and kept state dark=$dark',
      (t) async {
        t.view.physicalSize = const Size(390, 1000);
        t.view.devicePixelRatio = 1;
        addTearDown(t.view.resetPhysicalSize);
        addTearDown(t.view.resetDevicePixelRatio);
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final id = await t.runAsync(() async {
          await db.userProfileDao.upsertProfile(
            UserProfileTableCompanion.insert(name: 'Arun Singh'),
          );
          await db.thoughtDao.insertThought(
            ThoughtTableCompanion.insert(
              content: 'Read a few pages before bed',
              mood: const d.Value('promise'),
            ),
          );
          return db.thoughtDao.insertThought(
            ThoughtTableCompanion.insert(
              content: 'Make time for a quiet walk',
              mood: const d.Value('promise'),
            ),
          );
        });
        final container = ProviderContainer(
          overrides: [databaseProvider.overrideWithValue(db)],
        );
        Future<void> flush() async {
          for (var i = 0; i < 8; i++) {
            await t.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await t.pump(const Duration(milliseconds: 100));
          }
        }

        try {
          await t.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: dark ? AscentTheme.dark() : AscentTheme.light(),
                home: const RepaintBoundary(
                  key: ValueKey('promise_capture'),
                  child: PromisesScreen(),
                ),
              ),
            ),
          );
          await flush();
          await t.pumpAndSettle();
          expect(find.text('Hey Arun, we’re in this together.'), findsNothing);
          expect(find.text('Make time for a quiet walk'), findsOneWidget);
          expect(
            t.getSize(find.byKey(ValueKey('promise_card_$id'))).width,
            350,
          );
          expect(find.text('2 active · 0 kept'), findsOneWidget);
          if (Platform.environment['ASCENT_PROMISE_CAPTURE'] == '1') {
            await t.runAsync(() async {
              final boundary = t.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('promise_capture')),
              );
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '/tmp/ascent-promises-${dark ? 'dark' : 'light'}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }
          await t.tap(find.text('Mark kept').first);
          await flush();
          await t.pumpAndSettle();
          expect(find.text('Kept'), findsOneWidget);
          expect(
            (await t.runAsync(
              () => db.thoughtDao.getThoughtById(id!),
            ))!.isCompleted,
            isTrue,
          );
          t.view.physicalSize = const Size(320, 1400);
          await t.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: dark ? AscentTheme.dark() : AscentTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(
                    context,
                  ).copyWith(textScaler: const TextScaler.linear(2)),
                  child: child!,
                ),
                home: const PromisesScreen(),
              ),
            ),
          );
          await flush();
          await t.pumpAndSettle();
          expect(t.takeException(), isNull);
          await t.runAsync(() => db.delete(db.thoughtTable).go());
          t.view.physicalSize = const Size(390, 1000);
          await t.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: dark ? AscentTheme.dark() : AscentTheme.light(),
                builder: (context, child) => RepaintBoundary(
                  key: const ValueKey('promise_full_capture'),
                  child: child!,
                ),
                home: const PromisesScreen(),
              ),
            ),
          );
          await flush();
          await t.pumpAndSettle();
          expect(find.text('No promises yet'), findsOneWidget);
          expect(find.textContaining('A fresh page'), findsNothing);
          Future<void> captureState(String name) async {
            if (Platform.environment['ASCENT_PROMISE_CAPTURE'] != '1') return;
            await t.runAsync(() async {
              final boundary = t.renderObject<RenderRepaintBoundary>(
                find.byKey(const ValueKey('promise_full_capture')),
              );
              final image = await boundary.toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              await File(
                '/tmp/ascent-promises-$name-${dark ? 'dark' : 'light'}.png',
              ).writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          await captureState('empty');
          await t.tap(find.text('Create a promise'));
          await t.pumpAndSettle();
          await t.enterText(
            find.byKey(const ValueKey('promise_input')),
            'Take a short walk',
          );
          await t.pumpAndSettle();
          final nextButton = find.descendant(
            of: find.byKey(const ValueKey('promise_next')),
            matching: find.byType(FilledButton),
          );
          expect(t.widget<FilledButton>(nextButton).onPressed, isNotNull);
          await captureState('entry');
          await t.tap(find.text('Next promise'));
          await t.pumpAndSettle();
          expect(
            t
                .widget<FilledButton>(
                  find.widgetWithText(FilledButton, 'Review & save'),
                )
                .onPressed,
            isNotNull,
          );
          await t.tap(find.text('Review & save'));
          await t.pumpAndSettle();
          await captureState('review');
          expect(find.text('Save 1 promise'), findsOneWidget);
          expect(t.takeException(), isNull);
        } finally {
          await t.pumpWidget(const SizedBox());
          container.dispose();
          await t.pump(const Duration(seconds: 2));
        }
      },
    );
  }
}
