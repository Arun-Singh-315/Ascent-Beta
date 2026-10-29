import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_hub_models.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/home_layout_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/providers/time_tracking_provider.dart';
import 'package:ascent/features/home/home_screen.dart';
import 'package:drift/drift.dart' as drift;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _PreviewLearning extends LearningHubNotifier {
  @override
  LearningHubState build() => LearningHubState(
    courses: [
      Course(
        id: 'preview',
        title: 'MongoDB & REST APIs',
        modules: [
          const CourseModule(
            id: 1,
            title: 'MongoDB & REST APIs',
            lectures: [
              Lecture(
                id: 1,
                moduleId: 1,
                moduleTitle: 'MongoDB & REST APIs',
                title: "A beginner's walkthrough of building a REST API",
                durationSeconds: 350,
                elapsedSeconds: 4,
              ),
            ],
          ),
        ],
      ),
    ],
    activeCourseId: 'preview',
    activeLectureId: 1,
    currentElapsedSeconds: 4,
    hasStartedLearning: true,
  );
}

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  for (final variant in [
    (width: 390.0, scale: 1.0, dark: false),
    (width: 390.0, scale: 1.0, dark: true),
    (width: 320.0, scale: 2.0, dark: false),
    (width: 320.0, scale: 2.0, dark: true),
  ]) {
    final scenario = (variant.width, variant.scale);
    testWidgets(
      'Populated Home fits ${scenario.$1}px at ${scenario.$2}x, dark=${variant.dark}',
      (tester) async {
        tester.view.physicalSize = Size(
          scenario.$1,
          scenario.$2 == 1 ? 1600 : 2800,
        );
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final icons = File(
          'build/app/intermediates/flutter/debug/flutter_assets/fonts/MaterialIcons-Regular.otf',
        );
        if (icons.existsSync()) {
          await tester.runAsync(() async {
            final loader = FontLoader('MaterialIcons');
            loader.addFont(
              Future.value(ByteData.sublistView(icons.readAsBytesSync())),
            );
            await loader.load();
          });
        }
        SharedPreferences.setMockInitialValues({
          'ascent_day_one_tutorial_v2_dismissed': true,
          'ascent_daily_briefing_seen_v1': DateTime(
            DateTime.now().year,
            DateTime.now().month,
            DateTime.now().day,
          ).toIso8601String(),
          homeLayoutPreferenceKey: jsonEncode(
            HomeLayout(
              order: ['mind', 'today', 'learning', 'life'],
              visible: {'mind', 'today', 'learning', 'life'},
              tools: homeTools.keys.toSet(),
            ).toJson(),
          ),
        });
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        await db
            .into(db.userProfileTable)
            .insert(
              UserProfileTableCompanion.insert(
                name: 'Arun Singh Visen',
                targetRole: const drift.Value('Backend Engineer'),
                onboardingComplete: const drift.Value(true),
              ),
            );
        await db.thoughtDao.insertThought(
          ThoughtTableCompanion.insert(
            content:
                'One small step today: finish the API walkthrough and take a short break.',
          ),
        );
        final boundary = GlobalKey();
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            learningHubProvider.overrideWith(_PreviewLearning.new),
            todayActivitiesProvider.overrideWith(
              (ref) => Stream.value(const [
                TodayActivityItem(
                  id: 'preview',
                  title: 'Read a chapter',
                  sourceType: 'custom',
                  status: TodayActivityStatus.paused,
                  elapsedSecondsToday: 35,
                  categoryTag: 'Focus',
                  kind: ActivityKind.duration,
                  targetMinutes: 60,
                ),
              ]),
            ),
          ],
        );
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: RepaintBoundary(
                key: boundary,
                child: MaterialApp(
                  debugShowCheckedModeBanner: false,
                  theme: variant.dark
                      ? AscentTheme.dark(preset: DayThemePreset.merlotLinen)
                      : AscentTheme.light(
                          preset: scenario.$2 == 1
                              ? DayThemePreset.merlotLinen
                              : DayThemePreset.nordicSky,
                        ),
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(scenario.$2)),
                    child: child!,
                  ),
                  home: const HomeScreen(),
                ),
              ),
            ),
          );
          for (var i = 0; i < 8; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump(const Duration(milliseconds: 100));
          }
          Future<void> snapshot(String suffix) async {
            if (!const bool.fromEnvironment('HOME_SCREENSHOTS')) return;
            await tester.runAsync(() async {
              final image =
                  await (boundary.currentContext!.findRenderObject()
                          as RenderRepaintBoundary)
                      .toImage();
              final bytes = await image.toByteData(
                format: ui.ImageByteFormat.png,
              );
              final file = File(
                'build/qa/home-refinement/home_${scenario.$1.toInt()}_${scenario.$2}x_${variant.dark ? 'dark' : 'light'}_$suffix.png',
              );
              await file.parent.create(recursive: true);
              await file.writeAsBytes(bytes!.buffer.asUint8List());
              image.dispose();
            });
          }

          expect(tester.takeException(), isNull);
          await snapshot('home');
          expect(find.text('Read a chapter'), findsOneWidget);
          await snapshot('mind');
          await tester.scrollUntilVisible(
            find.text('250'),
            240,
            scrollable: find.byType(Scrollable).first,
          );
          expect(tester.takeException(), isNull);
          await snapshot('health');
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(seconds: 1));
          container.dispose();
          var closed = false;
          final closing = db.close().then((_) => closed = true);
          for (var i = 0; i < 30 && !closed; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          await closing;
        }
      },
    );
  }
}
