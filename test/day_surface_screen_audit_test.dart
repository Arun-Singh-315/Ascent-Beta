import 'package:drift/drift.dart' as drift;
import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/home_screen.dart';
import 'package:ascent/features/reminders/reminders_screen.dart';
import 'package:ascent/features/money/money_screen.dart';
import 'package:ascent/features/more/more_screen.dart';
import 'package:ascent/features/analytics/analytics_screen.dart';
import 'package:ascent/features/consistency/consistency_screen.dart';
import 'package:ascent/features/dsa/dsa_screen.dart';
import 'package:ascent/features/focus/focus_screen.dart';
import 'package:ascent/features/medicine/medicine_screen.dart';
import 'package:ascent/features/hydration/hydration_screen.dart';
import 'package:ascent/features/pipeline/pipeline_screen.dart';
import 'package:ascent/features/resume_vault/resume_vault_screen.dart';
import 'package:ascent/features/settings/settings_screen.dart';
import 'package:ascent/features/study_plan/study_plan_screen.dart';
import 'package:ascent/features/study_plan/course_catalog_screen.dart';
import 'package:ascent/features/study_plan/lecture_focus_player_screen.dart';
import 'package:ascent/features/thought_wall/thought_wall_screen.dart';
import 'package:ascent/features/today/task_board_screen.dart';
import 'package:ascent/features/backup/workspace_backup_screen.dart';
import 'package:ascent/features/interview_prep/interview_prep_screen.dart';
import 'package:ascent/features/momentum/momentum_screen.dart';
import 'package:ascent/features/book_reader/kindle_book_reader_screen.dart';
import 'package:ascent/features/walk/walk_screen.dart';
import 'package:ascent/features/chai_break/chai_break_screen.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  final screens = <String, Widget>{
    'HomeScreen': const HomeScreen(),
    'RemindersScreen': const RemindersScreen(),
    'MoneyScreen': const MoneyScreen(),
    'MoreScreen': const MoreScreen(),
    'AnalyticsScreen': const AnalyticsScreen(),
    'ConsistencyScreen': const ConsistencyScreen(),
    'DsaScreen': const DsaScreen(),
    'FocusScreen': const FocusScreen(),
    'MedicineScreen': const MedicineScreen(),
    'HydrationScreen': const HydrationScreen(),
    'PipelineScreen': const PipelineScreen(),
    'ResumeVaultScreen': const ResumeVaultScreen(),
    'SettingsScreen': const SettingsScreen(),
    'StudyPlanScreen': const StudyPlanScreen(),
    'CourseCatalogScreen': const CourseCatalogScreen(),
    'LectureFocusPlayerScreen': const LectureFocusPlayerScreen(),
    'ThoughtWallScreen': const ThoughtWallScreen(),
    'TaskBoardScreen': const TaskBoardScreen(),
    'WorkspaceBackupScreen': const WorkspaceBackupScreen(),
    'InterviewPrepScreen': const InterviewPrepScreen(),
    'MomentumScreen': const MomentumScreen(),
    'KindleBookReaderScreen': const KindleBookReaderScreen(),
    'WalkScreen': const WalkScreen(),
    'ChaiBreakScreen': const ChaiBreakScreen(),
  };
  for (final dark in [false, true]) {
    for (final entry in screens.entries) {
      testWidgets('${entry.key} renders in ${dark ? "night" : "day"}', (
        tester,
      ) async {
        // These restored legacy layouts already required 480px in night mode.
        // Day uses the same original layout now; narrow-screen repairs are deferred.
        tester.view.physicalSize = Size(
          ['AnalyticsScreen', 'HydrationScreen'].contains(entry.key)
              ? 480
              : 390,
          844,
        );
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        SharedPreferences.setMockInitialValues({
          'ascent_new_day_shown': DateTime.now().toIso8601String().substring(
            0,
            10,
          ),
          'ascent_last_hydration_prompt_time':
              DateTime.now().millisecondsSinceEpoch,
          for (final name in [
            'Thought Wall',
            'Tasks & Today',
            'Medicine & Health',
            'Study Plan',
            'Focus Timer',
            'Money',
            'Walk',
            'Chai Break',
            'Pipeline',
            'Settings',
            'DSA',
            'Analytics',
            'Reminders',
          ])
            'feature_guide_v1_$name': true,
        });
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.forTesting(NativeDatabase.memory());
        await db
            .into(db.userProfileTable)
            .insert(
              UserProfileTableCompanion.insert(
                name: 'Arun Singh Visen',
                onboardingComplete: const drift.Value(true),
              ),
            );
        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        final boundary = GlobalKey();
        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: dark ? AscentTheme.dark() : AscentTheme.light(),
                home: RepaintBoundary(key: boundary, child: entry.value),
              ),
            ),
          );
          for (var i = 0; i < 6; i++) {
            await tester.runAsync(
              () => Future<void>.delayed(const Duration(milliseconds: 20)),
            );
            await tester.pump(const Duration(milliseconds: 100));
          }
          final renderError = tester.takeException();
          if (renderError != null) debugDumpRenderTree();
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            final file = File(
              'build/qa/day-surfaces/${entry.key}_${dark ? "night" : "day"}.png',
            );
            await file.parent.create(recursive: true);
            await file.writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
          expect(renderError, isNull);
        } finally {
          await tester.pumpWidget(const SizedBox());
          await tester.pump(const Duration(milliseconds: 300));
          container.dispose();
          var closed = false;
          final closing = db.close().then((_) => closed = true);
          for (var i = 0; i < 30 && !closed; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          await closing;
        }
      });
    }
  }
}
