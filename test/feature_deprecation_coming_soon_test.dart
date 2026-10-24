import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/features/promises/promises_screen.dart';
import 'package:ascent/features/promises/providers/promise_providers.dart';
import 'package:ascent/features/study_plan/study_plan_screen.dart';
import 'package:ascent/features/walk/walk_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets('PromisesScreen renders production Promise overview with tabs', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activePromisesStreamProvider.overrideWith((ref) => Stream.value([])),
          completedPromisesStreamProvider.overrideWith((ref) => Stream.value([])),
          pausedPromisesStreamProvider.overrideWith((ref) => Stream.value([])),
        ],
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const PromisesScreen(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('Promises'), findsOneWidget);
    expect(find.text('Active'), findsOneWidget);
    expect(find.text('Completed'), findsOneWidget);
    expect(find.text('Paused'), findsOneWidget);
    expect(find.text('Make a promise'), findsWidgets);
  });

  testWidgets('StudyPlanScreen renders Coming Soon screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const StudyPlanScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coming Soon'), findsOneWidget);
    expect(find.text('Study Plan'), findsOneWidget);
  });

  testWidgets('WalkScreen renders Coming Soon screen', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AscentTheme.light(),
          home: const WalkScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Coming Soon'), findsOneWidget);
    expect(find.text('Walk & Pacing'), findsOneWidget);
  });
}
