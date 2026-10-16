import 'package:ascent/features/study_plan/course_catalog_screen.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/learning_hub/learning_hub_models.dart';
import 'package:ascent/features/study_plan/learning_next_step_card.dart';
import 'package:ascent/features/home/widgets/study_streak_meter_card.dart';
import 'package:ascent/core/streak/study_streak_models.dart';

void main() {
  testWidgets(
    'course search has a recoverable empty state and retains creation',
    (tester) async {
      SharedPreferences.setMockInitialValues({
        'feature_guide_v1_Learning Hub': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
          ],
          child: MaterialApp(
            theme: AscentTheme.light(),
            home: const CourseCatalogScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final search = find.byKey(const ValueKey('course-search'));
      await tester.ensureVisible(search);
      await tester.enterText(search, 'NoSuchCourseUniqueXYZ');
      await tester.pump();
      expect(find.text('No courses match your search.'), findsOneWidget);
      expect(find.byTooltip('Add Course'), findsOneWidget);
      await tester.ensureVisible(find.text('Clear filters'));
      await tester.tap(find.text('Clear filters'));
      await tester.pump();
      expect(find.text('No courses match your search.'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      await db.close();
    },
  );
  testWidgets(
    'learning next step and streak help stay usable at 2x text in both themes',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      for (final weight in [
        FontWeight.w400,
        FontWeight.w500,
        FontWeight.w600,
        FontWeight.w700,
      ]) {
        GoogleFonts.plusJakartaSans(fontWeight: weight);
      }
      await tester.runAsync(() => GoogleFonts.pendingFonts());
      final course = Course(
        id: 'one',
        title: 'Practical system design',
        modules: [
          CourseModule(
            id: 1,
            title: 'One',
            lectures: [
              Lecture(
                id: 1,
                moduleId: 1,
                moduleTitle: 'One',
                title: 'A long lesson title that should remain readable',
                durationSeconds: 1800,
                elapsedSeconds: 120,
              ),
            ],
          ),
        ],
      );
      for (final dark in [false, true]) {
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AscentTheme.dark() : AscentTheme.light(),
            home: MediaQuery(
              data: const MediaQueryData(textScaler: TextScaler.linear(2)),
              child: Scaffold(
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      LearningNextStepCard(
                        course: course,
                        activeLecture: course.nextLecture,
                        elapsed: 120,
                        playing: false,
                        onPlayer: () {},
                        onSyllabus: () {},
                      ),
                      const StudyStreakMeterCard(
                        status: StudyStreakStatus(todaySeconds: 0),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
        expect(find.text('Resume learning'), findsOneWidget);
        await tester.ensureVisible(find.text('How your streak works'));
        await tester.tap(find.text('How your streak works'));
        await tester.pumpAndSettle();
        expect(find.textContaining('local midnight'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox());
      }
    },
  );
}
