import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/features/walk/walk_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  GoogleFonts.config.allowRuntimeFetching = false;



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
