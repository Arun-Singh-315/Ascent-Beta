import 'dart:io';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final dark in [false, true]) {
    for (final scale in [1.0, 2.0]) {
      testWidgets(
        'Mind Space defaults to latest, expands to four; header fits 320px at $scale, dark=$dark',
        (tester) async {
          tester.view.physicalSize = const Size(320, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          final thoughts = <Thought>[];
          for (var i = 0; i < 5; i++) {
            final id = await db.thoughtDao.insertThought(
              ThoughtTableCompanion.insert(
                content: i == 4
                    ? 'My most recent thought. Take one small step today.'
                    : 'Earlier thought $i: keep the idea, then choose its next step.',
              ),
            );
            thoughts.insert(0, (await db.thoughtDao.getThoughtById(id))!);
          }
          final boundary = GlobalKey();
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
              recentThoughtsStreamProvider.overrideWith(
                (ref) => Stream.value(thoughts),
              ),
            ],
          );
          try {
            await tester.pumpWidget(
              UncontrolledProviderScope(
                container: container,
                child: MaterialApp(
                  theme: dark ? AscentTheme.dark() : AscentTheme.light(),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scale)),
                    child: child!,
                  ),
                  home: RepaintBoundary(
                    key: boundary,
                    child: const Scaffold(
                      body: SingleChildScrollView(
                        child: Padding(
                          padding: EdgeInsets.all(24),
                          child: Column(
                            children: [
                              HomeHeader(profile: null),
                              ThoughtWallHomePreview(),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.text('Quick capture'), findsNothing);
            expect(
              find.byKey(ValueKey('home_thought_${thoughts.first.id}')),
              findsOneWidget,
            );
            expect(
              find.byKey(ValueKey('home_thought_${thoughts[1].id}')),
              findsNothing,
            );
            expect(
              tester.getRect(find.byKey(const ValueKey('home_date'))).bottom,
              lessThan(
                tester
                    .getRect(find.byKey(const ValueKey('home_header_actions')))
                    .top,
              ),
            );
            if (const bool.fromEnvironment('MINDSPACE_SCREENSHOTS')) {
              await tester.runAsync(() async {
                final image =
                    await (boundary.currentContext!.findRenderObject()
                            as RenderRepaintBoundary)
                        .toImage();
                final bytes = await image.toByteData(
                  format: ui.ImageByteFormat.png,
                );
                final file = File(
                  'build/qa/mindspace/home_recent_${dark ? 'dark' : 'light'}_${scale}x.png',
                );
                await file.parent.create(recursive: true);
                await file.writeAsBytes(bytes!.buffer.asUint8List());
                image.dispose();
              });
            }
            await tester.ensureVisible(find.byTooltip('Expand Mind Space'));
            await tester.tap(find.byTooltip('Expand Mind Space'));
            await tester.pumpAndSettle();
            for (final thought in thoughts.take(4)) {
              expect(
                find.byKey(ValueKey('home_thought_${thought.id}')),
                findsOneWidget,
              );
            }
            expect(
              find.byKey(ValueKey('home_thought_${thoughts[4].id}')),
              findsNothing,
            );
            expect(find.text('View all'), findsOneWidget);
            await tester.tap(find.byTooltip('Collapse Mind Space'));
            await tester.pumpAndSettle();
            expect(
              find.byKey(ValueKey('home_thought_${thoughts[1].id}')),
              findsNothing,
            );
            expect(tester.takeException(), isNull);
            await tester.pumpWidget(const SizedBox());
            await tester.pumpAndSettle();
          } finally {
            container.dispose();
            await db.close();
          }
        },
      );
    }
  }
}
