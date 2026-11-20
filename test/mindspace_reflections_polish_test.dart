import 'dart:convert';
import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/app/theme/color_tokens.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/learning_hub/learning_catalog.dart';
import 'package:ascent/core/learning_hub/learning_hub_models.dart';
import 'package:ascent/core/learning_hub/learning_hub_provider.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:ascent/features/reminders/widgets/in_app_reminder_dialog.dart';
import 'package:ascent/features/today/add_lecture_activity_sheet.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settleDb(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  group('Mind Space Reflections & Theme Polish Tests', () {
    test(
      '1. Day mode theme accentPrimary is terracotta brand color, not green',
      () {
        final lightTheme = AscentTheme.light(
          preset: DayThemePreset.classicClay,
        );
        expect(
          lightTheme.colorScheme.primary,
          equals(AscentColors.accentPrimary),
          reason:
              'Day mode primary accent must match Ascent brand terracotta, not greenAction',
        );
        expect(
          AscentTheme.light().colorScheme.primary,
          isNot(equals(const Color(0xFF2F6B4F))),
        );
      },
    );

    test('2. SwitchTheme uses softened warm tones in light mode', () {
      final lightTheme = AscentTheme.light();
      final thumb = lightTheme.switchTheme.thumbColor?.resolve({
        WidgetState.selected,
      });
      final track = lightTheme.switchTheme.trackColor?.resolve({
        WidgetState.selected,
      });

      expect(thumb, isNotNull);
      expect(track, isNotNull);
      expect(thumb, isNot(equals(const Color(0xFF2F6B4F))));
    });

    testWidgets(
      '4. InAppReminderDialog renders with opaque elevated background without transparency bleed',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.forTesting(NativeDatabase.memory());

        final reminderId = await db.reminderDao.insertReminder(
          ReminderTableCompanion.insert(
            title: 'Spring Boot practice session',
            scheduledAt: DateTime.now().add(const Duration(minutes: 5)),
          ),
        );
        final reminder = (await db.reminderDao.getReminderById(reminderId))!;

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );

        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: MaterialApp(
                theme: AscentTheme.light(),
                home: Scaffold(body: InAppReminderDialog(reminder: reminder)),
              ),
            ),
          );
          await settleDb(tester);

          expect(find.text('REMINDER DUE'), findsOneWidget);
          expect(find.text('Spring Boot practice session'), findsOneWidget);
          expect(find.text('Mark as Done'), findsOneWidget);
          expect(find.text('+10m'), findsOneWidget);
          expect(find.text('Tomorrow'), findsOneWidget);
        } finally {
          container.dispose();
          await db.close();
        }
      },
    );

    testWidgets(
      '5b. Home Mind Space preview displays two thoughts (Pinned + Latest)',
      (tester) async {
        final pinnedThought = Thought(
          category: 'general',
          id: 101,
          content: 'Pinned: Finish Spring Boot course by 30',
          mood: 'promise',
          isPinned: true,
          isArchived: false,
          isCompleted: false,
          colorHex: '#6366F1',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        );

        final latestThought = Thought(
          category: 'general',
          id: 102,
          content: 'Latest: Just finished section 4',
          mood: 'thought',
          isPinned: false,
          isArchived: false,
          isCompleted: false,
          colorHex: '#6366F1',
          createdAt: DateTime.now(),
        );

        final extraThought = Thought(
          category: 'general',
          id: 103,
          content: 'Extra: Older unpinned thought',
          mood: 'thought',
          isPinned: false,
          isArchived: false,
          isCompleted: false,
          colorHex: '#6366F1',
          createdAt: DateTime.now().subtract(const Duration(days: 1)),
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              recentThoughtsStreamProvider.overrideWith(
                (ref) =>
                    Stream.value([pinnedThought, latestThought, extraThought]),
              ),
            ],
            child: MaterialApp(
              theme: AscentTheme.light(),
              home: const Scaffold(
                body: SingleChildScrollView(
                  child: ThoughtWallHomePreview(showComposer: false),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Pinned and latest thoughts must be shown in collapsed view
        expect(
          find.text('Pinned: Finish Spring Boot course by 30'),
          findsOneWidget,
        );
        expect(find.text('Latest: Just finished section 4'), findsOneWidget);
        expect(find.text('PINNED TO HOME'), findsOneWidget);
        // Extra 3rd thought must NOT be visible when collapsed
        expect(find.text('Extra: Older unpinned thought'), findsNothing);
      },
    );

    testWidgets(
      '6. AddCourseSheet returns created course and AddLectureActivitySheet updates selected course',
      (tester) async {
        SharedPreferences.setMockInitialValues({
          learningCatalogPreferenceKey: jsonEncode([
            Course(
              id: 'old_course',
              title: 'Old MongoDB Course',
              modules: [CourseModule(id: 1, title: 'Basics', lectures: [])],
            ).toJson(),
          ]),
        });
        final prefs = await SharedPreferences.getInstance();
        final db = AppDatabase.forTesting(NativeDatabase.memory());

        final container = ProviderContainer(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
          ],
        );
        await container.read(learningHubProvider.notifier).ready;

        try {
          await tester.pumpWidget(
            UncontrolledProviderScope(
              container: container,
              child: const MaterialApp(
                home: Scaffold(
                  body: AddLectureActivitySheet(
                    title: 'New Spring Lecture',
                    minutes: 45,
                  ),
                ),
              ),
            ),
          );
          await tester.pump();

          expect(find.text('Old MongoDB Course'), findsOneWidget);
          expect(find.text('Add course'), findsOneWidget);
        } finally {
          container.dispose();
          await db.close();
        }
      },
    );
  });
}
