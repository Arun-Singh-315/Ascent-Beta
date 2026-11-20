import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:ascent/features/ai_assistant/riya_paragraph_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RiyaParagraphText & Bubble Formatting Tests', () {
    const baseStyle = TextStyle(fontSize: 14.5, color: Colors.black);
    const accentColor = Color(0xFF2F6F6A);

    testWidgets('Renders simple single-line message directly', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RiyaParagraphText(
              text: 'Good afternoon Arun, how can I help today?',
              baseStyle: baseStyle,
              accentColor: accentColor,
            ),
          ),
        ),
      );

      expect(
        find.text('Good afternoon Arun, how can I help today?'),
        findsOneWidget,
      );
    });

    testWidgets('Renders multi-paragraph message with distinct spacing', (
      tester,
    ) async {
      const multiParagraph =
          'Here is your morning overview.\n\n'
          'You have 2 medicines scheduled after lunch. Hydration is currently at 500 mL.\n\n'
          'Keep your momentum steady today!';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RiyaParagraphText(
              text: multiParagraph,
              baseStyle: baseStyle,
              accentColor: accentColor,
            ),
          ),
        ),
      );

      expect(find.text('Here is your morning overview.'), findsOneWidget);
      expect(
        find.text(
          'You have 2 medicines scheduled after lunch. Hydration is currently at 500 mL.',
        ),
        findsOneWidget,
      );
      expect(find.text('Keep your momentum steady today!'), findsOneWidget);
    });

    testWidgets(
      'Renders bulleted lists with circular bullet markers and expanded text',
      (tester) async {
        const bulletListText =
            'Key priorities for today:\n'
            '• Review DSA Arrays notes\n'
            '- Log afternoon water\n'
            '* Check evening medicine schedule';

        await tester.pumpWidget(
          const MaterialApp(
            home: Scaffold(
              body: RiyaParagraphText(
                text: bulletListText,
                baseStyle: baseStyle,
                accentColor: accentColor,
              ),
            ),
          ),
        );

        expect(find.text('Key priorities for today:'), findsOneWidget);
        expect(find.text('Review DSA Arrays notes'), findsOneWidget);
        expect(find.text('Log afternoon water'), findsOneWidget);
        expect(find.text('Check evening medicine schedule'), findsOneWidget);
      },
    );

    testWidgets('Renders numbered list items with aligned number badges', (
      tester,
    ) async {
      const numberedListText =
          'Steps to complete:\n'
          '1. Drink 500 mL of water\n'
          '2. Take Vitamin D3 after breakfast\n'
          '3. Update your daily budget';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RiyaParagraphText(
              text: numberedListText,
              baseStyle: baseStyle,
              accentColor: accentColor,
            ),
          ),
        ),
      );

      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('3.'), findsOneWidget);
      expect(find.text('Drink 500 mL of water'), findsOneWidget);
    });

    testWidgets('Renders markdown section headings and blockquotes', (
      tester,
    ) async {
      const headingText =
          '### Health Summary\n\n'
          '> Hydration is on track today.\n\n'
          'All doses taken on time.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RiyaParagraphText(
              text: headingText,
              baseStyle: baseStyle,
              accentColor: accentColor,
            ),
          ),
        ),
      );

      expect(find.text('Health Summary'), findsOneWidget);
      expect(find.text('Hydration is on track today.'), findsOneWidget);
      expect(find.text('All doses taken on time.'), findsOneWidget);
    });

    testWidgets('Renders inline bold and code formatting properly', (
      tester,
    ) async {
      const formattedText =
          'Make sure to **save your changes** and run `flutter test` before committing.';

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RiyaParagraphText(
              text: formattedText,
              baseStyle: baseStyle,
              accentColor: accentColor,
            ),
          ),
        ),
      );

      expect(find.text('flutter test'), findsOneWidget);
      expect(find.byType(RichText), findsWidgets);
    });

    testWidgets('Immunity to UI overflow at 320px width with 2.0x text scale (Rule 13)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320 * 2.0, 800 * 2.0);
      tester.view.devicePixelRatio = 2.0;
      addTearDown(tester.view.resetPhysicalSize);

      const longComplexResponse =
          '### Daily Assistant Briefing\n\n'
          'Good afternoon Arun! Here is a detailed breakdown of your active commitments, upcoming health tasks, and budget allocations for the remainder of the day.\n\n'
          '• **Medicine Refill**: Paracetamol course has 2 days remaining. Consider ordering a refill soon.\n'
          '• **Hydration Target**: You have logged 500 mL out of 2500 mL. Take a glass of water to stay energized.\n'
          '• **Spending Pacing**: You have spent ₹150 today. Safe allowance is ₹938.\n\n'
          '1. Finish afternoon deep work session\n'
          '2. Evening walk for 30 minutes\n'
          '3. Mindful evening reflection\n\n'
          '> Balance daily effort with deliberate rest to maintain long-term momentum.';

      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(
            size: Size(320, 800),
            textScaler: TextScaler.linear(2.0),
          ),
          child: MaterialApp(
            home: Scaffold(
              body: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: RiyaParagraphText(
                    text: longComplexResponse,
                    baseStyle: GoogleFonts.plusJakartaSans(
                      fontSize: 14.0,
                      color: Colors.black87,
                    ),
                    accentColor: accentColor,
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Must render cleanly with zero RenderFlex exceptions
      expect(tester.takeException(), isNull);
      expect(find.text('Daily Assistant Briefing'), findsOneWidget);
      expect(find.text('1.'), findsOneWidget);
    });
  });
}
