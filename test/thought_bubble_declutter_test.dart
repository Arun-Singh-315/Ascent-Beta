import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/core/database/app_database.dart';
import 'package:ascent/core/providers/database_provider.dart';
import 'package:ascent/core/providers/settings_provider.dart';
import 'package:ascent/features/home/widgets/thought_wall_home_preview.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('Thought bubble does not clutter inline chips inside the bubble', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    final thought = Thought(
      id: 1,
      content: 'Simplicity is the prerequisite for reliability.',
      category: 'philosophy',
      mood: 'thought',
      colorHex: '#A4523A',
      isPinned: false,
      isCompleted: false,
      isArchived: false,
      createdAt: DateTime.now().subtract(const Duration(minutes: 5)),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          recentThoughtsStreamProvider.overrideWith((ref) => Stream.value([thought])),
          thoughtCategoriesStreamProvider.overrideWith((ref) => Stream.value({'philosophy': 'Philosophy'})),
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

    // Verify thought text is visible
    expect(find.textContaining('Simplicity is the prerequisite'), findsOneWidget);

    // Verify inline clutter chips (Plan, Todo, Reminder, Both) are NOT cluttering inside the thought bubble
    expect(find.byKey(const ValueKey('home_thought_quick_1')), findsNothing);
  });
}
