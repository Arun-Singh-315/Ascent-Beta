import 'dart:io';
import 'dart:ui' as ui;
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/home_customization_sheet.dart';
import 'package:ascent/features/home/widgets/home_header.dart';
import 'package:ascent/features/thought_wall/thought_actions.dart';
import 'package:ascent/features/thought_wall/thought_conversion_sheet.dart';
import 'package:ascent/features/thought_wall/thought_merge_sheet.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'package:ascent/features/today/add_lecture_activity_sheet.dart';
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
        'Mind Space sheets fit narrow screens and $scale text, dark=$dark',
        (tester) async {
          tester.view.physicalSize = const Size(320, 780);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.resetPhysicalSize);
          addTearDown(tester.view.resetDevicePixelRatio);
          final db = AppDatabase.forTesting(NativeDatabase.memory());
          SharedPreferences.setMockInitialValues({});
          final prefs = await SharedPreferences.getInstance();
          final notes = <Thought>[];
          for (final text in [
            'An idea that deserves a little space to breathe.',
            'Read more, keep the original details, then decide what comes next.',
          ]) {
            final id = await db.thoughtDao.insertThought(
              ThoughtTableCompanion.insert(content: text),
            );
            notes.add((await db.thoughtDao.getThoughtById(id))!);
          }
          final container = ProviderContainer(
            overrides: [
              databaseProvider.overrideWithValue(db),
              sharedPreferencesProvider.overrideWithValue(prefs),
            ],
          );
          final boundaryKey = GlobalKey();
          Widget harness(Widget child) => UncontrolledProviderScope(
            container: container,
            child: RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp(
                theme: dark ? AscentTheme.dark() : AscentTheme.light(),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    textScaler: TextScaler.linear(scale),
                    accessibleNavigation: true,
                    disableAnimations: true,
                  ),
                  child: child!,
                ),
                home: Scaffold(body: child),
              ),
            ),
          );
          Future<void> screenshot(String name) async {
            if (!const bool.fromEnvironment('MINDSPACE_SCREENSHOTS')) return;
            final boundary =
                boundaryKey.currentContext!.findRenderObject()
                    as RenderRepaintBoundary;
            final picture = await boundary.toImage(pixelRatio: 1);
            final data = await picture.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/qa/mindspace/${name}_${dark ? 'dark' : 'light'}_${scale}x.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(data!.buffer.asUint8List());
            picture.dispose();
          }

          try {
            await container
                .read(assistantNameProvider.notifier)
                .setName('Riya with a long customized name');
            await tester.pumpWidget(
              harness(
                const SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.all(12),
                    child: HomeHeader(profile: null),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.runAsync(() => screenshot('header'));
            await tester.pumpWidget(
              harness(
                SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: ThoughtCardBubble(
                      thought: notes.first,
                      index: 0,
                      showQuickActions: true,
                    ),
                  ),
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(find.byTooltip('Pin thought'), findsOneWidget);
            await tester.runAsync(() => screenshot('thought'));
            await tester.pumpWidget(
              harness(
                ThoughtConversionSheet(
                  db: db,
                  thoughts: notes,
                  initial: ThoughtConversionMode.both,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.runAsync(() => screenshot('conversion'));
            await tester.pumpWidget(harness(const HomeCustomizationSheet()));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.runAsync(() => screenshot('home'));
            await tester.pumpWidget(
              harness(
                const AddLectureActivitySheet(
                  title: 'Study distributed systems',
                  minutes: 30,
                ),
              ),
            );
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.runAsync(() => screenshot('lecture'));
            await tester.pumpWidget(
              harness(
                Builder(
                  builder: (context) => TextButton(
                    onPressed: () => showThoughtMerge(context, db, notes),
                    child: const Text('Merge'),
                  ),
                ),
              ),
            );
            await tester.tap(find.text('Merge'));
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            await tester.runAsync(() => screenshot('merge'));
            final preview = find.widgetWithText(
              TextField,
              'Merged note preview',
            );
            await tester.enterText(
              preview,
              'My edited merge must survive reordering.',
            );
            await tester.tap(find.byTooltip('Move note 1 down'));
            await tester.pumpAndSettle();
            expect(
              (tester.widget<TextField>(preview)).controller!.text,
              'My edited merge must survive reordering.',
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
