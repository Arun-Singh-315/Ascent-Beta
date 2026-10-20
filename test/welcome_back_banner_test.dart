import 'package:ascent/app/theme/app_theme.dart';
import 'package:ascent/features/home/widgets/welcome_back_banner.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  testWidgets(
    'WelcomeBackBanner renders greeting text, handles manual dismissal and timer auto-dismissal',
    (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.light(),
          home: Scaffold(
            body: WelcomeBackBanner(
              days: 4,
              visibleFor: const Duration(seconds: 4),
              onDismissed: () => dismissed = true,
            ),
          ),
        ),
      );

      // Verify initial entrance animation
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Welcome back! You were away 4 days.'), findsOneWidget);
      expect(find.byIcon(Icons.close_rounded), findsOneWidget);
      expect(dismissed, isFalse);

      // Verify close button dismisses banner
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    },
  );

  testWidgets(
    'WelcomeBackBanner auto-dismisses after visibleFor duration',
    (tester) async {
      var dismissed = false;

      await tester.pumpWidget(
        MaterialApp(
          theme: AscentTheme.dark(),
          home: Scaffold(
            body: WelcomeBackBanner(
              days: 1,
              visibleFor: const Duration(seconds: 2),
              onDismissed: () => dismissed = true,
            ),
          ),
        ),
      );

      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('Welcome back! You were away 1 day.'), findsOneWidget);
      expect(dismissed, isFalse);

      // Advance clock past duration
      await tester.pump(const Duration(seconds: 2));
      await tester.pumpAndSettle();
      expect(dismissed, isTrue);
    },
  );
}
